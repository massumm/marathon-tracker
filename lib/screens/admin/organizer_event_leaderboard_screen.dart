import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../../models/user_stats.dart';
import '../../../services/admin_service.dart';
import '../../../widgets/user_avatar.dart';

/// Post-event results screen — results split by category tabs.
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
  late TabController _tabController;
  StreamSubscription<List<UserStats>>? _sub;
  List<UserStats> _stats = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.event.categories.length,
      vsync: this,
    );
    _sub = AdminService.instance
        .watchEventResults(widget.event.id)
        .listen((stats) {
      if (mounted) setState(() => _stats = stats);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Event header bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.trackingGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.trackingGreen.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 13, color: AppTheme.trackingGreen),
                    SizedBox(width: 5),
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
        ),
        const Divider(height: 1, thickness: 1),
        if (widget.event.categories.isNotEmpty) ...[
          TabBar(
            controller: _tabController,
            isScrollable: widget.event.categories.length > 3,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.10)),
            tabs: widget.event.categories.entries
                .map((e) => Tab(text: e.value.label))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: widget.event.categories.entries
                  .map((e) => _buildList(e.key))
                  .toList(),
            ),
          ),
        ] else
          Expanded(child: _buildList(null)),
      ],
    );
  }

  Widget _buildList(String? categoryId) {
    final firstCategoryId = widget.event.categories.isNotEmpty
        ? widget.event.categories.entries.first.key
        : null;
    final filtered = categoryId == null
        ? _stats
        : _stats.where((s) {
            if (s.categoryId == categoryId) return true;
            // Old runs with no categoryId stored fall into the first tab
            if (s.categoryId.isEmpty && categoryId == firstCategoryId) return true;
            return false;
          }).toList();
    return _GenderTabbedResults(stats: filtered);
  }
}

class _GenderTabbedResults extends StatefulWidget {
  final List<UserStats> stats;
  const _GenderTabbedResults({required this.stats});

  @override
  State<_GenderTabbedResults> createState() => _GenderTabbedResultsState();
}

class _GenderTabbedResultsState extends State<_GenderTabbedResults> {
  int _selected = 0; // 0=All, 1=Male, 2=Female

  List<UserStats> _ranked(Iterable<UserStats> src) {
    final list = src.toList();
    for (int i = 0; i < list.length; i++) {
      list[i].rank = i + 1;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _selected == 1
        ? _ranked(widget.stats.where((s) => s.gender == 0))
        : _selected == 2
            ? _ranked(widget.stats.where((s) => s.gender == 1))
            : _ranked(widget.stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              _chip(0, 'All'),
              const SizedBox(width: 6),
              _chip(1, 'Male'),
              const SizedBox(width: 6),
              _chip(2, 'Female'),
            ],
          ),
        ),
        Expanded(child: _list(displayed)),
      ],
    );
  }

  Widget _chip(int value, String label) {
    final active = _selected == value;
    return GestureDetector(
      onTap: () => setState(() => _selected = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primary.withValues(alpha: 0.5) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _list(List<UserStats> ranked) {
    if (ranked.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No results', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: ranked.length,
      itemBuilder: (_, i) => _ResultRow(stat: ranked[i]),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final UserStats stat;
  const _ResultRow({required this.stat});

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
            UserAvatar(label: label, photoUrl: stat.photoUrl, size: 40),
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
  }
}
