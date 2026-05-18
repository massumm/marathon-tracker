import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../app/routes/app_routes.dart';
import '../services/friends_service.dart';
import '../services/live_tracking_service.dart';
import '../services/user_stats_service.dart';

class AuthController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  final isLoading = false.obs;

  // Username set just before account creation so the authStateChanges listener
  // can write the correct displayName when it fires.
  String? _pendingUsername;

  User? get currentUser => _auth.currentUser;

  @override
  void onReady() {
    super.onReady();
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        final username = _pendingUsername;
        _pendingUsername = null;
        FriendsService.instance.registerProfile(displayName: username);
        UserStatsService.instance.registerOrUpdate(displayName: username);
        //LiveTrackingService.instance.cleanupStaleBroadcast();
        //UserStatsService.instance.syncPendingStats();
        Get.offAllNamed(AppRoutes.home);
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
      String email, String password, String username) async {
    isLoading.value = true;
    try {
      // Store before creation so authStateChanges listener picks it up.
      _pendingUsername = username.trim();
      await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
    } catch (e) {
      _pendingUsername = null;
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
