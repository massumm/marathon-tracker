class KmlRoute {
  final String storagePath;
  final String fileName;

  const KmlRoute({required this.storagePath, required this.fileName});

  factory KmlRoute.fromStoragePath(String path) => KmlRoute(
        storagePath: path,
        fileName: path.split('/').last,
      );

  String get displayName =>
      fileName.replaceAll('.kml', '').replaceAll('_', ' ');
}
