import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../controllers/my_page_controller.dart';
import '../core/theme.dart';
import '../models/tracked_route.dart';
import '../widgets/route_list_card.dart';

class MyRoutesScreen extends GetView<MyPageController> {
  const MyRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_routes'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.fetchRoutes,
            tooltip: 'refresh'.tr,
          ),
        ],
      ),
      body: Obx(() {
        final pending = controller.localPendingNames;
        final refs = controller.routeRefs;

        if (!controller.isLoading.value && refs.isEmpty && pending.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_run,
                    size: 72, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('no_routes'.tr,
                    style: const TextStyle(
                        fontSize: 16, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Text('no_routes_subtitle'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Pending (local-only) routes at top with sync badge
            ...pending.map((name) => RouteListCard(
                  title: TrackedRoute.parseEventFromFileName(name),
                  subtitle: TrackedRoute.parseDateFromFileName(name),
                  leadingIcon: Icons.cloud_upload_outlined,
                  leadingColor: Colors.orange,
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('pending_sync'.tr,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600)),
                  ),
                  onTap: () => Get.toNamed(
                    AppRoutes.routeDetail,
                    arguments: 'local/$uid/$name',
                  ),
                )),
            // Cloud routes
            ...refs.map((ref) => RouteListCard(
                  title: TrackedRoute.parseEventFromFileName(ref.name),
                  subtitle: TrackedRoute.parseDateFromFileName(ref.name),
                  leadingIcon: Icons.flag_rounded,
                  onTap: () => Get.toNamed(
                    AppRoutes.routeDetail,
                    arguments: ref.fullPath,
                  ),
                )),
            if (controller.isLoading.value)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      }),
    );
  }
}
