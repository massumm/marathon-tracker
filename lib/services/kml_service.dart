import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xml/xml.dart' as xml;

class ParsedKml {
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final LatLng? finishPosition;
  // markerId.value → type name ('start'|'finish'|'water'|'restroom'|'snack'|'medical'|'info')
  final Map<String, String> markerTypeIds;
  const ParsedKml({
    required this.polylines,
    required this.markers,
    this.finishPosition,
    this.markerTypeIds = const {},
  });
}

class KmlService {
  KmlService._();
  static final KmlService instance = KmlService._();

  ParsedKml parse(String xmlBody,
      {Color polylineColor = const Color(0xFFFF6B35)}) {
    final document = xml.XmlDocument.parse(xmlBody);

    // ── Step 1: Parse <Style> id → hue ──────────────────────────────────────
    final styleHues = <String, double>{};
    for (final style in document.findAllElements('*').where((e) => e.name.local == 'Style')) {
      final id = style.getAttribute('id') ?? '';
      if (id.isEmpty) continue;
      xml.XmlElement? colorEl;
      for (final child in style.children) {
        if (child is xml.XmlElement && child.name.local == 'color') {
          colorEl = child;
          break;
        }
      }
      final colorText = colorEl?.innerText.trim();
      if (colorText != null && colorText.isNotEmpty) {
        styleHues[id] = _kmlColorToHue(colorText);
      }
    }

    // ── Step 2: Resolve <StyleMap> aliases (id → normal style id) ───────────
    final styleMapResolution = <String, String>{};
    for (final styleMap in document.findAllElements('*').where((e) => e.name.local == 'StyleMap')) {
      final id = styleMap.getAttribute('id') ?? '';
      if (id.isEmpty) continue;
      for (final pair in styleMap.findAllElements('*').where((e) => e.name.local == 'Pair')) {
        xml.XmlElement? keyEl;
        xml.XmlElement? styleUrlEl;
        for (final child in pair.children) {
          if (child is xml.XmlElement) {
            if (child.name.local == 'key') keyEl = child;
            if (child.name.local == 'styleUrl') styleUrlEl = child;
          }
        }
        if ((keyEl?.innerText ?? '') != 'normal') continue;
        final url = styleUrlEl?.innerText.trim() ?? '';
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
    final Map<String, String> markerTypeIds = {};
    for (final placemark in document.findAllElements('*').where((e) => e.name.local == 'Placemark')) {
      xml.XmlElement? pointEl;
      xml.XmlElement? nameEl;
      xml.XmlElement? descEl;
      xml.XmlElement? styleUrlEl;

      for (final child in placemark.children) {
        if (child is xml.XmlElement) {
          if (child.name.local == 'Point') pointEl = child;
          if (child.name.local == 'name') nameEl = child;
          if (child.name.local == 'description') descEl = child;
          if (child.name.local == 'styleUrl') styleUrlEl = child;
        }
      }

      if (pointEl == null) continue; // skip lines

      final name = nameEl?.innerText.trim() ?? '';
      final description = descEl?.innerText.trim() ?? '';
      final styleUrl = styleUrlEl?.innerText.trim() ?? '';

      xml.XmlElement? coordEl;
      for (final child in pointEl.children) {
        if (child is xml.XmlElement && child.name.local == 'coordinates') {
          coordEl = child;
          break;
        }
      }

      final coordText = coordEl?.innerText.trim();
      if (coordText == null) continue;
      final parts = coordText.split(',');
      if (parts.length < 2) continue;

      final lon = double.tryParse(parts[0].trim());
      final lat = double.tryParse(parts[1].trim());
      if (lat == null || lon == null) continue;

      final hue = resolveHue(styleUrl, name);
      final markerId = name.isNotEmpty ? name : '$lat,$lon';

      // Resolve type ID from styleUrl, then fall back to name keywords.
      const knownTypes = ['start', 'finish', 'water', 'restroom', 'snack', 'medical', 'info'];
      final rawId = styleUrl.startsWith('#') ? styleUrl.substring(1) : styleUrl;
      final resolvedId = styleMapResolution[rawId] ?? rawId;
      String typeId = knownTypes.contains(resolvedId)
          ? resolvedId
          : knownTypes.contains(rawId)
              ? rawId
              : _typeIdFromName(name);
      markerTypeIds[markerId] = typeId;

      markers.add(Marker(
        markerId: MarkerId(markerId),
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
    for (final element in document.findAllElements('*').where((e) => e.name.local == 'coordinates')) {
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

    // Identify finish: prefer explicit marker, fall back to last polyline point
    LatLng? finishPosition;
    for (final m in markers) {
      final id = m.markerId.value.toLowerCase();
      if (id.contains('finish') || id.contains('goal') || id.contains('end')) {
        finishPosition = m.position;
        break;
      }
    }
    // Fallback: use last point of the longest polyline
    if (finishPosition == null && polylines.isNotEmpty) {
      Polyline? longest;
      for (final p in polylines) {
        if (longest == null || p.points.length > longest.points.length) {
          longest = p;
        }
      }
      if (longest != null && longest.points.isNotEmpty) {
        finishPosition = longest.points.last;
      }
    }

    return ParsedKml(
      polylines: polylines,
      markers: markers,
      finishPosition: finishPosition,
      markerTypeIds: markerTypeIds,
    );
  }

  // ── Name → type ID string ─────────────────────────────────────────────────
  static String _typeIdFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('start')) return 'start';
    if (n.contains('finish') || n.contains('goal') || n.contains('end')) return 'finish';
    if (n.contains('water') || n.contains('drink') || n.contains('hydrat')) return 'water';
    if (n.contains('toilet') || n.contains('rest') || n.contains('wc') || n.contains('bathroom')) return 'restroom';
    if (n.contains('snack') || n.contains('food') || n.contains('refresh') || n.contains('eat')) return 'snack';
    if (n.contains('medical') || n.contains('aid') || n.contains('first')) return 'medical';
    if (n.contains('lobby') || n.contains('info') || n.contains('help')) return 'info';
    return '';
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
