import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/event_model.dart';
import '../services/event_notification_service.dart';

class MapController extends GetxController {
  static const _pageSize = 50;

  final events = <EventModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final errorMsg = ''.obs;

  StreamSubscription? _liveSub;
  EventModel? _cursor;
  // IDs belonging to the live first page — used to preserve paginated events
  // when the listener fires mid-scroll.
  final _firstPageIds = <String>{};

  @override
  void onInit() {
    super.onInit();
    _startListen();
  }

  @override
  void onClose() {
    _liveSub?.cancel();
    super.onClose();
  }

  // ── Real-time first page ──────────────────────────────────────────────────

  void _startListen() {
    if (events.isEmpty) isLoading.value = true;
    errorMsg.value = '';
    _liveSub?.cancel();
    _liveSub = FirebaseDatabase.instance
        .ref('events')
        .orderByChild('date')
        .limitToLast(_pageSize)
        .onValue
        .listen(
      (snap) {
        try {
          var firstPage = <EventModel>[];
          if (snap.snapshot.exists && snap.snapshot.value != null) {
            final map = snap.snapshot.value as Map<dynamic, dynamic>;
            firstPage = map.entries
                .map((e) => EventModel.fromMap(
                    e.key as String, e.value as Map<dynamic, dynamic>))
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
          }

          final newIds = {for (final e in firstPage) e.id};
          // Preserve any extra events the user loaded via "load more".
          final paginated =
              events.where((e) => !_firstPageIds.contains(e.id) && !newIds.contains(e.id)).toList();

          _firstPageIds
            ..clear()
            ..addAll(newIds);

          events.value = [...firstPage, ...paginated];

          // Initialise cursor for pagination only if not already set.
          if (_cursor == null && firstPage.isNotEmpty) {
            _cursor = firstPage.last;
          }
          hasMore.value = firstPage.length >= _pageSize;
          errorMsg.value = '';

          _debugPrint(events.toList());
          EventNotificationService.instance.scheduleForEvents(events.toList());
        } catch (e) {
          debugPrint('[MapController] listener error: $e');
        } finally {
          isLoading.value = false;
        }
      },
      onError: (_) {
        errorMsg.value = 'Error loading events';
        isLoading.value = false;
      },
    );
  }

  // ── Pagination (older events beyond first page) ───────────────────────────

  Future<void> _loadPage() async {
    if (isLoadingMore.value || !hasMore.value || _cursor == null) return;
    isLoadingMore.value = true;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('events')
          .orderByChild('date')
          .limitToLast(_pageSize + 1)
          .endAt(_cursor!.date, key: _cursor!.id)
          .get();

      var page = <EventModel>[];
      if (snap.exists && snap.value != null) {
        final map = snap.value as Map<dynamic, dynamic>;
        page = map.entries
            .map((e) => EventModel.fromMap(
                e.key as String, e.value as Map<dynamic, dynamic>))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date))
          ..removeWhere((e) => e.id == _cursor!.id);
      }

      // Deduplicate before appending.
      final existing = {for (final e in events) e.id};
      final fresh = page.where((e) => !existing.contains(e.id)).toList();
      events.addAll(fresh);

      if (page.isNotEmpty) _cursor = page.last;
      hasMore.value = page.length == _pageSize;

      debugPrint('[MapController] loadMore: +${fresh.length} events, total=${events.length}');
    } catch (_) {
      // Silently ignore pagination errors.
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() => _loadPage();

  // ── Manual refresh ────────────────────────────────────────────────────────

  @override
  Future<void> refresh() async {
    _cursor = null;
    _firstPageIds.clear();
    hasMore.value = true;
    errorMsg.value = '';
    _startListen();
  }

  Future<void> fetchEvents() => refresh();

  // ── Debug ─────────────────────────────────────────────────────────────────

  void _debugPrint(List<EventModel> evts) {
    debugPrint('[MapController] ── EVENT LIST (${evts.length} total) ──────────────────');
    for (var i = 0; i < evts.length; i++) {
      final e = evts[i];
      final cats = e.categories.values
          .map((c) => '${c.label}(cutoff:${c.cutoffMinutes}min)')
          .join(', ');
      debugPrint(
        '[MapController] [$i] id=${e.id}'
        ' | name="${e.name}"'
        ' | date=${e.date} startTime=${e.startTime.isEmpty ? "none" : e.startTime} endTime=${e.endTime.isEmpty ? "none" : e.endTime}'
        ' | cutoff=${e.cutoffMinutes}min chip=${e.chipTimeMinutes}min grace=${e.graceTimeMinutes}min'
        ' | isToday=${e.isToday} isFinished=${e.isFinished} isRunning=${e.isRunning} isResultsReady=${e.isResultsReady}'
        ' | finishAt=${e.finishDateTime}'
        ' | categories=[$cats]',
      );
    }
    debugPrint('[MapController] ────────────────────────────────────────────────────────');
  }
}
