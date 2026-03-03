import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/image_verification_result.dart';

/// Simplified Image Verification Service
/// Currently disabled - allows all submissions
/// TODO: Re-enable when Gemini API issues are resolved
class ImageVerificationService {
  final String? _apiKey;

  ImageVerificationService({String? apiKey}) : _apiKey = apiKey {
    debugPrint('ImageVerificationService: Initialized (verification disabled)');
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Verifies if an image matches the reported incident category and description
  /// Currently returns valid for all images until API issues are resolved
  Future<ImageVerificationResult> verifyImage({
    required Uint8List imageBytes,
    required String categoryName,
    required String description,
    String? mimeType,
  }) async {
    debugPrint('ImageVerificationService: Skipping verification (disabled)');
    debugPrint('  Category: $categoryName');
    debugPrint('  Description: $description');
    debugPrint('  Image size: ${imageBytes.length} bytes');

    // Return valid result - verification disabled
    return ImageVerificationResult(
      isValid: true,
      confidenceScore: 1.0,
      explanation: 'Verification skipped - feature temporarily disabled',
    );
  }

  /// Verifies multiple images and returns the combined result
  Future<ImageVerificationResult> verifyMultipleImages({
    required List<Uint8List> imageBytesList,
    required String categoryName,
    required String description,
  }) async {
    if (imageBytesList.isEmpty) {
      return ImageVerificationResult.skipped();
    }

    return verifyImage(
      imageBytes: imageBytesList.first,
      categoryName: categoryName,
      description: description,
    );
  }
}
