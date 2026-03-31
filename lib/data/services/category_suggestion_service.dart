import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/incident_model.dart';

/// Uses Gemini to suggest an [IncidentCategory] based on a report title.
class CategorySuggestionService {
  final GenerativeModel? _model;

  CategorySuggestionService({String? apiKey}) : _model = _initModel(apiKey);

  static GenerativeModel? _initModel(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return null;
    try {
      return GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 64,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CategorySuggestionService: init failed: $e');
      return null;
    }
  }

  bool get isConfigured => _model != null;

  /// Returns the best-matching [IncidentCategory] for the given [title],
  /// optionally using [description] as extra context.
  /// Returns null if the service is unconfigured, the input is too short,
  /// or Gemini cannot identify a clear match.
  Future<IncidentCategory?> suggestCategory(
    String title, {
    String description = '',
  }) async {
    if (_model == null || title.trim().length < 5) return null;

    final descPart = description.trim().isNotEmpty
        ? '\nDescription: ${description.trim()}'
        : '';

    final prompt = '''You are a classifier for a community safety app.
Given an incident title, return the best matching category.

Valid categories: crime, emergency, traffic, infrastructure, environmental, suspicious

Title: ${title.trim()}$descPart

Respond with ONLY this JSON (no markdown):
{"category": "<category_name>"}

If no category fits clearly, respond: {"category": "none"}''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return _parse(response.text);
    } on GenerativeAIException catch (e) {
      if (kDebugMode) debugPrint('CategorySuggestionService: API error: ${e.message}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('CategorySuggestionService: error: $e');
      return null;
    }
  }

  IncidentCategory? _parse(String? text) {
    if (text == null || text.isEmpty) return null;

    // Extract JSON object from response
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end > start) {
      try {
        final json = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
        final value = (json['category'] as String?)?.toLowerCase().trim();
        if (value == null || value == 'none') return null;
        return IncidentCategory.values.where((c) => c.name.toLowerCase() == value).firstOrNull;
      } catch (_) {}
    }

    // Fallback: scan response text for a category name
    final lower = text.toLowerCase();
    for (final cat in IncidentCategory.values) {
      if (lower.contains(cat.name.toLowerCase())) return cat;
    }
    return null;
  }
}
