import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/bindings/home_binding.dart';
import 'app/bindings/initial_binding.dart';
import 'app/bindings/kml_map_binding.dart';
import 'app/routes/app_routes.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'l10n/strings.dart';
import 'screens/home_screen.dart';
import 'screens/kml_map_screen.dart';
import 'screens/login_screen.dart';
import 'screens/my_page_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  WakelockPlus.enable();
  runApp(const MapApp());
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
      locale: const Locale('ja', 'JP'),
      fallbackLocale: const Locale('en', 'US'),
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.login,
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
      ],
    );
  }
}
