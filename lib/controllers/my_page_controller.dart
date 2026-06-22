import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:google_sign_in/google_sign_in.dart';
import '../controllers/auth_controller.dart';
import '../core/config.dart';
import '../core/image_utils.dart';
import '../models/group_model.dart';
import '../models/user_stats.dart';
import '../services/firebase_service.dart';
import '../services/friends_service.dart';
import '../services/group_service.dart';
import '../services/offline_storage_service.dart';
import '../services/user_stats_service.dart';

class MyPageController extends GetxController {
  final routeRefs = <fs.Reference>[].obs;
  final localPendingNames = <String>[].obs;
  final myGroups = <GroupModel>[].obs;
  final isLoading = false.obs;
  final isUploading = false.obs;
  final myStats = Rxn<UserStats>();
  final photoUrlObs = ''.obs;
  final displayNameObs = ''.obs;
  final ageObs = 0.obs;

  StreamSubscription? _statsSub;
  StreamSubscription? _groupsSub;

  User? get user => FirebaseAuth.instance.currentUser;

  String get displayName {
    if (displayNameObs.value.isNotEmpty) return displayNameObs.value;
    final raw = user?.displayName ?? '';
    if (raw.isNotEmpty) return raw;
    return 'Runner';
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
      // Seed displayNameObs from the DB if Firebase Auth hasn't synced yet
      // (e.g. right after signup before updateProfile propagates).
      if (displayNameObs.value.isEmpty && (s?.displayName.isNotEmpty ?? false)) {
        displayNameObs.value = s!.displayName;
      }
    });
    _groupsSub = GroupService.instance.watchAllMyGroups().listen((list) {
      myGroups.value = list;
    });
  }

  @override
  void onClose() {
    _statsSub?.cancel();
    _groupsSub?.cancel();
    super.onClose();
  }

  Future<void> fetchRoutes() async {
    final uid = user?.uid;
    if (uid == null) return;

    // 1. Load from local index immediately — no spinner, instant display
    final cachedNames =
        await OfflineStorageService.instance.getCachedRouteNames(uid);
    if (cachedNames.isNotEmpty && routeRefs.isEmpty) {
      routeRefs.value = cachedNames
          .map((n) => fs.FirebaseStorage.instance
              .ref('${AppConfig.routesStoragePath}/$uid/$n'))
          .toList();
    }

    // 2. Show pending-upload names (local only, not yet on cloud)
    localPendingNames.value =
        await OfflineStorageService.instance.getPendingFileNames(uid);

    // 3. Refresh from cloud in background
    isLoading.value = true;
    try {
      final refs = await FirebaseService.instance.fetchSavedRouteRefs();
      final refNames = refs.map((r) => r.name).toSet();
      // Preserve any locally-saved files not yet returned by listAll()
      // (Firebase Storage can take a few seconds to index a newly uploaded file)
      final localOnly = cachedNames.where((n) => !refNames.contains(n)).toList();
      final merged = [
        ...refs,
        ...localOnly.map((n) => fs.FirebaseStorage.instance
            .ref('${AppConfig.routesStoragePath}/$uid/$n')),
      ];
      await OfflineStorageService.instance
          .cacheRouteNames(uid, merged.map((r) => r.name).toList());
      routeRefs.value = merged;
    } catch (_) {
      // Keep cached data — already shown above
    } finally {
      isLoading.value = false;
    }
  }

  // ── Profile image upload ──────────────────────────────────────────────────

  Future<void> uploadProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    isUploading.value = true;
    try {
      final u = user;
      if (u == null) return;
      final raw = await picked.readAsBytes();
      final bytes = await compressImageUnder1MB(raw);
      if (bytes == null) {
        Get.snackbar('', 'image_too_large'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade600,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12));
        return;
      }
      final ref = fs.FirebaseStorage.instance.ref('profile_images/${u.uid}.jpg');
      await ref.putData(bytes, fs.SettableMetadata(contentType: 'image/jpeg'));
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

  Future<void> updateGender(int gender) async {
    await UserStatsService.instance.updateGender(gender);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final u = user;
    if (u == null || u.email == null) return;
    final cred = EmailAuthProvider.credential(email: u.email!, password: currentPassword);
    await u.reauthenticateWithCredential(cred);
    await u.updatePassword(newPassword);
  }

  Future<void> updateEmail(String newEmail, String currentPassword) async {
    final u = user;
    if (u == null || u.email == null) return;
    final cred = EmailAuthProvider.credential(email: u.email!, password: currentPassword);
    await u.reauthenticateWithCredential(cred);
    await u.verifyBeforeUpdateEmail(newEmail);
    await UserStatsService.instance.registerOrUpdate();
  }

  bool get isGoogleUser =>
      FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  bool get isAppleUser =>
      FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'apple.com') ??
      false;

  Future<void> deleteAccount(String password) async {
    final u = user;
    if (u == null || u.email == null) return;
    final authCtrl = Get.find<AuthController>();
    authCtrl.suppressAuthNav = true;
    try {
      final cred = EmailAuthProvider.credential(email: u.email!, password: password);
      await u.reauthenticateWithCredential(cred);
      _cancelSubscriptions();
      await u.delete();
    } finally {
      authCtrl.suppressAuthNav = false;
    }
  }

  Future<void> deleteAccountWithGoogle() async {
    final u = user;
    if (u == null) return;
    final authCtrl = Get.find<AuthController>();
    authCtrl.suppressAuthNav = true;
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign-in cancelled');
      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await u.reauthenticateWithCredential(cred);
      _cancelSubscriptions();
      await u.delete();
    } finally {
      authCtrl.suppressAuthNav = false;
    }
  }

  Future<void> deleteAccountWithApple() async {
    final u = user;
    if (u == null) return;
    final authCtrl = Get.find<AuthController>();
    authCtrl.suppressAuthNav = true;
    try {
      final appleProvider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('fullName');
      await u.reauthenticateWithProvider(appleProvider);
      _cancelSubscriptions();
      await u.delete();
    } finally {
      authCtrl.suppressAuthNav = false;
    }
  }

  void _cancelSubscriptions() {
    _statsSub?.cancel();
    _statsSub = null;
    _groupsSub?.cancel();
    _groupsSub = null;
  }

  Future<void> signOut() async {
    await Get.find<AuthController>().signOut();
  }
}
