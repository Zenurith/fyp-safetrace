import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/audit_log_model.dart';
import '../../../data/models/system_config_model.dart';
import '../../../data/repositories/audit_log_repository.dart';
import '../../../utils/app_theme.dart';
import '../../providers/system_config_provider.dart';
import '../../providers/user_provider.dart';

class SystemConfigPage extends StatefulWidget {
  const SystemConfigPage({super.key});

  @override
  State<SystemConfigPage> createState() => _SystemConfigPageState();
}

class _SystemConfigPageState extends State<SystemConfigPage> {
  late final TextEditingController _pointsForReportCtrl;
  late final TextEditingController _pointsForUpvoteCtrl;
  late final TextEditingController _pointsForDownvoteCtrl;
  late final TextEditingController _trustedThresholdCtrl;
  late final TextEditingController _alertRadiusCtrl;
  late final TextEditingController _maxAlertsCtrl;

  bool _reputationSaving = false;
  bool _notificationSaving = false;

  late final SystemConfigProvider _configProvider;

  @override
  void initState() {
    super.initState();
    _configProvider = context.read<SystemConfigProvider>();
    final config = _configProvider.config;

    _pointsForReportCtrl =
        TextEditingController(text: '${config.pointsForReport}');
    _pointsForUpvoteCtrl =
        TextEditingController(text: '${config.pointsForUpvoteReceived}');
    _pointsForDownvoteCtrl =
        TextEditingController(text: '${config.pointsForDownvoteReceived}');
    _trustedThresholdCtrl =
        TextEditingController(text: '${config.trustedThreshold}');
    _alertRadiusCtrl =
        TextEditingController(text: '${config.defaultAlertRadiusKm}');
    _maxAlertsCtrl =
        TextEditingController(text: '${config.maxAlertsPerHour}');
  }

  @override
  void dispose() {
    _pointsForReportCtrl.dispose();
    _pointsForUpvoteCtrl.dispose();
    _pointsForDownvoteCtrl.dispose();
    _trustedThresholdCtrl.dispose();
    _alertRadiusCtrl.dispose();
    _maxAlertsCtrl.dispose();
    super.dispose();
  }

  String get _adminName =>
      context.read<UserProvider>().currentUser?.name ?? 'admin';

  String get _adminId =>
      context.read<UserProvider>().currentUser?.id ?? '';

  void _logConfigChange(String action, String detail) {
    AuditLogRepository().create(AuditLogModel(
      id: '',
      adminId: _adminId,
      adminName: _adminName,
      action: action,
      targetType: 'config',
      targetId: 'app_settings',
      detail: detail,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _saveReputation() async {
    final pointsForReport = int.tryParse(_pointsForReportCtrl.text);
    final pointsForUpvote = int.tryParse(_pointsForUpvoteCtrl.text);
    final pointsForDownvote = int.tryParse(_pointsForDownvoteCtrl.text);
    final trustedThreshold = int.tryParse(_trustedThresholdCtrl.text);

    if (pointsForReport == null ||
        pointsForUpvote == null ||
        pointsForDownvote == null ||
        trustedThreshold == null) {
      _showSnack('Please enter valid integer values.');
      return;
    }
    if (trustedThreshold < 1) {
      _showSnack('Trusted threshold must be at least 1.');
      return;
    }

    setState(() => _reputationSaving = true);
    final ok = await _configProvider.updateFields(
      {
        'pointsForReport': pointsForReport,
        'pointsForUpvoteReceived': pointsForUpvote,
        'pointsForDownvoteReceived': pointsForDownvote,
        'trustedThreshold': trustedThreshold,
      },
      _adminName,
    );
    setState(() => _reputationSaving = false);
    if (ok) {
      _logConfigChange('Updated reputation settings',
          'Report:+$pointsForReport, Upvote:+$pointsForUpvote, Downvote:$pointsForDownvote, Trusted≥$trustedThreshold');
    }
    _showSnack(
        ok ? 'Reputation settings saved.' : 'Failed to save. Try again.');
  }

  Future<void> _saveNotifications() async {
    final radius = double.tryParse(_alertRadiusCtrl.text);
    final maxAlerts = int.tryParse(_maxAlertsCtrl.text);

    if (radius == null || maxAlerts == null || radius <= 0 || maxAlerts < 1) {
      _showSnack('Please enter valid positive values.');
      return;
    }

    setState(() => _notificationSaving = true);
    final ok = await _configProvider.updateFields(
      {
        'defaultAlertRadiusKm': radius,
        'maxAlertsPerHour': maxAlerts,
      },
      _adminName,
    );
    setState(() => _notificationSaving = false);
    if (ok) _logConfigChange('Updated notification defaults', 'Radius: ${radius}km, Max/hr: $maxAlerts');
    _showSnack(ok
        ? 'Notification defaults saved.'
        : 'Failed to save. Try again.');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: const TextStyle(fontFamily: AppTheme.fontFamily)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SystemConfigProvider>().config;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReputationSection(),
              const SizedBox(height: 20),
              _buildNotificationsSection(),
              const SizedBox(height: 16),
              _buildAuditFooter(config),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReputationSection() {
    return _ConfigSection(
      title: 'Reputation System',
      description:
          'Point values awarded for user actions. Changes apply to all future reputation calculations.',
      children: [
        _NumberField(
          label: 'Points for submitting a report',
          controller: _pointsForReportCtrl,
          hint: '10',
          allowNegative: false,
        ),
        _NumberField(
          label: 'Points per upvote received',
          controller: _pointsForUpvoteCtrl,
          hint: '5',
          allowNegative: false,
        ),
        _NumberField(
          label: 'Points per downvote received',
          controller: _pointsForDownvoteCtrl,
          hint: '-3',
          allowNegative: true,
          helperText: 'Enter a negative value to deduct points',
        ),
        _NumberField(
          label: 'Trusted user threshold (points)',
          controller: _trustedThresholdCtrl,
          hint: '500',
          allowNegative: false,
          helperText: 'Users above this score earn trusted status',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: _SaveButton(
            label: 'Save Reputation Settings',
            saving: _reputationSaving,
            onPressed: _saveReputation,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return _ConfigSection(
      title: 'Notification Defaults',
      description:
          'Default values used when a user has not customised their alert settings.',
      children: [
        _NumberField(
          label: 'Default alert radius (km)',
          controller: _alertRadiusCtrl,
          hint: '5',
          allowNegative: false,
          isDecimal: true,
        ),
        _NumberField(
          label: 'Max alerts per hour',
          controller: _maxAlertsCtrl,
          hint: '10',
          allowNegative: false,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: _SaveButton(
            label: 'Save Notification Defaults',
            saving: _notificationSaving,
            onPressed: _saveNotifications,
          ),
        ),
      ],
    );
  }

  Widget _buildAuditFooter(SystemConfigModel config) {
    if (config.updatedAt == null) return const SizedBox.shrink();
    final formatted =
        DateFormat('MMM d, yyyy  HH:mm').format(config.updatedAt!.toLocal());
    return Text(
      'Last updated $formatted by ${config.updatedBy ?? 'unknown'}',
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 12,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

// ─── Section container ────────────────────────────────────────────────────────

class _ConfigSection extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const _ConfigSection({
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.headingSmall),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

// ─── Number input row ─────────────────────────────────────────────────────────

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool allowNegative;
  final bool isDecimal;
  final String? helperText;

  const _NumberField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.allowNegative,
    this.isDecimal = false,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    color: AppTheme.primaryDark,
                  ),
                ),
                if (helperText != null)
                  Text(
                    helperText!,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 110,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(
                signed: allowNegative,
                decimal: isDecimal,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(isDecimal
                      ? r'[\d.]*'
                      : (allowNegative ? r'-?\d*' : r'\d*')),
                ),
              ],
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
              ),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Save button ──────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback onPressed;

  const _SaveButton({
    required this.label,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: saving ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: saving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : Text(
              label,
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily, fontSize: 13),
            ),
    );
  }
}
