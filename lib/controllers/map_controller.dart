import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/event_model.dart';
import '../services/event_notification_service.dart';

class MapController extends GetxController {
  static const _pageSize = 20;

  final events = <EventModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final errorMsg = ''.obs;

  EventModel? _cursor;

  @override
  void onInit() {
    super.onInit();
    _loadPage();
  }

  Future<void> _loadPage() async {
    if (isLoading.value || isLoadingMore.value || !hasMore.value) return;

    if (_cursor == null) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      var query = FirebaseDatabase.instance
          .ref('events')
          .orderByChild('createdAt')
          .limitToLast(_cursor == null ? _pageSize : _pageSize + 1);

      if (_cursor != null) {
        query = query.endAt(_cursor!.createdAt, key: _cursor!.id);
      }

      final snap = await query.get();
      debugPrint('[MapController] snap exists=${snap.exists}, cursor=${_cursor?.id}');
      var page = <EventModel>[];

      if (snap.exists && snap.value != null) {
        final map = snap.value as Map<dynamic, dynamic>;
        page = map.entries
            .map((e) => EventModel.fromMap(
                e.key as String, e.value as Map<dynamic, dynamic>))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (_cursor != null) {
          page.removeWhere((e) => e.id == _cursor!.id);
        }
      }

      debugPrint('[MapController] page.length=${page.length}, names=${page.map((e) => e.name).toList()}');
      events.addAll(page);

      if (page.isNotEmpty) _cursor = page.last;
      hasMore.value = page.length == _pageSize;
      debugPrint('[MapController] total events=${events.length}, hasMore=${hasMore.value}, newCursor=${_cursor?.id}');
      errorMsg.value = '';
      EventNotificationService.instance.scheduleForEvents(events.toList());
    } catch (_) {
      errorMsg.value = 'Error loading events';
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() => _loadPage();

  @override
  Future<void> refresh() async {
    events.clear();
    _cursor = null;
    hasMore.value = true;
    isLoading.value = false;
    isLoadingMore.value = false;
    errorMsg.value = '';
    await _loadPage();
  }

  Future<void> fetchEvents() => refresh();
}
