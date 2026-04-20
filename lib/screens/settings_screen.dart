import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/my_page_controller.dart';
import '../core/theme.dart';

class SettingsScreen extends GetView<MyPageController> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr)),
      body: ListView(
        children: [
          _sectionHeader('profile_settings'.tr),
          _tile(
            icon: Icons.camera_alt_outlined,
            title: 'profile_image'.tr,
            onTap: () => controller.uploadProfileImage(),
          ),
          _tile(
            icon: Icons.person_outline,
            title: 'edit_name'.tr,
            subtitle: controller.displayName,
            onTap: () => _editName(context),
          ),
          Obx(() => _tile(
                icon: Icons.cake_outlined,
                title: 'age'.tr,
                subtitle: controller.ageObs.value > 0
                    ? '${controller.ageObs.value}'
                    : '-',
                onTap: () => _editAge(context),
              )),
          const Divider(height: 1),
          _sectionHeader('account_settings'.tr),
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
          _tile(
            icon: Icons.language,
            title: 'language_settings'.tr,
            subtitle: Get.locale?.languageCode == 'ja' ? '日本語' : 'English',
            onTap: () {
              final isJa = Get.locale?.languageCode == 'ja';
              Get.updateLocale(
                isJa ? const Locale('en', 'US') : const Locale('ja', 'JP'),
              );
            },
          ),
          _tile(
            icon: Icons.delete_outline,
            title: 'delete_account'.tr,
            titleColor: Colors.red,
            onTap: () => _deleteAccount(context),
          ),
          const Divider(height: 1),
          _sectionHeader('version'.tr),
          _tile(
            icon: Icons.info_outline,
            title: 'version'.tr,
            subtitle: 'app_version'.tr,
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
    VoidCallback? onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: titleColor ?? AppTheme.textSecondary),
        title: Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: titleColor ?? AppTheme.textPrimary)),
        subtitle: subtitle != null && subtitle.isNotEmpty
            ? Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary))
            : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: AppTheme.textSecondary)
            : null,
        onTap: onTap,
      );

  void _editName(BuildContext context) {
    final ctrl = TextEditingController(text: controller.displayName);
    Get.dialog(AlertDialog(
      title: Text('edit_name'.tr),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: 'your_name'.tr),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            controller.updateDisplayName(ctrl.text);
          },
          child: Text('confirm'.tr),
        ),
      ],
    ));
  }

  void _editAge(BuildContext context) {
    final ctrl = TextEditingController(
      text: controller.ageObs.value > 0 ? '${controller.ageObs.value}' : '',
    );
    Get.dialog(AlertDialog(
      title: Text('edit_age'.tr),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: 'enter_age'.tr),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            final age = int.tryParse(ctrl.text.trim());
            if (age != null && age > 0) {
              Get.back();
              controller.updateAge(age);
            }
          },
          child: Text('confirm'.tr),
        ),
      ],
    ));
  }

  void _changeEmail(BuildContext context) {
    final ctrl = TextEditingController();
    Get.dialog(AlertDialog(
      title: Text('change_email'.tr),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(hintText: 'enter_new_email'.tr),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () async {
            final email = ctrl.text.trim();
            if (email.isNotEmpty) {
              Get.back();
              await controller.updateEmail(email);
              Get.snackbar('change_email'.tr, 'password_reset_sent'.tr,
                  snackPosition: SnackPosition.BOTTOM);
            }
          },
          child: Text('confirm'.tr),
        ),
      ],
    ));
  }

  void _resetPassword(BuildContext context) {
    Get.dialog(AlertDialog(
      title: Text('change_password'.tr),
      content: Text('${'change_password'.tr}?'),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () async {
            Get.back();
            await controller.sendPasswordReset();
            Get.snackbar('change_password'.tr, 'password_reset_sent'.tr,
                snackPosition: SnackPosition.BOTTOM);
          },
          child: Text('confirm'.tr),
        ),
      ],
    ));
  }

  void _deleteAccount(BuildContext context) {
    Get.dialog(AlertDialog(
      title: Text('delete_account'.tr),
      content: Text('delete_account_confirm'.tr),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            controller.deleteAccount();
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
          onPressed: () {
            Get.back();
            controller.signOut();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text('sign_out'.tr),
        ),
      ],
    ));
  }
}
