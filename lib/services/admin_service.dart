// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:flutter/foundation.dart';

import '../models/admin_user_model.dart';
import '../models/event_model.dart';
import '../models/runner_data.dart';
import '../models/user_stats.dart';

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final _db = FirebaseDatabase.instance;
  final _storage = fs.FirebaseStorage.instance;

  // ── Role resolution ───────────────────────────────────────────────────────

  Future<AdminUser?> fetchAdminUser(String uid) async {
    final snap = await _db.ref('admins/$uid').get();
    if (!snap.exists) return null;
    return AdminUser.fromMap(uid, snap.value as Map<dynamic, dynamic>);
  }

  // ── Organizer management (Super Admin only) ───────────────────────────────

  Stream<List<AdminUser>> watchOrganizers() {
    return _db.ref('admins').onValue.map((e) {
      final data = e.snapshot.value;
      if (data == null) return <AdminUser>[];
      final map = data as Map<dynamic, dynamic>;
      return map.entries
          .map((entry) => AdminUser.fromMap(
              entry.key as String, entry.value as Map<dynamic, dynamic>))
          .where((u) => u.role == AdminRole.organizer)
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
    });
  }

  Future<void> registerOrganizerRecord(
      String uid, String email, String displayName) async {
    await _db.ref('admins/$uid').set({
      'role': 'organizer',
      'email': email,
      'displayName': displayName,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteOrganizer(String uid) async {
    await _db.ref('admins/$uid').remove();
  }

  // ── Live runners ─────────────────────────────────────────────────────────

  /// Streams all active runners sorted by distanceKm descending.
  /// Display names are resolved from user_stats so they are always accurate.
  Stream<List<RunnerData>> watchLiveRunners() {
    return _db.ref('live_runners').onValue.asyncMap((event) async {
      final data = event.snapshot.value;
      if (data == null) return <RunnerData>[];
      final map = data as Map<dynamic, dynamic>;

      // Filter out runners whose lastSeen is stale (> 10 min) — covers brief
      // background suspensions on OEM devices while still hiding truly dead
      // sessions (crash / force-quit) from the admin leaderboard.
      final cutoff = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch;

      final statsSnap = await _db.ref('user_stats').get();
      final statsMap = statsSnap.exists
          ? statsSnap.value as Map<dynamic, dynamic>
          : <dynamic, dynamic>{};

      return map.entries
          .map((e) {
            final uid = e.key as String;
            final runner =
                RunnerData.fromMap(uid, e.value as Map<dynamic, dynamic>);
            final stats = statsMap[uid];
            final resolvedName = (stats is Map)
                ? (stats['displayName'] as String? ?? '').trim()
                : '';
            final displayName = resolvedName.isNotEmpty
                ? resolvedName
                : runner.displayName.isNotEmpty &&
                        runner.displayName != 'Runner'
                    ? runner.displayName
                    : runner.email.isNotEmpty
                        ? runner.email.split('@').first
                        : uid;
            return RunnerData(
              uid: runner.uid,
              email: runner.email,
              displayName: displayName,
              photoUrl: runner.photoUrl,
              lat: runner.lat,
              lng: runner.lng,
              startedAt: runner.startedAt,
              lastSeen: runner.lastSeen,
              distanceKm: runner.distanceKm,
              eventId: runner.eventId,
              categoryId: runner.categoryId,
            );
          })
          .where((r) => r.lastSeen >= cutoff)
          .toList()
        ..sort((a, b) => b.distanceKm.compareTo(a.distanceKm));
    });
  }

  /// Streams all finisher stats for a completed event, sorted by distance desc.
  /// Cross-references user_stats so names/photos are always up to date.
  Stream<List<UserStats>> watchEventResults(String eventId) {
    return _db.ref('event_stats/$eventId').onValue.asyncMap((e) async {
      final data = e.snapshot.value;
      if (data == null) return <UserStats>[];
      final map = data as Map<dynamic, dynamic>;

      final statsSnap = await _db.ref('user_stats').get();
      final statsMap = statsSnap.exists
          ? statsSnap.value as Map<dynamic, dynamic>
          : <dynamic, dynamic>{};

      final list = map.entries.map((entry) {
        final uid = entry.key as String;
        final m = entry.value as Map<dynamic, dynamic>;
        final userStats = statsMap[uid];
        final storedName = m['displayName'] as String? ?? '';
        final resolvedName = storedName.isNotEmpty
            ? storedName
            : (userStats is Map
                ? (userStats['displayName'] as String? ?? '')
                : '');
        final resolvedEmail =
            userStats is Map ? (userStats['email'] as String? ?? '') : '';
        final storedPhoto = m['photoUrl'] as String? ?? '';
        final resolvedPhoto = storedPhoto.isNotEmpty
            ? storedPhoto
            : (userStats is Map
                ? (userStats['photoUrl'] as String? ?? '')
                : '');
        final resolvedGender = (m['gender'] as num?)?.toInt() ??
            (userStats is Map ? (userStats['gender'] as num?)?.toInt() : null);
        return UserStats(
          uid: uid,
          displayName: resolvedName,
          email: resolvedEmail,
          photoUrl: resolvedPhoto,
          totalDistanceKm: (m['distanceKm'] as num?)?.toDouble() ?? 0.0,
          totalRuns: 1,
          totalSeconds: (m['seconds'] as num?)?.toInt() ?? 0,
          categoryId: m['categoryId'] as String? ?? '',
          gender: resolvedGender,
        );
      }).toList()
        ..sort((a, b) {
          final d = b.totalDistanceKm.compareTo(a.totalDistanceKm);
          return d != 0 ? d : a.totalSeconds.compareTo(b.totalSeconds);
        });
      for (int i = 0; i < list.length; i++) {
        list[i].rank = i + 1;
      }
      return list;
    });
  }

  /// Streams runners for a specific event, sorted by distanceKm descending.
  /// Uses a server-side Firebase query (orderByChild + equalTo) so only the
  /// matching event's runners come over the wire — client-side chaining on
  /// watchLiveRunners() was unreliable when multiple events ran simultaneously.
  Stream<List<RunnerData>> watchLiveRunnersForEvent(String eventId) {
    return _db
        .ref('live_runners')
        .orderByChild('eventId')
        .equalTo(eventId)
        .onValue
        .asyncMap((event) async {
      final data = event.snapshot.value;
      if (data == null) return <RunnerData>[];
      final map = data as Map<dynamic, dynamic>;

      final statsSnap = await _db.ref('user_stats').get();
      final statsMap = statsSnap.exists
          ? statsSnap.value as Map<dynamic, dynamic>
          : <dynamic, dynamic>{};

      final now = DateTime.now().millisecondsSinceEpoch;
      final list = map.entries.map((e) {
        final uid = e.key as String;
        final runner =
            RunnerData.fromMap(uid, e.value as Map<dynamic, dynamic>);
        final stats = statsMap[uid];
        final resolvedName = (stats is Map)
            ? (stats['displayName'] as String? ?? '').trim()
            : '';
        final displayName = resolvedName.isNotEmpty
            ? resolvedName
            : runner.displayName.isNotEmpty && runner.displayName != 'Runner'
                ? runner.displayName
                : runner.email.isNotEmpty
                    ? runner.email.split('@').first
                    : uid;
        return RunnerData(
          uid: runner.uid,
          email: runner.email,
          displayName: displayName,
          photoUrl: runner.photoUrl,
          lat: runner.lat,
          lng: runner.lng,
          startedAt: runner.startedAt,
          lastSeen: runner.lastSeen,
          distanceKm: runner.distanceKm,
          eventId: runner.eventId,
          categoryId: runner.categoryId,
          isVehicle: runner.isVehicle,
        );
      }).toList();

      // Online runners (lastSeen < 2 min) first, then offline — both groups
      // sorted by distance descending so the leaderboard stays meaningful.
      list.sort((a, b) {
        final aOnline = now - a.lastSeen < 120000;
        final bOnline = now - b.lastSeen < 120000;
        if (aOnline != bOnline) return aOnline ? -1 : 1;
        return b.distanceKm.compareTo(a.distanceKm);
      });
      return list;
    });
  }

  // ── Dashboard stats ───────────────────────────────────────────────────────

  Future<Map<String, int>> fetchStats({String? organizerUid}) async {
    final results = await Future.wait([
      _db.ref('user_stats').get(),
      _db.ref('events').get(),
    ]);
    final userCount = results[0].exists ? (results[0].value as Map).length : 0;
    int eventCount = 0;
    if (results[1].exists) {
      final eventsMap = results[1].value as Map;
      if (organizerUid != null) {
        eventCount = eventsMap.values
            .whereType<Map>()
            .where((e) => e['organizerUid'] == organizerUid)
            .length;
      } else {
        eventCount = eventsMap.length;
      }
    }
    return {'users': userCount, 'events': eventCount};
  }

  /// Real-time stats stream — emits whenever the events collection changes,
  /// and fetches the latest user count alongside each emission.
  Stream<Map<String, int>> watchStats({String? organizerUid}) {
    return _db.ref('events').onValue.asyncMap((eventsEvent) async {
      final usersSnap = await _db.ref('user_stats').get();
      final userCount = usersSnap.exists ? (usersSnap.value as Map).length : 0;
      int eventCount = 0;
      if (eventsEvent.snapshot.exists) {
        final eventsMap = eventsEvent.snapshot.value as Map;
        if (organizerUid != null) {
          eventCount = eventsMap.values
              .whereType<Map>()
              .where((e) => e['organizerUid'] == organizerUid)
              .length;
        } else {
          eventCount = eventsMap.length;
        }
      }
      return {'users': userCount, 'events': eventCount};
    });
  }

  // ── Events ────────────────────────────────────────────────────────────────

  Stream<List<EventModel>> watchEvents({String? organizerUid}) {
    return _db.ref('events').orderByChild('createdAt').onValue.map((e) {
      final data = e.snapshot.value;
      if (data == null) return <EventModel>[];
      final map = data as Map<dynamic, dynamic>;
      var events = map.entries
          .map((entry) => EventModel.fromMap(
              entry.key as String, entry.value as Map<dynamic, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (organizerUid != null) {
        events = events.where((ev) => ev.organizerUid == organizerUid).toList();
      }
      debugPrint('[AdminService.watchEvents] ── EVENT LIST (${events.length} total) ──────────────────');
      for (var i = 0; i < events.length; i++) {
        final ev = events[i];
        debugPrint(
          '[AdminService.watchEvents] [$i] id=${ev.id}'
          ' | name="${ev.name}"'
          ' | date=${ev.date} startTime=${ev.startTime.isEmpty ? "none" : ev.startTime}'
          ' | isToday=${ev.isToday} isFinished=${ev.isFinished} isRunning=${ev.isRunning}'
          ' | organizer=${ev.organizerUid.isEmpty ? "none" : ev.organizerUid}'
          ' | categories=${ev.categories.keys.toList()}',
        );
      }
      debugPrint('[AdminService.watchEvents] ────────────────────────────────────────────────────────');
      return events;
    });
  }

  Future<List<EventModel>> fetchEventsPage({
    int pageSize = 15,
    EventModel? cursor,
    String? organizerUid,
  }) async {
    Query query = _db
        .ref('events')
        .orderByChild('createdAt')
        .limitToLast(cursor == null ? pageSize : pageSize + 1);

    if (cursor != null) {
      query = query.endAt(cursor.createdAt, key: cursor.id);
    }

    final snap = await query.get();
    if (!snap.exists || snap.value == null) return [];

    final map = snap.value as Map<dynamic, dynamic>;
    var events = map.entries
        .map((e) => EventModel.fromMap(
            e.key as String, e.value as Map<dynamic, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (cursor != null) {
      events.removeWhere((e) => e.id == cursor.id);
    }

    if (organizerUid != null) {
      events = events.where((ev) => ev.organizerUid == organizerUid).toList();
    }

    debugPrint('[AdminService.fetchEventsPage] ── PAGE (${events.length} events, cursor=${cursor?.id}) ──────────────');
    for (var i = 0; i < events.length; i++) {
      final ev = events[i];
      debugPrint(
        '[AdminService.fetchEventsPage] [$i] id=${ev.id}'
        ' | name="${ev.name}"'
        ' | date=${ev.date} startTime=${ev.startTime.isEmpty ? "none" : ev.startTime}'
        ' | isToday=${ev.isToday} isFinished=${ev.isFinished} isRunning=${ev.isRunning}'
        ' | organizer=${ev.organizerUid.isEmpty ? "none" : ev.organizerUid}'
        ' | categories=${ev.categories.keys.toList()}',
      );
    }
    debugPrint('[AdminService.fetchEventsPage] ────────────────────────────────────────────────────────');

    return events;
  }

  Future<String> createEvent(Map<String, dynamic> data) async {
    final ref = _db.ref('events').push();
    await ref.set(data);
    return ref.key!;
  }

  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    await _db.ref('events/$id').update(data);
  }

  Future<void> deleteEvent(String id) async {
    await _db.ref('events/$id').remove();
    try {
      final storageRef = _storage.ref('events/$id');
      await _deleteFolder(storageRef);
    } catch (_) {}
  }

  Future<void> _deleteFolder(fs.Reference ref) async {
    final list = await ref.listAll();
    for (final item in list.items) {
      await item.delete();
    }
    for (final prefix in list.prefixes) {
      await _deleteFolder(prefix);
    }
  }

  // ── File uploads ──────────────────────────────────────────────────────────

  Future<({String name, Uint8List bytes})?> pickFile(String accept) async {
    final input = html.FileUploadInputElement()..accept = accept;
    input.click();
    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return null;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    return (
      name: file.name,
      bytes: Uint8List.fromList(reader.result as List<int>),
    );
  }

  Future<String> uploadBanner(String eventId, Uint8List bytes) async {
    final ref = _storage.ref('events/$eventId/banner.jpg');
    await ref.putData(bytes, fs.SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<String> uploadKml(String eventId, String categoryId, String fileName,
      Uint8List bytes) async {
    final storagePath = 'events/$eventId/kml/$categoryId.kml';
    final ref = _storage.ref(storagePath);
    await ref.putData(
        bytes,
        fs.SettableMetadata(
            contentType: 'application/vnd.google-earth.kml+xml'));
    return ref.getDownloadURL();
  }

  Future<Uint8List?> downloadKml(String kmlPath) async {
    try {
      return await _storage.ref(kmlPath).getData();
    } catch (_) {
      return null;
    }
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final snap = await _db.ref('user_stats').get();
    if (!snap.exists) return [];
    final map = snap.value as Map<dynamic, dynamic>;
    return map.entries.map((e) {
      final data = e.value as Map<dynamic, dynamic>;
      return {
        'uid': e.key as String,
        'displayName': data['displayName'] as String? ?? '',
        'email': data['email'] as String? ?? '',
        'photoUrl': data['photoUrl'] as String? ?? '',
        'totalDistanceKm': (data['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
        'totalRuns': (data['totalRuns'] as num?)?.toInt() ?? 0,
        'totalSeconds': (data['totalSeconds'] as num?)?.toInt() ?? 0,
      };
    }).toList()
      ..sort((a, b) => (b['totalDistanceKm'] as double)
          .compareTo(a['totalDistanceKm'] as double));
  }
}
