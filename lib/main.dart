// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:geolocator/geolocator.dart';

import 'mapscreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MapApp());
}

class MapApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: KmlListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class KmlListScreen extends StatefulWidget {
  @override
  _KmlListScreenState createState() => _KmlListScreenState();
}

class _KmlListScreenState extends State<KmlListScreen> {
  List<Map<String, String>> files = [];

  @override
  void initState() {
    super.initState();
    _fetchKmlFiles();
  }

  Future<void> _fetchKmlFiles() async {
    try {
      final firebase_storage.ListResult result = await firebase_storage.FirebaseStorage.instance
          .ref('kpl')
          .listAll();

      setState(() {
        files = result.items.map((item) {
          return {
            'name': item.name,
            'path': item.fullPath,
          };
        }).toList();
      });
    } catch (e) {
      print("Failed to list files: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("KML Files")),
      body: ListView.builder(
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          return ListTile(
            title: Text(file['name'] ?? ''),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapScreen(kmlFilePath: file['path']!),
              ),
            ),
          );
        },
      ),
    );
  }
}

