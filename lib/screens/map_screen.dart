import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/home_controller.dart';
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
      appBar: AppBar(
        title: Text('events_title'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'nav_my_page'.tr,
            onPressed: () => Get.find<HomeController>().changeTab(1),
          ),
        ],
      ),
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
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: controller.fetchEvents,
                  child: Text('refresh'.tr),
                ),
              ],
            ),
          );
        }
        if (controller.events.isEmpty) {
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
        return RefreshIndicator(
          onRefresh: controller.fetchEvents,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: controller.events.length,
            itemBuilder: (_, i) => _EventCard(event: controller.events[i]),
          ),
        );
      }),
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final EventModel event;
  const _EventCard({required this.event});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? _countdown() {
    final parts = widget.event.date.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    final eventDay = DateTime(year, month, day);
    final now = DateTime.now();
    final diff = eventDay.difference(DateTime(now.year, now.month, now.day));

    if (diff.isNegative) return 'finished';
    if (diff.inDays == 0) {
      final todayDiff = eventDay.difference(now);
      if (todayDiff.isNegative) return 'finished';
      final h = todayDiff.inHours;
      final m = todayDiff.inMinutes % 60;
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
    final eventDay = DateTime(year, month, day + 1); // day ends at midnight
    return DateTime.now().isAfter(eventDay);
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown();
    final finished = _isFinished;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: finished ? null : () => _showCategoryPicker(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Banner with floating title / date / place overlay ──────
            _BannerWithOverlay(event: widget.event, finished: finished),

            // ── Countdown + category row ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  if (finished) ...[
                    const Icon(Icons.flag, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'event_finished'.tr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey,
                      ),
                    ),
                  ] else if (countdown != null && countdown != 'finished') ...[
                    const Icon(Icons.timer_outlined,
                        size: 13, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      countdown,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'categories_label'.tr.replaceAll('@count', '${widget.event.categories.length}'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textSecondary, size: 18),
                ],
              ),
            ),

            // ── Groups bar ─────────────────────────────────────────────
            const Divider(height: 1, thickness: 1),
            _GroupBar(eventId: widget.event.id),
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

    // If only one category with KML, go directly
    final withKml =
        cats.where((c) => c.kmlUrl.isNotEmpty || c.kmlPath.isNotEmpty).toList();
    if (withKml.length == 1 && cats.length == 1) {
      _openMap(withKml.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
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
    Get.toNamed(
      AppRoutes.kmlMap,
      arguments: {
        'kmlUrl': cat.kmlUrl,
        'storagePath': cat.kmlPath,
        'label': '${widget.event.name} (${cat.label})',
        'eventId': widget.event.id,
      },
    );
  }
}

// ── Banner with floating title / date / place overlay ────────────────────────

class _BannerWithOverlay extends StatelessWidget {
  final EventModel event;
  final bool finished;
  const _BannerWithOverlay({required this.event, this.finished = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: cached network image or gradient fallback
          if (event.bannerUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: event.bannerUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => _gradientBg(),
              errorWidget: (_, __, ___) => _gradientBg(),
            )
          else
            _gradientBg(),

          // Dark gradient from bottom so text is always readable
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

          // Finished dimming overlay
          if (finished)
            Container(color: Colors.black.withValues(alpha: 0.45)),

          // Finished badge top-right
          if (finished)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag, size: 13, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      'event_finished'.tr,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          // Title + date + location floating bottom-left
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
                    shadows: [
                      Shadow(blurRadius: 4, color: Colors.black54),
                    ],
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
          child: Icon(Icons.directions_run,
              color: Colors.white54, size: 52),
        ),
      );
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
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12)),
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
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
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
                            color: Color(0xFF7C4DFF),
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
        );
      },
    );
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
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
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
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Category list — all shown, disabled if no KML
            ...categories.map((cat) {
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
            }),
          ],
        ),
      ),
    );
  }
}
