class ImageVerificationResult {
  final bool isValid;
  final double confidenceScore;
  final String explanation;
  final List<String> detectedElements;
  final List<String> concerns;

  ImageVerificationResult({
    required this.isValid,
    required this.confidenceScore,
    required this.explanation,
    this.detectedElements = const [],
    this.concerns = const [],
  });

  factory ImageVerificationResult.fromJson(Map<String, dynamic> json) {
    // Handle various response formats robustly
    bool isValid = false; // Default to FALSE for safety
    if (json['isValid'] is bool) {
      isValid = json['isValid'];
    } else if (json['isValid'] is String) {
      isValid = json['isValid'].toString().toLowerCase() == 'true';
    }

    double confidenceScore = 0.3; // Default to low confidence
    if (json['confidenceScore'] is num) {
      confidenceScore = (json['confidenceScore'] as num).toDouble();
    } else if (json['confidenceScore'] is String) {
      confidenceScore = double.tryParse(json['confidenceScore']) ?? 0.3;
    } else if (json['confidence'] is num) {
      // Alternative field name
      confidenceScore = (json['confidence'] as num).toDouble();
    }

    // Clamp confidence score to valid range
    confidenceScore = confidenceScore.clamp(0.0, 1.0);

    String explanation = 'Unable to verify';
    if (json['explanation'] is String && json['explanation'].isNotEmpty) {
      explanation = json['explanation'];
    } else if (json['message'] is String && json['message'].isNotEmpty) {
      explanation = json['message'];
    }

    List<String> detectedElements = [];
    if (json['detectedElements'] is List) {
      detectedElements = (json['detectedElements'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['detected_elements'] is List) {
      detectedElements = (json['detected_elements'] as List)
          .map((e) => e.toString())
          .toList();
    }

    List<String> concerns = [];
    if (json['concerns'] is List) {
      concerns = (json['concerns'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return ImageVerificationResult(
      isValid: isValid,
      confidenceScore: confidenceScore,
      explanation: explanation,
      detectedElements: detectedElements,
      concerns: concerns,
    );
  }

  /// Returns a result for when the verification service is unavailable
  /// Sets isValid to FALSE so it goes to manual review
  factory ImageVerificationResult.serviceUnavailable() {
    return ImageVerificationResult(
      isValid: false,
      confidenceScore: 0.0,
      explanation: 'Verification service unavailable. Submitted for manual review.',
      concerns: ['Service unavailable - requires manual verification'],
    );
  }

  /// Returns a result for when verification fails (API error, parsing error, etc.)
  /// Sets isValid to FALSE so it goes to manual review
  factory ImageVerificationResult.failed(String reason) {
    return ImageVerificationResult(
      isValid: false,
      confidenceScore: 0.0,
      explanation: reason,
      concerns: ['Verification failed - requires manual review'],
    );
  }

  /// Returns a result for when verification is skipped (no images provided)
  /// This is the ONLY case where we default to valid (no image to verify)
  factory ImageVerificationResult.skipped() {
    return ImageVerificationResult(
      isValid: true,
      confidenceScore: 1.0,
      explanation: 'No images to verify',
    );
  }

  /// Legacy factory - maps to failed for backwards compatibility
  factory ImageVerificationResult.unavailable() {
    return ImageVerificationResult.serviceUnavailable();
  }

  /// Legacy factory - maps to failed for backwards compatibility
  factory ImageVerificationResult.error(String message) {
    return ImageVerificationResult.failed(message);
  }

  bool get isHighConfidence => confidenceScore >= 0.7;
  bool get isLowConfidence => confidenceScore < 0.4;
  bool get needsReview => !isValid || confidenceScore < 0.5;

  String get confidenceLabel {
    if (confidenceScore >= 0.7) return 'High';
    if (confidenceScore >= 0.4) return 'Medium';
    return 'Low';
  }

  /// Formatted confidence as percentage
  String get confidencePercentage => '${(confidenceScore * 100).toInt()}%';

  /// Human-readable status for UI display
  String get statusLabel {
    if (isValid && isHighConfidence) return 'Verified';
    if (isValid) return 'Likely Valid';
    if (confidenceScore >= 0.3) return 'Needs Review';
    return 'Flagged';
  }

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'confidenceScore': confidenceScore,
      'explanation': explanation,
      'detectedElements': detectedElements,
      'concerns': concerns,
    };
  }

  @override
  String toString() {
    return 'ImageVerificationResult(isValid: $isValid, score: $confidencePercentage, explanation: $explanation)';
  }
}
