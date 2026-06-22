import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/map_controller.dart';
import '../../controllers/my_page_controller.dart';
import '../../core/theme.dart';
import '../../services/event_notification_service.dart';
import '../../widgets/app_snackbar.dart';

class SettingsScreen extends GetView<MyPageController> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                _sectionHeader('account_settings'.tr),
          if (!controller.isGoogleUser && !controller.isAppleUser) ...[
            _tile(
              icon: Icons.email_outlined,
              title: 'change_email'.tr,
              subtitle: controller.user?.email ?? '',
              onTap: () => _changeEmail(context),
            ),
            _tile(
              icon: Icons.lock_outline,
              title: 'change_password'.tr,
              onTap: () => _resetPassword(context),
            ),
          ],
          Obx(() {
            final gender = controller.myStats.value?.gender;
            final label = gender == 0
                ? 'Male'
                : gender == 1
                    ? 'Female'
                    : 'Not set';
            final missing = gender == null;
            return _tile(
              icon: gender == 1 ? Icons.female : Icons.male,
              iconColor: missing ? Colors.orange : null,
              title: 'gender'.tr,
              subtitle: label,
              subtitleColor: missing ? Colors.orange : null,
              warning: missing,
              onTap: () => _changeGender(context, gender),
            );
          }),
          _tile(
            icon: Icons.language,
            title: 'language_settings'.tr,
            subtitle: Get.locale?.languageCode == 'ja' ? '日本語' : 'English',
            onTap: () => _selectLanguage(),
          ),
          _tile(
            icon: Icons.delete_outline,
            title: 'delete_account'.tr,
            titleColor: Colors.red,
            onTap: () => _deleteAccount(context),
          ),
          const Divider(height: 1),
          _sectionHeader('notification_settings'.tr),
          const _NotificationToggleWidget(),
              ],
            ),
          ),
          _sectionHeader('version'.tr),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) {
              final version = snap.hasData
                  ? '${snap.data!.version} (${snap.data!.buildNumber})'
                  : '...';
              return _tile(
                icon: Icons.info_outline,
                title: 'version'.tr,
                subtitle: version,
              );
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: Text('sign_out'.tr,
                  style: const TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    Color? subtitleColor,
    bool warning = false,
    VoidCallback? onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: iconColor ?? titleColor ?? AppTheme.textSecondary),
        title: Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: titleColor ?? AppTheme.textPrimary)),
        subtitle: subtitle != null && subtitle.isNotEmpty
            ? Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor ?? AppTheme.textSecondary))
            : null,
        trailing: onTap != null
            ? warning
                ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
                : const Icon(Icons.chevron_right, color: AppTheme.textSecondary)
            : null,
        onTap: onTap,
      );

  void _changeGender(BuildContext context, int? currentGender) {
    Get.dialog(SimpleDialog(
      title: Text('gender_edit'.tr),
      children: [0, 1].map((value) {
        final label = value == 0 ? 'Male' : 'Female';
        final icon = value == 0 ? Icons.male : Icons.female;
        final color = value == 0 ? Colors.blue.shade400 : Colors.pink.shade300;
        final isCurrent = currentGender == value;
        return SimpleDialogOption(
          onPressed: () async {
            Get.back();
            await _updateGender(value, label);
          },
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal)),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Icon(Icons.check, size: 18, color: color),
            ],
          ]),
        );
      }).toList(),
    ));
  }

  Future<void> _updateGender(int gender, String label) async {
    try {
      await controller.updateGender(gender);
      showSnack('gender'.tr, 'Gender updated to $label',
          duration: const Duration(seconds: 2));
    } catch (e) {
      Get.snackbar(
        'gender'.tr,
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _selectLanguage() {
    final isJa = Get.locale?.languageCode == 'ja';
    Get.dialog(SimpleDialog(
      title: Text('language_settings'.tr),
      children: [
        SimpleDialogOption(
          onPressed: () {
            Get.back();
            Get.updateLocale(const Locale('en', 'US'));
          },
          child: Row(children: [
            Text('English', style: TextStyle(fontWeight: isJa ? FontWeight.normal : FontWeight.bold)),
            if (!isJa) ...[const SizedBox(width: 8), const Icon(Icons.check, size: 18)],
          ]),
        ),
        SimpleDialogOption(
          onPressed: () {
            Get.back();
            Get.updateLocale(const Locale('ja', 'JP'));
          },
          child: Row(children: [
            Text('日本語', style: TextStyle(fontWeight: isJa ? FontWeight.bold : FontWeight.normal)),
            if (isJa) ...[const SizedBox(width: 8), const Icon(Icons.check, size: 18)],
          ]),
        ),
      ],
    ));
  }

  void _changeEmail(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      title: Text('change_email'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(hintText: 'enter_new_email'.tr),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: InputDecoration(hintText: 'enter_current_password'.tr),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () async {
            final email = emailCtrl.text.trim();
            final password = passCtrl.text;
            if (email.isEmpty || password.isEmpty) return;
            try {
              await controller.updateEmail(email, password);
              Get.back();
              showSnack('change_email'.tr, 'email_verification_sent'.tr,
                  duration: const Duration(seconds: 5));
            } on FirebaseAuthException catch (e) {
              Get.back();
              final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
                  ? 'wrong_password'.tr
                  : e.message ?? e.code;
              Get.snackbar('change_email'.tr, msg,
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
            } catch (e) {
              Get.back();
              Get.snackbar('change_email'.tr, e.toString(),
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          child: Text('confirm'.tr),
        ),
      ],
    ));
  }

  void _resetPassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      title: Text('change_password'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: currentCtrl,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(hintText: 'current_password'.tr),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newCtrl,
            obscureText: true,
            decoration: InputDecoration(hintText: 'new_password'.tr),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmCtrl,
            obscureText: true,
            decoration: InputDecoration(hintText: 'confirm_new_password'.tr),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () async {
            final current = currentCtrl.text;
            final newPass = newCtrl.text;
            final confirm = confirmCtrl.text;
            if (current.isEmpty || newPass.isEmpty) return;
            if (newPass != confirm) {
              Get.snackbar('change_password'.tr, 'password_mismatch'.tr,
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
              return;
            }
            if (newPass.length < 6) {
              Get.snackbar('change_password'.tr, 'password_too_short'.tr,
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
              return;
            }
            try {
              await controller.changePassword(current, newPass);
              Get.back();
              showSnack('change_password'.tr, 'password_updated'.tr);
            } on FirebaseAuthException catch (e) {
              Get.back();
              final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
                  ? 'wrong_password'.tr
                  : e.message ?? e.code;
              Get.snackbar('change_password'.tr, msg,
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
            } catch (e) {
              Get.back();
              Get.snackbar('change_password'.tr, e.toString(),
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          child: Text('confirm'.tr),
        ),
      ],
    ));
  }

  void _deleteAccount(BuildContext context) {
    if (controller.isGoogleUser) {
      _deleteAccountGoogle();
    } else if (controller.isAppleUser) {
      _deleteAccountApple();
    } else {
      _deleteAccountEmail();
    }
  }

  void _deleteAccountGoogle() {
    Get.dialog(AlertDialog(
      title: Text('delete_account'.tr),
      content: Text('delete_account_google_confirm'.tr),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () async {
            Get.back();
            try {
              await controller.deleteAccountWithGoogle();
              Get.offAllNamed(AppRoutes.login);
            } catch (e) {
              Get.snackbar('delete_account'.tr, e.toString(),
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text('delete_account'.tr),
        ),
      ],
    ));
  }

  void _deleteAccountApple() {
    Get.dialog(AlertDialog(
      title: Text('delete_account'.tr),
      content: Text('delete_account_apple_confirm'.tr),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () async {
            Get.back();
            try {
              await controller.deleteAccountWithApple();
              Get.offAllNamed(AppRoutes.login);
            } catch (e) {
              Get.snackbar('delete_account'.tr, e.toString(),
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text('delete_account'.tr),
        ),
      ],
    ));
  }

  void _deleteAccountEmail() {
    final passCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      title: Text('delete_account'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('delete_account_confirm'.tr),
          const SizedBox(height: 12),
          TextField(
            controller: passCtrl,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(hintText: 'enter_current_password'.tr),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () async {
            final password = passCtrl.text;
            if (password.isEmpty) return;
            try {
              await controller.deleteAccount(password);
              Get.offAllNamed(AppRoutes.login);
            } on FirebaseAuthException catch (e) {
              Get.back();
              final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
                  ? 'wrong_password'.tr
                  : e.message ?? e.code;
              Get.snackbar('delete_account'.tr, msg,
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
            } catch (e) {
              Get.back();
              Get.snackbar('delete_account'.tr, e.toString(),
                  snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text('delete_account'.tr),
        ),
      ],
    ));
  }

  void _confirmSignOut(BuildContext context) {
    Get.dialog(AlertDialog(
      title: Text('sign_out'.tr),
      content: Text('sign_out_confirm'.tr),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () async {
            Get.back();
            await controller.signOut();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text('sign_out'.tr),
        ),
      ],
    ));
  }
}

class _NotificationToggleWidget extends StatefulWidget {
  const _NotificationToggleWidget();

  @override
  State<_NotificationToggleWidget> createState() =>
      _NotificationToggleWidgetState();
}

class _NotificationToggleWidgetState
    extends State<_NotificationToggleWidget> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = EventNotificationService.instance.isEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined,
          color: AppTheme.textSecondary),
      title: Text(
        'event_notifications'.tr,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary),
      ),
      subtitle: Text(
        'event_notifications_subtitle'.tr,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      value: _enabled,
      activeThumbColor: AppTheme.primary,
      onChanged: (val) async {
        setState(() => _enabled = val);
        await EventNotificationService.instance.setEnabled(val);
        // Re-schedule or cancel based on current events list
        try {
          final ctrl = Get.find<MapController>();
          await EventNotificationService.instance
              .scheduleForEvents(ctrl.events.toList());
        } catch (_) {}
      },
    );
  }
}
