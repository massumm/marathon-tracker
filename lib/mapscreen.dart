// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:geolocator/geolocator.dart';


class MapScreen extends StatefulWidget {
  final String kmlFilePath;
  MapScreen({required this.kmlFilePath});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LatLng _initialLocation = LatLng(23.777176, 90.399452); // default Dhaka
  Set<Polyline> _polylines = {};
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    
    _loadKmlRoute();
    _determinePosition();
  }

  Future<void> _loadKmlRoute() async {
    try {
      final ref = firebase_storage.FirebaseStorage.instance.ref(widget.kmlFilePath);
      final url = await ref.getDownloadURL();

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final coordinatesElements = document.findAllElements('coordinates');
        final List<LatLng> routePoints = [];

        for (var element in coordinatesElements) {
          final coordsText = element.text.trim();
          final coords = coordsText.split(RegExp(r'\s+'));

          for (var coord in coords) {
            final parts = coord.split(',');
            if (parts.length >= 2) {
              final lon = double.tryParse(parts[0]);
              final lat = double.tryParse(parts[1]);
              if (lat != null && lon != null) {
                routePoints.add(LatLng(lat, lon));
              }
            }
          }
        }

        if (routePoints.isNotEmpty) {
          setState(() {
            _polylines.add(Polyline(
              polylineId: PolylineId("route"),
              points: routePoints,
              color: Colors.blue,
              width: 4,
            ));
            _initialLocation = routePoints.first;
          });
        }
      }
    } catch (e) {
      print("Error loading KML: $e");
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Map Route")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _initialLocation, zoom: 15),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) => _controller = controller,
        polylines: _polylines,
      ),
    );
  }
}
