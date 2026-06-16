import 'dart:async';

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

  // Holds a URI received before auth was ready, to retry after login.
  String? _pendingUri;

  void init() {
    _checkInitialLink();
    _events.receiveBroadcastStream().listen((uri) {
      if (uri is String) _handleUri(uri);
    });
  }

  /// Call this from AuthController after a successful login so any deep link
  /// that arrived before auth was ready gets processed.
  void retryPending() {
    final uri = _pendingUri;
    if (uri == null) return;
    _pendingUri = null;
    _handleUri(uri);
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
    if (user == null) {
      // Auth not ready yet — park the URI and retry after login.
      _pendingUri = uri;
      return;
    }

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
