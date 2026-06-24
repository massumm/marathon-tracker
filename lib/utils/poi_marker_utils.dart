import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/kml_service.dart';

// ── POI type → color ──────────────────────────────────────────────────────────

Color poiColor(String typeId) => switch (typeId) {
  'start'    => Colors.green,
  'finish'   => Colors.red,
  'water'    => Colors.blue,
  'restroom' => Colors.orange,
  'snack'    => const Color(0xFF00838F), // cyan shade700
  'medical'  => Colors.pink,
  'info'     => Colors.purple,
  _          => Colors.blueGrey,
};

// ── POI type → icon glyph ─────────────────────────────────────────────────────

IconData poiIconData(String typeId) => switch (typeId) {
  'start'    => Icons.play_circle_outline,
  'finish'   => Icons.flag_outlined,
  'water'    => Icons.water_drop_outlined,
  'restroom' => Icons.wc_outlined,
  'snack'    => Icons.fastfood_outlined,
  'medical'  => Icons.local_hospital_outlined,
  'info'     => Icons.info_outline,
  _          => Icons.location_on,
};

// ── Single icon builder ───────────────────────────────────────────────────────

/// Builds the same 48 × 48 px circular bitmap used in the Route Editor:
/// drop-shadow → filled circle (type colour) → white border → icon glyph.
Future<BitmapDescriptor> buildPoiIcon(String typeId) async {
  const int sz = 48;
  const double cx = sz / 2.0;
  const double r = cx - 2;
  final color = poiColor(typeId);
  final iconData = poiIconData(typeId);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // drop shadow
  canvas.drawCircle(const Offset(cx + 1.5, cx + 1.5), r,
      Paint()..color = Colors.black.withValues(alpha: 0.28));
  // filled circle
  canvas.drawCircle(const Offset(cx, cx), r, Paint()..color = color);
  // white border
  canvas.drawCircle(
    const Offset(cx, cx),
    r,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );
  // icon glyph
  final tp = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: sz * 0.44,
        fontFamily: iconData.fontFamily,
        color: Colors.white,
      ),
    )
    ..layout();
  tp.paint(canvas, Offset(cx - tp.width / 2, cx - tp.height / 2));

  final img = await recorder.endRecording().toImage(sz, sz);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

// ── Batch builder ─────────────────────────────────────────────────────────────

/// Replaces the default-hue marker icons in [parsed] with the custom
/// circular bitmap icons. Returns the upgraded [Set<Marker>].
Future<Set<Marker>> buildCustomPOIMarkers(ParsedKml parsed) async {
  final result = <Marker>{};
  for (final m in parsed.markers) {
    final typeId = parsed.markerTypeIds[m.markerId.value] ?? '';
    final icon = await buildPoiIcon(typeId);
    result.add(Marker(
      markerId: m.markerId,
      position: m.position,
      infoWindow: m.infoWindow,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
    ));
  }
  return result;
}
