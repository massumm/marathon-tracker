import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Shared avatar widget — shows cached network photo when available,
/// falls back to initial letter. Images are cached to disk so they
/// don't re-download on every app launch.
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
    final radius = size / 2;

    if (photoUrl.isEmpty) {
      return _InitialAvatar(initial: initial, bg: bg, radius: radius, size: size);
    }

    return CachedNetworkImage(
      imageUrl: photoUrl,
      width: size,
      height: size,
      imageBuilder: (_, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
      ),
      placeholder: (_, __) => _InitialAvatar(
        initial: initial,
        bg: bg,
        radius: radius,
        size: size,
      ),
      errorWidget: (_, __, ___) => _InitialAvatar(
        initial: initial,
        bg: bg,
        radius: radius,
        size: size,
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String initial;
  final Color bg;
  final double radius;
  final double size;

  const _InitialAvatar({
    required this.initial,
    required this.bg,
    required this.radius,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: bg,
        ),
      ),
    );
  }
}
