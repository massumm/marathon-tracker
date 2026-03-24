import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'mypage_map_screen.dart'; // Make sure you have this file

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  _MypagescreenState createState() => _MypagescreenState();
}

class _MypagescreenState extends State<MyPageScreen> {
  Future<List<firebase_storage.Reference>> _fetchSavedRoutes() async {
    try {
      final listResult = await firebase_storage.FirebaseStorage.instance.ref('routes').listAll();

      // Only include .json files
      var filteredList = listResult.items.where((item) => item.name.endsWith(".json")).toList();

      // Sort the list in descending order by name
      filteredList.sort((a, b) => b.name.compareTo(a.name));
      return filteredList;
    } catch (e) {
      print("Error listing routes: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Page")),
      body: FutureBuilder<List<firebase_storage.Reference>>(
        future: _fetchSavedRoutes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading files"));
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return const Center(child: Text("No saved routes found."));
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
