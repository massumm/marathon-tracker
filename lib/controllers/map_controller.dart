import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import '../models/event_model.dart';

class MapController extends GetxController {
  final events = <EventModel>[].obs;
  final isLoading = false.obs;
  final errorMsg = ''.obs;

  StreamSubscription? _eventsSub;

  @override
  void onInit() {
    super.onInit();
    isLoading.value = true;
    final ref = FirebaseDatabase.instance.ref('events');
    // keepSynced ensures the cache is kept fresh whenever online.
    ref.keepSynced(true);
    _eventsSub = ref.orderByChild('createdAt').onValue.listen(
      (event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final map = event.snapshot.value as Map<dynamic, dynamic>;
          events.value = map.entries
              .map((e) => EventModel.fromMap(
                  e.key as String, e.value as Map<dynamic, dynamic>))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } else {
          events.value = [];
        }
        isLoading.value = false;
        errorMsg.value = '';
      },
      onError: (_) {
        errorMsg.value = 'Error loading events';
        isLoading.value = false;
      },
    );
  }

  // Kept for UI pull-to-refresh; stream already auto-syncs.
  Future<void> fetchEvents() async {}

  @override
  void onClose() {
    _eventsSub?.cancel();
    super.onClose();
  }
}
