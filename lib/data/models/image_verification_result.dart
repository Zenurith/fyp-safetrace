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
    return ImageVerificationResult(
      isValid: json['isValid'] ?? false,
      confidenceScore: (json['confidenceScore'] ?? 0.0).toDouble(),
      explanation: json['explanation'] ?? 'Unable to verify',
      detectedElements: List<String>.from(json['detectedElements'] ?? []),
      concerns: List<String>.from(json['concerns'] ?? []),
    );
  }

  /// Returns a result for when verification is unavailable
  factory ImageVerificationResult.unavailable() {
    return ImageVerificationResult(
      isValid: true,
      confidenceScore: 0.5,
      explanation: 'Verification unavailable',
    );
  }

  /// Returns a result for when verification is skipped (no images)
  factory ImageVerificationResult.skipped() {
    return ImageVerificationResult(
      isValid: true,
      confidenceScore: 1.0,
      explanation: 'No images to verify',
    );
  }

  bool get isHighConfidence => confidenceScore >= 0.7;
  bool get isLowConfidence => confidenceScore < 0.4;
  bool get needsReview => !isValid || confidenceScore < 0.5;

  String get confidenceLabel {
    if (confidenceScore >= 0.7) return 'High';
    if (confidenceScore >= 0.4) return 'Medium';
    return 'Low';
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
}
