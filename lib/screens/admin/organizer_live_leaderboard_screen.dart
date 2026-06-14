import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../models/runner_data.dart';
import '../../services/admin_service.dart';
import '../../widgets/user_avatar.dart';

/// Shell-embedded leaderboard for the Organizer role.
/// No Scaffold/AppBar — the OrganizerShell owns the top bar.
class OrganizerLiveLeaderboardScreen extends StatefulWidget {
  final EventModel event;
  const OrganizerLiveLeaderboardScreen({super.key, required this.event});

  @override
  State<OrganizerLiveLeaderboardScreen> createState() =>
      _OrganizerLiveLeaderboardScreenState();
}

class _OrganizerLiveLeaderboardScreenState
    extends State<OrganizerLiveLeaderboardScreen>
    with TickerProviderStateMixin {
  bool _counting = false;
  bool _ended = false;
  late ValueNotifier<Duration> _remaining;
  late ValueNotifier<Duration> _cutoffRemaining;
  Timer? _ticker;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;
  late TabController _tabController;
  StreamSubscription<List<RunnerData>>? _runnersSub;
  List<RunnerData> _runners = [];
  Set<String> _finishedCats = {};

  Set<String> _computeFinishedCats() => widget.event.categories.values
      .where(widget.event.isCategoryFinished)
      .map((c) => c.id)
      .toSet();

  @override
  void initState() {
    super.initState();
    _runnersSub = AdminService.instance
        .watchLiveRunnersForEvent(widget.event.id)
        .listen((runners) {
      if (mounted) setState(() => _runners = runners);
    });
    _remaining = ValueNotifier(Duration.zero);
    _cutoffRemaining = ValueNotifier(Duration.zero);
    _finishedCats = _computeFinishedCats();

    debugPrint('[LEADERBOARD] Event: ${widget.event.name}, Categories count: ${widget.event.categories.length}');
    for (final cat in widget.event.categories.entries) {
      debugPrint('[LEADERBOARD] Category: ${cat.key} - ${cat.value.label}');
    }

    _tabController = TabController(
      length: widget.event.categories.length,
      vsync: this,
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    final event = widget.event;
    if (event.startTime.isNotEmpty) {
      final rem = event.eventDateTime.difference(DateTime.now());
      if (rem.inSeconds > 0) {
        _counting = true;
        _remaining.value = rem;
      }
    }
    if (event.hasCutoff) {
      final cr = event.cutoffDateTime.difference(DateTime.now());
      if (cr.inSeconds <= 0) {
        _ended = true;
      } else {
        _cutoffRemaining.value = cr;
      }
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_counting) {
        final r = widget.event.eventDateTime.difference(DateTime.now());
        if (r.inSeconds <= 0) {
          // setState required — _counting is a plain bool, not a ValueNotifier,
          // so build() won't re-run without it, leaving screen stuck at 00:00.
          setState(() {
            _counting = false;
            _remaining.value = Duration.zero;
          });
        } else {
          _remaining.value = r;
        }
      }
      if (widget.event.hasCutoff && !_ended) {
        final cr = widget.event.cutoffDateTime.difference(DateTime.now());
        if (cr.inSeconds <= 0) {
          setState(() {
            _ended = true;
            _cutoffRemaining.value = Duration.zero;
          });
        } else {
          _cutoffRemaining.value = cr;
        }
      }
      // Per-category cutoffs are independent of the event-level cutoff —
      // without this, a category tab only flips to final standings on the
      // next runner update instead of at the cutoff moment.
      final finishedNow = _computeFinishedCats();
      if (!setEquals(finishedNow, _finishedCats)) {
        setState(() => _finishedCats = finishedNow);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _runnersSub?.cancel();
    _pulse.dispose();
    _remaining.dispose();
    _cutoffRemaining.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String pad(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${pad(h)}:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_ended) return _buildEnded();
    if (_counting) return _buildCountdown();

    if (widget.event.categories.isEmpty) {
      return _buildLeaderboard(null);
    }

    final categoryList = widget.event.categories.entries.toList();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: categoryList.length > 3,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: categoryList.map((e) => Tab(text: e.value.label)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: categoryList
                .map((catEntry) => _buildLeaderboard(catEntry.value))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEnded() {
    return Column(
      children: [
        _finalStandingsBanner(widget.event.name),
        Expanded(child: _buildLeaderboard(null)),
      ],
    );
  }

  Widget _finalStandingsBanner(String label) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.flag_rounded, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            'Cutoff reached — Final Standings · $label',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _remaining,
      builder: (_, remaining, __) {
        final h = remaining.inHours;
        final m = remaining.inMinutes.remainder(60);
        final s = remaining.inSeconds.remainder(60);
        String pad(int n) => n.toString().padLeft(2, '0');
        final showHours = remaining.inHours > 0;
        final timeStr =
            showHours ? '${pad(h)}:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}';

    final eventDate = widget.event.date;
    final eventTime = widget.event.startTime;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.red.withValues(alpha: 0.35)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_outlined, size: 12, color: Colors.red),
                SizedBox(width: 5),
                Text(
                  'NOT STARTED YET',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
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
            '$eventDate at $eventTime',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 40),
          ScaleTransition(
            scale: _pulseAnim,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
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
                  width: 164,
                  height: 164,
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
                    fontSize: showHours ? 40 : 52,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: showHours ? 2 : 4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Live leaderboard will activate automatically',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
      },
    );
  }

  /// [cat] is null for the no-categories and event-ended fallbacks,
  /// which show all runners.
  Widget _buildLeaderboard(RaceCategory? cat) {
    final finished = cat != null && _finishedCats.contains(cat.id);
    final runners = cat == null
        ? _runners
        : _runners.where((r) => r.categoryId == cat.id).toList();

    if (runners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_run_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No runners yet',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(
              'Waiting for participants in "${widget.event.name}"...',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (finished)
          _finalStandingsBanner(cat.label)
        else
          ValueListenableBuilder<Duration>(
            valueListenable: _cutoffRemaining,
            builder: (_, cutoff, __) {
              final cutoffDisplay = (!_ended && widget.event.hasCutoff)
                  ? _fmtDuration(cutoff)
                  : null;
              return _LiveBanner(
                  eventName: widget.event.name,
                  count: runners.length,
                  cutoffRemaining: cutoffDisplay);
            },
          ),
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
}

class _LiveBanner extends StatelessWidget {
  final String eventName;
  final int count;
  final String? cutoffRemaining;
  const _LiveBanner(
      {required this.eventName, required this.count, this.cutoffRemaining});

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count running',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary),
              ),
              if (cutoffRemaining != null)
                Text(
                  'cutoff $cutoffRemaining',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                ),
            ],
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
