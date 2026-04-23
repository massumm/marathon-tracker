import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../models/runner_data.dart';
import '../../services/admin_service.dart';
import '../../widgets/user_avatar.dart';

class AdminLiveLeaderboardScreen extends StatelessWidget {
  final EventModel event;
  const AdminLiveLeaderboardScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Leaderboard',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(event.name,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          // Live indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
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
                const SizedBox(width: 6),
                const Text('LIVE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                        letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<RunnerData>>(
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
                      style: TextStyle(
                          fontSize: 16, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('Waiting for participants to start...',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: runners.length,
            itemBuilder: (_, i) =>
                _RunnerRow(runner: runners[i], rank: i + 1),
          );
        },
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
