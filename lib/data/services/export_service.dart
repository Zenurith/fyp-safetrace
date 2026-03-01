import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/incident_model.dart';

class ExportService {
  static Future<String?> exportToCsv(List<IncidentModel> incidents) async {
    if (incidents.isEmpty) return null;

    final List<List<dynamic>> rows = [
      // Header row
      [
        'ID',
        'Title',
        'Category',
        'Severity',
        'Status',
        'Address',
        'Latitude',
        'Longitude',
        'Description',
        'Reported At',
        'Reporter ID',
        'Is Anonymous',
        'Upvotes',
        'Downvotes',
        'Vote Score',
      ],
    ];

    // Data rows
    for (final incident in incidents) {
      rows.add([
        incident.id,
        incident.title,
        incident.categoryLabel,
        incident.severityLabel,
        incident.statusLabel,
        incident.address,
        incident.latitude,
        incident.longitude,
        incident.description.replaceAll('\n', ' '),
        DateFormat('yyyy-MM-dd HH:mm').format(incident.reportedAt),
        incident.reporterId,
        incident.isAnonymous ? 'Yes' : 'No',
        incident.upvotes,
        incident.downvotes,
        incident.voteScore,
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/incidents_$timestamp.csv');
      await file.writeAsString(csv);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> exportToPdf(List<IncidentModel> incidents) async {
    if (incidents.isEmpty) return null;

    final pdf = pw.Document();

    // Group incidents into pages (15 per page)
    const incidentsPerPage = 15;
    final pageCount = (incidents.length / incidentsPerPage).ceil();

    for (int page = 0; page < pageCount; page++) {
      final startIndex = page * incidentsPerPage;
      final endIndex = (startIndex + incidentsPerPage).clamp(0, incidents.length);
      final pageIncidents = incidents.sublist(startIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                if (page == 0) ...[
                  pw.Text(
                    'SafeTrace Incident Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated on ${DateFormat('MMMM d, y at h:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Total incidents: ${incidents.length}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 16),
                ],

                // Incidents list
                ...pageIncidents.map((incident) => _buildIncidentRow(incident)),

                // Page number
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Page ${page + 1} of $pageCount',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/incidents_$timestamp.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      return null;
    }
  }

  static pw.Widget _buildIncidentRow(IncidentModel incident) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  incident.title,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusBadge(incident.status),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              _buildCategoryBadge(incident.categoryLabel),
              pw.SizedBox(width: 8),
              _buildSeverityBadge(incident.severityLabel),
              pw.Spacer(),
              pw.Text(
                DateFormat('MMM d, y').format(incident.reportedAt),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            incident.address,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatusBadge(IncidentStatus status) {
    PdfColor color;
    switch (status) {
      case IncidentStatus.pending:
        color = PdfColors.orange;
        break;
      case IncidentStatus.underReview:
        color = PdfColors.blue;
        break;
      case IncidentStatus.verified:
        color = PdfColors.green;
        break;
      case IncidentStatus.resolved:
        color = PdfColors.teal;
        break;
      case IncidentStatus.dismissed:
        color = PdfColors.grey;
        break;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: color,
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

  static Future<void> shareFile(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }
}
