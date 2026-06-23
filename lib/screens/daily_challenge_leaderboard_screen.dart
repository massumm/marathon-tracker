import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/theme.dart';
import '../../models/user_stats.dart';
import '../../services/user_stats_service.dart';
import '../../widgets/user_avatar.dart';

class DailyChallengeLeaderboardScreen extends StatelessWidget {
  const DailyChallengeLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('daily_challenge_leaderboard'.tr)),
      body: StreamBuilder<List<UserStats>>(
        stream: UserStatsService.instance.watchDailyChallengeLeaderboard(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_outlined,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('no_daily_challenge_runs'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 70, endIndent: 16),
            itemBuilder: (_, i) => _RankRow(stats: entries[i]),
          );
        },
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final UserStats stats;
  const _RankRow({required this.stats});

  Color get _medalColor => stats.rank == 1
      ? const Color(0xFFFFB300)
      : stats.rank == 2
          ? const Color(0xFF90A4AE)
          : stats.rank == 3
              ? const Color(0xFFBF8970)
              : AppTheme.textSecondary;

  @override
  Widget build(BuildContext context) {
    final isTop3 = stats.rank <= 3;
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.userProfile, arguments: stats.uid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: isTop3
                  ? Text(
                      stats.rank == 1
                          ? '🥇'
                          : stats.rank == 2
                              ? '🥈'
                              : '🥉',
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      '#${stats.rank}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            UserAvatar(label: stats.label, photoUrl: stats.photoUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stats.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isTop3 ? _medalColor : AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis),
                  Text('${stats.dailyRuns} ${'runs'.tr}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Text(
              stats.dailyDistanceStr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
