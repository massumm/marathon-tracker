import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/admin_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await AdminService.instance.fetchUsers();
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _users = []; _loading = false; });
    }
  }

  String _timeStr(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No users yet',
                            style: TextStyle(
                                fontSize: 16, color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FB),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey.shade200, width: 1),
                              ),
                            ),
                            child: Row(
                              children: [
                                _headerCell('#', width: 40),
                                _headerCell('User', flex: 2),
                                _headerCell('Distance'),
                                _headerCell('Runs'),
                                _headerCell('Time'),
                              ],
                            ),
                          ),

                          // Rows
                          ...List.generate(_users.length, (i) {
                            final u = _users[i];
                            final label =
                                (u['displayName'] as String).isNotEmpty
                                    ? u['displayName'] as String
                                    : (u['email'] as String).split('@').first;
                            final dist = (u['totalDistanceKm'] as double)
                                .toStringAsFixed(2);
                            final runs = u['totalRuns'] as int;
                            final secs = u['totalSeconds'] as int;
                            final photo = u['photoUrl'] as String;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                border: i < _users.length - 1
                                    ? Border(
                                        bottom: BorderSide(
                                            color: Colors.grey.shade100,
                                            width: 1),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // Rank
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: i < 3
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  // Avatar + name
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AppTheme.primary
                                              .withValues(alpha: 0.12),
                                          backgroundImage: photo.isNotEmpty
                                              ? NetworkImage(photo)
                                              : null,
                                          child: photo.isEmpty
                                              ? Text(
                                                  label.isNotEmpty
                                                      ? label[0].toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppTheme.primary,
                                                      fontSize: 14),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(label,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14)),
                                              Text(u['email'] as String,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme
                                                          .textSecondary),
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Distance
                                  Expanded(
                                    child: Text(
                                      '$dist km',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  // Runs
                                  Expanded(
                                    child: Text('$runs',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textPrimary)),
                                  ),
                                  // Time
                                  Expanded(
                                    child: Text(_timeStr(secs),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textPrimary)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

        // Refresh FAB
        Positioned(
          right: 28,
          bottom: 28,
          child: FloatingActionButton(
            mini: true,
            onPressed: _load,
            tooltip: 'Refresh',
            child: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text, {double? width, int flex = 1}) {
    final child = Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary,
        letterSpacing: 0.3,
      ),
    );
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex, child: child);
  }
}
