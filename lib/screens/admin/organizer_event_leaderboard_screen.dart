import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../models/user_stats.dart';
import '../../services/admin_service.dart';
import '../../widgets/user_avatar.dart';

/// Post-event results screen — overall participant leaderboard only.
/// No Scaffold — the OrganizerShell owns the top bar.
class OrganizerEventLeaderboardScreen extends StatelessWidget {
  final EventModel event;
  const OrganizerEventLeaderboardScreen({super.key, required this.event});

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
                  event.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                event.date,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: StreamBuilder<List<UserStats>>(
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
          ),
        ),
      ],
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
