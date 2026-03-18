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


    return Column(
      children: [
        // Filters bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.cardBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search users by name or @handle...',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: AppTheme.backgroundGrey,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppTheme.primaryRed.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Role filter
              _FilterChip(
                value: _roleFilter,
                items: const {
                  'all': 'All Roles',
                  'admin': 'Admins',
                  'user': 'Users',
                },
                onChanged: (value) => setState(() => _roleFilter = value!),
                icon: Icons.admin_panel_settings_outlined,
              ),
              const SizedBox(width: 12),

              // Status filter
              _FilterChip(
                value: _statusFilter,
                items: const {
                  'all': 'All Status',
                  'active': 'Active',
                  'banned': 'Banned',
                  'suspended': 'Suspended',
                },
                onChanged: (value) => setState(() => _statusFilter = value!),
                icon: Icons.verified_user_outlined,
              ),
              const SizedBox(width: 16),

              // Refresh button
              _ActionIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh users',
                onPressed: _refresh,
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
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryRed),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppTheme.primaryRed.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading users',
                        style: AppTheme.headingSmall.copyWith(
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check your connection and try again',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                        ),
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
                        Icons.person_search_rounded,
                        size: 64,
                        color: (AppTheme.textSecondary)
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty || _roleFilter != 'all' || _statusFilter != 'all'
                            ? 'No users match your filters'
                            : 'No users found',
                        style: AppTheme.headingSmall.copyWith(
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search or filters',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UserCard(user: user, onRefresh: _refresh),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  const _FilterChip({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {


    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w500,
              ),
              dropdownColor: Colors.white,
              iconEnabledColor: AppTheme.textSecondary,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              items: items.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {


    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppTheme.primaryRed.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onRefresh;

  const _UserCard({required this.user, required this.onRefresh});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {

    final user = widget.user;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isHovered ? AppTheme.backgroundGrey : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.cardBorder,
          ),
        ),
        child: Row(
          children: [
            // Avatar section with level ring
            _AvatarSection(user: user),
            const SizedBox(width: 20),

            // User info section
            Expanded(
              child: _UserInfoSection(user: user),
            ),

            // Stats section
            _StatsSection(user: user),
            const SizedBox(width: 24),

            // Actions section
            _ActionsSection(
              user: user,
              onRefresh: widget.onRefresh,
              isHovered: _isHovered,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  final UserModel user;

  const _AvatarSection({required this.user});

  Color _getLevelColor(int level) {
    if (level >= 8) return const Color(0xFFFFD700); // Gold
    if (level >= 6) return const Color(0xFFC0C0C0); // Silver
    if (level >= 4) return const Color(0xFFCD7F32); // Bronze
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(user.level);
    final hasRing = user.level >= 4;

    return Stack(
      children: [
        Container(
          padding: hasRing ? const EdgeInsets.all(3) : EdgeInsets.zero,
          decoration: hasRing
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      levelColor,
                      levelColor.withValues(alpha: 0.6),
                      levelColor,
                    ],
                  ),
                )
              : null,
          child: UserAvatar(
            photoUrl: user.profilePhotoUrl,
            initials: user.initials,
            radius: 28,
            backgroundColor: user.isAdmin ? AppTheme.primaryRed : AppTheme.primaryDark,
          ),
        ),
        // Status indicator
        if (user.isBanned || user.isActivelySuspended)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: user.isBanned ? AppTheme.primaryRed : AppTheme.warningOrange,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Icon(
                user.isBanned ? Icons.block_rounded : Icons.schedule_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        // Admin badge
        if (user.isAdmin && !user.isBanned && !user.isActivelySuspended)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _UserInfoSection extends StatelessWidget {
  final UserModel user;

  const _UserInfoSection({required this.user});

  @override
  Widget build(BuildContext context) {


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name row with badges
        Row(
          children: [
            Flexible(
              child: Text(
                user.name,
                style: AppTheme.headingSmall.copyWith(
                  color: AppTheme.primaryDark,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isTrusted && !user.isBanned) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Trusted User',
                child: Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: AppTheme.successGreen,
                ),
              ),
            ],
            if (user.isBanned) ...[
              const SizedBox(width: 8),
              _StatusPill(label: 'Banned', color: AppTheme.primaryRed),
            ] else if (user.isActivelySuspended) ...[
              const SizedBox(width: 8),
              _StatusPill(label: 'Suspended', color: AppTheme.warningOrange),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Handle and role
        Row(
          children: [
            Text(
              user.handle,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              user.levelTitle,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final UserModel user;

  const _StatsSection({required this.user});

  @override
  Widget build(BuildContext context) {


    return Row(
      children: [
        _StatItem(
          icon: Icons.stars_rounded,
          value: '${user.points}',
          label: 'Points',
          color: const Color(0xFFFFB800),
),
        const SizedBox(width: 20),
        _StatItem(
          icon: Icons.description_outlined,
          value: '${user.reports}',
          label: 'Reports',
          color: AppTheme.primaryDark,
),
        const SizedBox(width: 20),
        _StatItem(
          icon: Icons.emoji_events_outlined,
          value: 'Lv.${user.level}',
          label: user.levelTitle,
          color: AppTheme.successGreen,
),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.primaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w300,
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRefresh;
  final bool isHovered;

  const _ActionsSection({
    required this.user,
    required this.onRefresh,
    required this.isHovered,
  });

  @override
  Widget build(BuildContext context) {


    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isHovered ? 1.0 : 0.7,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Role chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: user.isAdmin
                  ? AppTheme.primaryRed.withValues(alpha: 0.1)
                  : AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(8),
              border: user.isAdmin
                  ? Border.all(
                      color: AppTheme.primaryRed.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: Text(
              user.isAdmin ? 'Admin' : 'User',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: user.isAdmin
                    ? AppTheme.primaryRed
                    : (AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Promote/Demote button
          _CardActionButton(
            icon: user.isAdmin ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            label: user.isAdmin ? 'Demote' : 'Promote',
            color: user.isAdmin ? AppTheme.warningOrange : AppTheme.successGreen,
            onPressed: () async {
              final newRole = user.isAdmin ? 'user' : 'admin';
              await context.read<UserProvider>().setUserRole(user.id, newRole);
              onRefresh();
            },
          ),
          const SizedBox(width: 8),

          // Moderate button
          _CardActionButton(
            icon: Icons.gavel_rounded,
            label: 'Moderate',
            color: AppTheme.primaryRed,
            onPressed: () async {
              final result = await UserModerationDialog.show(context, user);
              if (result == true) {
                onRefresh();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _CardActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          hoverColor: color.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
