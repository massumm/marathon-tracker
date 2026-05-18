import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/admin_service.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: AdminService.instance.watchStats(),
      builder: (context, snap) {
        final stats = snap.data;
        final loading = snap.connectionState == ConnectionState.waiting;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome banner ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1D2E), Color(0xFF2D3148)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    _AdminIcon(),
                    SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to Admin Panel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage events, users and marathon routes',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Stats ───────────────────────────────────────────────────
              loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Row(
                      children: [
                        _StatCard(
                          icon: Icons.people,
                          label: 'Total Users',
                          value: '${stats?['users'] ?? 0}',
                          color: AppTheme.secondary,
                          gradient: const [
                            Color(0xFF00B4D8),
                            Color(0xFF0096C7)
                          ],
                        ),
                        const SizedBox(width: 20),
                        _StatCard(
                          icon: Icons.event,
                          label: 'Events',
                          value: '${stats?['events'] ?? 0}',
                          color: AppTheme.primary,
                          gradient: const [
                            Color(0xFFFF6B35),
                            Color(0xFFE05520)
                          ],
                        ),
                        const SizedBox(width: 20),
                        const _StatCard(
                          icon: Icons.map,
                          label: 'KML Routes',
                          value: '—',
                          color: AppTheme.trackingGreen,
                          gradient: [
                            Color(0xFF48BB78),
                            Color(0xFF38A169)
                          ],
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminIcon extends StatelessWidget {
  const _AdminIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.admin_panel_settings,
          color: AppTheme.primary, size: 30),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final List<Color> gradient;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
