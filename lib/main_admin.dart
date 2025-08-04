import 'package:flutter/material.dart';
import 'admin/dashboard.dart';

void main() {
  runApp(AdminPanelApp());
}

class AdminPanelApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Panel',
      debugShowCheckedModeBanner: false,
      home: AdminDashboard(),
    );
  }
}
