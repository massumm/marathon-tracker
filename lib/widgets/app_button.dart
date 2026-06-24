import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Uniform `ElevatedButton` used across dialogs and action rows.
/// White text on a colored background. Use the named factories for
/// the most common styles, or pass [backgroundColor] directly.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.backgroundColor = AppTheme.primary,
  });

  /// Gray cancel / dismiss button.
  static AppButton cancel({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        backgroundColor: AppTheme.textSecondary,
      );

  /// Red destructive-action button.
  static AppButton danger({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        backgroundColor: Colors.red,
      );

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }
}
