import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  // Firebase Storage paths — 'kpl' is the existing bucket name, do not rename
  static const String kmlStoragePath = 'kpl';
  static const String routesStoragePath = 'routes';
  static const String kmlUploadPath = 'kml';

  // Map defaults (Tokyo)
  static const double defaultLat = 35.6895;
  static const double defaultLng = 139.6917;

  // Run metadata
  static const String eventName = 'Iwaki Sunshine Marathon';
  static const String eventType = 'Full Marathon';

  // Google APIs
  static const String googleMapsApiKey =
      'AIzaSyBpC0p4Ii20PRsABxxuJrZTeRhc4ysRnfA';

  // Tutorial links — update these URLs to point to the correct videos
  static const String drawOnMapTutorialUrl =
      'https://www.youtube.com/watch?v=42_QTluGfok';

  // Web base URL for share/join deep links. Resolved from the active Firebase
  // project so the LIVE build uses the production custom domain and the STAGE
  // build uses the stage hosting — never hardcode the dev URL.
  static String get webBaseUrl {
    try {
      return Firebase.app().options.projectId == 'runmate-live'
          ? 'https://runmate.club'
          : 'https://runmate-252e5.web.app';
    } catch (_) {
      return 'https://runmate.club';
    }
  }
}


