import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../../services/admin_service.dart';
import 'event_form_screen.dart';
import 'organizer_live_map_screen.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  static const _pageSize = 15;

  final _scrollController = ScrollController();
  final _events = <EventModel>[];
  bool _loading = false;
  bool _hasMore = true;
  bool _initialized = false;
  EventModel? _cursor;

  @override
  void initState() {
    super.initState();
    _loadPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);

    final page = await AdminService.instance.fetchEventsPage(
      pageSize: _pageSize,
      cursor: _cursor,
    );

    if (!mounted) return;
    setState(() {
      _events.addAll(page);
      if (page.isNotEmpty) _cursor = page.last;
      _hasMore = page.length == _pageSize;
      _loading = false;
      _initialized = true;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _events.clear();
      _cursor = null;
      _hasMore = true;
      _initialized = false;
    });
    await _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        if (_events.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No events yet',
                    style:
                        TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                const Text('Create your first marathon event',
                    style:
                        TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          )
        else
          ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 100),
            itemCount: _events.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _events.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final event = _events[i];
              return _EventCard(
                event: event,
                onDeleted: () => setState(
                    () => _events.removeWhere((e) => e.id == event.id)),
                onEdited: _refresh,
              );
            },
          ),

        // FAB
        Positioned(
          right: 28,
          bottom: 28,
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('New Event'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EventFormScreen()),
            ).then((_) => _refresh()),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onDeleted;
  final VoidCallback onEdited;

  const _EventCard({
    required this.event,
    required this.onDeleted,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final uploadedCats =
        event.categories.values.where((c) => c.kmlPath.isNotEmpty).length;
    final totalCats = event.categories.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Banner
          if (event.bannerUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                event.bannerUrl,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary,
                        AppTheme.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: const Center(
                    child: Icon(Icons.directions_run,
                        color: Colors.white, size: 36),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary,
                    AppTheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child:
                    Icon(Icons.directions_run, color: Colors.white, size: 36),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    _ActionIcon(
                      icon: Icons.edit_outlined,
                      color: AppTheme.textSecondary,
                      tooltip: 'Edit',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventFormScreen(existing: event),
                        ),
                      ).then((_) => onEdited()),
                    ),
                    const SizedBox(width: 4),
                    _ActionIcon(
                      icon: Icons.delete_outline,
                      color: Colors.redAccent,
                      tooltip: 'Delete',
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Date + location
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(event.date,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(width: 20),
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(event.location,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),

                const SizedBox(height: 16),

                // Categories chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: event.categories.values.map((cat) {
                    final hasKml = cat.kmlPath.isNotEmpty;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasKml
                            ? AppTheme.trackingGreen.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasKml
                              ? AppTheme.trackingGreen.withValues(alpha: 0.4)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasKml
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            size: 13,
                            color: hasKml
                                ? AppTheme.trackingGreen
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasKml
                                  ? AppTheme.trackingGreen
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          if (cat.cutoff.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${cat.cutoff})',
                              style: TextStyle(
                                fontSize: 10,
                                color: hasKml
                                    ? AppTheme.trackingGreen
                                        .withValues(alpha: 0.7)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),
                Text(
                  '$uploadedCats / $totalCats KML files uploaded',
                  style: TextStyle(
                    fontSize: 12,
                    color: uploadedCats == totalCats && totalCats > 0
                        ? AppTheme.trackingGreen
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _LiveLeaderboardButton(event: event),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Delete "${event.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await AdminService.instance.deleteEvent(event.id);
              onDeleted();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _LiveLeaderboardButton extends StatefulWidget {
  final EventModel event;
  const _LiveLeaderboardButton({required this.event});

  @override
  State<_LiveLeaderboardButton> createState() => _LiveLeaderboardButtonState();
}

class _LiveLeaderboardButtonState extends State<_LiveLeaderboardButton> {
  Timer? _finishTimer;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _armTimers();
  }

  @override
  void didUpdateWidget(_LiveLeaderboardButton old) {
    super.didUpdateWidget(old);
    if (old.event.finishDateTime != widget.event.finishDateTime ||
        old.event.eventDateTime != widget.event.eventDateTime) {
      _armTimers();
    }
  }

  void _armTimers() {
    _finishTimer?.cancel();
    _startTimer?.cancel();
    final now = DateTime.now();
    final finish = widget.event.finishDateTime;
    if (finish != null) {
      final delay = finish.difference(now);
      if (!delay.isNegative) {
        _finishTimer = Timer(delay + const Duration(seconds: 1), () {
          if (mounted) setState(() {});
        });
      }
    }
    final startDelay = widget.event.eventDateTime.difference(now);
    if (!startDelay.isNegative) {
      _startTimer = Timer(startDelay + const Duration(seconds: 1), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _startTimer?.cancel();
    super.dispose();
  }

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerLiveMapScreen(event: widget.event),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isEnded = event.isResultsReady;
    final isRunning = event.isRunning;

    if (isEnded) {
      return _buildButton(
        context,
        gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
        icon: Icons.emoji_events_outlined,
        label: 'View Final Results',
      );
    }

    if (isRunning) {
      return StreamBuilder(
        stream: AdminService.instance.watchLiveRunnersForEvent(event.id),
        builder: (_, snap) {
          final count = snap.data?.length ?? 0;
          return _buildButton(
            context,
            gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
            liveDot: true,
            label:
                'LIVE — View Leaderboard${count > 0 ? '  ($count running)' : ''}',
          );
        },
      );
    }

    return _buildButton(
      context,
      color: Colors.grey.shade200,
      icon: Icons.leaderboard_outlined,
      iconColor: Colors.grey.shade400,
      label: 'Leaderboard (upcoming)',
      labelColor: Colors.grey.shade500,
      enabled: false,
    );
  }

  Widget _buildButton(
    BuildContext context, {
    LinearGradient? gradient,
    Color? color,
    IconData? icon,
    Color? iconColor,
    bool liveDot = false,
    required String label,
    Color? labelColor,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: gradient,
          color: color,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? () => _open(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (liveDot)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    )
                  else if (icon != null)
                    Icon(icon, size: 16, color: iconColor ?? Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: labelColor ?? Colors.white,
                      letterSpacing: gradient != null ? 0.3 : 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
