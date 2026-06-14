import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = '',
  });

  static void show({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String? confirmLabel,
  }) {
    Get.dialog(ConfirmDialog(
      title: title,
      message: message,
      onConfirm: onConfirm,
      confirmLabel: confirmLabel ?? 'confirm'.tr,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            onConfirm();
          },
          child: Text(confirmLabel.isNotEmpty ? confirmLabel : 'confirm'.tr),
        ),
      ],
    );
  }
}
