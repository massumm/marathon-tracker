import 'dart:html' as html; // Web-only
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class KMLUploadScreen extends StatefulWidget {
  const KMLUploadScreen({super.key});

  @override
  _KMLUploadScreenState createState() => _KMLUploadScreenState();
}

class _KMLUploadScreenState extends State<KMLUploadScreen> {
  bool _isUploading = false;

  void _pickAndUploadFile() async {
    final uploadInput = html.FileUploadInputElement()..accept = '.kml';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      if (file == null) return;

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      setState(() => _isUploading = true);

      try {
        await reader.onLoad.first;
        final data = Uint8List.fromList(reader.result as List<int>);

        final ref = FirebaseStorage.instance.ref('kml/${file.name}');
        await ref.putData(data);

        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Uploaded ${file.name}')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Upload failed: $e')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload KML")),
      body: Center(
        child: _isUploading
            ? const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Uploading..."),
          ],
        )
            : ElevatedButton(
          onPressed: _pickAndUploadFile,
          child: const Text("Upload KML File"),
        ),
      ),
    );
  }
}
