import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../app/routes/app_routes.dart';
import '../controllers/group_controller.dart';
import '../core/theme.dart';
import '../models/group_model.dart';
import '../widgets/user_avatar.dart';

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late final GroupController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<GroupController>();
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text('create_group'.tr),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'group_name_hint'.tr,
            border: const OutlineInputBorder(),
          ),
          maxLength: 30,
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
          Obx(() => ElevatedButton(
                onPressed: _ctrl.isLoading.value
                    ? null
                    : () async {
                        Get.back();
                        final group = await _ctrl.createGroup(nameCtrl.text);
                        if (group != null) {
                          GroupQrSheet.show(group);
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white),
                child: Text('create'.tr),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('groups'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'scan_to_join'.tr,
            onPressed: () => Get.toNamed(
              AppRoutes.qrScanner,
              arguments: {'mode': 'group'},
            ),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Groups list ────────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (!_ctrl.groupsLoaded.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final groups = _ctrl.groups;
              if (groups.isEmpty) {
                return _EmptyGroupState(onCreate: _showCreateDialog);
              }
              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _GroupTile(
                  group: groups[i],
                  myUid: _ctrl.myUid,
                  onTap: () => Get.toNamed(
                    AppRoutes.groupDetail,
                    arguments: groups[i],
                  ),
                  onDelete: groups[i].adminUid == _ctrl.myUid
                      ? () => _confirmDelete(groups[i])
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: Obx(() => _ctrl.groups.isEmpty
          ? const SizedBox.shrink()
          : FloatingActionButton(
              onPressed: _showCreateDialog,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )),
    );
  }

  void _confirmDelete(GroupModel g) {
    Get.dialog(AlertDialog(
      title: Text('delete_group'.tr),
      content: Text('delete_group_confirm'.tr.replaceAll('@name', g.name)),
      actions: [
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            _ctrl.deleteGroup(g);
          },
          child: Text('delete'.tr,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      ],
    ));
  }
}

// ── Group tile ────────────────────────────────────────────────────────────────

class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final String myUid;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _GroupTile({
    required this.group,
    required this.myUid,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = group.adminUid == myUid;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.group, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(group.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'admin'.tr,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade800),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      UserAvatar(
                          label: group.adminDisplayName,
                          photoUrl: group.adminPhotoUrl,
                          size: 16),
                      const SizedBox(width: 4),
                      Text(
                        group.adminDisplayName.isNotEmpty
                            ? group.adminDisplayName
                            : 'unknown'.tr,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.people_outline,
                          size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text('${group.memberCount}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.redAccent),
                onPressed: onDelete,
              )
            else
              const Icon(Icons.chevron_right,
                  size: 20, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyGroupState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyGroupState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group_outlined, size: 64, color: Color(0xFFB0BEC5)),
          const SizedBox(height: 16),
          Text('no_groups'.tr,
              style: const TextStyle(
                  fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text('no_groups_subtitle'.tr,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text('create_group'.tr),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Get.toNamed(
              AppRoutes.qrScanner,
              arguments: {'mode': 'group'},
            ),
            icon: const Icon(Icons.qr_code_2),
            label: Text('scan_to_join'.tr),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Group QR sheet ────────────────────────────────────────────────────────────

class GroupQrSheet extends StatelessWidget {
  final GroupModel group;
  const GroupQrSheet({super.key, required this.group});

  static void show(GroupModel group) {
    Get.bottomSheet(
      GroupQrSheet(group: group),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrData = 'marathon-map://group/${group.id}';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            28, 28, 28, MediaQuery.of(context).viewInsets.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(group.name,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('group_qr_subtitle'.tr,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(data: qrData, size: 200),
          ),
          const SizedBox(height: 12),
          Text(
            '${'members_count'.tr}: ${group.memberCount} / 20',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (btnCtx) => ElevatedButton.icon(
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text('share_join_link'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final link =
                      'https://runmate-252e5.web.app/join.html?id=${group.id}&name=${Uri.encodeComponent(group.name)}';
                  final box = btnCtx.findRenderObject() as RenderBox?;
                  final rect = box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : const Rect.fromLTWH(0, 0, 100, 100);
                  Share.share(
                    '${'share_join_link_text'.tr.replaceAll('@name', group.name)}\n$link',
                    sharePositionOrigin: rect,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  }
}
