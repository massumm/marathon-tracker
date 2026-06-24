import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../core/theme.dart';
import 'app_button.dart';

class AppDialogs {
  AppDialogs._();

  // ── Confirm ───────────────────────────────────────────────────────────────
  // Two-button (gray Cancel + colored Action). Returns true if confirmed.
  static Future<bool> confirm({
    required BuildContext context,
    required IconData icon,
    Color iconColor = AppTheme.primary,
    required String title,
    required String body,
    String? cancelLabel,
    required String confirmLabel,
    Color confirmColor = AppTheme.primary,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          AppButton.cancel(
            label: cancelLabel ?? 'cancel'.tr,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppButton(
            label: confirmLabel,
            onPressed: () => Navigator.pop(context, true),
            backgroundColor: confirmColor,
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Alert ─────────────────────────────────────────────────────────────────
  // Single-button info/warning dialog.
  static Future<void> alert({
    required BuildContext context,
    required IconData icon,
    Color iconColor = AppTheme.primary,
    required String title,
    required String body,
    String? buttonLabel,
    Color buttonColor = AppTheme.primary,
    VoidCallback? onPressed,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          AppButton(
            label: buttonLabel ?? 'ok'.tr,
            onPressed: () {
              Navigator.pop(context);
              onPressed?.call();
            },
            backgroundColor: buttonColor,
          ),
        ],
      ),
    );
  }

  // ── Location Off ──────────────────────────────────────────────────────────
  static Future<void> locationOff(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_disabled,
                color: Colors.redAccent, size: 36),
            const SizedBox(height: 8),
            Text(
              'location_off_title'.tr,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'location_off_body'.tr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          AppButton.cancel(
            label: 'cancel'.tr,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: 'open_settings'.tr,
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
          ),
        ],
      ),
    );
  }

  // ── Permission Denied ─────────────────────────────────────────────────────
  static Future<void> permissionDenied(
    BuildContext context, {
    required bool forever,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined,
                color: Colors.orange, size: 36),
            const SizedBox(height: 8),
            Text(
              'location_permission_title'.tr,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          forever
              ? 'location_permission_forever'.tr
              : 'location_permission_denied'.tr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          AppButton.cancel(
            label: 'cancel'.tr,
            onPressed: () => Navigator.pop(context),
          ),
          if (forever)
            AppButton(
              label: 'open_settings'.tr,
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
            ),
        ],
      ),
    );
  }

  // ── iOS Always Location ───────────────────────────────────────────────────
  // Returns true to continue anyway, false if user opened settings.
  static Future<bool> iosAlwaysLocation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: AppTheme.primary, size: 36),
            const SizedBox(height: 8),
            Text(
              'ios_bg_title'.tr,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'ios_bg_body'.tr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          AppButton.cancel(
            label: 'open_settings'.tr,
            onPressed: () {
              Navigator.pop(context, false);
              Geolocator.openAppSettings();
            },
          ),
          AppButton(
            label: 'continue_anyway'.tr,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return result ?? true;
  }
}
