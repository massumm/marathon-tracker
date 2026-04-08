import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme.dart';
import '../models/user_stats.dart';
import '../services/friends_service.dart';
import '../services/user_stats_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final String _uid;
  UserStats? _stats;
  bool _loading = true;
  String _friendStatus = ''; // '', 'self', 'friends', 'sent', 'add'

  @override
  void initState() {
    super.initState();
    _uid = Get.arguments as String;
    _load();
  }

  Future<void> _load() async {
    final stats = await UserStatsService.instance.getUserStats(_uid);
    final status = await _friendStatus_();
    if (mounted) {
      setState(() {
        _stats = stats;
        _friendStatus = status;
        _loading = false;
      });
    }
  }

  Future<String> _friendStatus_() async {
    if (await FriendsService.instance.isFriend(_uid)) return 'friends';
    if (await FriendsService.instance.requestSent(_uid)) return 'sent';
    return 'add';
  }

  Future<void> _sendRequest() async {
    final s = _stats;
    if (s == null) return;
    await FriendsService.instance
        .sendRequest(_uid, s.email, s.displayName);
    if (mounted) setState(() => _friendStatus = 'sent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('profile'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? Center(child: Text('user_not_found'.tr))
              : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final s = _stats!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // ── Avatar ──────────────────────────────────────────────────────
          CircleAvatar(
            radius: 52,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            backgroundImage:
                s.photoUrl.isNotEmpty ? NetworkImage(s.photoUrl) : null,
            child: s.photoUrl.isEmpty
                ? Text(
                    s.label.isNotEmpty ? s.label[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            s.label,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(s.email,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),

          // ── Friend action ────────────────────────────────────────────────
          if (_friendStatus == 'friends')
            Chip(
              avatar: const Icon(Icons.check, size: 16, color: Colors.green),
              label: Text('already_friends'.tr,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFFE8F5E9),
            )
          else if (_friendStatus == 'sent')
            Chip(
              label: Text('request_sent'.tr,
                  style: const TextStyle(fontSize: 13)),
              backgroundColor: const Color(0xFFFFF8E1),
            )
          else if (_friendStatus == 'add')
            ElevatedButton.icon(
              onPressed: _sendRequest,
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: Text('add_friend'.tr),
            ),

          const SizedBox(height: 28),

          // ── Stats grid ───────────────────────────────────────────────────
          _StatsGrid(stats: s),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final UserStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _StatCard(
              icon: Icons.straighten,
              value: stats.distanceStr,
              label: 'total_distance'.tr,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.directions_run,
              value: '${stats.totalRuns}',
              label: 'total_runs'.tr,
              color: AppTheme.secondary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              icon: Icons.timer_outlined,
              value: stats.timeStr,
              label: 'total_time'.tr,
              color: const Color(0xFF8E6BBF),
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.speed,
              value: stats.avgPaceStr,
              label: 'avg_pace'.tr,
              color: AppTheme.trackingGreen,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
