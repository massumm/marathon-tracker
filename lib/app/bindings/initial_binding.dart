import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/free_run_controller.dart';
import '../../controllers/kml_map_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController(), permanent: true);
    Get.put(KmlMapController(), permanent: true);
    Get.put(FreeRunController(), permanent: true);
  }
}
