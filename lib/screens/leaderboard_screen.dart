import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../core/theme.dart';
import '../models/user_stats.dart';
import '../services/friends_service.dart';
import '../services/user_stats_service.dart';
import '../widgets/user_avatar.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('leaderboard'.tr)),
      body: StreamBuilder<List<String>>(
        stream: FriendsService.instance.watchFriendUids(),
        builder: (_, friendSnap) {
          final friendUids = friendSnap.data ?? [];

          return StreamBuilder<List<UserStats>>(
            stream:
                UserStatsService.instance.watchFriendLeaderboard(friendUids),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting ||
                  friendSnap.connectionState == ConnectionState.waiting) {
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
                              fontSize: 16,
                              color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      const Text(
                        'Add friends to see them here',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // ── Top 3 podium ──────────────────────────────────────
                  if (list.length >= 3) _Podium(top3: list.take(3).toList()),
                  // ── Rest of list ──────────────────────────────────────
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                          top: 8, bottom: 16, left: 0, right: 0),
                      itemCount: list.length > 3 ? list.length - 3 : 0,
                      itemBuilder: (_, i) =>
                          _LeaderRow(stats: list[i + 3]),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Podium (top 3) ─────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<UserStats> top3;
  const _Podium({required this.top3});

  @override
  Widget build(BuildContext context) {
    // Order: 2nd left, 1st centre, 3rd right
    final order = [top3[1], top3[0], top3[2]];
    final heights = [80.0, 110.0, 60.0];
    final avatarSizes = [52.0, 66.0, 46.0];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final s = order[i];
          final isFirst = s.rank == 1;
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  Get.toNamed(AppRoutes.userProfile, arguments: s.uid),
              child: Column(
                children: [
                  // Crown for 1st
                  if (isFirst)
                    const Text('👑',
                        style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  UserAvatar(
                      label: s.label,
                      photoUrl: s.photoUrl,
                      size: avatarSizes[i]),
                  const SizedBox(height: 6),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isFirst
                          ? _medalColor(1)
                          : AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    s.distanceStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _medalColor(s.rank),
                    ),
                  ),
                  Text(
                    '${s.totalRuns} ${'runs'.tr}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  // Podium block
                  Container(
                    height: heights[i],
                    decoration: BoxDecoration(
                      color: _medalColor(s.rank).withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      border: Border.all(
                          color: _medalColor(s.rank).withValues(alpha: 0.4),
                          width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        _medalEmoji(s.rank),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
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

// ── Row for rank 4+ ────────────────────────────────────────────────────────

class _LeaderRow extends StatelessWidget {
  final UserStats stats;
  const _LeaderRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Get.toNamed(AppRoutes.userProfile, arguments: stats.uid),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 32,
              child: Text(
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
            UserAvatar(
                label: stats.label,
                photoUrl: stats.photoUrl,
                size: 40),
            const SizedBox(width: 12),
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
            // Distance + runs
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stats.distanceStr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
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
}
