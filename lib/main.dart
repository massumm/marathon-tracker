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
import 'firebase_options.dart';
import 'l10n/strings.dart';
import 'screens/home_screen.dart';
import 'screens/kml_map_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/my_page_map_screen.dart';
import 'screens/my_routes_screen.dart';
import 'screens/route_detail_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/group_management_screen.dart';
import 'screens/group_detail_screen.dart';
import 'controllers/group_controller.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Don't await — getToken() is a network call that blocks the splash screen
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
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } on FirebaseException catch (e) {
    if (!e.code.contains('duplicate-app')) rethrow;
  }
  // Must be called before any DatabaseReference is used.
  // Wrapped in try/catch because background isolates (FCM) may call this
  // after the main engine has already initialized the DB instance.
  runZonedGuarded(
    () => FirebaseDatabase.instance.setPersistenceEnabled(true),
    (_, __) {}, // silently ignore — thrown on hot restart when DB is already initialised
  );
}

class MapApp extends StatelessWidget {
  const MapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Marathon Map',
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
        GetPage(
          name: AppRoutes.login,
          page: () => const LoginScreen(),
        ),
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
        GetPage(
          name: AppRoutes.myPageMap,
          page: () => const MyPageMapScreen(),
        ),
        GetPage(
          name: AppRoutes.routeDetail,
          page: () => const RouteDetailScreen(),
        ),
        GetPage(
          name: AppRoutes.myRoutes,
          page: () => const MyRoutesScreen(),
        ),
        GetPage(
          name: AppRoutes.qrScanner,
          page: () => const QrScannerScreen(),
        ),
        GetPage(
          name: AppRoutes.leaderboard,
          page: () => const LeaderboardScreen(),
        ),
        GetPage(
          name: AppRoutes.userProfile,
          page: () => const UserProfileScreen(),
        ),
        GetPage(
          name: AppRoutes.settings,
          page: () => const SettingsScreen(),
        ),
        GetPage(
          name: AppRoutes.groupManagement,
          page: () => const GroupManagementScreen(),
          binding: BindingsBuilder(() {
            Get.put(GroupController());
          }),
        ),
        GetPage(
          name: AppRoutes.groupDetail,
          page: () => const GroupDetailScreen(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => GroupDetailController());
          }),
        ),
      ],
    );
  }
}
