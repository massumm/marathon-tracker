import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../models/runner_data.dart';
import '../../services/admin_service.dart';
import '../../widgets/user_avatar.dart';

class AdminLiveLeaderboardScreen extends StatefulWidget {
  final EventModel event;
  const AdminLiveLeaderboardScreen({super.key, required this.event});

  @override
  State<AdminLiveLeaderboardScreen> createState() =>
      _AdminLiveLeaderboardScreenState();
}

class _AdminLiveLeaderboardScreenState extends State<AdminLiveLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  bool _counting = false;   // pre-start countdown
  bool _ended = false;      // cutoff passed
  Duration _remaining = Duration.zero;
  Duration _cutoffRemaining = Duration.zero;
  Timer? _ticker;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;
  late TabController _tabController;
  StreamSubscription<List<RunnerData>>? _runnersSub;
  List<RunnerData> _runners = [];
  // null = all, 0 = male, 1 = female
  int? _genderFilter;

  @override
  void initState() {
    super.initState();
    _runnersSub = AdminService.instance
        .watchLiveRunnersForEvent(widget.event.id)
        .listen((runners) {
      if (mounted) setState(() => _runners = runners);
    });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _tabController = TabController(
      length: widget.event.categories.length,
      vsync: this,
    );

    final event = widget.event;
    if (event.startTime.isNotEmpty) {
      final rem = event.eventDateTime.difference(DateTime.now());
      if (rem.inSeconds > 0) {
        _counting = true;
        _remaining = rem;
      }
    }
    if (event.hasCutoff) {
      final cr = event.cutoffDateTime.difference(DateTime.now());
      if (cr.inSeconds <= 0) {
        _ended = true;
      } else {
        _cutoffRemaining = cr;
      }
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_counting) {
          final r = widget.event.eventDateTime.difference(DateTime.now());
          if (r.inSeconds <= 0) {
            _counting = false;
            _remaining = Duration.zero;
          } else {
            _remaining = r;
          }
        }
        if (widget.event.hasCutoff && !_ended) {
          final cr = widget.event.cutoffDateTime.difference(DateTime.now());
          if (cr.inSeconds <= 0) {
            _ended = true;
            _cutoffRemaining = Duration.zero;
          } else {
            _cutoffRemaining = cr;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _runnersSub?.cancel();
    _pulse.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Leaderboard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(widget.event.name,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ended
                ? const Text('ENDED',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                        letterSpacing: 1))
                : Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _counting ? Colors.orange : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _counting ? 'SOON' : 'LIVE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _counting ? Colors.orange : Colors.red,
                              letterSpacing: 1,
                            ),
                          ),
                          if (!_counting && widget.event.hasCutoff)
                            Text(
                              'cutoff ${_fmtDuration(_cutoffRemaining)}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textSecondary),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
      body: _ended
          ? _buildEnded()
          : _counting
              ? _buildCountdown()
              : Column(
                  children: [
                    if (widget.event.categories.isNotEmpty)
                      TabBar(
                        controller: _tabController,
                        isScrollable: widget.event.categories.length > 3,
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicatorColor: AppTheme.primary,
                        tabs: widget.event.categories.entries
                            .map((e) => Tab(text: e.value.label))
                            .toList(),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: widget.event.categories.entries
                            .map((catEntry) => _buildCategoryLeaderboard(catEntry.key))
                            .toList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String pad(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${pad(h)}:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}';
  }

  Widget _buildEnded() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flag_rounded, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Cutoff reached — Final Standings · ${widget.event.name}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Expanded(child: _buildLeaderboard()),
      ],
    );
  }

  Widget _buildCountdown() {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    String pad(int n) => n.toString().padLeft(2, '0');
    final showHours = _remaining.inHours > 0;
    final timeStr =
        showHours ? '${pad(h)}:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_outlined, size: 12, color: Colors.orange),
                SizedBox(width: 5),
                Text(
                  'NOT STARTED YET',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.event.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.event.date} at ${widget.event.startTime}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 44),
          ScaleTransition(
            scale: _pulseAnim,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                ),
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.20),
                      width: 1.5,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: showHours ? 42 : 54,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: showHours ? 2 : 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Live leaderboard will activate automatically',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLeaderboard(String categoryId) {
    final byCategory =
        _runners.where((r) => r.categoryId == categoryId).toList();
    final runners = _genderFilter == null
        ? byCategory
        : byCategory.where((r) => r.gender == _genderFilter).toList();

    return Column(
      children: [
        _GenderFilterBar(
          selected: _genderFilter,
          onChanged: (v) => setState(() => _genderFilter = v),
        ),
        if (runners.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_run_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No runners in this category',
                      style: TextStyle(
                          fontSize: 16, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('Waiting for participants to start...',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: runners.length,
              itemBuilder: (_, i) => _RunnerRow(runner: runners[i], rank: i + 1),
            ),
          ),
      ],
    );
  }

  Widget _buildLeaderboard() {
    return _buildCategoryLeaderboard(
      widget.event.categories.isNotEmpty
          ? widget.event.categories.entries.first.key
          : '',
    );
  }
}

class _GenderFilterBar extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;
  const _GenderFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _chip(null, 'All'),
          const SizedBox(width: 8),
          _chip(0, 'Male'),
          const SizedBox(width: 8),
          _chip(1, 'Female'),
        ],
      ),
    );
  }

  Widget _chip(int? value, String label) {
    final active = selected == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onChanged(value),
      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: active ? AppTheme.primary : AppTheme.textSecondary,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: active
            ? AppTheme.primary.withValues(alpha: 0.5)
            : Colors.grey.shade300,
      ),
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
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
