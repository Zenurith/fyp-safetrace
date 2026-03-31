import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/incident_model.dart';
import 'export_file_saver.dart';

class ExportService {
  static final _dateFormatter = DateFormat('MMM d, y');
  static final _datetimeFormatter = DateFormat('MMM d, y h:mm a');

  // ─── PDF Export ───────────────────────────────────────────────────────────

  static Future<String?> exportToPdf(List<IncidentModel> incidents) async {
    if (incidents.isEmpty) return null;

    final pdf = pw.Document();
    final generatedAt = DateFormat("MMMM d, y 'at' h:mm a").format(DateTime.now());

    // Page 1: summary
    pdf.addPage(_buildSummaryPage(incidents, generatedAt));

    // Remaining pages: incident list (8 per page — rows are taller now)
    const incidentsPerPage = 8;
    final pageCount = (incidents.length / incidentsPerPage).ceil();

    for (int page = 0; page < pageCount; page++) {
      final start = page * incidentsPerPage;
      final end = (start + incidentsPerPage).clamp(0, incidents.length);
      final pageIncidents = incidents.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Incident Details',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Page ${page + 1} of $pageCount',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              ...pageIncidents.map((i) => _buildIncidentRow(i)),
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'SafeTrace  •  Generated $generatedAt',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return saveExportFile('incidents_$ts.pdf', await pdf.save());
  }

  static pw.Page _buildSummaryPage(List<IncidentModel> incidents, String generatedAt) {
    final statusCounts = {
      for (final s in IncidentStatus.values)
        s: incidents.where((i) => i.status == s).length,
    };
    final severityCounts = {
      for (final s in SeverityLevel.values)
        s: incidents.where((i) => i.severity == s).length,
    };
    final categoryCounts = <String, int>{};
    for (final i in incidents) {
      categoryCounts[i.categoryLabel] = (categoryCounts[i.categoryLabel] ?? 0) + 1;
    }
    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SafeTrace Incident Report',
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated $generatedAt',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 24),

          // Key stats row
          pw.Row(
            children: [
              _statBox('Total Incidents', '${incidents.length}', PdfColors.grey800),
              pw.SizedBox(width: 12),
              _statBox('Active', '${incidents.where((i) => i.isActive).length}', PdfColors.blue700),
              pw.SizedBox(width: 12),
              _statBox('Resolved', '${statusCounts[IncidentStatus.resolved] ?? 0}', PdfColors.teal700),
              pw.SizedBox(width: 12),
              _statBox('Dismissed', '${statusCounts[IncidentStatus.dismissed] ?? 0}', PdfColors.grey600),
            ],
          ),
          pw.SizedBox(height: 24),

          // Two-column: status + severity breakdown
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _buildStatusBreakdown(statusCounts)),
              pw.SizedBox(width: 16),
              pw.Expanded(child: _buildSeverityBreakdown(severityCounts)),
            ],
          ),
          pw.SizedBox(height: 16),

          // Full-width: category breakdown
          _buildCategoryBreakdown(sortedCategories, incidents.length),
        ],
      ),
    );
  }

  static pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: color),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildStatusBreakdown(Map<IncidentStatus, int> counts) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('By Status', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey200),
          pw.SizedBox(height: 4),
          ...IncidentStatus.values.map((s) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 8, height: 8,
                  decoration: pw.BoxDecoration(
                    color: _statusPdfColor(s),
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(_getStatusLabel(s), style: const pw.TextStyle(fontSize: 10)),
                ),
                pw.Text(
                  '${counts[s] ?? 0}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  static pw.Widget _buildSeverityBreakdown(Map<SeverityLevel, int> counts) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('By Severity', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey200),
          pw.SizedBox(height: 4),
          ...SeverityLevel.values.map((s) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 8, height: 8,
                  decoration: pw.BoxDecoration(
                    color: _severityPdfColor(s),
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    s.name[0].toUpperCase() + s.name.substring(1),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Text(
                  '${counts[s] ?? 0}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  static pw.Widget _buildCategoryBreakdown(
    List<MapEntry<String, int>> entries,
    int total,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('By Category', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey200),
          pw.SizedBox(height: 4),
          ...entries.map((e) {
            final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(1) : '0.0';
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(e.key, style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.Text(
                    '${e.value}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '($pct%)',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildIncidentRow(IncidentModel incident) {
    final description = incident.description.trim();
    final truncatedDesc =
        description.length > 120 ? '${description.substring(0, 120)}…' : description;

    final hasIncidentTime = incident.incidentTime != null &&
        incident.incidentTime!.difference(incident.reportedAt).abs() >
            const Duration(minutes: 5);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Title + status
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  incident.title,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
              ),
              _buildStatusBadge(incident.status),
            ],
          ),
          pw.SizedBox(height: 4),

          // Category + severity + reported date
          pw.Row(
            children: [
              _buildCategoryBadge(incident.categoryLabel),
              pw.SizedBox(width: 6),
              _buildSeverityBadge(incident.severityLabel),
              pw.Spacer(),
              pw.Text(
                _dateFormatter.format(incident.reportedAt),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),

          // Address
          if (incident.address.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              incident.address,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              maxLines: 1,
            ),
          ],

          // Description
          if (truncatedDesc.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              truncatedDesc,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
              maxLines: 2,
            ),
          ],

          // Votes + confirmations + incident time
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              pw.Text(
                '▲ ${incident.upvotes}  ▼ ${incident.downvotes}  ·  ${incident.confirmations} confirmations',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              if (hasIncidentTime) ...[
                pw.Spacer(),
                pw.Text(
                  'Occurred: ${_dateFormatter.format(incident.incidentTime!)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── CSV Export ───────────────────────────────────────────────────────────

  static Future<String?> exportToCsv(List<IncidentModel> incidents) async {
    if (incidents.isEmpty) return null;

    final buffer = StringBuffer();

    // Header row
    buffer.writeln([
      'ID', 'Title', 'Category', 'Severity', 'Status',
      'Description', 'Address', 'Latitude', 'Longitude',
      'Reported At', 'Incident Time',
      'Upvotes', 'Downvotes', 'Vote Score', 'Confirmations',
      'Anonymous', 'Image Verified',
    ].map(_csvEscape).join(','));

    // Data rows
    for (final i in incidents) {
      buffer.writeln([
        i.id,
        i.title,
        i.categoryLabel,
        i.severityLabel,
        i.statusLabel,
        i.description,
        i.address,
        i.latitude.toStringAsFixed(6),
        i.longitude.toStringAsFixed(6),
        _datetimeFormatter.format(i.reportedAt),
        i.incidentTime != null ? _datetimeFormatter.format(i.incidentTime!) : '',
        '${i.upvotes}',
        '${i.downvotes}',
        '${i.voteScore}',
        '${i.confirmations}',
        i.isAnonymous ? 'Yes' : 'No',
        i.imageVerified == null ? '' : (i.imageVerified! ? 'Yes' : 'No'),
      ].map(_csvEscape).join(','));
    }

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return saveExportFile('incidents_$ts.csv', buffer.toString().codeUnits);
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────

  static Future<void> shareFile(String filePath) async {
    await shareExportFile(filePath);
  }

  static pw.Widget _buildStatusBadge(IncidentStatus status) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: _statusPdfColor(status),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        _getStatusLabel(status),
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildCategoryBadge(String category) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        category,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
      ),
    );
  }

  static pw.Widget _buildSeverityBadge(String severity) {
    PdfColor color;
    switch (severity.toLowerCase()) {
      case 'high':
        color = PdfColors.red;
        break;
      case 'moderate':
        color = PdfColors.orange;
        break;
      default:
        color = PdfColors.green;
    }
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        severity,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
      ),
    );
  }

  static PdfColor _statusPdfColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return PdfColors.orange;
      case IncidentStatus.underReview:
        return PdfColors.blue;
      case IncidentStatus.verified:
        return PdfColors.green;
      case IncidentStatus.resolved:
        return PdfColors.teal;
      case IncidentStatus.dismissed:
        return PdfColors.grey;
    }
  }

  static PdfColor _severityPdfColor(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.high:
        return PdfColors.red;
      case SeverityLevel.moderate:
        return PdfColors.orange;
      case SeverityLevel.low:
        return PdfColors.green;
    }
  }

  static String _getStatusLabel(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Pending';
      case IncidentStatus.underReview:
        return 'Under Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.dismissed:
        return 'Dismissed';
    }
  }
}
