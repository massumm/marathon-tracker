import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'mypage.dart';
import 'mapscreen.dart'; // your existing map screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MapApp());
}

class MapApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    MapScreen(),
    MyPageScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'MyPage',
          ),
        ],
      ),
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
                builder: (_) => MapScreen(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Dummy MyPage screen

