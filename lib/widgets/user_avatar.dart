import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Shared avatar widget — shows network photo when available, falls back to initial.
class UserAvatar extends StatelessWidget {
  final String label;
  final String photoUrl;
  final double size;
  final Color? bgColor;

  const UserAvatar({
    super.key,
    required this.label,
    required this.photoUrl,
    required this.size,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final bg = bgColor ?? AppTheme.primary;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg.withValues(alpha: 0.15),
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w700,
                color: bg,
              ),
            )
          : null,
    );
  }
}
