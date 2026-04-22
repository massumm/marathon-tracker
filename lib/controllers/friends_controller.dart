import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/friend_model.dart';
import '../services/friends_service.dart';

enum SearchState { idle, loading, found, notFound }

class FriendsController extends GetxController {
  final friends = <FriendModel>[].obs;
  final requests = <FriendRequestModel>[].obs;
  final sentRequests = <FriendRequestModel>[].obs;

  final searchState = SearchState.idle.obs;
  // Each entry: {uid, email, displayName, status}
  final searchResults = <Map<String, dynamic>>[].obs;
  // uids currently sending a friend request
  final sendingUids = <String>{}.obs;

  final searchCtrl = TextEditingController();

  StreamSubscription? _friendsSub;
  StreamSubscription? _requestsSub;
  StreamSubscription? _sentRequestsSub;
  StreamSubscription? _liveRunnersSub;
  final _liveUids = <String>{};

  @override
  void onInit() {
    super.onInit();
    _friendsSub = FriendsService.instance.watchFriends().listen((list) {
      friends.value = list;
      _refreshRunningStatus();
    });
    _requestsSub = FriendsService.instance.watchRequests().listen((list) {
      requests.value = list;
    });
    _sentRequestsSub = FriendsService.instance.watchSentRequests().listen((list) {
      sentRequests.value = list;
    });
    _watchLiveRunners();
  }

  @override
  void onClose() {
    _friendsSub?.cancel();
    _requestsSub?.cancel();
    _sentRequestsSub?.cancel();
    _liveRunnersSub?.cancel();
    searchCtrl.dispose();
    super.onClose();
  }

  // ── Live running status ───────────────────────────────────────────────────

  void _watchLiveRunners() {
    _liveRunnersSub = FirebaseDatabase.instance
        .ref('live_runners')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      _liveUids.clear();
      if (data != null) {
        _liveUids.addAll(
            (data as Map<dynamic, dynamic>).keys.cast<String>());
      }
      _refreshRunningStatus();
    });
  }

  void _refreshRunningStatus() {
    for (final f in friends) {
      f.isRunning = _liveUids.contains(f.uid);
    }
    friends.refresh();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> searchUser() async {
    final query = searchCtrl.text.trim();
    if (query.isEmpty) return;

    searchState.value = SearchState.loading;
    searchResults.clear();

    final results = await FriendsService.instance.searchByQuery(query);
    if (results.isEmpty) {
      searchState.value = SearchState.notFound;
      return;
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final enriched = <Map<String, dynamic>>[];

    for (final r in results) {
      final uid = r['uid'] as String;
      String status;
      if (uid == myUid) {
        status = 'self';
      } else if (await FriendsService.instance.isFriend(uid)) {
        status = 'friends';
      } else if (await FriendsService.instance.requestSent(uid)) {
        status = 'sent';
      } else {
        status = 'add';
      }
      enriched.add({...r, 'status': status});
    }

    searchResults.value = enriched;
    searchState.value = SearchState.found;
  }

  Future<void> sendRequest(String uid, String email, String displayName) async {
    sendingUids.add(uid);
    sendingUids.refresh();
    await FriendsService.instance.sendRequest(uid, email, displayName);
    // Update status in the results list
    final idx = searchResults.indexWhere((r) => r['uid'] == uid);
    if (idx != -1) {
      searchResults[idx] = {...searchResults[idx], 'status': 'sent'};
      searchResults.refresh();
    }
    sendingUids.remove(uid);
    sendingUids.refresh();
  }

  Future<void> acceptRequest(FriendRequestModel req) async {
    await FriendsService.instance
        .acceptRequest(req.fromUid, req.email, req.displayName);
  }

  Future<void> rejectRequest(FriendRequestModel req) async {
    await FriendsService.instance.rejectRequest(req.fromUid);
  }

  Future<void> cancelSentRequest(FriendRequestModel req) async {
    await FriendsService.instance.cancelSentRequest(req.fromUid);
  }

  Future<void> removeFriend(FriendModel f) async {
    await FriendsService.instance.removeFriend(f.uid);
  }

  void clearSearch() {
    searchCtrl.clear();
    searchState.value = SearchState.idle;
    searchResults.clear();
  }
}
