import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:geolocator/geolocator.dart';

class KmlMapScreen extends StatefulWidget {
  final String kmlFilePath;

  const KmlMapScreen({super.key, required this.kmlFilePath});

  @override
  _KmlMapScreenState createState() => _KmlMapScreenState();
}

class _KmlMapScreenState extends State<KmlMapScreen> {
  GoogleMapController? _controller;
  Timer? _timer;
  int _elapsedSeconds = 0;
  Set<Polyline> _polylines = {};
  LatLng _initialLocation = const LatLng(23.777176, 90.399452);
  Set<Marker> _markers = {};
  final List<LatLng> _trackingPoints = [];
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;
  bool _isLoading = false;
  bool _kmlLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadKmlRoute(widget.kmlFilePath);

  }

  /// Loads a KML route from the specified [path] in Firebase Storage.
  ///
  /// This method fetches the KML file from Firebase Storage, parses its XML content,
  /// and extracts polyline paths and placemark markers.
  ///
  /// The extracted polylines and markers are then displayed on the map.
  /// The map camera is animated to the starting point of the first loaded polyline.
  /// If any error occurs during the process, an error message is printed to the console.
  Future<void> _loadKmlRoute(String path) async {
    try {
      final ref = firebase_storage.FirebaseStorage.instance.ref(path);
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final coordinatesElements = document.findAllElements('coordinates');
        final placemarks = document.findAllElements('Placemark');

        Set<Polyline> loadedPolylines = {};
        Set<Marker> loadedMarkers = {};
        int polylineId = 0;
        // 1. Parse polyline paths
        for (var element in coordinatesElements) {
          final coords = element.text.trim().split(RegExp(r'\s+'));
          final points = <LatLng>[];

          for (var coord in coords) {
            final parts = coord.split(',');
            if (parts.length >= 2) {
              final lon = double.tryParse(parts[0]);
              final lat = double.tryParse(parts[1]);
              if (lat != null && lon != null) {
                points.add(LatLng(lat, lon));
              }
            }
          }
          // 2. Parse markers (placemarks with Point)
          for (var placemark in placemarks) {
            print("placemarks$placemark");
            final name = placemark.getElement('name')?.text ?? '';
            final description = placemark.getElement('description')?.text ?? '';
            final coordText = placemark.findAllElements('coordinates').first.text.trim();
            print("coordText$coordText");
            final parts = coordText.split(',');
            if (parts.length >= 2) {
              final lon = double.tryParse(parts[0]);
              final lat = double.tryParse(parts[1]);
              if (lat != null && lon != null) {
                final position = LatLng(lat, lon);
                loadedMarkers.add(
                  Marker(
                    markerId: MarkerId(name),
                    position: position,
                    infoWindow: InfoWindow(title: name, snippet: description),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  ),
                );
              }
            }
          }
          if (points.length >= 2) {
            loadedPolylines.add(Polyline(
              polylineId: PolylineId("route_$polylineId"),
              points: points,
              color: Colors.orange,
              width: 4,
            ));
            polylineId++;
          }
        }

        // 3. Apply updates
        if (loadedPolylines.isNotEmpty) {
          setState(() {
            print("polylines added${loadedPolylines.first.points.first}");
            _polylines = loadedPolylines;
            _initialLocation = loadedPolylines.first.points.first;
            _markers = loadedMarkers;
            _kmlLoaded = true;
          });
          _controller?.animateCamera(
            CameraUpdate.newLatLng(_initialLocation),
          );
        }
      }
    } catch (e) {
      print("Error loading KML: $e");
    }
  }

  /// Starts tracking the user's location.
  ///
  /// This method clears any previous tracking data, sets the tracking state to true,
  /// and initializes a timer to update the elapsed time.
  /// It then gets the current GPS position and animates the map camera to that location.
  /// A stream listener is set up to continuously receive position updates,
  /// adding each new location to the `_trackingPoints` list and updating the UI.
  /// The `_isTracking` flag is set to true to reflect the active tracking state.
  Future<void> _startTracking() async {
    _trackingPoints.clear();
    _isTracking = true;
    _timer?.cancel(); // clear previous timer

    final position = await Geolocator.getCurrentPosition();
    final currentLatLng = LatLng(position.latitude, position.longitude);
    _controller?.animateCamera(CameraUpdate.newLatLng(currentLatLng));

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });
    setState(() {});

    _positionStream = Geolocator.getPositionStream().listen((position) {
      print("position$position");
      final latLng = LatLng(position.latitude, position.longitude);
      _controller?.animateCamera(CameraUpdate.newLatLng(latLng));
      _trackingPoints.add(latLng);
      setState(() {});
    });
  }

  /// Stops tracking the user's location and saves the recorded route.
  ///
  /// This method performs the following actions:
  /// 1. Sets an loading state to show a progress indicator.
  /// 2. Cancels the position stream and timer used for tracking.
  /// 3. Sets `_isTracking` to false to indicate that tracking has stopped.
  /// 4. Generates a unique filename for the route data based on the current timestamp.
  /// 5. Calculates the elapsed time, start time, total distance, and average pace of the tracked route.
  /// 6. Constructs a JSON object containing the route details:
  ///    - Event name (e.g., "Iwaki Sunshine Marathon")
  ///    - Event type (e.g., "Full Marathon")
  ///    - Start date and time
  ///    - Total time, distance, and pace
  ///    - A list of latitude and longitude coordinates representing the route.
  /// 7. Uploads the JSON data to Firebase Storage under the 'routes/' directory.
  /// 8. Clears the loading state.
  /// 9. Navigates back to the first screen in the navigation stack (typically the home screen).
  /// 10. Sets the tab index on the `HomeScreen` to 1 (assuming this navigates to a specific tab, e.g., My Page).
  Future<void> _stopTracking() async {
    setState(() {
      _isLoading = true;
    });
    _positionStream?.cancel();
    _timer?.cancel();
    _isTracking = false;

    // Artificial delay to simulate saving and show loader
    final now = DateTime.now();
    final fileName = 'my_route_${now.millisecondsSinceEpoch}.json';

    // Time and distance calculations
    final elapsedTime = Duration(seconds: _elapsedSeconds);
    final startTime = now.subtract(elapsedTime);

    // Calculate total distance
    double totalDistance = 0.0;
    for (int i = 1; i < _trackingPoints.length; i++) {
      totalDistance += Geolocator.distanceBetween(
        _trackingPoints[i - 1].latitude,
        _trackingPoints[i - 1].longitude,
        _trackingPoints[i].latitude,
        _trackingPoints[i].longitude,
      );
    }
    totalDistance = totalDistance / 1000; // meters to kilometers

    // Calculate average pace (km/h)
    final pace = totalDistance / (_elapsedSeconds / 3600); // km per hour

    // Build the final JSON
    final data = {
      "event": "Iwaki Sunshine Marathon",        //大会
      "type": "Full Marathon",                   // フルマラソン
      "start_date": "${startTime.year}/${startTime.month.toString().padLeft(2, '0')}/${startTime.day.toString().padLeft(2, '0')}",
      "start_time": "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:${startTime.second.toString().padLeft(2, '0')}",
      "time": _formatTime(_elapsedSeconds),      // hh:mm:ss
      "distance": "${totalDistance.toStringAsFixed(1)} km",
      "pace": "${pace.toStringAsFixed(1)} km/h",
      "route": _trackingPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    };

    // Upload to Firebase Storage
    final ref = firebase_storage.FirebaseStorage.instance.ref('routes/$fileName');
    await ref.putString(jsonEncode(data));

    setState(() {
      _isLoading = false;
    });

    Navigator.of(context).popUntil((route) => route.isFirst);
    // Optionally use a method to change the tab index
   // HomeScreen.setTabIndex(1); // implement this

  }
  /// Formats the given number of seconds into a string representation of time (hh:mm:ss).
  ///
  /// [seconds]: The total number of seconds to format.
  ///
  /// Returns a string in "hh:mm:ss" format.
  /// For example, `_formatTime(3661)` would return "01:01:01".
  String _formatTime(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$secs";
  }


  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("マップビュー")),
      body: Stack(
        children: [
          if (_kmlLoaded)
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _initialLocation, zoom: 17),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) => _controller = controller,
            polylines: {
              ..._polylines,
              if (_isTracking)
                Polyline(
                  polylineId: const PolylineId("tracking"),
                  points: _trackingPoints,
                  color: Colors.green,
                  width: 4,
                ),
            },
            markers: _markers,
          ),

          if (!_kmlLoaded)
            const Center(child: CircularProgressIndicator()),
          Container(
            margin: const EdgeInsets.only(left: 70, right: 70),
            alignment: Alignment.topCenter,


            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _formatTime(_elapsedSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
,
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _isTracking ? _stopTracking : _startTracking,
                child: Image.asset(
                    _isTracking ? "assets/images/stop.png" : "assets/images/start.png",
                  height: 70,
                  width: 70,
                ),
              ),
            ),
          ),
          if(_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
