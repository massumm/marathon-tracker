import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/auth_controller.dart';
import '../models/user_stats.dart';
import '../services/firebase_service.dart';
import '../services/friends_service.dart';
import '../services/user_stats_service.dart';

class MyPageController extends GetxController {
  final routeRefs = <fs.Reference>[].obs;
  final isLoading = false.obs;
  final isUploading = false.obs;
  final myStats = Rxn<UserStats>();
  final photoUrlObs = ''.obs;
  final displayNameObs = ''.obs;
  final ageObs = 0.obs;

  StreamSubscription? _statsSub;

  User? get user => FirebaseAuth.instance.currentUser;

  String get displayName {
    if (displayNameObs.value.isNotEmpty) return displayNameObs.value;
    final raw = user?.displayName ?? '';
    if (raw.isNotEmpty) return raw;
    final email = user?.email ?? '';
    return email.isNotEmpty ? email.split('@').first : 'Runner';
  }

  @override
  void onInit() {
    super.onInit();
    photoUrlObs.value = user?.photoURL ?? '';
    displayNameObs.value = user?.displayName ?? '';
    fetchRoutes();
    _statsSub = UserStatsService.instance.watchMyStats().listen((s) {
      myStats.value = s;
      if (s != null && s.age > 0) ageObs.value = s.age;
    });
  }

  @override
  void onClose() {
    _statsSub?.cancel();
    super.onClose();
  }

  Future<void> fetchRoutes() async {
    isLoading.value = true;
    try {
      routeRefs.value =
          await FirebaseService.instance.fetchSavedRouteRefs();
    } catch (_) {
      routeRefs.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  // ── Profile image upload ──────────────────────────────────────────────────

  Future<void> uploadProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    isUploading.value = true;
    try {
      final u = user;
      if (u == null) return;
      final bytes = await picked.readAsBytes();
      final ref = fs.FirebaseStorage.instance
          .ref('profile_images/${u.uid}.jpg');
      await ref.putData(
          bytes, fs.SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await u.updatePhotoURL(url);
      await FriendsService.instance.registerProfile();
      await UserStatsService.instance.registerOrUpdate(photoUrl: url);
      photoUrlObs.value = url;
    } finally {
      isUploading.value = false;
    }
  }

  // ── Display name edit ─────────────────────────────────────────────────────

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final u = user;
    if (u == null) return;
    isLoading.value = true;
    try {
      await u.updateDisplayName(trimmed);
      await FriendsService.instance.registerProfile();
      await UserStatsService.instance.registerOrUpdate(displayName: trimmed);
      displayNameObs.value = trimmed;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateAge(int age) async {
    await UserStatsService.instance.updateAge(age);
    ageObs.value = age;
  }

  Future<void> sendPasswordReset() async {
    final email = user?.email;
    if (email == null) return;
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> updateEmail(String newEmail) async {
    final u = user;
    if (u == null) return;
    await u.verifyBeforeUpdateEmail(newEmail);
    await UserStatsService.instance.registerOrUpdate();
  }

  Future<void> deleteAccount() async {
    final u = user;
    if (u == null) return;
    await u.delete();
    await Get.find<AuthController>().signOut();
  }

  Future<void> signOut() async {
    await Get.find<AuthController>().signOut();
  }
}
