// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:geolocator/geolocator.dart';
import 'kml_map_screen.dart';


class MapScreen extends StatefulWidget {
  // final String kmlFilePath;

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LatLng _initialLocation = LatLng(35.6895, 139.6917); // default Tokyo, Japan
  Set<Polyline> _polylines = {};
  Position? _currentPosition;

  //initial setup for tracking user
  List<LatLng> _trackingPoints = [];

  bool _isTracking = false;


  @override
  void initState() {
    super.initState();
    _determinePosition();
  }



  Future<List<String>> _fetchKmlFiles() async {
    try {
      final result = await firebase_storage.FirebaseStorage.instance
          .ref('kpl')
          .listAll();

      return result.items.map((item) => item.fullPath).toList(); // only paths
    } catch (e) {
      print("Failed to list files: $e");
      return [];
    }
  }

  /// Determines the current position of the device.
  ///
  /// This function checks if location services are enabled and if the app has
  /// the necessary permissions to access the device's location.
  /// If services are disabled or permissions are denied, the function returns early.
  /// If permissions are granted, it fetches the current position and updates
  /// the state with the new position. It also attempts to move the map camera
  /// to the new location if the map controller is available.
  ///
  /// This function does not return a value.
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
    setState(() {
      _currentPosition = position;
      //_initialLocation = LatLng(position.latitude, position.longitude);

      // Move camera to current position if map is already created
      _controller?.animateCamera(CameraUpdate.newLatLng(_initialLocation));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("地図表示")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _initialLocation, zoom: 11),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) => _controller = controller,
                  polylines: _isTracking
                      ? {
                    Polyline(
                      polylineId: PolylineId("tracking"),
                      points: _trackingPoints,
                      color: Colors.green,
                      width: 4,
                    )
                  }
                      : _polylines,
                )

              ],
            ),
          ),

          // Route list below map
          Expanded(
            flex: 2,
            child: FutureBuilder<List<String>>(
              future: _fetchKmlFiles(), // Fetch file list from Firebase
              builder: (context, snapshot) {
                print("snapshot details in mapscreen"+snapshot.toString());
                if (snapshot.connectionState == ConnectionState.waiting) {

                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error loading routes"));
                }

                // Sort file paths in descending order
                final filePaths = (snapshot.data ?? [])..sort((a, b) => b.compareTo(a));

                return ListView.builder(

                  itemCount: filePaths.length,
                  itemBuilder: (context, index) {

                    final path = filePaths[index]; // Already sorted
                    final name = path.split('/').last; // Extract file name
                    return ListTile(
                      title: Text(name),
                      onTap: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KmlMapScreen(kmlFilePath: path),
                            ),
                          )

                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

    );
  }
}
