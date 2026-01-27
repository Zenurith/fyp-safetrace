// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/services/location_service.dart';
import '../../config/app_constants.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _descriptionController = TextEditingController();
  final _locationService = LocationService();

  IncidentCategory _selectedCategory = IncidentCategory.crime;
  SeverityLevel _selectedSeverity = SeverityLevel.high;
  bool _isAnonymous = true;
  double _latitude = AppConstants.defaultLat;
  double _longitude = AppConstants.defaultLng;
  String _address = 'Jalan Genting Klang, Setapak';
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null && mounted) {
        final addr = await _locationService.getAddressFromCoordinates(
            pos.latitude, pos.longitude);
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _address = addr;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLocation = false);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final provider = context.read<IncidentProvider>();
    provider.reportIncident(
      title: _selectedCategory.name,
      category: _selectedCategory,
      severity: _selectedSeverity,
      description: _descriptionController.text.trim().isEmpty
          ? 'No description provided.'
          : _descriptionController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      address: _address,
      isAnonymous: _isAnonymous,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Incident reported successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location section
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryRed,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color: AppTheme.primaryRed.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Automatically detected:',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            Text(
              _loadingLocation ? 'Detecting location...' : _address,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _detectLocation,
              icon: const Icon(Icons.location_on, size: 16),
              label: const Text('Adjust Location'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category section
            const Text(
              'Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: IncidentCategory.values.map((cat) {
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primaryRed
                            : Colors.grey[300]!,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _categoryIcon(cat),
                          size: 32,
                          color: selected
                              ? AppTheme.categoryColor(_categoryLabel(cat))
                              : Colors.grey[600],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _categoryLabel(cat),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected
                                ? AppTheme.primaryDark
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Severity section
            const Text(
              'Severity Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: SeverityLevel.values.map((level) {
                final selected = _selectedSeverity == level;
                final color = _severityColor(level);
                return GestureDetector(
                  onTap: () => setState(() => _selectedSeverity = level),
                  child: Column(
                    children: [
                      Container(
                        width: selected ? 56 : 44,
                        height: selected ? 56 : 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _severityLabel(level),
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: selected ? AppTheme.primaryDark : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Description
            const Text(
              'Description (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe what you observed...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Add Photo/Video
            Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.grey[600], size: 20),
                const SizedBox(width: 6),
                Text(
                  'Add Photo/Video',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Anonymous toggle
            Row(
              children: [
                const Text(
                  'Report anonymously',
                  style: TextStyle(fontSize: 15),
                ),
                const Spacer(),
                Switch(
                  value: _isAnonymous,
                  activeColor: AppTheme.primaryRed,
                  onChanged: (v) => setState(() => _isAnonymous = v),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Submit Report'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(IncidentCategory cat) {
    switch (cat) {
      case IncidentCategory.crime:
        return Icons.shield;
      case IncidentCategory.infrastructure:
        return Icons.construction;
      case IncidentCategory.suspicious:
        return Icons.visibility;
      case IncidentCategory.traffic:
        return Icons.directions_car;
      case IncidentCategory.environmental:
        return Icons.eco;
      case IncidentCategory.emergency:
        return Icons.local_hospital;
    }
  }

  String _categoryLabel(IncidentCategory cat) {
    switch (cat) {
      case IncidentCategory.crime:
        return 'Crime';
      case IncidentCategory.infrastructure:
        return 'Infrastructure';
      case IncidentCategory.suspicious:
        return 'Suspicious';
      case IncidentCategory.traffic:
        return 'Traffic';
      case IncidentCategory.environmental:
        return 'Environmental';
      case IncidentCategory.emergency:
        return 'Emergency';
    }
  }

  String _severityLabel(SeverityLevel level) {
    switch (level) {
      case SeverityLevel.low:
        return 'Low';
      case SeverityLevel.moderate:
        return 'Moderate';
      case SeverityLevel.high:
        return 'High';
    }
  }

  Color _severityColor(SeverityLevel level) {
    switch (level) {
      case SeverityLevel.low:
        return AppTheme.severityLow;
      case SeverityLevel.moderate:
        return AppTheme.severityModerate;
      case SeverityLevel.high:
        return AppTheme.severityHigh;
    }
  }
}
