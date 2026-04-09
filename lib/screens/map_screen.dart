import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/map_controller.dart';
import '../core/theme.dart';
import '../models/event_model.dart';

class MapScreen extends GetView<MapController> {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('events_title'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr,
            onPressed: controller.fetchEvents,
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
            itemBuilder: (_, i) =>
                _EventCard(event: controller.events[i]),
          ),
        );
      }),
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final EventModel event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showCategoryPicker(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Banner image ────────────────────────────────────────────
            if (event.bannerUrl.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(
                  event.bannerUrl,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _defaultBanner(),
                ),
              )
            else
              _defaultBanner(),

            // ── Event info ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Text(event.date,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(width: 16),
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(event.location,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Category count
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${event.categories.length} カテゴリー',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          color: AppTheme.textSecondary, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultBanner() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary,
            AppTheme.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Center(
        child: Icon(Icons.directions_run, color: Colors.white, size: 36),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    final cats = event.categories.values
        .where((c) => c.kmlUrl.isNotEmpty || c.kmlPath.isNotEmpty)
        .toList();

    if (cats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('このイベントにはルートがまだありません'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // If only one category, go directly
    if (cats.length == 1) {
      _openMap(cats.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPickerSheet(
        eventName: event.name,
        categories: cats,
        onSelect: (cat) {
          Navigator.pop(context);
          _openMap(cat);
        },
      ),
    );
  }

  void _openMap(RaceCategory cat) {
    // Pass KML info as arguments
    Get.toNamed(
      AppRoutes.kmlMap,
      arguments: {
        'kmlUrl': cat.kmlUrl,
        'storagePath': cat.kmlPath,
        'label': cat.label,
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
                  const Text(
                    'カテゴリーを選択してください',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Category list
            ...categories.map((cat) => InkWell(
                  onTap: () => onSelect(cat),
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
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
