import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/friends_controller.dart';
import '../core/theme.dart';
import '../models/friend_model.dart';
import '../widgets/qr_code_sheet.dart';
import '../widgets/user_avatar.dart';

class FriendsScreen extends GetView<FriendsController> {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('friends_title'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'my_qr_code'.tr,
            onPressed: QrCodeSheet.show,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'scan_qr'.tr,
            onPressed: () => Get.toNamed(AppRoutes.qrScanner),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(controller: controller),
          Expanded(
            child: Obx(() {
              final requests = controller.requests;
              final friends = controller.friends;

              if (requests.isEmpty && friends.isEmpty) {
                return const _EmptyState();
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (requests.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'incoming_requests'.tr,
                      count: requests.length,
                    ),
                    ...requests.map(
                      (r) => _RequestTile(
                        request: r,
                        onAccept: () => controller.acceptRequest(r),
                        onReject: () => controller.rejectRequest(r),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (friends.isNotEmpty) ...[
                    _SectionHeader(
                        title: 'friends_label'.tr, count: friends.length),
                    ...friends.map(
                      (f) => _FriendTile(
                        friend: f,
                        onRemove: () => _confirmRemove(context, f),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, FriendModel f) {
    Get.dialog(
      AlertDialog(
        title: Text('remove_friend'.tr),
        content: Text(
            'remove_friend_confirm'.tr.replaceAll('@name', f.label)),
        actions: [
          TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              controller.removeFriend(f);
            },
            child: Text('delete'.tr,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final FriendsController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'search_hint'.tr,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: controller.clearSearch,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onSubmitted: (_) => controller.searchUser(),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final loading =
                    controller.searchState.value == SearchState.loading;
                return SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: loading ? null : controller.searchUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text('search'.tr),
                  ),
                );
              }),
            ],
          ),
          Obx(() {
            final state = controller.searchState.value;
            final results = controller.searchResults;

            if (state == SearchState.notFound) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'user_not_found'.tr,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 13),
                ),
              );
            }

            if (state == SearchState.found && results.isNotEmpty) {
              return Column(
                children: results
                    .map((r) => _SearchResultTile(
                          result: r,
                          isSending: controller.sendingUids
                              .contains(r['uid'] as String),
                          onAdd: () => controller.sendRequest(
                            r['uid'] as String,
                            r['email'] as String,
                            r['displayName'] as String,
                          ),
                        ))
                    .toList(),
              );
            }

            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> result;
  final bool isSending;
  final VoidCallback onAdd;

  const _SearchResultTile({
    required this.result,
    required this.isSending,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final uid = result['uid'] as String;
    final displayName = result['displayName'] as String? ?? '';
    final email = result['email'] as String? ?? '';
    final status = result['status'] as String? ?? 'add';
    final label =
        displayName.isNotEmpty ? displayName : email.split('@').first;

    return InkWell(
      onTap: status != 'self'
          ? () => Get.toNamed(AppRoutes.userProfile, arguments: uid)
          : null,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            UserAvatar(
              label: label,
              photoUrl: result['photoUrl'] as String? ?? '',
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(email,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ),
            _statusWidget(status, isSending, onAdd),
          ],
        ),
      ),
    );
  }

  Widget _statusWidget(
      String status, bool isSending, VoidCallback onAdd) {
    switch (status) {
      case 'self':
        return Text('you_label'.tr,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary));
      case 'friends':
        return Chip(
          label: Text('already_friends'.tr,
              style: const TextStyle(fontSize: 11)),
          backgroundColor: const Color(0xFFE8F5E9),
          padding: EdgeInsets.zero,
        );
      case 'sent':
        return Chip(
          label: Text('request_sent'.tr,
              style: const TextStyle(fontSize: 11)),
          backgroundColor: const Color(0xFFFFF8E1),
          padding: EdgeInsets.zero,
        );
      default:
        return SizedBox(
          height: 34,
          child: ElevatedButton.icon(
            onPressed: isSending ? null : onAdd,
            icon: isSending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.person_add_outlined, size: 16),
            label: Text('add'.tr,
                style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        );
    }
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Request tile ──────────────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final FriendRequestModel request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Get.toNamed(AppRoutes.userProfile, arguments: request.fromUid),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: UserAvatar(
          label: request.label,
          photoUrl: request.photoUrl,
          size: 44,
        ),
        title: Text(request.label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(request.email,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              label: 'reject'.tr,
              color: Colors.grey.shade400,
              onTap: onReject,
            ),
            const SizedBox(width: 8),
            _ActionButton(
              label: 'accept'.tr,
              color: AppTheme.primary,
              onTap: onAccept,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Friend tile ───────────────────────────────────────────────────────────────

class _FriendTile extends StatelessWidget {
  final FriendModel friend;
  final VoidCallback onRemove;

  const _FriendTile({required this.friend, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Get.toNamed(AppRoutes.userProfile, arguments: friend.uid),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Stack(
          children: [
            UserAvatar(label: friend.label, photoUrl: friend.photoUrl, size: 44),
            if (friend.isRunning)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(friend.label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          friend.isRunning ? 'running_now'.tr : friend.email,
          style: TextStyle(
            fontSize: 11,
            color: friend.isRunning
                ? Colors.green
                : AppTheme.textSecondary,
            fontWeight: friend.isRunning
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert,
              size: 20, color: AppTheme.textSecondary),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline,
              size: 64, color: Color(0xFFB0BEC5)),
          const SizedBox(height: 16),
          Text('no_friends'.tr,
              style: const TextStyle(
                  fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text('no_friends_subtitle'.tr,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

