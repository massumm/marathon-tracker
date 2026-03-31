import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../services/firebase_service.dart';

class MyPageController extends GetxController {
  final routeRefs = <fs.Reference>[].obs;
  final isLoading = false.obs;

  User? get user => FirebaseAuth.instance.currentUser;

  String get displayName {
    final raw = user?.displayName ?? '';
    if (raw.isNotEmpty) return raw;
    final email = user?.email ?? '';
    return email.isNotEmpty ? email.split('@').first : 'Runner';
  }

  @override
  void onInit() {
    super.onInit();
    fetchRoutes();
  }

  Future<void> fetchRoutes() async {
    isLoading.value = true;
    try {
      routeRefs.value = await FirebaseService.instance.fetchSavedRouteRefs();
    } catch (_) {
      routeRefs.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await Get.find<AuthController>().signOut();
  }
}
