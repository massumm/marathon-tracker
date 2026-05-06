import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../models/user_stats.dart';
import '../../services/admin_service.dart';
import '../../widgets/user_avatar.dart';

/// Post-event results screen with Overall and By Group tabs.
/// No Scaffold — the OrganizerShell owns the top bar.
class OrganizerEventLeaderboardScreen extends StatefulWidget {
  final EventModel event;
  const OrganizerEventLeaderboardScreen({super.key, required this.event});

  @override
  State<OrganizerEventLeaderboardScreen> createState() =>
      _OrganizerEventLeaderboardScreenState();
}

class _OrganizerEventLeaderboardScreenState
    extends State<OrganizerEventLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Event header bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.trackingGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              AppTheme.trackingGreen.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_outlined,
                            size: 13, color: AppTheme.trackingGreen),
                        const SizedBox(width: 5),
                        Text(
                          'Results',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trackingGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.event.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    widget.event.date,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TabBar(
                controller: _tabs,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Overall'),
                  Tab(text: 'By Group'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _OverallTab(event: widget.event),
              _ByGroupTab(event: widget.event),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Overall tab ───────────────────────────────────────────────────────────────

class _OverallTab extends StatelessWidget {
  final EventModel event;
  const _OverallTab({required this.event});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserStats>>(
      stream: AdminService.instance.watchEventResults(event.id),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snap.data ?? [];
        if (stats.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.leaderboard_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No results yet',
                    style: TextStyle(
                        fontSize: 16, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                const Text('Participant data will appear after the event.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: stats.length,
          itemBuilder: (_, i) => _ResultRow(stat: stats[i]),
        );
      },
    );
  }
}

// ── By Group tab ──────────────────────────────────────────────────────────────

class _GroupInfo {
  final String groupId;
  final String name;
  final List<String> memberUids;
  const _GroupInfo(
      {required this.groupId,
      required this.name,
      required this.memberUids});
}

class _ByGroupTab extends StatefulWidget {
  final EventModel event;
  const _ByGroupTab({required this.event});

  @override
  State<_ByGroupTab> createState() => _ByGroupTabState();
}

class _ByGroupTabState extends State<_ByGroupTab> {
  late final Future<List<_GroupInfo>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroups();
  }

  Future<List<_GroupInfo>> _loadGroups() async {
    final db = FirebaseDatabase.instance;
    final snap = await db.ref('event_groups/${widget.event.id}').get();
    if (!snap.exists || snap.value == null) return [];

    final groupIds =
        (snap.value as Map<dynamic, dynamic>).keys.map((k) => k as String).toList();

    final snaps = await Future.wait(
      groupIds.map((gid) => Future.wait([
            db.ref('groups/$gid').get(),
            db.ref('group_members/$gid').get(),
          ])),
    );

    final result = <_GroupInfo>[];
    for (int i = 0; i < groupIds.length; i++) {
      final groupSnap = snaps[i][0];
      final membersSnap = snaps[i][1];
      final groupData = groupSnap.exists && groupSnap.value is Map
          ? groupSnap.value as Map<dynamic, dynamic>
          : <dynamic, dynamic>{};
      final name = groupData['name'] as String? ?? 'Group';
      final memberUids = membersSnap.exists && membersSnap.value is Map
          ? (membersSnap.value as Map<dynamic, dynamic>)
              .keys
              .map((k) => k as String)
              .toList()
          : <String>[];
      result.add(_GroupInfo(
          groupId: groupIds[i], name: name, memberUids: memberUids));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_GroupInfo>>(
      future: _groupsFuture,
      builder: (_, groupSnap) {
        if (groupSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = groupSnap.data ?? [];
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No groups for this event',
                    style: TextStyle(
                        fontSize: 16, color: AppTheme.textSecondary)),
              ],
            ),
          );
        }
        return StreamBuilder<List<UserStats>>(
          stream: AdminService.instance.watchEventResults(widget.event.id),
          builder: (_, statsSnap) {
            final allStats = statsSnap.data ?? [];
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: groups.length,
              itemBuilder: (_, i) {
                final group = groups[i];
                final allowed = group.memberUids.toSet();
                var groupStats = allStats
                    .where((s) => allowed.contains(s.uid))
                    .toList();
                for (int r = 0; r < groupStats.length; r++) {
                  groupStats[r].rank = r + 1;
                }
                return _GroupSection(
                    groupName: group.name, stats: groupStats);
              },
            );
          },
        );
      },
    );
  }
}

class _GroupSection extends StatelessWidget {
  final String groupName;
  final List<UserStats> stats;
  const _GroupSection({required this.groupName, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group, size: 17, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    groupName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${stats.length} finisher${stats.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
          if (stats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No participants from this group',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            )
          else
            ...stats.map((s) => _ResultRow(stat: s, isInCard: true)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Shared row widget ─────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  final UserStats stat;
  final bool isInCard;
  const _ResultRow({required this.stat, this.isInCard = false});

  @override
  Widget build(BuildContext context) {
    final rank = stat.rank;
    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : Colors.grey.shade400;

    final label = stat.displayName.isNotEmpty
        ? stat.displayName
        : stat.email.isNotEmpty
            ? stat.email.split('@').first
            : stat.uid.substring(0, 6);

    Widget row = Padding(
      padding: EdgeInsets.symmetric(
          horizontal: isInCard ? 16 : 0, vertical: 6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: isInCard
            ? null
            : BoxDecoration(
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
            // Rank badge
            SizedBox(
              width: 36,
              child: rank <= 3
                  ? Icon(Icons.emoji_events_rounded,
                      size: 22, color: medalColor)
                  : Text(
                      '#$rank',
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
                label: label, photoUrl: stat.photoUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stat.totalDistanceKm.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  stat.timeStr,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return row;
  }
}
