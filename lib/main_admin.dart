import 'package:flutter/material.dart';
import 'admin/dashboard.dart';

void main() {
  runApp(const AdminPanelApp());
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Admin Panel',
      debugShowCheckedModeBanner: false,
      home: AdminDashboard(),
    );
  }
}
