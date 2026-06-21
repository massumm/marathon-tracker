import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../app/routes/app_routes.dart';
import '../services/deep_link_service.dart';
import '../services/friends_service.dart';
import '../services/user_stats_service.dart';

class AuthController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  final isLoading = false.obs;
  bool suppressAuthNav = false;

  String? _pendingUsername;
  int? _pendingGender;
  bool _pendingVerification = false;

  User? get currentUser => _auth.currentUser;

  @override
  void onReady() {
    super.onReady();
    _auth.authStateChanges().listen((user) {
      if (_pendingVerification || suppressAuthNav) return;
      if (user != null) {
        final username = _pendingUsername;
        final gender = _pendingGender;
        _pendingUsername = null;
        _pendingGender = null;
        FriendsService.instance.registerProfile(displayName: username);
        UserStatsService.instance.registerOrUpdate(displayName: username, gender: gender);
        Get.offAllNamed(AppRoutes.home);
        DeepLinkService.instance.retryPending();
      } else {
        Get.offAllNamed(AppRoutes.login);
      }
    });
  }

  Future<void> signInWithGoogle() async {
    isLoading.value = true;
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      debugPrint('Google idToken: ${googleAuth.idToken}');
      debugPrint('Google accessToken: ${googleAuth.accessToken}');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    isLoading.value = true;
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signUpWithEmail(
      String email, String password, String username,
      {int? gender}) async {
    isLoading.value = true;
    try {
      // Store before creation so authStateChanges listener picks it up.
      _pendingUsername = username.trim();
      _pendingGender = gender;
      _pendingVerification = true;
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.updateProfile(displayName: username.trim());
      await cred.user?.sendEmailVerification();
      Get.offAllNamed(AppRoutes.emailVerification, arguments: email.trim());
    } catch (e) {
      _pendingUsername = null;
      _pendingGender = null;
      _pendingVerification = false;
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithApple() async {
    isLoading.value = true;
    try {
      final appleProvider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('fullName');
      final result = await _auth.signInWithProvider(appleProvider);
      // Apple only sends the display name on first sign-in.
      // authStateChanges fires during signInWithProvider, so we update the
      // services again here if a name is available.
      final name = result.user?.displayName;
      if (name != null && name.isNotEmpty) {
        FriendsService.instance.registerProfile(displayName: name);
        UserStatsService.instance.registerOrUpdate(displayName: name);
      }
    } catch (e) {
      debugPrint('Apple Sign-In error: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    final verified = _auth.currentUser?.emailVerified ?? false;
    if (verified) {
      _pendingVerification = false;
      final username = _pendingUsername;
      final gender = _pendingGender;
      _pendingUsername = null;
      _pendingGender = null;
      FriendsService.instance.registerProfile(displayName: username);
      UserStatsService.instance.registerOrUpdate(displayName: username, gender: gender);
      Get.offAllNamed(AppRoutes.home);
      DeepLinkService.instance.retryPending();
    }
    return verified;
  }

  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
