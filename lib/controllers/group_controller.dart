import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../models/group_model.dart';
import '../services/group_service.dart';

// ── Group Management Controller ───────────────────────────────────────────────

class GroupController extends GetxController {
  final groups = <GroupModel>[].obs;
  final isLoading = false.obs;

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
    });
  }

  @override
  void onClose() {
    _groupsSub?.cancel();
    super.onClose();
  }

  Future<void> createGroup(String name) async {
    if (name.trim().isEmpty) return;
    isLoading.value = true;
    final groupId =
        await GroupService.instance.createGroup(eventId, name.trim());
    isLoading.value = false;

    if (groupId == null) {
      Get.snackbar(
        'group_limit_title'.tr,
        'group_limit_body'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> joinByQr(String groupId) async {
    isLoading.value = true;
    final result = await GroupService.instance.joinGroup(groupId);
    isLoading.value = false;

    switch (result) {
      case JoinResult.ok:
        Get.snackbar('', 'group_joined'.tr,
            snackPosition: SnackPosition.BOTTOM);
        break;
      case JoinResult.alreadyMember:
        Get.snackbar('', 'group_already_member'.tr,
            snackPosition: SnackPosition.BOTTOM);
        break;
      case JoinResult.full:
        Get.snackbar('', 'group_full'.tr,
            snackPosition: SnackPosition.BOTTOM);
        break;
      case JoinResult.selfAdmin:
        Get.snackbar('', 'group_self_admin'.tr,
            snackPosition: SnackPosition.BOTTOM);
        break;
      case JoinResult.notFound:
        Get.snackbar('', 'group_not_found'.tr,
            snackPosition: SnackPosition.BOTTOM);
        break;
    }
  }

  Future<void> deleteGroup(GroupModel g) async {
    await GroupService.instance.deleteGroup(g.id, g.eventId);
    Get.snackbar('', 'group_deleted'.tr,
        snackPosition: SnackPosition.BOTTOM);
  }

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
}

// ── Group Detail Controller ───────────────────────────────────────────────────

class GroupDetailController extends GetxController {
  final members = <GroupMemberModel>[].obs;

  late GroupModel group;
  StreamSubscription? _membersSub;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is GroupModel) {
      group = args;
    }
    _membersSub =
        GroupService.instance.watchGroupMembers(group.id).listen((list) {
      members.value = list;
    });
  }

  @override
  void onClose() {
    _membersSub?.cancel();
    super.onClose();
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

  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get isAdmin => group.adminUid == myUid;
}
