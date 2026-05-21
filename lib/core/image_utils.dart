import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

const _maxInputBytes = 5 * 1024 * 1024; // 5 MB – reject above this
const _targetBytes = 1 * 1024 * 1024;   // 1 MB – compress to below this

/// Compresses [bytes] to below 1 MB by stepping down JPEG quality.
///
/// Returns the compressed bytes on success.
/// Returns null if the input exceeds 5 MB (caller should show an error).
Future<Uint8List?> compressImageUnder1MB(Uint8List bytes) async {
  if (bytes.length > _maxInputBytes) return null;
  if (bytes.length <= _targetBytes) return bytes;

  // Try progressively lower quality before touching dimensions.
  for (final quality in [75, 55, 35]) {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
    );
    if (result.length <= _targetBytes) return result;
  }

  // Last resort: also cap the longer edge at 1200 px.
  return await FlutterImageCompress.compressWithList(
    bytes,
    minWidth: 1200,
    minHeight: 1200,
    quality: 30,
  );
}
