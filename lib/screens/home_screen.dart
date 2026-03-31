import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import 'map_screen.dart';
import 'my_page_screen.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          body: IndexedStack(
            index: controller.tabIndex.value,
            children: const [
              MapScreen(),
              MyPageScreen(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: controller.tabIndex.value,
            onTap: controller.changeTab,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: '地図表示',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'マイページ',
              ),
            ],
          ),
        ));
  }
}
