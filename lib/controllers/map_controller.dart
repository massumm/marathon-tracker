import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import '../models/event_model.dart';

class MapController extends GetxController {
  final events = <EventModel>[].obs;
  final isLoading = false.obs;
  final errorMsg = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      final snap = await FirebaseDatabase.instance.ref('events').get();
      if (snap.exists && snap.value != null) {
        final map = snap.value as Map<dynamic, dynamic>;
        final list = map.entries
            .map((e) => EventModel.fromMap(
                e.key as String, e.value as Map<dynamic, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        events.value = list;
      } else {
        events.value = [];
      }
    } catch (e) {
      errorMsg.value = 'Error loading events';
    } finally {
      isLoading.value = false;
    }
  }
}
