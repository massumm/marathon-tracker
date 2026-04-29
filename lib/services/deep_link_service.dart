import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import 'group_service.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const _method = MethodChannel('app/deep_link');
  static const _events = EventChannel('app/deep_link/events');

  void init() {
    _checkInitialLink();
    _events.receiveBroadcastStream().listen((uri) {
      if (uri is String) _handleUri(uri);
    });
  }

  Future<void> _checkInitialLink() async {
    try {
      final uri = await _method.invokeMethod<String>('getInitialLink');
      if (uri != null) _handleUri(uri);
    } catch (_) {}
  }

  Future<void> _handleUri(String uri) async {
    if (!uri.startsWith('marathon-map://group/')) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final groupId = uri.replaceFirst('marathon-map://group/', '').trim();
    if (groupId.isEmpty) return;

    final group = await GroupService.instance.getGroup(groupId);
    if (group == null) {
      Get.snackbar('', 'group_not_found'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final already = await GroupService.instance.isMember(groupId);
    if (already || group.adminUid == user.uid) {
      Get.toNamed(AppRoutes.groupDetail, arguments: group);
      return;
    }

    final result = await GroupService.instance.requestJoin(groupId);
    switch (result) {
      case JoinResult.requestSent:
        Get.snackbar('', 'join_request_sent'.tr, snackPosition: SnackPosition.BOTTOM);
        break;
      case JoinResult.full:
        Get.snackbar('', 'group_full'.tr, snackPosition: SnackPosition.BOTTOM);
        break;
      case JoinResult.notFound:
        Get.snackbar('', 'group_not_found'.tr, snackPosition: SnackPosition.BOTTOM);
        break;
      case JoinResult.ok:
        Get.snackbar('', 'group_joined'.tr, snackPosition: SnackPosition.BOTTOM);
        break;
      default:
        break;
    }
  }
}
