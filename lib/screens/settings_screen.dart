import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../controllers/map_controller.dart';
import '../../controllers/my_page_controller.dart';
import '../../core/theme.dart';
import '../../services/event_notification_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialogs.dart';
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
                Obx(() {
                  final phone = controller.myStats.value?.phone ?? '';
                  return _tile(
                    icon: Icons.phone_outlined,
                    title: 'phone_number'.tr,
                    subtitle: phone.isEmpty ? 'Not set' : phone,
                    onTap: () => _changePhone(context, phone),
                  );
                }),
                _tile(
                  icon: Icons.language,
                  title: 'language_settings'.tr,
                  subtitle: Get.locale?.languageCode == 'ja'
                      ? '日本語'
                      : Get.locale?.languageCode == 'bn'
                          ? 'বাংলা'
                          : 'English',
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
          // _sectionHeader('version'.tr),
          // FutureBuilder<PackageInfo>(
          //   future: PackageInfo.fromPlatform(),
          //   builder: (_, snap) {
          //     final version = snap.hasData
          //         ? '${snap.data!.version} (${snap.data!.buildNumber})'
          //         : '...';
          //     return _tile(
          //       icon: Icons.info_outline,
          //       title: 'version'.tr,
          //       subtitle: version,
          //     );
          //   },
          // ),
          // const Divider(height: 1),
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
        leading: Icon(icon,
            color: iconColor ?? titleColor ?? AppTheme.textSecondary),
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

  void _changePhone(BuildContext context, String current) {
    final phoneCtrl = TextEditingController(text: current);
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.phone_outlined, color: AppTheme.primary, size: 36),
        const SizedBox(height: 8),
        Text('phone_number'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ]),
      content: TextField(
        controller: phoneCtrl,
        autofocus: true,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(hintText: 'enter_phone_number'.tr),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        AppButton.cancel(label: 'cancel'.tr, onPressed: Get.back),
        AppButton(
          label: 'confirm'.tr,
          onPressed: () async {
            final phone = phoneCtrl.text.trim();
            try {
              await controller.updatePhoneNumber(phone);
              Get.back();
              showSnack('phone_number'.tr, 'phone_updated'.tr,
                  duration: const Duration(seconds: 2));
            } catch (e) {
              Get.back();
              Get.snackbar('phone_number'.tr, e.toString(),
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white);
            }
          },
        ),
      ],
    ));
  }

  void _selectLanguage() {
    final lang = Get.locale?.languageCode;
    Get.dialog(SimpleDialog(
      title: Text('language_settings'.tr),
      children: [
        SimpleDialogOption(
          onPressed: () {
            Get.back();
            Get.updateLocale(const Locale('en', 'US'));
          },
          child: Row(children: [
            Text('English',
                style: TextStyle(
                    fontWeight:
                        lang == 'en' ? FontWeight.bold : FontWeight.normal)),
            if (lang == 'en') ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 18)
            ],
          ]),
        ),
        SimpleDialogOption(
          onPressed: () {
            Get.back();
            Get.updateLocale(const Locale('ja', 'JP'));
          },
          child: Row(children: [
            Text('日本語',
                style: TextStyle(
                    fontWeight:
                        lang == 'ja' ? FontWeight.bold : FontWeight.normal)),
            if (lang == 'ja') ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 18)
            ],
          ]),
        ),
        SimpleDialogOption(
          onPressed: () {
            Get.back();
            Get.updateLocale(const Locale('bn', 'BD'));
          },
          child: Row(children: [
            Text('বাংলা',
                style: TextStyle(
                    fontWeight:
                        lang == 'bn' ? FontWeight.bold : FontWeight.normal)),
            if (lang == 'bn') ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 18)
            ],
          ]),
        ),
      ],
    ));
  }

  void _changeEmail(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alternate_email, color: AppTheme.primary, size: 36),
          const SizedBox(height: 8),
          Text('change_email'.tr,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
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
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        AppButton.cancel(label: 'cancel'.tr, onPressed: Get.back),
        AppButton(
          label: 'confirm'.tr,
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
              final msg =
                  (e.code == 'wrong-password' || e.code == 'invalid-credential')
                      ? 'wrong_password'.tr
                      : e.message ?? e.code;
              Get.snackbar('change_email'.tr, msg,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white);
            } catch (e) {
              Get.back();
              Get.snackbar('change_email'.tr, e.toString(),
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white);
            }
          },
        ),
      ],
    ));
  }

  void _resetPassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, color: AppTheme.primary, size: 36),
          const SizedBox(height: 8),
          Text('change_password'.tr,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
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
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        AppButton.cancel(label: 'cancel'.tr, onPressed: Get.back),
        AppButton(
          label: 'confirm'.tr,
          onPressed: () async {
            final current = currentCtrl.text;
            final newPass = newCtrl.text;
            final confirm = confirmCtrl.text;
            if (current.isEmpty || newPass.isEmpty) return;
            if (newPass != confirm) {
              Get.snackbar('change_password'.tr, 'password_mismatch'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white);
              return;
            }
            if (newPass.length < 6) {
              Get.snackbar('change_password'.tr, 'password_too_short'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white);
              return;
            }
            try {
              await controller.changePassword(current, newPass);
              Get.back();
              showSnack('change_password'.tr, 'password_updated'.tr);
            } on FirebaseAuthException catch (e) {
              Get.back();
              final msg =
                  (e.code == 'wrong-password' || e.code == 'invalid-credential')
                      ? 'wrong_password'.tr
                      : e.message ?? e.code;
              Get.snackbar('change_password'.tr, msg,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white);
            } catch (e) {
              Get.back();
              Get.snackbar('change_password'.tr, e.toString(),
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white);
            }
          },
        ),
      ],
    ));
  }

  void _deleteAccount(BuildContext context) {
    if (controller.isGoogleUser) {
      _deleteAccountGoogle(context);
    } else if (controller.isAppleUser) {
      _deleteAccountApple(context);
    } else {
      _deleteAccountEmail();
    }
  }

  void _deleteAccountGoogle(BuildContext context) {
    AppDialogs.confirm(
      context: context,
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.red,
      title: 'delete_account'.tr,
      body: 'delete_account_google_confirm'.tr,
      confirmLabel: 'delete_account'.tr,
      confirmColor: Colors.red,
    ).then((confirmed) async {
      if (!confirmed) return;
      try {
        await controller.deleteAccountWithGoogle();
        Get.offAllNamed(AppRoutes.login);
      } catch (e) {
        Get.snackbar('delete_account'.tr, e.toString(),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    });
  }

  void _deleteAccountApple(BuildContext context) {
    AppDialogs.confirm(
      context: context,
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.red,
      title: 'delete_account'.tr,
      body: 'delete_account_apple_confirm'.tr,
      confirmLabel: 'delete_account'.tr,
      confirmColor: Colors.red,
    ).then((confirmed) async {
      if (!confirmed) return;
      try {
        await controller.deleteAccountWithApple();
        Get.offAllNamed(AppRoutes.login);
      } catch (e) {
        Get.snackbar('delete_account'.tr, e.toString(),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    });
  }

  void _deleteAccountEmail() {
    final passCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 36),
          const SizedBox(height: 8),
          Text('delete_account'.tr,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('delete_account_confirm'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: passCtrl,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(hintText: 'enter_current_password'.tr),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: Get.back,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textSecondary,
              foregroundColor: Colors.white),
          child: Text('cancel'.tr),
        ),
        ElevatedButton(
          onPressed: () async {
            final password = passCtrl.text;
            if (password.isEmpty) return;
            try {
              await controller.deleteAccount(password);
              Get.offAllNamed(AppRoutes.login);
            } on FirebaseAuthException catch (e) {
              Get.back();
              final msg =
                  (e.code == 'wrong-password' || e.code == 'invalid-credential')
                      ? 'wrong_password'.tr
                      : e.message ?? e.code;
              Get.snackbar('delete_account'.tr, msg,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white);
            } catch (e) {
              Get.back();
              Get.snackbar('delete_account'.tr, e.toString(),
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red,
                  colorText: Colors.white);
            }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: Text('delete_account'.tr),
        ),
      ],
    ));
  }

  void _confirmSignOut(BuildContext context) {
    AppDialogs.confirm(
      context: context,
      icon: Icons.logout,
      iconColor: Colors.red,
      title: 'sign_out'.tr,
      body: 'sign_out_confirm'.tr,
      confirmLabel: 'sign_out'.tr,
      confirmColor: Colors.red,
    ).then((confirmed) async {
      if (!confirmed) return;
      await controller.signOut();
    });
  }
}

class _NotificationToggleWidget extends StatefulWidget {
  const _NotificationToggleWidget();

  @override
  State<_NotificationToggleWidget> createState() =>
      _NotificationToggleWidgetState();
}

class _NotificationToggleWidgetState extends State<_NotificationToggleWidget> {
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
