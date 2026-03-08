import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/incident_model.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/incident_bottom_sheet.dart';
import '../widgets/user_avatar.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Function(int)? onSwitchTab;

  const ProfileScreen({super.key, this.onSwitchTab});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _reportsListening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reportsListening) {
      final userId = context.read<UserProvider>().currentUser?.id;
      if (userId != null) {
        context.read<IncidentProvider>().startListeningMyReports(userId);
        _reportsListening = true;
      }
    }
  }

  void _showIncidentDetail(BuildContext context, IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: IncidentBottomSheet(
            incidentId: incident.id,
            onViewOnMap: () {
              Navigator.pop(context);
              context.read<IncidentProvider>().selectIncident(incident);
              widget.onSwitchTab?.call(0);
            },
          ),
        ),
      ),
    );
  }

  void _shareIncident(IncidentModel incident) {
    Share.share(
      '${incident.categoryLabel}: ${incident.title}\n${incident.address}\n\n${incident.description}',
      subject: incident.title,
    );
  }

  void _confirmDelete(BuildContext context, IncidentModel incident) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text('Delete "${incident.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<IncidentProvider>().deleteIncident(incident.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report deleted'),
                    backgroundColor: AppTheme.primaryRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EditIncidentSheet(
        incident: incident,
        onSave: (updated) async {
          Navigator.pop(ctx);
          await context.read<IncidentProvider>().updateIncident(updated);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report updated'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        },
      ),
    );
  }

  void _showPhotoOptions(BuildContext context) {
    final provider = context.read<UserProvider>();
    final user = provider.currentUser;
    final hasPhoto = user?.profilePhotoUrl != null && user!.profilePhotoUrl!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.accentBlue),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUploadPhoto(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.accentBlue),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUploadPhoto(context, ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.primaryRed),
                title: const Text('Remove Photo', style: TextStyle(color: AppTheme.primaryRed)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _removePhoto(context);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(BuildContext context, ImageSource source) async {
    final provider = context.read<UserProvider>();
    final file = await provider.pickProfilePhoto(source: source);
    if (file != null) {
      final success = await provider.uploadProfilePhoto(file);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Profile photo updated' : 'Failed to update photo'),
            backgroundColor: success ? AppTheme.successGreen : AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto(BuildContext context) async {
    final provider = context.read<UserProvider>();
    final success = await provider.removeProfilePhoto();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile photo removed' : 'Failed to remove photo'),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.primaryRed,
        ),
      );
    }
  }

  void _showEditProfileDialog(BuildContext context) {
    final provider = context.read<UserProvider>();
    final user = provider.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);
    final handleController = TextEditingController(text: user.handle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: handleController,
              decoration: const InputDecoration(
                labelText: 'Handle',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = user.copyWith(
                name: nameController.text.trim(),
                handle: handleController.text.trim(),
              );
              provider.updateUser(updated);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.profilePurple,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        final user = provider.currentUser;
        if (user == null) {
          if (provider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const Center(child: Text('No user data'));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: AppTheme.profilePurple,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<UserProvider>().refreshCurrentUser();
                },
                tooltip: 'Refresh profile',
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header section with purple background
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.profilePurple,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.only(
                      top: 8, bottom: 32, left: 20, right: 20),
                  child: Column(
                    children: [
                      // Avatar with edit overlay
                      GestureDetector(
                        onTap: () => _showPhotoOptions(context),
                        child: Stack(
                          children: [
                            UserAvatar(
                              photoUrl: user.profilePhotoUrl,
                              initials: user.initials,
                              radius: 44,
                              backgroundColor: Colors.teal,
                              borderWidth: 3,
                              borderColor: Colors.amber,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.handle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Member since ${DateFormat('MMM yyyy').format(user.memberSince)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      if (user.isTrusted) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'TRUSTED MEMBER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stats row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(value: '${user.reports}', label: 'Reports'),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                      _StatItem(value: '${user.votes}', label: 'Votes'),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                      _StatItem(value: '${user.points}', label: 'Points'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Edit Profile button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showEditProfileDialog(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentBlue,
                        side: const BorderSide(color: AppTheme.accentBlue),
                      ),
                      child: const Text('Edit Profile'),
                    ),
                  ),
                ),
                // Admin Dashboard button (only for admins)
                if (user.isAdmin) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminScreen()),
                          );
                        },
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('Admin Dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Reputation Score card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Reputation Score',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${user.points}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                        ),
                        Text(
                          'Level ${user.level} ${user.levelTitle}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${user.pointsToNextLevel} points to Level ${user.level + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: user.levelProgress,
                            minHeight: 10,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation(
                                AppTheme.successGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // My Reports history
                _MyReportsSection(
                  onTap: _showIncidentDetail,
                  onEdit: _showEditSheet,
                  onDelete: _confirmDelete,
                  onShare: _shareIncident,
                ),
                const SizedBox(height: 16),

                // Sign Out button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        context.read<UserProvider>().clearUser();
                        await FirebaseAuth.instance.signOut();
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryRed,
                        side: const BorderSide(color: AppTheme.primaryRed),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MyReportsSection extends StatelessWidget {
  final void Function(BuildContext, IncidentModel) onTap;
  final void Function(BuildContext, IncidentModel) onEdit;
  final void Function(BuildContext, IncidentModel) onDelete;
  final void Function(IncidentModel) onShare;

  const _MyReportsSection({
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<IncidentProvider>().myReports;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'My Reports',
                style: AppTheme.headingSmall,
              ),
              const Spacer(),
              Text(
                '${reports.length} total',
                style: AppTheme.caption,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  Icon(Icons.report_outlined, size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('No reports yet', style: AppTheme.caption),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final incident = reports[index];
                return _ReportHistoryCard(
                  incident: incident,
                  onTap: () => onTap(context, incident),
                  onEdit: () => onEdit(context, incident),
                  onDelete: () => onDelete(context, incident),
                  onShare: () => onShare(incident),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReportHistoryCard extends StatelessWidget {
  final IncidentModel incident;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _ReportHistoryCard({
    required this.incident,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  Color get _statusColor {
    switch (incident.status) {
      case IncidentStatus.pending:
        return AppTheme.warningOrange;
      case IncidentStatus.underReview:
        return AppTheme.primaryDark;
      case IncidentStatus.verified:
        return AppTheme.successGreen;
      case IncidentStatus.resolved:
        return AppTheme.successGreen;
      case IncidentStatus.dismissed:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppTheme.categoryColor(incident.categoryLabel);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.cardDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Category color bar
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: categoryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Chip(label: incident.categoryLabel, color: categoryColor),
                        const SizedBox(width: 6),
                        _Chip(label: incident.statusLabel, color: _statusColor),
                        const SizedBox(width: 6),
                        Text(incident.timeAgo, style: AppTheme.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Actions menu
            PopupMenuButton<_CardAction>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
              onSelected: (action) {
                switch (action) {
                  case _CardAction.edit:
                    onEdit();
                    break;
                  case _CardAction.share:
                    onShare();
                    break;
                  case _CardAction.delete:
                    onDelete();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _CardAction.edit,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: _CardAction.share,
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Share'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _CardAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppTheme.primaryRed),
                      const SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: AppTheme.primaryRed)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardAction { edit, share, delete }

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EditIncidentSheet extends StatefulWidget {
  final IncidentModel incident;
  final Future<void> Function(IncidentModel) onSave;

  const _EditIncidentSheet({required this.incident, required this.onSave});

  @override
  State<_EditIncidentSheet> createState() => _EditIncidentSheetState();
}

class _EditIncidentSheetState extends State<_EditIncidentSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late IncidentCategory _category;
  late SeverityLevel _severity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.incident.title);
    _descController = TextEditingController(text: widget.incident.description);
    _category = widget.incident.category;
    _severity = widget.incident.severity;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final updated = widget.incident.copyWith(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category,
      severity: _severity,
    );
    await widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Edit Report', style: AppTheme.headingSmall),
          const SizedBox(height: 16),
          // Title
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            maxLength: 100,
          ),
          const SizedBox(height: 12),
          // Description
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 12),
          // Category
          Text('Category', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: IncidentCategory.values.map((cat) {
              final label = cat.name[0].toUpperCase() + cat.name.substring(1);
              final isSelected = _category == cat;
              return GestureDetector(
                onTap: () => setState(() => _category = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryDark : AppTheme.cardBorder,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: isSelected ? Colors.white : AppTheme.primaryDark,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Severity
          Text('Severity', style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: SeverityLevel.values.map((sev) {
              final label = sev.name[0].toUpperCase() + sev.name.substring(1);
              final isSelected = _severity == sev;
              final color = sev == SeverityLevel.high
                  ? AppTheme.primaryRed
                  : sev == SeverityLevel.moderate
                      ? AppTheme.warningOrange
                      : AppTheme.successGreen;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _severity = sev),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? color : AppTheme.cardBorder),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: isSelected ? Colors.white : AppTheme.primaryDark,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryDark,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
