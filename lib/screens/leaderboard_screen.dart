import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../core/theme.dart';
import '../models/group_model.dart';
import '../models/user_stats.dart';
import '../services/group_service.dart';
import '../services/user_stats_service.dart';
import '../widgets/user_avatar.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('leaderboard'.tr)),
      body: StreamBuilder<List<GroupModel>>(
        stream: GroupService.instance.watchAllMyGroups(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_outlined,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('no_groups_leaderboard'.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 40),
            itemCount: groups.length,
            itemBuilder: (_, i) => _GroupSection(group: groups[i]),
          );
        },
      ),
    );
  }
}

// ── Group section ─────────────────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  final GroupModel group;
  const _GroupSection({required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Group header ───────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${group.memberCount} ${'members'.tr}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        // ── Ranked members ─────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: StreamBuilder<List<GroupMemberModel>>(
            stream: GroupService.instance.watchGroupMembers(group.id),
            builder: (ctx, membersSnap) {
              final members = membersSnap.data ?? [];
              if (members.isEmpty) {
                return _noDataRow('no_run_data_yet'.tr);
              }
              final memberUids = members.map((m) => m.uid).toList();
              return StreamBuilder<List<UserStats>>(
                stream: UserStatsService.instance
                    .watchFriendLeaderboard(memberUids),
                builder: (ctx, statsSnap) {
                  if (statsSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final stats = statsSnap.data ?? [];
                  if (stats.isEmpty) return _noDataRow('no_run_data_yet'.tr);
                  return Column(
                    children: [
                      if (stats.length >= 3)
                        _GroupPodium(top3: stats.take(3).toList()),
                      ...stats.skip(stats.length >= 3 ? 3 : 0).map(
                            (s) => _MemberRow(stats: s),
                          ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _noDataRow(String msg) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
      );
}

// ── Podium (top 3 within a group) ─────────────────────────────────────────────

class _GroupPodium extends StatelessWidget {
  final List<UserStats> top3;
  const _GroupPodium({required this.top3});

  @override
  Widget build(BuildContext context) {
    final order = top3.length == 3
        ? [top3[1], top3[0], top3[2]]
        : top3; // fallback for < 3
    final heights = [70.0, 96.0, 52.0];
    final avatarSizes = [46.0, 58.0, 40.0];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(order.length, (i) {
          final s = order[i];
          final isFirst = s.rank == 1;
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  Get.toNamed(AppRoutes.userProfile, arguments: s.uid),
              child: Column(
                children: [
                  if (isFirst)
                    const Text('👑', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 3),
                  UserAvatar(
                      label: s.label,
                      photoUrl: s.photoUrl,
                      size: avatarSizes[i]),
                  const SizedBox(height: 4),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFirst ? _medalColor(1) : AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    s.distanceStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _medalColor(s.rank),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: heights[i],
                    decoration: BoxDecoration(
                      color: _medalColor(s.rank).withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                      border: Border.all(
                          color: _medalColor(s.rank).withValues(alpha: 0.35),
                          width: 1.5),
                    ),
                    child: Center(
                      child: Text(_medalEmoji(s.rank),
                          style: const TextStyle(fontSize: 20)),
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

// ── Row for rank 4+ ───────────────────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  final UserStats stats;
  const _MemberRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(AppRoutes.userProfile, arguments: stats.uid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#${stats.rank}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            UserAvatar(label: stats.label, photoUrl: stats.photoUrl, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stats.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis),
                  Text('${stats.totalRuns} ${'runs'.tr}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Text(
              stats.distanceStr,
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
