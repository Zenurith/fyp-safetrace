import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/user_model.dart';
import '../../../utils/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/user_moderation_dialog.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  late Future<List<UserModel>> _usersFuture;
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all', 'admin', 'user'
  String _statusFilter = 'all'; // 'all', 'active', 'banned', 'suspended'

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

  List<UserModel> _filterUsers(List<UserModel> users) {
    return users.where((user) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!user.name.toLowerCase().contains(query) &&
            !user.handle.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Role filter
      if (_roleFilter == 'admin' && !user.isAdmin) return false;
      if (_roleFilter == 'user' && user.isAdmin) return false;

      // Status filter
      if (_statusFilter == 'active' && (user.isBanned || user.isActivelySuspended)) {
        return false;
      }
      if (_statusFilter == 'banned' && !user.isBanned) return false;
      if (_statusFilter == 'suspended' && !user.isActivelySuspended) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Filters bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                flex: 2,
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: AppTheme.bodyMedium.copyWith(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by name or handle...',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                    prefixIcon: Icon(Icons.search, size: 20, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Role filter
              _FilterDropdown(
                value: _roleFilter,
                items: const {
                  'all': 'All Roles',
                  'admin': 'Admins',
                  'user': 'Users',
                },
                onChanged: (value) => setState(() => _roleFilter = value!),
              ),
              const SizedBox(width: 12),

              // Status filter
              _FilterDropdown(
                value: _statusFilter,
                items: const {
                  'all': 'All Status',
                  'active': 'Active',
                  'banned': 'Banned',
                  'suspended': 'Suspended',
                },
                onChanged: (value) => setState(() => _statusFilter = value!),
              ),
              const SizedBox(width: 12),

              // Refresh button
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Users list
        Expanded(
          child: FutureBuilder<List<UserModel>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error loading users',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final allUsers = snapshot.data ?? [];
              final users = _filterUsers(allUsers);

              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty || _roleFilter != 'all' || _statusFilter != 'all'
                            ? 'No users match your filters'
                            : 'No users found',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _UserCard(user: user, onRefresh: _refresh);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          style: AppTheme.bodyMedium.copyWith(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
          ),
          dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
          iconEnabledColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          items: items.entries.map((e) {
            return DropdownMenuItem(
              value: e.key,
              child: Text(e.value),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRefresh;

  const _UserCard({required this.user, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecorationFor(context),
      child: Row(
        children: [
          // Avatar with status indicator
          Stack(
            children: [
              UserAvatar(
                photoUrl: user.profilePhotoUrl,
                initials: user.initials,
                radius: 24,
                backgroundColor: user.isAdmin ? AppTheme.primaryRed : AppTheme.primaryDark,
              ),
              if (user.isBanned || user.isActivelySuspended)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: user.isBanned ? AppTheme.primaryRed : AppTheme.warningOrange,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      user.isBanned ? Icons.block : Icons.timer,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: AppTheme.headingSmall.copyWith(
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isBanned) ...[
                      const SizedBox(width: 8),
                      _StatusBadge(label: 'BANNED', color: AppTheme.primaryRed),
                    ] else if (user.isActivelySuspended) ...[
                      const SizedBox(width: 8),
                      _StatusBadge(label: 'SUSPENDED', color: AppTheme.warningOrange),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.handle,
                  style: AppTheme.caption.copyWith(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Stats
          _StatColumn(label: 'Points', value: '${user.points}'),
          const SizedBox(width: 24),
          _StatColumn(label: 'Reports', value: '${user.reports}'),
          const SizedBox(width: 24),
          _StatColumn(label: 'Level', value: '${user.level}'),
          const SizedBox(width: 24),

          // Role chip
          _RoleChip(isAdmin: user.isAdmin),
          const SizedBox(width: 16),

          // Actions
          TextButton(
            onPressed: () async {
              final newRole = user.isAdmin ? 'user' : 'admin';
              await context.read<UserProvider>().setUserRole(user.id, newRole);
              onRefresh();
            },
            style: TextButton.styleFrom(
              foregroundColor: user.isAdmin ? AppTheme.warningOrange : AppTheme.successGreen,
            ),
            child: Text(
              user.isAdmin ? 'Demote' : 'Promote',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final result = await UserModerationDialog.show(context, user);
              if (result == true) {
                onRefresh();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
            child: const Text(
              'Moderate',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Text(
          value,
          style: AppTheme.headingSmall.copyWith(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
          ),
        ),
        Text(
          label,
          style: AppTheme.caption.copyWith(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final bool isAdmin;

  const _RoleChip({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppTheme.primaryRed.withValues(alpha: 0.1)
            : (isDark ? AppTheme.darkCardBorder : AppTheme.backgroundGrey),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAdmin
              ? AppTheme.primaryRed.withValues(alpha: 0.3)
              : (isDark ? AppTheme.darkCardBorder : AppTheme.cardBorder),
        ),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'User',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isAdmin
              ? AppTheme.primaryRed
              : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
        ),
      ),
    );
  }
}
