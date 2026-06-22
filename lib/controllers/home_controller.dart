import 'package:get/get.dart';

import 'my_page_controller.dart';

class HomeController extends GetxController {
  final tabIndex = 0.obs;

  void changeTab(int index) {
    tabIndex.value = index;
    // MyPage tab — refresh the completed-runs list so newly finished runs
    // appear immediately (the controller is long-lived, so onInit won't re-run).
    if (index == 2 && Get.isRegistered<MyPageController>()) {
      Get.find<MyPageController>().fetchRoutes();
    }
  }
}
