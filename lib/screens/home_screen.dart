import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/home_controller.dart';
import '../controllers/kml_map_controller.dart';
import '../controllers/my_page_controller.dart';
import '../core/theme.dart';
import '../services/offline_storage_service.dart';
import 'map_screen.dart';
import 'my_page_screen.dart' show MyPageBody;

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final online = OfflineStorageService.instance.isOnline.value;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: online ? 0 : 28,
        color: const Color(0xFF424242),
        child: online
            ? null
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 12, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text('offline_banner'.tr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white70)),
                ],
              ),
      );
    });
  }
}

// ── Running banner ────────────────────────────────────────────────────────────

class _RunningBanner extends StatelessWidget {
  const _RunningBanner();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<KmlMapController>();
    return Obx(() {
      if (!ctrl.isTracking.value) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.kmlMap),
        child: Container(
          color: AppTheme.trackingGreen,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.directions_run,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('run_in_progress'.tr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                Obx(() => Text(ctrl.formatTime(ctrl.elapsedSeconds.value),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1))),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ── Home screen ───────────────────────────────────────────────────────────────

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      body: Stack(
        children: [
          Column(
            children: [
              _OfflineBanner(),
              _RunningBanner(),
              Expanded(child: MapScreen()),
            ],
          ),
          _ProfileBottomSheet(),
        ],
      ),
    );
  }
}

// ── Profile bottom sheet ──────────────────────────────────────────────────────

class _ProfileBottomSheet extends StatelessWidget {
  const _ProfileBottomSheet();

  static const double _min = 0.095;
  static const double _max = 0.93;

  @override
  Widget build(BuildContext context) {
    // Positioned.fill — same as GitHub's wrapper
    return Positioned.fill(
      child: DraggableScrollableSheet(
        minChildSize: _min,
        initialChildSize: _min,
        maxChildSize: _max,
        builder: (context, scrollCtrl) {
          // AnimatedBuilder on scrollCtrl — same pattern as GitHub
          return AnimatedBuilder(
            animation: scrollCtrl,
            builder: (context, _) {
              double pct = _min;
              if (scrollCtrl.hasClients) {
                pct = (scrollCtrl.position.viewportDimension /
                        MediaQuery.of(context).size.height)
                    .clamp(_min, _max);
              }
              // 0 = fully collapsed  →  1 = fully expanded
              final scaled =
                  ((pct - _min) / (_max - _min)).clamp(0.0, 1.0);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(26)),
                  // Same CustomScrollView structure as original — keeps
                  // scrollCtrl attached to exactly one Scrollable so
                  // DraggableScrollableSheet drag works correctly.
                  child: _ProfileSheetContent(
                    scrollController: scrollCtrl,
                    scaled: scaled,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Profile sheet content ─────────────────────────────────────────────────────

class _ProfileSheetContent extends StatelessWidget {
  final ScrollController scrollController;
  final double scaled;
  const _ProfileSheetContent(
      {required this.scrollController, required this.scaled});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<MyPageController>();
    final topPad = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle — top margin grows as sheet expands (GitHub topMargin animation)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(
                    top: 8 + scaled * topPad,
                    bottom: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Avatar + name + settings
              // Font size animates: GitHub uses "14 + percentage * 8"
              Obx(() => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                    child: Row(
                      children: [
                        _SheetAvatar(
                          photoUrl: ctrl.photoUrlObs.value,
                          name: ctrl.displayName,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ctrl.displayName,
                                style: TextStyle(
                                  // animates 15 → 18 as sheet opens
                                  fontSize: 15 + scaled * 3,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'my_page_title'.tr,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined,
                              size: 20, color: AppTheme.textSecondary),
                          onPressed: () =>
                              Get.toNamed(AppRoutes.settings),
                        ),
                      ],
                    ),
                  )),

              const Divider(height: 1),
            ],
          ),
        ),

        // Full profile body
        SliverFillRemaining(
          hasScrollBody: true,
          child: MyPageBody(
            controller: ctrl,
            scrollController: scrollController,
          ),
        ),
      ],
    );
  }
}

// ── Sheet avatar ──────────────────────────────────────────────────────────────

class _SheetAvatar extends StatelessWidget {
  final String photoUrl;
  final String name;
  const _SheetAvatar({required this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            placeholder: (_, __) => _initial(),
            errorWidget: (_, __, ___) => _initial(),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
      child: _initial(),
    );
  }

  Widget _initial() => Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      );
}
