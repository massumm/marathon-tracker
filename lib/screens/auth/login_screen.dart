import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme.dart';

enum _AuthMode { signIn, signUp }

class LoginScreen extends GetView<AuthController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginBody();
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _auth = Get.find<AuthController>();
  _AuthMode _mode = _AuthMode.signIn;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int? _selectedGender;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    _formKey.currentState?.reset();
    _emailCtrl.clear();
    _usernameCtrl.clear();
    _passwordCtrl.clear();
    _confirmCtrl.clear();
    setState(() {
      _mode = mode;
      _selectedGender = null;
    });
  }

  void _showError(String message) {
    Get.snackbar('Error', message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      if (_mode == _AuthMode.signIn) {
        await _auth.signInWithEmail(_emailCtrl.text, _passwordCtrl.text);
      } else {
        await _auth.signUpWithEmail(
            _emailCtrl.text, _passwordCtrl.text, _usernameCtrl.text.trim(),
            gender: _selectedGender);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] FirebaseAuthException → code=${e.code} message=${e.message} email=${e.email} credential=${e.credential}');
      _showError(_friendlyError(e.code));
    } catch (e) {
      debugPrint('[Auth] Unknown error → $e');
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showForgotPassword() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    Get.dialog(AlertDialog(
      title: const Text('Forgot Password?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter your email and we\'ll send you a reset link.'),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@example.com'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            final email = emailCtrl.text.trim();
            if (email.isEmpty) return;
            try {
              await _auth.sendPasswordReset(email);
              Get.back();
              Get.snackbar('Email Sent', 'Check your inbox for a reset link.',
                  snackPosition: SnackPosition.BOTTOM);
            } on FirebaseAuthException catch (e) {
              Get.back();
              _showError(_friendlyError(e.code));
            } catch (e) {
              Get.back();
              _showError('Something went wrong. Please try again.');
            }
          },
          child: const Text('Send'),
        ),
      ],
    ));
  }

  Future<void> _signInWithGoogle() async {
    try {
      await _auth.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyError(e.code));
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _signInWithApple() async {
    try {
      await _auth.signInWithApple();
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyError(e.code));
    } catch (e) {
      _showError(e.toString());
    }
  }

  String _friendlyError(String code) => switch (code) {
        'user-not-found' => 'No account found for that email.',
        'wrong-password' => 'Incorrect password.',
        'invalid-credential' => 'Incorrect email or password.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Password must be at least 6 characters.',
        'invalid-email' => 'Please enter a valid email address.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'No internet connection.',
        _ => 'Authentication failed. Please try again.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 32),
              _buildToggle(),
              const SizedBox(height: 28),
              _buildForm(),
              const SizedBox(height: 20),
              _buildSubmitButton(),
              const SizedBox(height: 24),
              _buildDivider(),
              const SizedBox(height: 20),
              _buildGoogleButton(),
              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                _buildAppleButton(),
              ],
              const SizedBox(height: 24),
              Text(
                'By continuing you agree to our Terms of Service.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child:
              const Icon(Icons.directions_run, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 20),
        const Text('RunMate',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('Track your marathon route\nand relive every kilometer.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
      ]);

  Widget _buildToggle() => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEEF0F5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(children: [
          _ToggleTab(
              label: 'Sign In',
              selected: _mode == _AuthMode.signIn,
              onTap: () => _switchMode(_AuthMode.signIn)),
          _ToggleTab(
              label: 'Create Account',
              selected: _mode == _AuthMode.signUp,
              onTap: () => _switchMode(_AuthMode.signUp)),
        ]),
      );

  Widget _buildForm() => Form(
        key: _formKey,
        child: Column(children: [
          if (_mode == _AuthMode.signUp) ...[
            TextFormField(
              controller: _usernameCtrl,
              textInputAction: TextInputAction.next,
              decoration: _inputDeco(
                label: 'Username',
                hint: 'Your display name',
                icon: Icons.person_outline,
              ),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return 'Username is required';
                if (val.length < 3) return 'Minimum 3 characters';
                if (val.length > 30) return 'Maximum 30 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _selectedGender,
              decoration: _inputDeco(
                label: 'Gender',
                hint: 'Select gender',
                icon: Icons.person_outline,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              isDense: true,
              items: const [
                DropdownMenuItem(
                  value: 0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Male', style: TextStyle(fontSize: 13)),
                  ),
                ),
                DropdownMenuItem(
                  value: 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Female', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedGender = v),
              validator: (v) => v == null ? 'Please select a gender' : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDeco(
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.email_outlined),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            textInputAction: _mode == _AuthMode.signUp
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted:
                _mode == _AuthMode.signIn ? (_) => _submit() : null,
            decoration: _inputDeco(
              label: 'Password',
              hint: 'Min. 6 characters',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          if (_mode == _AuthMode.signIn) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPassword,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Forgot password?',
                    style: TextStyle(fontSize: 13, color: AppTheme.primary)),
              ),
            ),
          ],
          if (_mode == _AuthMode.signUp) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: _inputDeco(
                label: 'Confirm Password',
                hint: 'Re-enter password',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please confirm your password';
                }
                if (v != _passwordCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
          ],
        ]),
      );

  InputDecoration _inputDeco({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE1E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE1E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      );

  Widget _buildSubmitButton() => Obx(() => SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: _auth.isLoading.value ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _auth.isLoading.value
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(_mode == _AuthMode.signIn ? 'Sign In' : 'Create Account',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ));

  Widget _buildDivider() => Row(children: [
        const Expanded(child: Divider(color: Color(0xFFDDE1E7))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or continue with',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8))),
        ),
        const Expanded(child: Divider(color: Color(0xFFDDE1E7))),
      ]);

  Widget _buildGoogleButton() => Obx(() => SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: _auth.isLoading.value ? null : _signInWithGoogle,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFDDE1E7), width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _GoogleG(),
            const SizedBox(width: 10),
            Text(
                _mode == _AuthMode.signIn
                    ? 'Sign in with Google'
                    : 'Sign up with Google',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ]),
        ),
      ));

  Widget _buildAppleButton() => Obx(() => SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: _auth.isLoading.value ? null : () => _signInWithApple(),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFDDE1E7), width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.apple, size: 22, color: AppTheme.textPrimary),
            const SizedBox(width: 10),
            Text(
                _mode == _AuthMode.signIn
                    ? 'Sign in with Apple'
                    : 'Sign up with Apple',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ]),
        ),
      ));
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary)),
          ),
        ),
      );
}

class _GoogleG extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 20, height: 20, child: CustomPaint(painter: _GoogleLogoPainter()));
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    const pi = 3.14159265358979;
    final segments = [
      (0.0, 90.0, const Color(0xFF4285F4)),
      (90.0, 180.0, const Color(0xFF34A853)),
      (180.0, 270.0, const Color(0xFFFBBC05)),
      (270.0, 360.0, const Color(0xFFEA4335)),
    ];
    for (final seg in segments) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        (seg.$1 - 90) * pi / 180,
        (seg.$2 - seg.$1) * pi / 180,
        true,
        Paint()..color = seg.$3,
      );
    }
    canvas.drawCircle(Offset(cx, cy), r * 0.65, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_) => false;
}
