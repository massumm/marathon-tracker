import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_bar/liquid_glass_bar.dart';

import '../../app/routes/app_routes.dart';
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

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          extendBody: true,
          body: Column(
            children: [
              const _RunningBanner(),
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
          bottomNavigationBar: LiquidGlassBar(
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
        ));
  }
}
