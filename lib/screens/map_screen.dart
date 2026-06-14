import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/routes/app_routes.dart';
import '../controllers/kml_map_controller.dart';
import '../controllers/map_controller.dart';
import '../core/theme.dart';
import '../models/event_model.dart';
import '../services/group_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _ctrl = Get.find<MapController>();
  final _scrollController = ScrollController();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _ctrl.loadMore();
    }
  }

  bool _isLive(EventModel e) {
    if (e.isFinished) return false;
    if (!e.isToday) return false;
    final dt = e.eventDateTime;
    if (dt.year == 0) return false;
    return dt.isBefore(DateTime.now());
  }

  int _sortPriority(EventModel e) {
    if (_isLive(e)) return 0;
    if (!e.isFinished) return 1;
    return 2;
  }

  List<EventModel> get _filtered {
    final events = _ctrl.events.toList()
      ..sort((a, b) => _sortPriority(a).compareTo(_sortPriority(b)));
    if (_filter == 'live') return events.where(_isLive).toList();
    if (_filter == 'upcoming') {
      return events.where((e) => !e.isFinished && !_isLive(e)).toList();
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('events_title'.tr)
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _FilterTab(
                    label: 'filter_all'.tr,
                    value: 'all',
                    selected: _filter,
                    onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 16),
                _FilterTab(
                    label: 'filter_live'.tr,
                    value: 'live',
                    selected: _filter,
                    onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 16),
                _FilterTab(
                    label: 'filter_upcoming'.tr,
                    value: 'upcoming',
                    selected: _filter,
                    onTap: (v) => setState(() => _filter = v)),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_ctrl.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_ctrl.errorMsg.value.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text('error_loading'.tr,
                          style:
                              const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _ctrl.fetchEvents,
                        child: Text('refresh'.tr),
                      ),
                    ],
                  ),
                );
              }
              if (_ctrl.events.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map_outlined,
                          size: 64, color: Color(0xFFB0BEC5)),
                      const SizedBox(height: 16),
                      Text('no_events'.tr,
                          style: const TextStyle(
                              fontSize: 16, color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              }

              final filtered = _filtered;
              if (filtered.isEmpty) {
                return Center(
                  child: Text('no_events_filter'.tr,
                      style: const TextStyle(
                          fontSize: 14, color: AppTheme.textSecondary)),
                );
              }
              return RefreshIndicator(
                onRefresh: _ctrl.refresh,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: MediaQuery.of(context).padding.bottom + 8,
                  ),
                  itemCount: filtered.length +
                      (_ctrl.isLoadingMore.value ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == filtered.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return _EventCard(
                        key: ValueKey(filtered[i].id), event: filtered[i]);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;
  const _FilterTab(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? 20 : 0,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final EventModel event;
  const _EventCard({super.key, required this.event});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? _countdown() {
    final eventDt = widget.event.eventDateTime;
    if (eventDt.year == 0) return null;
    final diff = eventDt.difference(DateTime.now());
    if (diff.isNegative) return 'finished';
    if (diff.inDays >= 2) return '${diff.inDays} days remaining';
    final h = diff.inHours;
    if (h == 0) {
      // Floor gives 0 when <60 s remain — always show at least 1 min.
      final m = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return '$m min remaining';
    }
    final m = diff.inMinutes % 60;
    return '${h}h ${m}m remaining';
  }

  bool get _isFinished {
    final parts = widget.event.date.split('-');
    if (parts.length != 3) return false;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return false;
    final endOfEvent = DateTime(year, month, day + 1);
    return DateTime.now().isAfter(endOfEvent);
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown();
    final finished = _isFinished;
    final isLive = countdown == 'finished' && !finished;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: finished ? null : () => _showCategoryPicker(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BannerWithOverlay(
              event: widget.event,
              finished: finished,
              isLive: isLive,
              countdown: (countdown != null && countdown != 'finished')
                  ? countdown
                  : null,
            ),
            if (!finished && widget.event.hasRegistration) ...[
              const Divider(height: 1, thickness: 1),
              _RegistrationBar(event: widget.event),
            ],
            _GroupBar(eventId: widget.event.id, finished: finished),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    final cats = widget.event.categories.values.toList();

    if (cats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_categories'.tr),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final withKml =
        cats.where((c) => c.kmlUrl.isNotEmpty || c.kmlPath.isNotEmpty).toList();
    if (withKml.length == 1 && cats.length == 1) {
      _openMap(withKml.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPickerSheet(
        eventName: widget.event.name,
        categories: cats,
        onSelect: (cat) {
          Navigator.pop(context);
          _openMap(cat);
        },
      ),
    );
  }

  void _openMap(RaceCategory cat) {
    final runCtrl = Get.find<KmlMapController>();
    if (runCtrl.isTracking.value) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.directions_run,
              color: AppTheme.trackingGreen, size: 40),
          title: Text('already_running_title'.tr,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text('already_running_body'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Get.toNamed(AppRoutes.kmlMap);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.trackingGreen,
                  foregroundColor: Colors.white),
              child: Text('return_to_run'.tr),
            ),
          ],
        ),
      );
      return;
    }
    debugPrint('[MAP_SCREEN] Starting run with categoryId: ${cat.id}, category label: ${cat.label}');
    Get.toNamed(
      AppRoutes.kmlMap,
      arguments: {
        'kmlUrl': cat.kmlUrl,
        'storagePath': cat.kmlPath,
        'label': '${widget.event.name} (${cat.label})',
        'eventId': widget.event.id,
        'categoryId': cat.id,
        'eventDateTime': widget.event.eventDateTime.millisecondsSinceEpoch,
        'hasStartTime': widget.event.startTime.isNotEmpty,
        'cutoffMinutes': widget.event.cutoffMinutes,
        'chipTimeMinutes': widget.event.chipTimeMinutes,
        'graceTimeMinutes': widget.event.graceTimeMinutes,
        'categoryCutoff': cat.cutoff,
      },
    );
  }
}

// ── Banner with floating title / date / place overlay ────────────────────────

class _BannerWithOverlay extends StatelessWidget {
  final EventModel event;
  final bool finished;
  final bool isLive;
  final String? countdown;
  const _BannerWithOverlay({
    required this.event,
    this.finished = false,
    this.isLive = false,
    this.countdown,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (event.bannerUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: event.bannerUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => _gradientBg(),
              errorWidget: (_, __, ___) => _gradientBg(),
            )
          else
            _gradientBg(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.35, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),
          if (finished) Container(color: Colors.black.withValues(alpha: 0.45)),
          // ── LIVE badge — top left ──────────────────────────────────────
          if (isLive)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.trackingGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ── Status badge — top right ───────────────────────────────────
          if (finished)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag, size: 12, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      'event_finished'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (countdown != null)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      countdown!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(event.date,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientBg() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary,
              AppTheme.primary.withValues(alpha: 0.65),
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.directions_run, color: Colors.white54, size: 52),
        ),
      );
}

// ── Groups bar ────────────────────────────────────────────────────────────────

class _GroupBar extends StatefulWidget {
  final String eventId;
  final bool finished;
  const _GroupBar({required this.eventId, this.finished = false});
  @override
  State<_GroupBar> createState() => _GroupBarState();
}

class _GroupBarState extends State<_GroupBar> {
  late final Stream<int> _stream;

  @override
  void initState() {
    super.initState();
    _stream = GroupService.instance.watchMyGroupCountForEvent(widget.eventId);
  }

  @override
  void didUpdateWidget(_GroupBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _stream = GroupService.instance.watchMyGroupCountForEvent(widget.eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        final hasGroups = count > 0;

        // Finished event with no joined groups — nothing to show.
        if (widget.finished && !hasGroups) return const SizedBox.shrink();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1, thickness: 1),
            Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            onTap: () => Get.toNamed(
              AppRoutes.groupManagement,
              arguments: {'eventId': widget.eventId},
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasGroups
                      ? [const Color(0xFFFF6B35), const Color(0xFFE03E10)]
                      : [const Color.fromRGBO(218, 61, 32, 32),const Color.fromRGBO(218, 61, 32, 32)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.groups_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'groups'.tr,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            hasGroups
                                ? 'groups_count'
                                    .tr
                                    .replaceAll('@count', '$count')
                                : 'groups_cta'.tr,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasGroups)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '$count',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'join'.tr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ),
          ),
            ),
          ],
        );
      },
    );
  }
}

// ── Registration bar ──────────────────────────────────────────────────────────

class _RegistrationBar extends StatelessWidget {
  final EventModel event;
  const _RegistrationBar({required this.event});

  @override
  Widget build(BuildContext context) {
    final isOpen = event.isRegistrationOpen;

    String label;
    Color textColor;
    Color iconColor;
    if (isOpen) {
      label = 'register_now'.tr;
      textColor = const Color.fromARGB(218, 255, 0, 0);
      iconColor = const Color.fromARGB(255, 207, 65, 65);
    } else {
      final startParts = event.registrationStartDate.split('-');
      bool beforeStart = false;
      if (startParts.length == 3) {
        final startDate = DateTime(
          int.tryParse(startParts[0]) ?? 0,
          int.tryParse(startParts[1]) ?? 0,
          int.tryParse(startParts[2]) ?? 0,
        );
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        beforeStart = todayDate.isBefore(startDate);
      }
      label = beforeStart
          ? 'registration_opens'
              .tr
              .replaceAll('@date', event.registrationStartDate)
          : 'registration_closed'.tr;
      textColor = const Color.fromARGB(255, 116, 64, 64);
      iconColor = const Color.fromARGB(255, 208, 119, 119);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOpen ? () => _launch(context, event.registrationUrl) : null,
        child: Ink(
          decoration: BoxDecoration(
            // gradient: isOpen
            //     ? const LinearGradient(
            //         colors: [Color.fromARGB(255, 249, 222, 111),Color.fromARGB(255, 249, 222, 111)],
            //         begin: Alignment.centerLeft,
            //         end: Alignment.centerRight,
            //       )
            //     : null,
            color: isOpen ? const Color.fromARGB(255, 249, 222, 111) : const Color.fromARGB(255, 245, 190, 104),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isOpen
                      ? Icons.app_registration_rounded
                      : Icons.lock_outline_rounded,
                  size: 16,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                if (isOpen)
                  Icon(Icons.open_in_new_rounded,
                      size: 14, color: const Color.fromARGB(255, 245, 2, 2).withValues(alpha: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _launch(BuildContext context, String raw) async {
    final normalized = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open registration link.')),
        );
      }
    }
  }
}

// ── Category picker bottom sheet ──────────────────────────────────────────────

class _CategoryPickerSheet extends StatelessWidget {
  final String eventName;
  final List<RaceCategory> categories;
  final void Function(RaceCategory) onSelect;

  const _CategoryPickerSheet({
    required this.eventName,
    required this.categories,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scrollable = categories.length > 6;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(
                  eventName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'select_category'.tr,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          SizedBox(
            height: scrollable ? 6 * 72.0 : null,
            child: ListView.builder(
              shrinkWrap: !scrollable,
              physics: scrollable ? null : const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final cat = categories[i];
                final hasKml = cat.kmlUrl.isNotEmpty || cat.kmlPath.isNotEmpty;
                return InkWell(
                  onTap: hasKml ? () => onSelect(cat) : null,
                  child: Opacity(
                    opacity: hasKml ? 1.0 : 0.4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.directions_run,
                                color: AppTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.label,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (cat.cutoff.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cut-Off: ${cat.cutoff}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                                if (!hasKml) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'no_route_set'.tr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (hasKml)
                            const Icon(Icons.chevron_right,
                                color: AppTheme.textSecondary)
                          else
                            const Icon(Icons.lock_outline,
                                size: 18, color: Colors.orange),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
