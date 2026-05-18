import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/map_controller.dart';
import '../../controllers/my_page_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(HomeController());
    Get.lazyPut(() => MapController(), fenix: true);
    Get.lazyPut(() => MyPageController());
  }
}
