import 'package:flutter/material.dart';


import 'kml_upload_screen.dart';

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin Dashboard")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome to Admin Panel", style: TextStyle(fontSize: 20)),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => KMLUploadScreen()));
              },
              child: Text("Manage Routes"),
            )
          ],
        ),
      ),
    );
  }
}
