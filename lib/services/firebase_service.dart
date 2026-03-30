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
}
