// This file is web-only — uses dart:html for file picking.
// Do not run on mobile/desktop targets.
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/config.dart';
import '../../core/theme.dart';

class KMLUploadScreen extends StatefulWidget {
  const KMLUploadScreen({super.key});

  @override
  State<KMLUploadScreen> createState() => _KMLUploadScreenState();
}

class _KMLUploadScreenState extends State<KMLUploadScreen> {
  bool _isUploading = false;
  String? _lastUploaded;

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
        final ref = FirebaseStorage.instance
            .ref('${AppConfig.kmlUploadPath}/${file.name}');
        await ref.putData(data);

        if (mounted) {
          setState(() {
            _isUploading = false;
            _lastUploaded = file.name;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploaded ${file.name}'),
              backgroundColor: AppTheme.trackingGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload KML')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _isUploading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Uploading...'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            width: 2),
                        borderRadius: BorderRadius.circular(16),
                        color: AppTheme.primary.withValues(alpha: 0.04),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.upload_file,
                              size: 52,
                              color: AppTheme.primary.withValues(alpha: 0.7)),
                          const SizedBox(height: 12),
                          const Text('Select a .kml file to upload',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.textSecondary)),
                          if (_lastUploaded != null) ...[
                            const SizedBox(height: 8),
                            Text('Last: $_lastUploaded',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickAndUploadFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Choose File'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
