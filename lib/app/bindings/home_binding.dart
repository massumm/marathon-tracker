import 'package:get/get.dart';
import '../../controllers/friends_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/map_controller.dart';
import '../../controllers/my_page_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.lazyPut(() => MapController());
    Get.lazyPut(() => MyPageController());
    Get.lazyPut(() => FriendsController());
  }
}
