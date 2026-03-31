import 'package:get/get.dart';
import '../../controllers/kml_map_controller.dart';

class KmlMapBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(KmlMapController());
  }
}
