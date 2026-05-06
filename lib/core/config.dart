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
}
