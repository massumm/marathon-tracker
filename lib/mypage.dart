import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'mypage_map_screen.dart'; // Make sure you have this file

class MyPageScreen extends StatefulWidget {
  @override
  _MypagescreenState createState() => _MypagescreenState();
}

class _MypagescreenState extends State<MyPageScreen> {
  Future<List<firebase_storage.Reference>> _fetchSavedRoutes() async {
    try {
      final listResult = await firebase_storage.FirebaseStorage.instance.ref('routes').listAll();

      // Only include .json files
      return listResult.items.where((item) => item.name.endsWith(".json")).toList();
    } catch (e) {
      print("Error listing routes: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Page")),
      body: FutureBuilder<List<firebase_storage.Reference>>(
        future: _fetchSavedRoutes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error loading files"));
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return Center(child: Text("No saved routes found."));
          }

          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final ref = files[index];
              return ListTile(
                title: Text(ref.name),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyPageMapScreen(filePath: ref.fullPath),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
