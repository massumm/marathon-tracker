import 'dart:async';
import 'dart:math' as math;

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

class MapScreen extends GetView<MapController> {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMsg.value.isNotEmpty) {
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
                  onPressed: controller.fetchEvents,
                  child: Text('refresh'.tr),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.fetchEvents,
          child: _EventListView(events: controller.events),
        );
      }),
    );
  }
}

// ── Horizontal PageView with title + filter tabs ──────────────────────────────

class _EventListView extends StatefulWidget {
  final List<EventModel> events;
  const _EventListView({required this.events});

  @override
  State<_EventListView> createState() => _EventListViewState();
}

class _EventListViewState extends State<_EventListView> {
  late final PageController _pageCtrl =
      PageController(viewportFraction: 0.87);
  String _filter = 'all';

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _setFilter(String f) {
    setState(() => _filter = f);
    if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
  }

  DateTime _eventDate(EventModel e) {
    final parts = e.date.split('-');
    if (parts.length != 3) return DateTime(0);
    return DateTime(
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
      int.tryParse(parts[2]) ?? 0,
    );
  }

  List<EventModel> get _filtered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_filter == 'live') {
      return widget.events.where((e) => _eventDate(e) == today).toList();
    }
    if (_filter == 'upcoming') {
      return widget.events
          .where((e) => _eventDate(e).isAfter(today))
          .toList();
    }
    return widget.events;
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title + filter tabs ────────────────────────────
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'events_title'.tr,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _FilterTab('all', _filter, _setFilter),
                    _FilterTab('live', _filter, _setFilter),
                    _FilterTab('upcoming', _filter, _setFilter),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),

        // ── Event cards or empty state ─────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('no_events_filter'.tr,
                      style: const TextStyle(
                          fontSize: 14, color: AppTheme.textSecondary)))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: screenH * 0.60,
                    child: PageView.builder(
                      clipBehavior: Clip.none,
                      controller: _pageCtrl,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => AnimatedBuilder(
                        animation: _pageCtrl,
                        builder: (_, __) {
                          double pageOffset = 0;
                          if (_pageCtrl.position.haveDimensions) {
                            pageOffset = _pageCtrl.page! - i;
                          }
                          final gauss = math.exp(-(math
                              .pow((pageOffset.abs() - 0.5), 2) /
                              0.08));
                          return Transform.translate(
                            offset: Offset(
                                -32 * gauss * pageOffset.sign, 0),
                            child: _EventCard(
                              event: filtered[i],
                              pageOffset: pageOffset,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Filter tab widget ─────────────────────────────────────────────────────────

class _FilterTab extends StatelessWidget {
  final String value;
  final String selected;
  final void Function(String) onTap;
  const _FilterTab(this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'filter_$value'.tr,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
                color: active
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: active ? 22 : 0,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final EventModel event;
  final double pageOffset;
  const _EventCard({required this.event, required this.pageOffset});

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
    if (diff.isNegative) return null;
    if (diff.inDays == 0) {
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      if (h == 0) return '$m min remaining';
      return '${h}h ${m}m remaining';
    }
    if (diff.inDays == 1) return '1 day remaining';
    return '${diff.inDays} days remaining';
  }

  bool get _isFinished {
    final parts = widget.event.date.split('-');
    if (parts.length != 3) return false;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return false;
    return DateTime.now().isAfter(DateTime(year, month, day + 1));
  }

  @override
  Widget build(BuildContext context) {
    final finished = _isFinished;
    final countdown = _countdown();
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      clipBehavior: Clip.none,
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            offset: const Offset(8, 20),
            blurRadius: 24,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Parallax banner image ──────────────────────
            GestureDetector(
              onTap: finished ? null : () => _showCategoryPicker(context),
              child: SizedBox(
                height: screenH * 0.30,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Banner with parallax alignment
                    widget.event.bannerUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.event.bannerUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment(
                                -widget.pageOffset.abs().clamp(0.0, 1.0), 0),
                            placeholder: (_, __) => _gradientBg(),
                            errorWidget: (_, __, ___) => _gradientBg(),
                          )
                        : _gradientBg(),

                    // Bottom scrim
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.4, 1.0],
                          colors: [Colors.transparent, Color(0xCC000000)],
                        ),
                      ),
                    ),

                    // Finished overlay
                    if (finished) Container(color: const Color(0x73000000)),

                    // Finished badge
                    if (finished)
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xA6000000),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flag,
                                  size: 13, color: Colors.white70),
                              const SizedBox(width: 5),
                              Text('event_finished'.tr,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),

                    // Event name bottom-left
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Text(
                        widget.event.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black54)
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Info section ───────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: finished ? null : () => _showCategoryPicker(context),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(widget.event.date,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_outlined,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.event.location,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (countdown != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 12, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(countdown,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.redAccent)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Registration bar ───────────────────────────
            _RegistrationBar(event: widget.event),

            // ── Groups bar ─────────────────────────────────
            _GroupBar(eventId: widget.event.id),
          ],
        ),
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
          child:
              Icon(Icons.directions_run, color: Colors.white54, size: 52),
        ),
      );

  void _showCategoryPicker(BuildContext context) {
    final cats = widget.event.categories.values.toList();
    if (cats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('no_categories'.tr),
          backgroundColor: Colors.orange));
      return;
    }
    final withKml = cats
        .where((c) => c.kmlUrl.isNotEmpty || c.kmlPath.isNotEmpty)
        .toList();
    if (withKml.length == 1 && cats.length == 1) {
      _openMap(withKml.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.directions_run,
              color: AppTheme.trackingGreen, size: 40),
          title: Text('already_running_title'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text('already_running_body'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr)),
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
    Get.toNamed(AppRoutes.kmlMap, arguments: {
      'kmlUrl': cat.kmlUrl,
      'storagePath': cat.kmlPath,
      'label': '${widget.event.name} (${cat.label})',
      'eventId': widget.event.id,
    });
  }
}

// ── Groups bar ────────────────────────────────────────────────────────────────

class _GroupBar extends StatelessWidget {
  final String eventId;
  const _GroupBar({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: GroupService.instance.watchMyGroupCountForEvent(eventId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        final hasGroups = count > 0;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Get.toNamed(
              AppRoutes.groupManagement,
              arguments: {'eventId': eventId},
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasGroups
                      ? [const Color(0xFFFF6B35), const Color(0xFFE03E10)]
                      : [const Color(0xFF7C4DFF), const Color(0xFF512DA8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.groups_rounded,
                          color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('groups'.tr,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text(
                            hasGroups
                                ? 'groups_count'
                                    .tr
                                    .replaceAll('@count', '$count')
                                : 'groups_cta'.tr,
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                    Colors.white.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    if (hasGroups)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_alt_rounded,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text('$count',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('join'.tr,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7C4DFF))),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
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
      textColor = Colors.white;
      iconColor = Colors.white;
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
        beforeStart =
            DateTime(today.year, today.month, today.day).isBefore(startDate);
      }
      label = beforeStart
          ? 'registration_opens'
              .tr
              .replaceAll('@date', event.registrationStartDate)
          : 'registration_closed'.tr;
      textColor = Colors.grey.shade500;
      iconColor = Colors.grey.shade400;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOpen ? () => _launch(context, event.registrationUrl) : null,
        child: Ink(
          decoration: BoxDecoration(
            gradient: isOpen
                ? const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isOpen ? null : Colors.grey.shade50,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              children: [
                Icon(
                  isOpen
                      ? Icons.app_registration_rounded
                      : Icons.lock_outline_rounded,
                  size: 15,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textColor))),
                if (isOpen)
                  Icon(Icons.open_in_new_rounded,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _launch(BuildContext context, String raw) async {
    final normalized =
        raw.startsWith('http://') || raw.startsWith('https://')
            ? raw
            : 'https://$raw';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open registration link.')));
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(eventName,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('select_category'.tr,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ...categories.map((cat) {
              final hasKml =
                  cat.kmlUrl.isNotEmpty || cat.kmlPath.isNotEmpty;
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
                              color: AppTheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.directions_run,
                              color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat.label,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              if (cat.cutoff.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('Cut-Off: ${cat.cutoff}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary)),
                              ],
                              if (!hasKml) ...[
                                const SizedBox(height: 2),
                                Text('no_route_set'.tr,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange)),
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
            }),
          ],
        ),
      ),
    );
  }
}
