import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/admin_user_model.dart';

class OrganizerProfileScreen extends StatefulWidget {
  final AdminUser organizer;

  const OrganizerProfileScreen({
    super.key,
    required this.organizer,
  });

  @override
  State<OrganizerProfileScreen> createState() =>
      _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  final _passKey = GlobalKey<FormState>();

  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _passSaving = false;
  String? _passError;
  String? _passSuccess;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!(_passKey.currentState?.validate() ?? false)) return;
    setState(() {
      _passSaving = true;
      _passError = null;
      _passSuccess = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPassCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPassCtrl.text);
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      setState(() => _passSuccess = 'Password updated successfully.');
    } on FirebaseAuthException catch (e) {
      setState(() => _passError = _friendlyError(e.code));
    } catch (e) {
      setState(() => _passError = e.toString());
    } finally {
      setState(() => _passSaving = false);
    }
  }

  String _friendlyError(String code) => switch (code) {
        'wrong-password' || 'invalid-credential' =>
          'Current password is incorrect.',
        'weak-password' => 'New password must be at least 6 characters.',
        'requires-recent-login' =>
          'Please sign out and sign in again before changing your password.',
        _ => 'An error occurred. Please try again.',
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAccountInfo(),
          const SizedBox(height: 28),
          _buildPasswordCard(),
        ],
      ),
    );
  }

  Widget _buildAccountInfo() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.orange.withValues(alpha: 0.15),
              child: Text(
                (widget.organizer.displayName.isNotEmpty
                        ? widget.organizer.displayName
                        : widget.organizer.email)
                    .substring(0, 1)
                    .toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.organizer.displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.organizer.email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Organizer',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildPasswordCard() => _SectionCard(
        title: 'Change Password',
        icon: Icons.lock_outline,
        child: Form(
          key: _passKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _currentPassCtrl,
                obscureText: _obscureCurrent,
                decoration: _inputDeco(
                  label: 'Current Password',
                  hint: 'Enter current password',
                  suffix: _eyeButton(_obscureCurrent,
                      () => setState(() => _obscureCurrent = !_obscureCurrent)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Current password is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newPassCtrl,
                obscureText: _obscureNew,
                decoration: _inputDeco(
                  label: 'New Password',
                  hint: 'Min. 6 characters',
                  suffix: _eyeButton(_obscureNew,
                      () => setState(() => _obscureNew = !_obscureNew)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'New password is required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                decoration: _inputDeco(
                  label: 'Confirm New Password',
                  hint: 'Re-enter new password',
                  suffix: _eyeButton(
                      _obscureConfirm,
                      () =>
                          setState(() => _obscureConfirm = !_obscureConfirm)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (v != _newPassCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              if (_passError != null) ...[
                const SizedBox(height: 8),
                _StatusText(_passError!, isError: true),
              ],
              if (_passSuccess != null) ...[
                const SizedBox(height: 8),
                _StatusText(_passSuccess!, isError: false),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _passSaving ? null : _savePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _passSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Update Password',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _eyeButton(bool obscure, VoidCallback onPressed) => IconButton(
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
          color: AppTheme.textSecondary,
        ),
        onPressed: onPressed,
      );

  InputDecoration _inputDeco(
          {required String label, required String hint, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE1E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE1E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ]),
            const SizedBox(height: 4),
            const Divider(color: Color(0xFFEEF0F5)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _StatusText extends StatelessWidget {
  final String text;
  final bool isError;
  const _StatusText(this.text, {required this.isError});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 14,
            color: isError ? Colors.red.shade600 : Colors.green.shade600,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isError ? Colors.red.shade600 : Colors.green.shade600,
              ),
            ),
          ),
        ],
      );
}
