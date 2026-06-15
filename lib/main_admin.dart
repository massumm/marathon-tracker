import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'models/admin_user_model.dart';
import 'screens/admin/auth/admin_login_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/admin/organizer/organizer_shell.dart';
import 'services/admin_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  runApp(const AdminPanelApp());
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (!e.code.contains('duplicate-app')) rethrow;
  }
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.theme,
      title: 'Marathon Map Admin',
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return _RoleRouter(uid: snapshot.data!.uid);
          }
          return const AdminLoginScreen();
        },
      ),
    );
  }
}

class _RoleRouter extends StatefulWidget {
  final String uid;
  const _RoleRouter({required this.uid});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  AdminUser? _adminUser;
  bool _loading = true;
  bool _unauthorized = false;

  // Absolute session cap — force logout regardless of activity.
  static const _sessionTimeout = Duration(hours: 8);
  static const _sessionKey = 'admin_session_start';

  // Idle timeout — logout if no pointer interaction for this long.
  static const _idleTimeout = Duration(days: 1);

  Timer? _idleTimer;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _resolveRole();
    _resetIdleTimer();
    _initSession();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ── Idle timer ────────────────────────────────────────────────────────────

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _doSignOut);
  }

  // ── Absolute session timer ────────────────────────────────────────────────

  void _initSession() {
    final stored = html.window.localStorage[_sessionKey];
    final now = DateTime.now().millisecondsSinceEpoch;

    if (stored != null) {
      final loginMs = int.tryParse(stored);
      if (loginMs != null) {
        final elapsed = now - loginMs;
        if (elapsed >= _sessionTimeout.inMilliseconds) {
          // Already expired before the widget even mounted — sign out next frame.
          WidgetsBinding.instance.addPostFrameCallback((_) => _doSignOut());
          return;
        }
        // Session still valid — fire timer for the remaining window.
        final remaining =
            Duration(milliseconds: _sessionTimeout.inMilliseconds - elapsed);
        _sessionTimer = Timer(remaining, _doSignOut);
        return;
      }
    }

    // Fresh login — record the start time and start the full timer.
    html.window.localStorage[_sessionKey] = now.toString();
    _sessionTimer = Timer(_sessionTimeout, _doSignOut);
  }

  // Called for both idle expiry and absolute session expiry, and manual logout.
  void _doSignOut() {
    html.window.localStorage.remove(_sessionKey);
    FirebaseAuth.instance.signOut();
  }

  // ── Role resolution ───────────────────────────────────────────────────────

  Future<void> _resolveRole() async {
    final user = await AdminService.instance.fetchAdminUser(widget.uid);
    if (mounted) {
      setState(() {
        _adminUser = user;
        _loading = false;
        _unauthorized = user == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_unauthorized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account is not authorized to access this panel.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _doSignOut,
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      );
    }

    final adminUser = _adminUser!;
    final shell = adminUser.isSuperAdmin
        ? AdminShell(onSignOut: _doSignOut)
        : OrganizerShell(organizer: adminUser, onSignOut: _doSignOut);

    // Any pointer interaction resets the idle timer.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerMove: (_) => _resetIdleTimer(),
      onPointerSignal: (_) => _resetIdleTimer(),
      child: shell,
    );
  }
}
