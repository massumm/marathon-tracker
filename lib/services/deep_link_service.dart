import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import 'group_service.dart';
import '../widgets/app_snackbar.dart';

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
      showSnack('', 'group_not_found'.tr);
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
        showSnack('', 'join_request_sent'.tr);
        break;
      case JoinResult.full:
        showSnack('', 'group_full'.tr);
        break;
      case JoinResult.notFound:
        showSnack('', 'group_not_found'.tr);
        break;
      case JoinResult.ok:
        showSnack('', 'group_joined'.tr);
        break;
      default:
        break;
    }
  }
}
