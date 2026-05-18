import 'dart:async';

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
      stream: AdminService.instance.watchLiveRunnersForEvent(event.id),
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
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: runners.length,
                itemBuilder: (_, i) =>
                    _RunnerRow(runner: runners[i], rank: i + 1),
              ),
            ),
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

class _RunnerRow extends StatefulWidget {
  final RunnerData runner;
  final int rank;
  const _RunnerRow({required this.runner, required this.rank});

  @override
  State<_RunnerRow> createState() => _RunnerRowState();
}

class _RunnerRowState extends State<_RunnerRow> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isOnline =>
      DateTime.now().millisecondsSinceEpoch - widget.runner.lastSeen < 120000;

  String _lastSeenText() {
    final ms =
        DateTime.now().millisecondsSinceEpoch - widget.runner.lastSeen;
    if (ms < 60000) return 'just now';
    if (ms < 3600000) return '${ms ~/ 60000}m ago';
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    return m > 0 ? '${h}h ${m}m ago' : '${h}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final runner = widget.runner;
    final label = runner.displayName.isNotEmpty
        ? runner.displayName
        : runner.email.split('@').first;
    final online = _isOnline;

    final elapsedMs =
        (DateTime.now().millisecondsSinceEpoch - runner.startedAt)
            .clamp(0, double.maxFinite.toInt());
    final hours = elapsedMs ~/ 3600000;
    final minutes = (elapsedMs % 3600000) ~/ 60000;
    final seconds = (elapsedMs % 60000) ~/ 1000;
    final timeStr =
        hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m ${seconds}s';

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
          // Rank
          SizedBox(
            width: 28,
            child: Text(
              '#${widget.rank}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Online / offline dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF2E7D32) : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          UserAvatar(label: label, photoUrl: runner.photoUrl, size: 38),
          const SizedBox(width: 10),
          // Name + status line
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
                  online ? runner.email : 'offline · ${_lastSeenText()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: online
                        ? AppTheme.textSecondary
                        : Colors.redAccent.shade200,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Distance + elapsed time
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
