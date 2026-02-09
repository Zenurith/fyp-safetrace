import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/category_model.dart';
import '../../utils/app_theme.dart';
import '../providers/incident_provider.dart';
import '../providers/user_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/user_avatar.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppTheme.primaryRed,
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Incidents'),
              Tab(text: 'Categories'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _IncidentsTab(),
            _CategoriesTab(),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  late Future<List<UserModel>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = context.read<UserProvider>().fetchAllUsers();
  }

  void _refresh() {
    setState(() {
      _usersFuture = context.read<UserProvider>().fetchAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: UserAvatar(
                photoUrl: user.profilePhotoUrl,
                initials: user.initials,
                radius: 20,
                backgroundColor: user.isAdmin
                    ? AppTheme.primaryRed
                    : AppTheme.accentBlue,
              ),
              title: Text(user.name),
              subtitle: Text('${user.handle}  •  ${user.role}'),
              trailing: TextButton(
                onPressed: () async {
                  final newRole = user.isAdmin ? 'user' : 'admin';
                  await context
                      .read<UserProvider>()
                      .setUserRole(user.id, newRole);
                  _refresh();
                },
                child: Text(
                  user.isAdmin ? 'Demote' : 'Promote',
                  style: TextStyle(
                    color: user.isAdmin
                        ? AppTheme.warningOrange
                        : AppTheme.successGreen,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _IncidentsTab extends StatelessWidget {
  const _IncidentsTab();

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.incidents;

    if (incidents.isEmpty) {
      return const Center(child: Text('No incidents found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: incidents.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final incident = incidents[index];
        return _IncidentListItem(incident: incident);
      },
    );
  }
}

class _IncidentListItem extends StatelessWidget {
  final IncidentModel incident;

  const _IncidentListItem({required this.incident});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.categoryColor(incident.categoryLabel),
        child: const Icon(Icons.warning_amber_rounded,
            color: Colors.white, size: 20),
      ),
      title: Text(incident.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${incident.categoryLabel}  •  ${incident.severityLabel}'),
          const SizedBox(height: 4),
          _StatusChip(status: incident.status),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: AppTheme.accentBlue),
            onPressed: () => _showStatusDialog(context),
            tooltip: 'Update Status',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.primaryRed),
            onPressed: () => _showDeleteDialog(context),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  void _showStatusDialog(BuildContext context) {
    final noteController = TextEditingController();
    IncidentStatus selectedStatus = incident.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Incident Status'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  incident.address,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Status:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...IncidentStatus.values.map((status) {
                  return RadioListTile<IncidentStatus>(
                    value: status,
                    groupValue: selectedStatus,
                    title: Text(_getStatusLabel(status)),
                    subtitle: Text(
                      _getStatusDescription(status),
                      style: const TextStyle(fontSize: 12),
                    ),
                    activeColor: _getStatusColor(status),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedStatus = value);
                      }
                    },
                  );
                }),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Status Note (Optional)',
                    hintText: 'Add a note about this status change...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await context.read<IncidentProvider>().updateIncidentStatus(
                      incident.id,
                      selectedStatus,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Status updated to ${_getStatusLabel(selectedStatus)}',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Incident'),
        content: Text('Are you sure you want to delete "${incident.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<IncidentProvider>().deleteIncident(incident.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(IncidentStatus status) {
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

  String _getStatusDescription(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return 'Awaiting initial review';
      case IncidentStatus.underReview:
        return 'Being investigated by authorities';
      case IncidentStatus.verified:
        return 'Confirmed by multiple sources';
      case IncidentStatus.resolved:
        return 'Issue has been addressed';
      case IncidentStatus.dismissed:
        return 'Invalid or false report';
    }
  }

  Color _getStatusColor(IncidentStatus status) {
    switch (status) {
      case IncidentStatus.pending:
        return Colors.orange;
      case IncidentStatus.underReview:
        return Colors.blue;
      case IncidentStatus.verified:
        return Colors.green;
      case IncidentStatus.resolved:
        return Colors.teal;
      case IncidentStatus.dismissed:
        return Colors.grey;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final IncidentStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _getStatusColor().withValues(alpha: 0.5)),
      ),
      child: Text(
        _getStatusLabel(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case IncidentStatus.pending:
        return Colors.orange;
      case IncidentStatus.underReview:
        return Colors.blue;
      case IncidentStatus.verified:
        return Colors.green;
      case IncidentStatus.resolved:
        return Colors.teal;
      case IncidentStatus.dismissed:
        return Colors.grey;
    }
  }

  String _getStatusLabel() {
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

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = categoryProvider.categories;

    if (categoryProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categoryProvider.error != null) {
      return Center(child: Text('Error: ${categoryProvider.error}'));
    }

    return Scaffold(
      body: categories.isEmpty
          ? const Center(child: Text('No categories found.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              onReorder: (oldIndex, newIndex) {
                // Handle reordering if needed
              },
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryListItem(
                  key: ValueKey(category.id),
                  category: category,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context),
        backgroundColor: AppTheme.primaryRed,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryDialog(
        onSave: (name, iconName, colorHex) async {
          final result = await context.read<CategoryProvider>().addCategory(
                name: name,
                iconName: iconName,
                colorHex: colorHex,
              );
          if (result != null && context.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Category "$name" added')),
            );
          }
        },
      ),
    );
  }
}

class _CategoryListItem extends StatelessWidget {
  final CategoryModel category;

  const _CategoryListItem({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(category.icon, color: category.color),
        ),
        title: Row(
          children: [
            Text(category.name),
            if (category.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          category.isEnabled ? 'Enabled' : 'Disabled',
          style: TextStyle(
            color: category.isEnabled ? AppTheme.successGreen : Colors.grey,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: category.isEnabled,
              activeColor: AppTheme.successGreen,
              onChanged: (value) {
                context.read<CategoryProvider>().toggleCategoryEnabled(category.id);
              },
            ),
            if (!category.isDefault) ...[
              IconButton(
                icon: const Icon(Icons.edit, color: AppTheme.accentBlue),
                onPressed: () => _showEditDialog(context),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: AppTheme.primaryRed),
                onPressed: () => _showDeleteDialog(context),
                tooltip: 'Delete',
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryDialog(
        category: category,
        onSave: (name, iconName, colorHex) async {
          final updated = category.copyWith(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
          );
          final result =
              await context.read<CategoryProvider>().updateCategory(updated);
          if (result && context.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Category "$name" updated')),
            );
          }
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final result = await context
                  .read<CategoryProvider>()
                  .deleteCategory(category.id);
              if (result && context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category "${category.name}" deleted')),
                );
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.primaryRed)),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final CategoryModel? category;
  final Function(String name, String iconName, String colorHex) onSave;

  const _CategoryDialog({this.category, required this.onSave});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedIcon = widget.category?.iconName ?? 'category';
    _selectedColor = widget.category?.colorHex ?? '#3182CE';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'shield':
        return Icons.shield;
      case 'construction':
        return Icons.construction;
      case 'visibility':
        return Icons.visibility;
      case 'directions_car':
        return Icons.directions_car;
      case 'eco':
        return Icons.eco;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'warning':
        return Icons.warning;
      case 'report':
        return Icons.report;
      case 'security':
        return Icons.security;
      case 'flash_on':
        return Icons.flash_on;
      case 'water_drop':
        return Icons.water_drop;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.category;
    }
  }

  Color _getColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Category' : 'Add Category'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Icon', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryModel.availableIcons.map((iconName) {
                  final isSelected = _selectedIcon == iconName;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getColor(_selectedColor).withValues(alpha: 0.2)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? _getColor(_selectedColor)
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        _getIconData(iconName),
                        color: isSelected
                            ? _getColor(_selectedColor)
                            : Colors.grey[600],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryModel.availableColors.map((colorHex) {
                  final isSelected = _selectedColor == colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorHex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _getColor(colorHex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _getColor(colorHex).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getColor(_selectedColor).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconData(_selectedIcon),
                        color: _getColor(_selectedColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _nameController.text.isEmpty
                          ? 'Preview'
                          : _nameController.text,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
                  widget.onSave(
                    _nameController.text.trim(),
                    _selectedIcon,
                    _selectedColor,
                  );
                },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
