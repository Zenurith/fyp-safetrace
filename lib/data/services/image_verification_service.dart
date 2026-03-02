import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/image_verification_result.dart';

class ImageVerificationService {
  GenerativeModel? _model;

  ImageVerificationService({String? apiKey}) {
    if (apiKey != null && apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
      );
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
      return ImageVerificationResult.unavailable();
    }

    final prompt = '''
You are an image verification system for a safety incident reporting app called SafeTrace.

Analyze this image and determine if it matches the reported incident:
- Category: $categoryName
- Description: ${description.isEmpty ? 'No description provided' : description}

Respond ONLY with valid JSON in this exact format (no markdown, no code blocks):
{
  "isValid": true,
  "confidenceScore": 0.85,
  "explanation": "Brief explanation of your assessment",
  "detectedElements": ["list", "of", "relevant", "objects", "detected"],
  "concerns": ["any", "issues", "or", "red", "flags"]
}

Category Guidelines:
- Crime: Look for evidence of theft, vandalism, assault, break-ins, graffiti, property damage
- Infrastructure: Look for potholes, broken roads, damaged buildings, faulty streetlights, construction hazards, water pipe issues
- Suspicious: Look for suspicious persons, abandoned packages, unusual vehicles, trespassing
- Traffic: Look for accidents, road blockages, traffic congestion, vehicle collisions, road hazards
- Environmental: Look for flooding, pollution, illegal dumping, fallen trees, fire/smoke, hazardous materials
- Emergency: Look for medical emergencies, fires, accidents requiring immediate response

Rules:
- isValid = true if the image reasonably matches the category and description
- Consider partial matches valid (e.g., aftermath of an incident, preparations, related activity)
- Flag obvious mismatches: stock photos, screenshots, memes, selfies, completely unrelated images
- Be lenient with image quality issues (blurry, dark, poor lighting)
- confidenceScore: 0.7+ means confident match, 0.4-0.7 is uncertain, below 0.4 is likely mismatch
- If the image shows any reasonable evidence related to the category, lean toward valid
''';

    try {
      final content = Content.multi([
        TextPart(prompt),
        DataPart(mimeType ?? 'image/jpeg', imageBytes),
      ]);

      final response = await _model!.generateContent([content]);
      final text = response.text ?? '';

      // Parse JSON response - try to extract JSON from the response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        try {
          final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          return ImageVerificationResult.fromJson(json);
        } catch (parseError) {
          // JSON parsing failed, return unavailable
          return ImageVerificationResult(
            isValid: true,
            confidenceScore: 0.5,
            explanation: 'Could not parse verification response',
          );
        }
      }

      return ImageVerificationResult.unavailable();
    } catch (e) {
      // API error - don't block legitimate reports
      return ImageVerificationResult(
        isValid: true,
        confidenceScore: 0.5,
        explanation: 'Verification service error: ${e.toString().substring(0, 50)}...',
      );
    }
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

    // Verify only the first image (primary evidence)
    // This reduces API costs while still providing verification
    return verifyImage(
      imageBytes: imageBytesList.first,
      categoryName: categoryName,
      description: description,
    );
  }
}
