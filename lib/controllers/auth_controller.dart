import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../app/routes/app_routes.dart';
import '../services/friends_service.dart';
import '../services/user_stats_service.dart';

class AuthController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

  final isLoading = false.obs;

  User? get currentUser => _auth.currentUser;

  @override
  void onReady() {
    super.onReady();
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        FriendsService.instance.registerProfile();
        UserStatsService.instance.registerOrUpdate();
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
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
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

  Future<void> signUpWithEmail(String email, String password) async {
    isLoading.value = true;
    try {
      await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
