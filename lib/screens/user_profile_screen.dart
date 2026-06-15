import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme.dart';
import '../../models/user_stats.dart';
import '../../services/user_stats_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final String _uid;
  UserStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _uid = Get.arguments as String;
    _load();
  }

  Future<void> _load() async {
    final stats = await UserStatsService.instance.getUserStats(_uid);
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('profile'.tr,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? Center(child: Text('user_not_found'.tr))
              : _ProfileBody(stats: _stats!),
    );
  }
}

// ── Profile body ──────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final UserStats stats;
  const _ProfileBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Banner + avatar ───────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              _Banner(),
              Positioned(
                bottom: -52,
                left: 0,
                right: 0,
                child: Center(child: _Avatar(stats: s)),
              ),
            ],
          ),

          const SizedBox(height: 68),

          // ── Name + email ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  s.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                if (s.email.isNotEmpty)
                  Text(
                    s.email,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Stats ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _StatsSection(stats: s),
          ),

          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ── Gradient banner ───────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF8C5A), AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: _DecorCircle(size: 130, opacity: 0.08),
          ),
          Positioned(
            bottom: 20,
            left: -20,
            child: _DecorCircle(size: 90, opacity: 0.06),
          ),
        ],
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _DecorCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final UserStats stats;
  const _Avatar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: stats.photoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: stats.photoUrl,
              width: 108,
              height: 108,
              imageBuilder: (_, img) => CircleAvatar(
                radius: 52,
                backgroundImage: img,
              ),
              placeholder: (_, __) => _InitialCircle(label: stats.label),
              errorWidget: (_, __, ___) => _InitialCircle(label: stats.label),
            )
          : _InitialCircle(label: stats.label),
    );
  }
}

class _InitialCircle extends StatelessWidget {
  final String label;
  const _InitialCircle({required this.label});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 52,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

// ── Stats section ─────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final UserStats stats;
  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(Icons.straighten_rounded, stats.distanceStr,
          'total_distance'.tr, const Color(0xFFFF6B35)),
      _StatItem(Icons.directions_run_rounded, '${stats.totalRuns}',
          'total_runs'.tr, const Color(0xFF00B4D8)),
      _StatItem(Icons.timer_rounded, stats.timeStr,
          'total_time'.tr, const Color(0xFF8E6BBF)),
      _StatItem(Icons.speed_rounded, stats.avgPaceStr,
          'avg_pace'.tr, const Color(0xFF48BB78)),
      _StatItem(Icons.hiking_rounded, stats.stepsStr,
          'total_steps'.tr, const Color(0xFF0288D1)),
      _StatItem(Icons.local_fire_department_rounded, stats.caloriesStr,
          'total_calories'.tr, const Color(0xFFE64A19)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (_, i) => _StatCard(item: items[i]),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatItem(this.icon, this.value, this.label, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: item.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
