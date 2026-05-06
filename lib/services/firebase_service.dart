import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import '../core/config.dart';
import '../models/kml_route.dart';
import '../models/tracked_route.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final _storage = fs.FirebaseStorage.instance;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  String get _userRoutesPath => '${AppConfig.routesStoragePath}/$_uid';

  Future<List<KmlRoute>> fetchKmlRoutes() async {
    final result = await _storage.ref(AppConfig.kmlStoragePath).listAll();
    final paths = result.items.map((item) => item.fullPath).toList()
      ..sort((a, b) => b.compareTo(a));
    return paths.map(KmlRoute.fromStoragePath).toList();
  }

  Future<String> getDownloadUrl(String storagePath) async {
    return await _storage.ref(storagePath).getDownloadURL();
  }

  Future<void> saveTrackedRoute(String fileName, String jsonBody) async {
    final ref = _storage.ref('$_userRoutesPath/$fileName');
    await ref.putString(jsonBody);
  }

  Future<List<fs.Reference>> fetchSavedRouteRefs() async {
    final result = await _storage.ref(_userRoutesPath).listAll();
    final sorted = result.items
        .where((item) => item.name.endsWith('.json'))
        .toList()
      ..sort((a, b) => TrackedRoute.parseDateTimeFromFileName(b.name)
          .compareTo(TrackedRoute.parseDateTimeFromFileName(a.name)));
    // Deduplicate: keep only the most recent run per event+date combo.
    // Handles the case where a user starts, stops early, then starts again.
    final seen = <String>{};
    final deduped = <fs.Reference>[];
    for (final ref in sorted) {
      final key = _runDayKey(ref.name);
      if (seen.add(key)) deduped.add(ref);
    }
    return deduped;
  }

  /// Extracts a deduplication key: slug + date, dropping the HH-mm time part.
  /// Files with the same event name and calendar date collapse to one record.
  static String _runDayKey(String fileName) {
    final base = fileName.replaceAll('.json', '');
    final parts = base.split('_');
    if (parts.length >= 2) {
      final datePart = parts[parts.length - 2];
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
        return parts.sublist(0, parts.length - 1).join('_');
      }
    }
    return fileName;
  }

  /// Saves a photo taken during a run.
  /// [runStartMs] must match the timestamp in the route filename.
  Future<void> saveRunPhoto(int runStartMs, Uint8List bytes) async {
    final photoTs = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref(
        '${AppConfig.routesStoragePath}/$_uid/photos/$runStartMs/photo_$photoTs.jpg');
    await ref.putData(
        bytes, fs.SettableMetadata(contentType: 'image/jpeg'));
  }

  /// Lists photo references for a saved route identified by its storage path.
  /// [runStartMs] is preferred (from route JSON); falls back to filename parsing.
  Future<List<fs.Reference>> fetchRunPhotoRefs(
      String routeStoragePath, {int runStartMs = 0}) async {
    try {
      final parts = routeStoragePath.split('/');
      final uid = parts.length > 1 ? parts[1] : (_uid);
      String ts;
      if (runStartMs > 0) {
        ts = '$runStartMs';
      } else {
        // Legacy: extract ms timestamp from old filename format my_route_{ms}.json
        ts = parts.last.replaceAll('.json', '').split('_').last;
      }
      final photoPath = '${AppConfig.routesStoragePath}/$uid/photos/$ts';
      final result = await _storage.ref(photoPath).listAll();
      return result.items;
    } catch (_) {
      return [];
    }
  }
}
