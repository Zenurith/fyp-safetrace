import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Extracts a single JPEG thumbnail frame from a local video file.
/// Returns null if extraction fails.
Future<Uint8List?> extractVideoFrame(String path) async {
  return VideoThumbnail.thumbnailData(
    video: path,
    imageFormat: ImageFormat.JPEG,
    maxWidth: 640,
    quality: 75,
  );
}
