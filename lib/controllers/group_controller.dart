import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../models/group_model.dart';
import '../services/group_service.dart';
import '../widgets/app_snackbar.dart';

// ── Group Management Controller ───────────────────────────────────────────────

class GroupController extends GetxController {
  final groups = <GroupModel>[].obs;
  final isLoading = false.obs;
  final groupsLoaded = false.obs;

  String eventId = '';
  StreamSubscription? _groupsSub;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      eventId = args['eventId'] as String? ?? '';
    } else if (args is String) {
      eventId = args;
    }
    _groupsSub =
        GroupService.instance.watchMyGroupsForEvent(eventId).listen((list) {
      groups.value = list;
      groupsLoaded.value = true;
    }, onError: (_) {}); // ignore permission-denied during logout
  }

  @override
  void onClose() {
    _groupsSub?.cancel();
    super.onClose();
  }

  Future<GroupModel?> createGroup(String name) async {
    if (name.trim().isEmpty) return null;
    isLoading.value = true;
    final group =
        await GroupService.instance.createGroup(eventId, name.trim());
    isLoading.value = false;

    if (group == null) {
      showSnack('group_limit_title'.tr, 'group_limit_body'.tr);
    }
    return group;
  }

  Future<void> joinByQr(String groupId) async {
    isLoading.value = true;
    final result = await GroupService.instance.joinGroup(groupId);
    isLoading.value = false;

    switch (result) {
      case JoinResult.requestSent:
        showSnack('', 'join_request_sent'.tr);
        break;
      case JoinResult.ok:
        showSnack('', 'group_joined'.tr);
        break;
      case JoinResult.alreadyMember:
        showSnack('', 'group_already_member'.tr);
        break;
      case JoinResult.full:
        showSnack('', 'group_full'.tr);
        break;
      case JoinResult.selfAdmin:
        showSnack('', 'group_self_admin'.tr);
        break;
      case JoinResult.notFound:
        showSnack('', 'group_not_found'.tr);
        break;
    }
  }

  Future<void> deleteGroup(GroupModel g) async {
    await GroupService.instance.deleteGroup(g.id, g.eventId);
    showSnack('', 'group_deleted'.tr);
  }

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
}

// ── Group Detail Controller ───────────────────────────────────────────────────

class GroupDetailController extends GetxController {
  final members = <GroupMemberModel>[].obs;
  final joinRequests = <GroupMemberModel>[].obs;
  final groupName = ''.obs;

  late GroupModel group;
  StreamSubscription? _membersSub;
  StreamSubscription? _requestsSub;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is GroupModel) {
      group = args;
      groupName.value = args.name;
    } else {
      // No valid GroupModel passed — cannot initialize. Pop immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.back());
      return;
    }
    _membersSub =
        GroupService.instance.watchGroupMembers(group.id).listen((list) {
      members.value = list;
    }, onError: (_) {}); // ignore permission-denied during logout
    if (isAdmin) {
      _requestsSub =
          GroupService.instance.watchJoinRequests(group.id).listen((list) {
        joinRequests.value = list;
      }, onError: (_) {});
    }
  }

  @override
  void onClose() {
    _membersSub?.cancel();
    _requestsSub?.cancel();
    super.onClose();
  }

  Future<void> acceptRequest(String uid) async {
    await GroupService.instance.acceptJoinRequest(group.id, uid);
  }

  Future<void> declineRequest(String uid) async {
    await GroupService.instance.declineJoinRequest(group.id, uid);
  }

  Future<void> removeMember(String uid) async {
    await GroupService.instance.removeMember(group.id, uid);
  }

  Future<void> leaveGroup() async {
    await GroupService.instance.leaveGroup(group.id);
    Get.back();
  }

  Future<void> deleteGroup() async {
    await GroupService.instance.deleteGroup(group.id, group.eventId);
    Get.back();
    Get.back();
  }

  Future<void> renameGroup(String newName) async {
    if (newName.trim().isEmpty) return;
    await GroupService.instance.renameGroup(group.id, newName.trim());
    groupName.value = newName.trim();
  }

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get isAdmin => group.adminUid == myUid;
}
