import 'dart:typed_data';

/// Web stub — video thumbnail extraction is not supported on web.
/// Returns null so the caller falls back to manual review.
Future<Uint8List?> extractVideoFrame(String path) async => null;
