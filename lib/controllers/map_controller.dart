import 'package:get/get.dart';
import '../models/kml_route.dart';
import '../services/firebase_service.dart';

class MapController extends GetxController {
  final routes = <KmlRoute>[].obs;
  final isLoading = false.obs;
  final errorMsg = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchRoutes();
  }

  Future<void> fetchRoutes() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      routes.value = await FirebaseService.instance.fetchKmlRoutes();
    } catch (e) {
      errorMsg.value = 'Error loading routes';
    } finally {
      isLoading.value = false;
    }
  }
}
