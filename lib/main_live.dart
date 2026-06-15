import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:firebase_database/firebase_database.dart';

import 'app/bindings/home_binding.dart';
import 'services/deep_link_service.dart';
import 'services/event_notification_service.dart';
import 'services/notification_service.dart';
import 'services/offline_storage_service.dart';
import 'widgets/offline_banner.dart';
import 'app/bindings/initial_binding.dart';
import 'app/bindings/kml_map_binding.dart';
import 'app/routes/app_routes.dart';
import 'core/theme.dart';
import 'firebase_options_live.dart';
import 'l10n/strings.dart';
import 'screens/home/home_screen.dart';
import 'screens/map/kml_map_screen.dart';
import 'screens/social/leaderboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/map/my_page_map_screen.dart';
import 'screens/run/my_routes_screen.dart';
import 'screens/run/route_detail_screen.dart';
import 'screens/run/qr_scanner_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/profile/user_profile_screen.dart';
import 'screens/social/group_management_screen.dart';
import 'screens/social/group_detail_screen.dart';
import 'controllers/group_controller.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: LiveFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  NotificationService.instance.init();
  await EventNotificationService.instance.init();
  DeepLinkService.instance.init();
  OfflineStorageService.instance.init();
  WakelockPlus.enable();
  _initForegroundTask();
  runApp(const MapApp());
}

void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'runmate_tracking',
      channelName: 'Run Tracking',
      channelDescription: 'Keeps your run active in the background',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(options: LiveFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (!e.code.contains('duplicate-app')) rethrow;
  }
  runZonedGuarded(
    () => FirebaseDatabase.instance.setPersistenceEnabled(true),
    (_, __) {},
  );
}

class MapApp extends StatelessWidget {
  const MapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'RunMate',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      translations: AppStrings(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('ja', 'JP'),
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.login,
      builder: (ctx, child) => Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          child!,
          const OfflineBanner(),
        ],
      ),
      getPages: [
        GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
        GetPage(
          name: AppRoutes.home,
          page: () => const HomeScreen(),
          binding: HomeBinding(),
        ),
        GetPage(
          name: AppRoutes.kmlMap,
          page: () => const KmlMapScreen(),
          binding: KmlMapBinding(),
        ),
        GetPage(name: AppRoutes.myPageMap, page: () => const MyPageMapScreen()),
        GetPage(name: AppRoutes.routeDetail, page: () => const RouteDetailScreen()),
        GetPage(name: AppRoutes.myRoutes, page: () => const MyRoutesScreen()),
        GetPage(name: AppRoutes.qrScanner, page: () => const QrScannerScreen()),
        GetPage(name: AppRoutes.leaderboard, page: () => const LeaderboardScreen()),
        GetPage(name: AppRoutes.userProfile, page: () => const UserProfileScreen()),
        GetPage(name: AppRoutes.settings, page: () => const SettingsScreen()),
        GetPage(
          name: AppRoutes.groupManagement,
          page: () => const GroupManagementScreen(),
          binding: BindingsBuilder(() { Get.put(GroupController()); }),
        ),
        GetPage(
          name: AppRoutes.groupDetail,
          page: () => const GroupDetailScreen(),
          binding: BindingsBuilder(() => Get.lazyPut(() => GroupDetailController())),
        ),
      ],
    );
  }
}
