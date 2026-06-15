import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config.dart';

class OfflineStorageService {
  OfflineStorageService._();
  static final instance = OfflineStorageService._();

  late Directory _root;
  final isOnline = Rxn<bool>();
  final pendingRunCount = 0.obs;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}/offline_routes');
    await _root.create(recursive: true);

    // Seed observable from disk
    final existing = await _loadPendingRuns();
    pendingRunCount.value = existing.length;

    FirebaseDatabase.instance.ref('.info/connected').onValue.listen((e) async {
      final connected = e.snapshot.value as bool? ?? false;
      isOnline.value = connected;
      if (connected) {
        await _syncPending();
        await syncPendingRuns();
      }
    });
  }

  // ── Run save ──────────────────────────────────────────────────────────────

  /// Saves route JSON to local storage. Never fails — call before cloud upload.
  Future<void> saveRouteLocally(String uid, String fileName, String json) async {
    final dir = Directory('${_root.path}/data/$uid');
    await dir.create(recursive: true);
    await File('${dir.path}/$fileName').writeAsString(json);
    // Update local index
    final names = await getCachedRouteNames(uid);
    if (!names.contains(fileName)) {
      names.insert(0, fileName);
      await _writeIndex(uid, names);
    }
  }

  /// Returns locally saved JSON for a route, or null if not found.
  Future<String?> getLocalRouteJson(String uid, String fileName) async {
    final file = File('${_root.path}/data/$uid/$fileName');
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Marks a route file as needing upload to Firebase Storage.
  Future<void> markPending(String uid, String fileName) async {
    final pending = await _loadPending();
    final key = '$uid/$fileName';
    if (!pending.contains(key)) {
      pending.add(key);
      await _writePending(pending);
    }
  }

  /// Returns file names saved locally but not yet uploaded for the given uid.
  Future<List<String>> getPendingFileNames(String uid) async {
    final pending = await _loadPending();
    return pending
        .where((k) => k.startsWith('$uid/'))
        .map((k) => k.substring(uid.length + 1))
        .toList();
  }

  // ── Route list index ──────────────────────────────────────────────────────

  /// Returns cached route file names for uid (newest first).
  Future<List<String>> getCachedRouteNames(String uid) async {
    final file = File('${_root.path}/index/$uid.json');
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheRouteNames(String uid, List<String> names) =>
      _writeIndex(uid, names);

  // ── Content cache (route detail JSON) ────────────────────────────────────

  /// Returns cached JSON body for a Firebase Storage path, or null.
  Future<String?> getCachedContent(String storagePath) async {
    final file = _cacheFile(storagePath);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Caches downloaded JSON body for a Firebase Storage path.
  Future<void> cacheContent(String storagePath, String json) async {
    final dir = Directory('${_root.path}/content_cache');
    await dir.create(recursive: true);
    await _cacheFile(storagePath).writeAsString(json);
  }

  File _cacheFile(String storagePath) {
    final safe = storagePath.replaceAll('/', '__');
    return File('${_root.path}/content_cache/$safe.json');
  }

  // ── Pending runs queue ────────────────────────────────────────────────────

  /// Adds a run to the pending queue. Deduplicates by runId.
  Future<void> enqueuePendingRun({
    required String runId,
    required String uid,
    required String fileName,
    required double distanceKm,
    required int seconds,
    required String eventId,
    required String displayName,
    required String photoUrl,
    String categoryId = '',
  }) async {
    final runs = await _loadPendingRuns();
    if (runs.any((r) => r['runId'] == runId)) return;
    runs.add({
      'runId': runId,
      'uid': uid,
      'fileName': fileName,
      'distanceKm': distanceKm,
      'seconds': seconds,
      'eventId': eventId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'categoryId': categoryId,
    });
    await _writePendingRuns(runs);
    pendingRunCount.value = runs.length;
  }

  Future<List<Map<String, dynamic>>> _loadPendingRuns() async {
    final file = File('${_root.path}/pending_runs.json');
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writePendingRuns(List<Map<String, dynamic>> runs) =>
      File('${_root.path}/pending_runs.json')
          .writeAsString(jsonEncode(runs));

  /// Syncs all pending runs: uploads Storage + writes RTDB stats.
  /// Leaves failed entries in the queue for the next connectivity event.
  Future<void> syncPendingRuns() async {
    final runs = await _loadPendingRuns();
    if (runs.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final run in List<Map<String, dynamic>>.from(runs)) {
      try {
        final uid = run['uid'] as String;
        final fileName = run['fileName'] as String;
        final distanceKm = (run['distanceKm'] as num).toDouble();
        final seconds = run['seconds'] as int;
        final eventId = run['eventId'] as String? ?? '';
        final displayName = run['displayName'] as String? ?? '';
        final photoUrl = run['photoUrl'] as String? ?? '';
        final categoryId = run['categoryId'] as String? ?? '';

        // 1. Upload route JSON to Firebase Storage
        final file = File('${_root.path}/data/$uid/$fileName');
        if (await file.exists()) {
          final jsonBody = await file.readAsString();
          final ref = fs.FirebaseStorage.instance
              .ref('${AppConfig.routesStoragePath}/$uid/$fileName');
          await ref.putString(jsonBody,
              metadata:
                  fs.SettableMetadata(contentType: 'application/json'));
        }

        // 2. Update global user stats via RTDB
        final db = FirebaseDatabase.instance;
        await db.ref('user_stats/$uid').update({
          'totalDistanceKm': ServerValue.increment(distanceKm),
          'totalRuns': ServerValue.increment(1),
          'totalSeconds': ServerValue.increment(seconds),
        });

        // 3. Event-scoped stats (if applicable)
        if (eventId.isNotEmpty) {
          int? gender;
          try {
            final gSnap = await db.ref('user_stats/$uid/gender').get();
            gender = gSnap.exists ? (gSnap.value as num?)?.toInt() : null;
          } catch (_) {}

          await db.ref('event_stats/$eventId/$uid').update({
            'distanceKm': distanceKm,
            'seconds': seconds,
            'displayName': displayName,
            'photoUrl': photoUrl,
            'categoryId': categoryId,
            if (gender != null) 'gender': gender,
            'updatedAt': ServerValue.timestamp,
          });
        }
        // Success — do not re-add to remaining
      } catch (_) {
        remaining.add(run);
      }
    }

    await _writePendingRuns(remaining);
    pendingRunCount.value = remaining.length;
  }

  // ── Pending sync ──────────────────────────────────────────────────────────

  Future<void> _syncPending() async {
    final pending = await _loadPending();
    if (pending.isEmpty) return;

    final stillPending = <String>[];
    for (final key in List<String>.from(pending)) {
      try {
        final slash = key.indexOf('/');
        final uid = key.substring(0, slash);
        final fileName = key.substring(slash + 1);
        final file = File('${_root.path}/data/$uid/$fileName');
        if (!await file.exists()) continue;

        final jsonBody = await file.readAsString();
        final ref = fs.FirebaseStorage.instance
            .ref('${AppConfig.routesStoragePath}/$uid/$fileName');
        await ref.putString(jsonBody,
            metadata:
                fs.SettableMetadata(contentType: 'application/json'));
      } catch (_) {
        stillPending.add(key);
      }
    }
    await _writePending(stillPending);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<List<String>> _loadPending() async {
    final file = File('${_root.path}/pending.json');
    if (!await file.exists()) return [];
    try {
      return (jsonDecode(await file.readAsString()) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writePending(List<String> pending) =>
      File('${_root.path}/pending.json').writeAsString(jsonEncode(pending));

  Future<void> _writeIndex(String uid, List<String> names) async {
    final dir = Directory('${_root.path}/index');
    await dir.create(recursive: true);
    await File('${_root.path}/index/$uid.json').writeAsString(jsonEncode(names));
  }
}
