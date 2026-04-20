import 'package:get/get.dart';
import '../../controllers/kml_map_controller.dart';

class KmlMapBinding extends Bindings {
  @override
  void dependencies() {
    // Controller is permanent — registered in InitialBinding.
    // Prepare the route args here so it's ready before the screen builds.
    Get.find<KmlMapController>().prepareRoute(Get.arguments);
  }
}
