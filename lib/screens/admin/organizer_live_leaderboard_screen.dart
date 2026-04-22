import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../models/runner_data.dart';
import '../../services/admin_service.dart';
import '../../widgets/user_avatar.dart';

/// Shell-embedded leaderboard for the Organizer role.
/// No Scaffold/AppBar — the OrganizerShell owns the top bar.
class OrganizerLiveLeaderboardScreen extends StatelessWidget {
  final EventModel event;
  const OrganizerLiveLeaderboardScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RunnerData>>(
      stream: AdminService.instance.watchLiveRunners(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final runners = snap.data ?? [];

        if (runners.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_run_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No runners yet',
                    style:
                        TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Text(
                  'Waiting for participants in "${event.name}"...',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _LiveBanner(eventName: event.name, count: runners.length),
            if (runners.length >= 3)
              _Podium(top3: runners.take(3).toList()),
            if (runners.length < 3)
              _SmallPodium(runners: runners),
            if (runners.length > 3)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: runners.length - 3,
                  itemBuilder: (_, i) {
                    final r = runners[i + 3];
                    return _RunnerRow(runner: r, rank: i + 4);
                  },
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        );
      },
    );
  }
}

class _LiveBanner extends StatelessWidget {
  final String eventName;
  final int count;
  const _LiveBanner({required this.eventName, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text('LIVE',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                  letterSpacing: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              eventName,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$count running',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<RunnerData> top3;
  const _Podium({required this.top3});

  @override
  Widget build(BuildContext context) {
    final order = [top3[1], top3[0], top3[2]];
    final ranks = [2, 1, 3];
    final heights = [80.0, 110.0, 60.0];
    final avatarSizes = [52.0, 66.0, 46.0];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final r = order[i];
          final rank = ranks[i];
          final isFirst = rank == 1;
          final label = r.displayName.isNotEmpty
              ? r.displayName
              : r.email.split('@').first;

          return Expanded(
            child: Column(
              children: [
                if (isFirst)
                  const Text('👑', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                UserAvatar(
                    label: label,
                    photoUrl: r.photoUrl,
                    size: avatarSizes[i]),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isFirst ? _medalColor(1) : AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${r.distanceKm.toStringAsFixed(2)} km',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _medalColor(rank),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: _medalColor(rank).withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    border: Border.all(
                        color: _medalColor(rank).withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: Center(
                    child: Text(_medalEmoji(rank),
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ],
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

class _SmallPodium extends StatelessWidget {
  final List<RunnerData> runners;
  const _SmallPodium({required this.runners});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: runners.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          return _RunnerRow(runner: entry.value, rank: rank);
        }).toList(),
      ),
    );
  }
}

class _RunnerRow extends StatelessWidget {
  final RunnerData runner;
  final int rank;
  const _RunnerRow({required this.runner, required this.rank});

  @override
  Widget build(BuildContext context) {
    final label = runner.displayName.isNotEmpty
        ? runner.displayName
        : runner.email.split('@').first;

    final elapsed = DateTime.now().millisecondsSinceEpoch - runner.startedAt;
    final minutes = elapsed ~/ 60000;
    final seconds = (elapsed % 60000) ~/ 1000;
    final timeStr = '${minutes}m ${seconds}s';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
            child: Text(
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
          UserAvatar(label: label, photoUrl: runner.photoUrl, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  runner.email,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${runner.distanceKm.toStringAsFixed(2)} km',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
