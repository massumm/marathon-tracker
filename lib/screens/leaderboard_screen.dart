import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../core/theme.dart';
import '../models/user_stats.dart';
import '../services/user_stats_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('leaderboard'.tr)),
      body: StreamBuilder<List<UserStats>>(
        stream: UserStatsService.instance.watchLeaderboard(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      size: 64, color: Color(0xFFB0BEC5)),
                  const SizedBox(height: 16),
                  Text('no_runners_yet'.tr,
                      style: const TextStyle(
                          fontSize: 16, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) => _LeaderRow(stats: list[i]),
          );
        },
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final UserStats stats;
  const _LeaderRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isTop3 = stats.rank <= 3;

    return InkWell(
      onTap: () =>
          Get.toNamed(AppRoutes.userProfile, arguments: stats.uid),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          border: isTop3
              ? Border.all(
                  color: _medalColor(stats.rank).withValues(alpha: 0.35),
                  width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 36,
              child: isTop3
                  ? Text(
                      _medalEmoji(stats.rank),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
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
            // Avatar
            _Avatar(stats: stats, size: 42),
            const SizedBox(width: 12),
            // Name + email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    stats.email,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stats.distanceStr,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isTop3 ? _medalColor(stats.rank) : AppTheme.primary,
                  ),
                ),
                Text(
                  '${stats.totalRuns} ${'runs'.tr}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _medalEmoji(int rank) =>
      rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';

  Color _medalColor(int rank) => rank == 1
      ? const Color(0xFFFFB300)
      : rank == 2
          ? const Color(0xFF90A4AE)
          : const Color(0xFFBF8970);
}

class _Avatar extends StatelessWidget {
  final UserStats stats;
  final double size;
  const _Avatar({required this.stats, required this.size});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
      backgroundImage: stats.photoUrl.isNotEmpty
          ? NetworkImage(stats.photoUrl)
          : null,
      child: stats.photoUrl.isEmpty
          ? Text(
              stats.label.isNotEmpty
                  ? stats.label[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            )
          : null,
    );
  }
}
