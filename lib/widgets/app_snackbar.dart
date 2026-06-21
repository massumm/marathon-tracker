import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_map/core/theme.dart';

void showSnack(String title, String message, {Duration? duration}) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: AppTheme.primary.withValues(alpha: 0.9),
    colorText: Colors.white,
    margin: const EdgeInsets.all(12),
    duration: duration ?? const Duration(seconds: 3),
  );
}
