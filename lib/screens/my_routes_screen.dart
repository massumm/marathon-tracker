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
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.routeRefs.isEmpty) {
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

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: controller.routeRefs.length,
          itemBuilder: (_, i) {
            final ref = controller.routeRefs[i];
            return RouteListCard(
              title: TrackedRoute.parseEventFromFileName(ref.name),
              subtitle: TrackedRoute.parseDateFromFileName(ref.name),
              leadingIcon: Icons.flag_rounded,
              onTap: () => Get.toNamed(
                AppRoutes.routeDetail,
                arguments: ref.fullPath,
              ),
            );
          },
        );
      }),
    );
  }
}
