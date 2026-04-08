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

  final searchState = SearchState.idle.obs;
  final searchResult = Rxn<Map<String, dynamic>>();
  // Indicates the relationship to the searched user
  final searchStatus = ''.obs; // '', 'self', 'friends', 'sent', 'add'

  final isSendingRequest = false.obs;

  final searchCtrl = TextEditingController();

  StreamSubscription? _friendsSub;
  StreamSubscription? _requestsSub;
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
    _watchLiveRunners();
  }

  @override
  void onClose() {
    _friendsSub?.cancel();
    _requestsSub?.cancel();
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
    final email = searchCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;

    searchState.value = SearchState.loading;
    searchResult.value = null;
    searchStatus.value = '';

    final result = await FriendsService.instance.searchByEmail(email);
    if (result == null) {
      searchState.value = SearchState.notFound;
      return;
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (result['uid'] == myUid) {
      searchStatus.value = 'self';
    } else if (await FriendsService.instance.isFriend(result['uid'] as String)) {
      searchStatus.value = 'friends';
    } else if (await FriendsService.instance
        .requestSent(result['uid'] as String)) {
      searchStatus.value = 'sent';
    } else {
      searchStatus.value = 'add';
    }

    searchResult.value = result;
    searchState.value = SearchState.found;
  }

  Future<void> sendRequest() async {
    final r = searchResult.value;
    if (r == null) return;
    isSendingRequest.value = true;
    await FriendsService.instance.sendRequest(
      r['uid'] as String,
      r['email'] as String,
      r['displayName'] as String,
    );
    searchStatus.value = 'sent';
    isSendingRequest.value = false;
  }

  Future<void> acceptRequest(FriendRequestModel req) async {
    await FriendsService.instance
        .acceptRequest(req.fromUid, req.email, req.displayName);
  }

  Future<void> rejectRequest(FriendRequestModel req) async {
    await FriendsService.instance.rejectRequest(req.fromUid);
  }

  Future<void> removeFriend(FriendModel f) async {
    await FriendsService.instance.removeFriend(f.uid);
  }

  void clearSearch() {
    searchCtrl.clear();
    searchState.value = SearchState.idle;
    searchResult.value = null;
    searchStatus.value = '';
  }
}
