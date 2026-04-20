import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/home_controller.dart';
import '../controllers/my_page_controller.dart';
import '../core/theme.dart';
import '../models/user_stats.dart';

class MyPageScreen extends GetView<MyPageController> {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_page_title'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'settings'.tr,
            onPressed: () => Get.toNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: Obx(() => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ── Profile header ─────────────────────────────────────────
              _ProfileHeader(controller: controller),

              // ── Stats row ──────────────────────────────────────────────
              if (controller.myStats.value != null)
                _StatsRow(stats: controller.myStats.value!),

              const SizedBox(height: 8),

              // ── Action cards ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'explore'.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _ActionCard(
                      icon: Icons.emoji_events,
                      label: 'leaderboard'.tr,
                      color: const Color(0xFFFFB300),
                      onTap: () =>
                          Get.toNamed(AppRoutes.leaderboard),
                    ),
                    _ActionCard(
                      icon: Icons.map_outlined,
                      label: 'my_routes'.tr,
                      color: AppTheme.primary,
                      onTap: () => Get.toNamed(AppRoutes.myRoutes),
                    ),
                    _ActionCard(
                      icon: Icons.people_outline,
                      label: 'nav_friends'.tr,
                      color: AppTheme.secondary,
                      onTap: () =>
                          Get.find<HomeController>().changeTab(1),
                    ),
                    _ActionCard(
                      icon: Icons.chat_bubble_outline,
                      label: 'chat'.tr,
                      color: const Color(0xFF8E6BBF),
                      onTap: () => Get.snackbar(
                        'chat'.tr,
                        'coming_soon'.tr,
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 2),
                      ),
                    ),
                  ],
                ),
              ),

            ],
          )),
    );
  }

}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final MyPageController controller;
  const _ProfileHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final photoUrl = controller.photoUrlObs.value;
      final name = controller.displayName;
      final email = controller.user?.email ?? '';
      final uploading = controller.isUploading.value;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with upload overlay
            GestureDetector(
              onTap: uploading ? null : controller.uploadProfileImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor:
                        AppTheme.primary.withValues(alpha: 0.15),
                    backgroundImage: photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl.isEmpty
                        ? Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          )
                        : null,
                  ),
                  if (uploading)
                    const Positioned.fill(
                      child: CircleAvatar(
                        backgroundColor: Colors.black38,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Name + email + edit
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _editName(context, name),
                        child: const Icon(Icons.edit_outlined,
                            size: 18, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  if (email.isNotEmpty)
                    Text(email,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('runner'.tr,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  void _editName(BuildContext context, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    Get.dialog(
      AlertDialog(
        title: Text('edit_name'.tr),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: 'your_name'.tr),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              controller.updateDisplayName(ctrl.text);
            },
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final UserStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statCol(stats.distanceStr, 'total_distance'.tr),
          _divider(),
          _statCol('${stats.totalRuns}', 'total_runs'.tr),
          _divider(),
          _statCol(stats.avgPaceStr, 'avg_pace'.tr),
        ],
      ),
    );
  }

  Widget _statCol(String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.75))),
        ],
      );

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withValues(alpha: 0.3),
      );
}

// ── Action card ───────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
