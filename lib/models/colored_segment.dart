import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ColoredSegment {
  final Color color;
  final List<LatLng> points;
  const ColoredSegment({required this.color, required this.points});
}
