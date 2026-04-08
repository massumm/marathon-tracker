import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/friends_controller.dart';
import '../controllers/home_controller.dart';
import 'friends_screen.dart';
import 'map_screen.dart';
import 'my_page_screen.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pendingCount = Get.find<FriendsController>().requests.length;

      return Scaffold(
        body: IndexedStack(
          index: controller.tabIndex.value,
          children: const [
            MapScreen(),
            FriendsScreen(),
            MyPageScreen(),
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
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                child: const Icon(Icons.people_outline),
              ),
              activeIcon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                child: const Icon(Icons.people),
              ),
              label: 'nav_friends'.tr,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: 'nav_my_page'.tr,
            ),
          ],
        ),
      );
    });
  }
}
