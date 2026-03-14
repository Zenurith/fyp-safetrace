import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_constants.dart';
import '../data/models/incident_model.dart';
import 'app_theme.dart';

/// Generates a WhatsApp-ready message for the incident.
/// Calls Gemini to generate safety tips; falls back to a plain template on error.
Future<String> _generateWhatsAppMessage(IncidentModel incident) async {
  final mapsUrl =
      'https://maps.google.com/?q=${incident.latitude},${incident.longitude}';

  final fixedHeader = '🚨 ${incident.categoryLabel}: ${incident.title}\n'
      '📍 ${incident.address}\n'
      '🗺 $mapsUrl\n\n'
      '${incident.description}';

  const fallbackFooter = '\n\n— Reported via SafeTrace';

  try {
    final apiKey = AppConstants.geminiApiKey;
    if (apiKey.isEmpty) {
      return '$fixedHeader$fallbackFooter';
    }

    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 150,
      ),
    );

    final prompt = '''You are a safety advisor. Given this incident report, generate 2-3 concise, practical safety tips for people near the area.

Incident type: ${incident.categoryLabel}
Severity: ${incident.severityLabel}
Details: ${incident.description}

Rules:
- Tips must be specific to the incident type (e.g. flood vs crime vs fire)
- Each tip starts with a bullet point •
- Plain text only, no markdown, no asterisks
- Under 60 words total''';

    final response = await model.generateContent([Content.text(prompt)]);
    final tips = response.text?.trim();

    if (tips == null || tips.isEmpty) {
      return '$fixedHeader$fallbackFooter';
    }

    return '$fixedHeader\n\n💡 Safety Tips:\n$tips\n\n— Reported via SafeTrace';
  } catch (e) {
    if (kDebugMode) debugPrint('share_utils: Gemini error, using fallback: $e');
    return '$fixedHeader$fallbackFooter';
  }
}

/// Shows a bottom sheet with share options (WhatsApp and other apps).
Future<void> showShareOptions(
    BuildContext context, IncidentModel incident) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => _ShareOptionsSheet(incident: incident),
  );
}

class _ShareOptionsSheet extends StatefulWidget {
  final IncidentModel incident;
  const _ShareOptionsSheet({required this.incident});

  @override
  State<_ShareOptionsSheet> createState() => _ShareOptionsSheetState();
}

class _ShareOptionsSheetState extends State<_ShareOptionsSheet> {
  bool _loadingWhatsApp = false;

  Future<void> _shareToWhatsApp() async {
    setState(() => _loadingWhatsApp = true);
    try {
      final message = await _generateWhatsAppMessage(widget.incident);
      final encoded = Uri.encodeComponent(message);
      final uri = Uri.parse('whatsapp://send?text=$encoded');
      final canOpen = await canLaunchUrl(uri);
      if (!mounted) return;
      if (canOpen) {
        await launchUrl(uri);
        if (mounted) Navigator.pop(context);
      } else {
        // WhatsApp not installed — fall back to generic share
        await Share.share(message, subject: widget.incident.title);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('share_utils: WhatsApp launch error: $e');
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loadingWhatsApp = false);
    }
  }

  Future<void> _shareGeneric() async {
    Navigator.pop(context);
    await Share.share(
      '${widget.incident.categoryLabel}: ${widget.incident.title}\n'
      '${widget.incident.address}\n\n'
      '${widget.incident.description}',
      subject: widget.incident.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: _loadingWhatsApp
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: Text(
                'Share to WhatsApp',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Includes AI-generated safety tips',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              enabled: !_loadingWhatsApp,
              onTap: _shareToWhatsApp,
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined,
                  color: AppTheme.primaryDark),
              title: Text(
                'Share (other apps)',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: _shareGeneric,
            ),
          ],
        ),
      ),
    );
  }
}
