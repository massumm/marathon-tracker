import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xml/xml.dart' as xml;

class ParsedKml {
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final LatLng? finishPosition;
  const ParsedKml(
      {required this.polylines,
      required this.markers,
      this.finishPosition});
}

class KmlService {
  KmlService._();
  static final KmlService instance = KmlService._();

  ParsedKml parse(String xmlBody,
      {Color polylineColor = const Color(0xFFFF6B35)}) {
    final document = xml.XmlDocument.parse(xmlBody);

    // ── Step 1: Parse <Style> id → hue ──────────────────────────────────────
    final styleHues = <String, double>{};
    for (final style in document.findAllElements('Style')) {
      final id = style.getAttribute('id') ?? '';
      if (id.isEmpty) continue;
      final colorText =
          style.findAllElements('color').firstOrNull?.innerText.trim();
      if (colorText != null && colorText.isNotEmpty) {
        styleHues[id] = _kmlColorToHue(colorText);
      }
    }

    // ── Step 2: Resolve <StyleMap> aliases (id → normal style id) ───────────
    final styleMapResolution = <String, String>{};
    for (final styleMap in document.findAllElements('StyleMap')) {
      final id = styleMap.getAttribute('id') ?? '';
      if (id.isEmpty) continue;
      for (final pair in styleMap.findAllElements('Pair')) {
        if ((pair.getElement('key')?.innerText ?? '') != 'normal') continue;
        final url =
            pair.getElement('styleUrl')?.innerText.trim() ?? '';
        final targetId = url.startsWith('#') ? url.substring(1) : url;
        styleMapResolution[id] = targetId;
      }
    }

    // ── Helper: styleUrl → hue (with fallback to name keywords) ─────────────
    double resolveHue(String styleUrl, String name) {
      final id = styleUrl.startsWith('#') ? styleUrl.substring(1) : styleUrl;
      if (styleHues.containsKey(id)) return styleHues[id]!;
      final resolved = styleMapResolution[id];
      if (resolved != null && styleHues.containsKey(resolved)) {
        return styleHues[resolved]!;
      }
      return _hueFromName(name);
    }

    // ── Step 3: Parse <Point> markers ────────────────────────────────────────
    final Set<Marker> markers = {};
    for (final placemark in document.findAllElements('Placemark')) {
      final pointEl = placemark.findAllElements('Point').firstOrNull;
      if (pointEl == null) continue; // skip lines

      final name =
          placemark.getElement('name')?.innerText.trim() ?? '';
      final description =
          placemark.getElement('description')?.innerText.trim() ?? '';
      final styleUrl =
          placemark.getElement('styleUrl')?.innerText.trim() ?? '';

      final coordText = pointEl
          .findAllElements('coordinates')
          .firstOrNull
          ?.innerText
          .trim();
      if (coordText == null) continue;
      final parts = coordText.split(',');
      if (parts.length < 2) continue;

      final lon = double.tryParse(parts[0].trim());
      final lat = double.tryParse(parts[1].trim());
      if (lat == null || lon == null) continue;

      final hue = resolveHue(styleUrl, name);

      markers.add(Marker(
        markerId: MarkerId(name.isNotEmpty ? name : '$lat,$lon'),
        position: LatLng(lat, lon),
        infoWindow: InfoWindow(
          title: name,
          snippet: description.isNotEmpty ? description : null,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      ));
    }

    // ── Step 4: Parse polylines ───────────────────────────────────────────────
    final Set<Polyline> polylines = {};
    int polylineId = 0;
    for (final element in document.findAllElements('coordinates')) {
      final coords =
          element.innerText.trim().split(RegExp(r'\s+'));
      final points = <LatLng>[];
      for (final coord in coords) {
        final p = coord.split(',');
        if (p.length < 2) continue;
        final lon = double.tryParse(p[0].trim());
        final lat = double.tryParse(p[1].trim());
        if (lat != null && lon != null) points.add(LatLng(lat, lon));
      }
      if (points.length >= 2) {
        polylines.add(Polyline(
          polylineId: PolylineId('route_$polylineId'),
          points: points,
          color: polylineColor,
          width: 5,
        ));
        polylineId++;
      }
    }

    // Identify finish marker by name keyword
    LatLng? finishPosition;
    for (final m in markers) {
      final id = m.markerId.value.toLowerCase();
      if (id.contains('finish') || id.contains('goal') || id.contains('end')) {
        finishPosition = m.position;
        break;
      }
    }

    return ParsedKml(
        polylines: polylines, markers: markers, finishPosition: finishPosition);
  }

  // ── KML AABBGGRR → HSV hue ────────────────────────────────────────────────
  static double _kmlColorToHue(String kmlColor) {
    final c = kmlColor.replaceAll('#', '').trim();
    if (c.length < 8) return BitmapDescriptor.hueAzure;
    // KML format: AABBGGRR
    final r = int.tryParse(c.substring(6, 8), radix: 16) ?? 128;
    final g = int.tryParse(c.substring(4, 6), radix: 16) ?? 128;
    final b = int.tryParse(c.substring(2, 4), radix: 16) ?? 128;
    final color = Color.fromARGB(255, r, g, b);
    return HSVColor.fromColor(color).hue;
  }

  // ── Name-keyword fallback hues ────────────────────────────────────────────
  static double _hueFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('water') || n.contains('drink') || n.contains('hydrat')) {
      return BitmapDescriptor.hueBlue;
    }
    if (n.contains('toilet') || n.contains('rest') ||
        n.contains('wc') || n.contains('bathroom')) {
      return BitmapDescriptor.hueOrange;
    }
    if (n.contains('snack') || n.contains('food') ||
        n.contains('refresh') || n.contains('eat')) {
      return BitmapDescriptor.hueGreen;
    }
    if (n.contains('start')) return BitmapDescriptor.hueGreen;
    if (n.contains('finish') || n.contains('goal') || n.contains('end')) {
      return BitmapDescriptor.hueRed;
    }
    if (n.contains('medical') || n.contains('aid') || n.contains('first')) {
      return BitmapDescriptor.hueRed;
    }
    if (n.contains('lobby') || n.contains('info') || n.contains('help')) {
      return BitmapDescriptor.hueViolet;
    }
    return BitmapDescriptor.hueAzure;
  }
}
