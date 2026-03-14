import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/image_verification_result.dart';

/// Image Verification Service using Google Gemini API
/// Verifies that uploaded images match the reported incident category
class ImageVerificationService {
  final String? _apiKey;
  GenerativeModel? _model;

  /// Category guidelines for verification
  static const Map<String, List<String>> _categoryGuidelines = {
    'Crime': [
      'theft in progress or aftermath',
      'vandalism or property damage',
      'graffiti',
      'assault or physical altercation',
      'break-in evidence',
      'suspicious criminal activity',
    ],
    'Infrastructure': [
      'potholes or road damage',
      'broken sidewalks or pavements',
      'damaged street lights',
      'fallen trees blocking paths',
      'damaged public property',
      'construction hazards',
      'broken bridges or railings',
    ],
    'Suspicious': [
      'suspicious person loitering',
      'abandoned packages or bags',
      'unusual activity',
      'unattended vehicles in odd locations',
      'people photographing secure areas',
    ],
    'Traffic': [
      'car accidents or collisions',
      'traffic jams or congestion',
      'broken traffic lights',
      'road blockages',
      'illegally parked vehicles',
      'dangerous driving evidence',
    ],
    'Environmental': [
      'flooding or water damage',
      'pollution or dumping',
      'fallen trees',
      'fires or smoke',
      'hazardous waste',
      'dead animals',
      'overflowing drains',
    ],
    'Emergency': [
      'medical emergencies',
      'fires',
      'accidents requiring immediate help',
      'natural disasters',
      'structural collapse',
      'people in distress',
    ],
  };

  ImageVerificationService({String? apiKey}) : _apiKey = apiKey {
    final key = _apiKey;
    if (key != null && key.isNotEmpty) {
      try {
        _model = GenerativeModel(
          model: 'gemini-3.1-flash-lite-preview',
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: 0.1, // Lower temperature for more consistent results
            maxOutputTokens: 1024,
          ),
        );
        if (kDebugMode) debugPrint('ImageVerificationService: Initialized with Gemini model');
      } catch (e) {
        if (kDebugMode) debugPrint('ImageVerificationService: Failed to initialize model: $e');
        _model = null;
      }
    } else {
      if (kDebugMode) debugPrint('ImageVerificationService: No API key provided');
    }
  }

  bool get isConfigured => _model != null;

  /// Verifies if an image matches the reported incident category and description
  Future<ImageVerificationResult> verifyImage({
    required Uint8List imageBytes,
    required String categoryName,
    required String description,
    String? mimeType,
  }) async {
    if (_model == null) {
      if (kDebugMode) debugPrint('ImageVerificationService: Model not configured, skipping verification');
      return ImageVerificationResult.serviceUnavailable();
    }

    if (kDebugMode) {
      debugPrint('ImageVerificationService: Starting verification');
      debugPrint('  Category: $categoryName');
      debugPrint('  Description: ${description.isNotEmpty ? description : "(empty)"}');
      debugPrint('  Image size: ${imageBytes.length} bytes');
    }

    try {
      final guidelines = _categoryGuidelines[categoryName] ?? [];
      final guidelinesText = guidelines.isNotEmpty
          ? 'Expected elements for "$categoryName" incidents:\n${guidelines.map((g) => '- $g').join('\n')}'
          : 'Category: $categoryName';

      final prompt = '''You are a STRICT image verification system for SafeTrace, a community safety reporting app.

TASK: Determine if this image is ACTUALLY related to the reported incident category.

REPORTED CATEGORY: $categoryName
USER DESCRIPTION: ${description.isNotEmpty ? description : "No description provided"}

$guidelinesText

IMPORTANT RULES:
1. You must be STRICT - only approve images that CLEARLY show something related to the category
2. Random photos, selfies, memes, screenshots, or unrelated content = isValid: FALSE
3. If the image shows a completely different type of incident = isValid: FALSE
4. If you cannot clearly identify relevant elements = isValid: FALSE
5. When in doubt, set isValid: FALSE (better to flag for human review)

Respond with ONLY this JSON (no markdown, no explanation outside JSON):
{
  "isValid": false,
  "confidenceScore": 0.0,
  "explanation": "Why this image does or does not match the category",
  "detectedElements": ["what you see in the image"],
  "concerns": ["any red flags or issues"]
}

SCORING GUIDE:
- isValid: true + score 0.8-1.0 = Image CLEARLY shows a $categoryName incident
- isValid: true + score 0.5-0.79 = Image PROBABLY shows a $categoryName incident
- isValid: false + score 0.3-0.49 = Image MIGHT be related but unclear
- isValid: false + score 0.0-0.29 = Image is NOT related to $categoryName

DEFAULT TO isValid: false IF UNCERTAIN. Return ONLY the JSON object.''';

      final imagePart = DataPart(
        mimeType ?? 'image/jpeg',
        imageBytes,
      );

      final response = await _model!.generateContent([
        Content.multi([
          TextPart(prompt),
          imagePart,
        ]),
      ]);

      final responseText = response.text;
      if (kDebugMode) debugPrint('ImageVerificationService: Raw response: $responseText');

      if (responseText == null || responseText.isEmpty) {
        if (kDebugMode) debugPrint('ImageVerificationService: Empty response from API');
        return ImageVerificationResult.failed('Empty response from verification service');
      }

      // Parse the JSON response
      final result = _parseResponse(responseText);
      if (kDebugMode) debugPrint('ImageVerificationService: Parsed result - isValid: ${result.isValid}, score: ${result.confidenceScore}');
      return result;
    } on GenerativeAIException catch (e) {
      if (kDebugMode) debugPrint('ImageVerificationService: Gemini API error: ${e.message}');
      return ImageVerificationResult.failed('Verification service error: ${e.message}');
    } catch (e) {
      if (kDebugMode) debugPrint('ImageVerificationService: Unexpected error: $e');
      return ImageVerificationResult.failed('Verification failed: $e');
    }
  }

  /// Parse the JSON response from Gemini, handling various formats
  ImageVerificationResult _parseResponse(String responseText) {
    try {
      // Clean up the response - remove markdown code blocks if present
      String cleanedResponse = responseText.trim();

      // Remove ```json and ``` markers if present
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.substring(7);
      } else if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse.substring(3);
      }

      if (cleanedResponse.endsWith('```')) {
        cleanedResponse = cleanedResponse.substring(0, cleanedResponse.length - 3);
      }

      cleanedResponse = cleanedResponse.trim();

      // Try to find JSON object in the response
      final jsonStart = cleanedResponse.indexOf('{');
      final jsonEnd = cleanedResponse.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
        if (kDebugMode) debugPrint('ImageVerificationService: Could not find JSON in response');
        return _createFallbackResult(responseText);
      }

      final jsonString = cleanedResponse.substring(jsonStart, jsonEnd + 1);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      return ImageVerificationResult.fromJson(json);
    } catch (e) {
      if (kDebugMode) debugPrint('ImageVerificationService: JSON parse error: $e');
      return _createFallbackResult(responseText);
    }
  }

  /// Create a fallback result when JSON parsing fails by analyzing the text
  ImageVerificationResult _createFallbackResult(String responseText) {
    final lowerText = responseText.toLowerCase();

    // Look for clear indicators in the response
    // Default to INVALID unless there's clear evidence of a match
    bool isValid = false;
    double score = 0.3;
    String explanation = 'Could not parse verification response. Flagged for manual review.';

    // Only set valid if there's strong positive language
    if ((lowerText.contains('"isvalid": true') || lowerText.contains('"isvalid":true')) &&
        (lowerText.contains('clearly shows') ||
         lowerText.contains('definitely') ||
         lowerText.contains('confirmed'))) {
      isValid = true;
      score = 0.6;
      explanation = 'Verification indicates match. Review recommended.';
    } else if (lowerText.contains('not valid') ||
               lowerText.contains('does not match') ||
               lowerText.contains('unrelated') ||
               lowerText.contains('no match') ||
               lowerText.contains('"isvalid": false') ||
               lowerText.contains('"isvalid":false')) {
      isValid = false;
      score = 0.2;
      explanation = 'Image does not appear to match the reported category.';
    }

    return ImageVerificationResult(
      isValid: isValid,
      confidenceScore: score,
      explanation: explanation,
      concerns: ['Automated parsing failed - manual review recommended'],
    );
  }

  /// Verifies multiple images and returns the combined result
  /// Only verifies the first image to save API costs
  Future<ImageVerificationResult> verifyMultipleImages({
    required List<Uint8List> imageBytesList,
    required String categoryName,
    required String description,
  }) async {
    if (imageBytesList.isEmpty) {
      return ImageVerificationResult.skipped();
    }

    // Only verify the first image for cost efficiency
    return verifyImage(
      imageBytes: imageBytesList.first,
      categoryName: categoryName,
      description: description,
    );
  }
}
