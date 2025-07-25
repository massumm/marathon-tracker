import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:convert';

import 'package:http/http.dart' as http;

class MyPageMapScreen extends StatelessWidget {
  final String filePath;

  MyPageMapScreen({required this.filePath});

  Future<Map<String, dynamic>> _loadJsonData() async {
    final ref = firebase_storage.FirebaseStorage.instance.ref(filePath);
    final url = await ref.getDownloadURL();

    final response = await Uri.parse(url).resolveUri(Uri());
    final jsonString = await http.read(response);
    return json.decode(jsonString);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Route Viewer")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadJsonData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Failed to load route"));
          }

          final data = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Loaded JSON:\n${json.encode(data)}"),
          );
        },
      ),
    );
  }
}
