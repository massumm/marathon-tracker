import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import '../core/config.dart';
import '../models/kml_route.dart';

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
    final filtered = result.items
        .where((item) => item.name.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.name.compareTo(a.name));
    return filtered;
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
  Future<List<fs.Reference>> fetchRunPhotoRefs(
      String routeStoragePath) async {
    try {
      final parts = routeStoragePath.split('/');
      // path: routes/{uid}/my_route_{ts}.json  → parts[1]=uid, parts[2]=filename
      final uid = parts[1];
      final ts = parts.last.replaceAll('.json', '').split('_').last;
      final photoPath =
          '${AppConfig.routesStoragePath}/$uid/photos/$ts';
      final result = await _storage.ref(photoPath).listAll();
      return result.items;
    } catch (_) {
      return [];
    }
  }
}
