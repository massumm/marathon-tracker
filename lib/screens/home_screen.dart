import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/home_controller.dart';
import '../controllers/kml_map_controller.dart';
import '../core/theme.dart';
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
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: controller.tabIndex.value,
            onTap: controller.changeTab,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.map_outlined),
                activeIcon: const Icon(Icons.map),
                label: 'nav_map'.tr,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: 'nav_my_page'.tr,
              ),
            ],
          ),
        ));
  }
}
