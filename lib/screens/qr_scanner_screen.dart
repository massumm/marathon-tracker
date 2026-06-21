import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../app/routes/app_routes.dart';
import '../../core/theme.dart';
import '../../services/friends_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/group_service.dart';
import '../../services/user_stats_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _cam = MobileScannerController();
  bool _processed = false;

  // Pass arguments: {'mode': 'group'} to scan group QR codes.
  // Default (no args / mode:'friend') scans friend QR codes.
  bool get _isGroupMode {
    final args = Get.arguments;
    return args is Map && args['mode'] == 'group';
  }

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processed) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    if (_isGroupMode) {
      if (!raw.startsWith('marathon-map://group/')) return;
      _processed = true;
      await _cam.stop();
      final groupId = raw.replaceFirst('marathon-map://group/', '');
      if (!mounted) return;
      Get.back();
      final result = await GroupService.instance.requestJoin(groupId);
      final msg = switch (result) {
        JoinResult.requestSent => 'join_request_sent'.tr,
        JoinResult.ok => 'group_joined'.tr,
        JoinResult.alreadyMember => 'group_already_member'.tr,
        JoinResult.full => 'group_full'.tr,
        JoinResult.selfAdmin => 'group_self_admin'.tr,
        JoinResult.notFound => 'group_not_found'.tr,
      };
      showSnack('', msg);
    } else {
      if (!raw.startsWith('marathon-map://friend/')) return;
      _processed = true;
      await _cam.stop();
      final uid = raw.replaceFirst('marathon-map://friend/', '');
      if (!mounted) return;

      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == myUid) {
        Get.back();
        showSnack('', 'self_friend_alert'.tr);
        return;
      }

      final stats = await UserStatsService.instance.getUserStats(uid);
      if (!mounted) return;
      if (stats == null) {
        Get.back();
        showSnack('QR', 'user_not_found'.tr);
        return;
      }

      final isFriend = await FriendsService.instance.isFriend(uid);
      final sent = await FriendsService.instance.requestSent(uid);
      if (!mounted) return;
      Get.back();

      if (isFriend) {
        Get.toNamed(AppRoutes.userProfile, arguments: uid);
      } else if (sent) {
        showSnack(stats.label, 'request_sent'.tr);
      } else {
        _showAddDialog(uid, stats.email, stats.label);
      }
    }
  }

  void _showAddDialog(String uid, String email, String label) {
    Get.dialog(AlertDialog(
      title: Text('add_friend'.tr),
      content: Text(label),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () async {
            Get.back();
            await FriendsService.instance.sendRequest(uid, email, label);
            showSnack(label, 'request_sent'.tr);
          },
          child: Text('add_friend'.tr),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('scan_qr'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: _cam.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cam,
            onDetect: _onDetect,
          ),
          // Overlay frame
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              'scan_qr_hint'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
