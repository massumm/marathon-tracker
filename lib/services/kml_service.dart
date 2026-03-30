import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:xml/xml.dart' as xml;

class ParsedKml {
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  const ParsedKml({required this.polylines, required this.markers});
}

class KmlService {
  KmlService._();
  static final KmlService instance = KmlService._();

  ParsedKml parse(String xmlBody, {Color polylineColor = const Color(0xFFFF6B35)}) {
    final document = xml.XmlDocument.parse(xmlBody);
    final coordinatesElements = document.findAllElements('coordinates');
    final placemarks = document.findAllElements('Placemark').toList();

    final Set<Polyline> polylines = {};
    final Set<Marker> markers = {};
    int polylineId = 0;

    // Parse markers once, outside the coordinates loop (fixes duplicate insertion bug)
    for (var placemark in placemarks) {
      final name = placemark.getElement('name')?.innerText ?? '';
      final description = placemark.getElement('description')?.innerText ?? '';
      final coordElements = placemark.findAllElements('coordinates');
      if (coordElements.isEmpty) continue;
      final parts = coordElements.first.innerText.trim().split(',');
      if (parts.length >= 2) {
        final lon = double.tryParse(parts[0]);
        final lat = double.tryParse(parts[1]);
        if (lat != null && lon != null) {
          markers.add(Marker(
            markerId: MarkerId(name),
            position: LatLng(lat, lon),
            infoWindow: InfoWindow(title: name, snippet: description),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
          ));
        }
      }
    }

    // Parse polylines
    for (var element in coordinatesElements) {
      final coords = element.innerText.trim().split(RegExp(r'\s+'));
      final points = <LatLng>[];
      for (var coord in coords) {
        final parts = coord.split(',');
        if (parts.length >= 2) {
          final lon = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lat != null && lon != null) points.add(LatLng(lat, lon));
        }
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

    return ParsedKml(polylines: polylines, markers: markers);
  }
}
