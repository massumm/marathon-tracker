import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_bar/liquid_glass_bar.dart';

import '../../app/routes/app_routes.dart';
import '../../controllers/free_run_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/kml_map_controller.dart';
import '../../core/theme.dart';
import 'map_screen.dart';
import 'my_page_screen.dart';

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
                const Icon(Icons.directions_run, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'run_in_progress'.tr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
                Obx(() => Text(
                      ctrl.formatTime(ctrl.elapsedSeconds.value),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 1),
                    )),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _FreeRunBanner extends StatelessWidget {
  const _FreeRunBanner();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<FreeRunController>();
    return Obx(() {
      final state = ctrl.runState.value;
      if (state == FreeRunState.idle || state == FreeRunState.stopped) {
        return const SizedBox.shrink();
      }
      return GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.freeRun),
        child: Container(
          color: AppTheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.directions_run_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state == FreeRunState.paused
                        ? 'Daily Challenge – Paused'
                        : 'Daily Challenge in progress',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
                Obx(() => Text(
                      ctrl.formattedTime,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 1),
                    )),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// Daily Challenge call-to-action — docked just above the bottom nav bar.
// Hidden while a challenge run is active (the in-progress banner shows then).
class _DailyChallengeCta extends StatelessWidget {
  const _DailyChallengeCta();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<FreeRunController>();
    return Obx(() {
      final state = ctrl.runState.value;
      if (state != FreeRunState.idle && state != FreeRunState.stopped) {
        return const SizedBox.shrink();
      }
      return GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.freeRun),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2B2B2B), Color(0xFF000000)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Color(0xFFFF8A4C), size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Daily Challenge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Run and see your rank in community',
                      style: TextStyle(
                        color: Color(0xFFB9B4BD),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          extendBody: true,
          body: Column(
            children: [
              const _RunningBanner(),
              const _FreeRunBanner(),
              Expanded(
                child: IndexedStack(
                  index: controller.tabIndex.value,
                  children: const [
                    MapScreen(),
                    MyPageScreen(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Only on the Events tab — hidden on My Page.
              if (controller.tabIndex.value == 0) const _DailyChallengeCta(),
              LiquidGlassBar(
                currentIndex: controller.tabIndex.value,
                onTap: controller.changeTab,
                style: LiquidGlassBarStyle(
                  activeColor: AppTheme.primary,
                  inactiveColor: Colors.grey.shade500,
                  borderRadius: 32,
                  height: 60,
                  iconSize: 24,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                ),
                items: [
                  LiquidGlassBarItem(
                    iconData: controller.tabIndex.value == 0
                        ? Icons.map
                        : Icons.map_outlined,
                    label: 'nav_map'.tr,
                  ),
                  LiquidGlassBarItem(
                    iconData: controller.tabIndex.value == 1
                        ? Icons.person
                        : Icons.person_outline,
                    label: 'nav_my_page'.tr,
                  ),
                ],
              ),
            ],
          ),
        ));
  }
}

