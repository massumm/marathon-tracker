import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/my_page_controller.dart';
import '../core/theme.dart';
import '../models/tracked_route.dart';
import '../widgets/route_list_card.dart';

class MyPageScreen extends GetView<MyPageController> {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.fetchRoutes,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _confirmSignOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Column(
        children: [
          _UserCard(controller: controller),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final files = controller.routeRefs;
              if (files.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_run,
                          size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('記録されたルートはありません',
                          style: TextStyle(
                              fontSize: 16, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      const Text('Start a run to see your routes here.',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
                    child: Text(
                      '記録  (${files.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: files.length,
                      itemBuilder: (_, i) {
                        final ref = files[i];
                        return RouteListCard(
                          title: TrackedRoute.parseDateFromFileName(ref.name),
                          subtitle: ref.name,
                          leadingIcon: Icons.flag_rounded,
                          onTap: () => Get.toNamed(
                            AppRoutes.myPageMap,
                            arguments: ref.fullPath,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    Get.dialog(AlertDialog(
      title: const Text('Sign out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(
            onPressed: Get.back, child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Get.back();
            controller.signOut();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Sign out'),
        ),
      ],
    ));
  }
}

class _UserCard extends StatelessWidget {
  final MyPageController controller;
  const _UserCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    if (user == null) return const SizedBox.shrink();

    final name = controller.displayName;
    final email = user.email ?? '';
    final photoUrl = user.photoURL;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(name[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary))
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            if (email.isNotEmpty)
              Text(email,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Runner',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary)),
        ),
      ]),
    );
  }
}
