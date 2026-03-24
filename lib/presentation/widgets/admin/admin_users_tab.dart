import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/user_model.dart';
import '../../../utils/app_theme.dart';
import '../../providers/user_provider.dart';
import '../user_avatar.dart';
import '../user_moderation_dialog.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
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
    final currentUser = context.watch<UserProvider>().currentUser;
    return FutureBuilder<List<UserModel>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading users',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          );
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return Center(
            child: Text(
              'No users found',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _UserCard(
              user: users[index],
              currentUser: currentUser,
              onRefresh: _refresh,
            );
          },
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final UserModel? currentUser;
  final VoidCallback onRefresh;

  const _UserCard({
    required this.user,
    required this.currentUser,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final viewer = currentUser;
    final isSelf = viewer != null && user.id == viewer.id;

    // Promote button visibility and target role
    String? promoteToRole;
    if (!isSelf) {
      if (user.role == 'user') {
        promoteToRole = 'admin';
      } else if (user.role == 'admin' && (viewer?.isSuperAdmin ?? false)) {
        promoteToRole = 'superadmin';
      }
    }

    // Demote button visibility and target role
    String? demoteToRole;
    if (!isSelf && (viewer?.isSuperAdmin ?? false)) {
      if (user.role == 'admin') {
        demoteToRole = 'user';
      } else if (user.isSuperAdmin) {
        demoteToRole = 'admin';
      }
    }

    // Moderate button visibility
    final showModerate = !isSelf &&
        (user.role == 'user' ||
            (user.role == 'admin' && (viewer?.isSuperAdmin ?? false)) ||
            (user.isSuperAdmin && (viewer?.isSuperAdmin ?? false)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  UserAvatar(
                    photoUrl: user.profilePhotoUrl,
                    initials: user.initials,
                    radius: 24,
                    backgroundColor:
                        user.isAdmin ? AppTheme.primaryRed : AppTheme.primaryDark,
                  ),
                  if (user.isBanned || user.isActivelySuspended)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: user.isBanned
                              ? AppTheme.primaryRed
                              : AppTheme.warningOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: AppTheme.headingSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isBanned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BANNED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (user.isActivelySuspended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SUSPENDED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(user.handle, style: AppTheme.caption),
                  ],
                ),
              ),
              _RoleChip(role: user.role),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${user.points} pts  •  ${user.reports} reports  •  Level ${user.level}',
                  style: AppTheme.caption,
                ),
              ),
              if (promoteToRole != null) ...[
                TextButton(
                  onPressed: () async {
                    await context
                        .read<UserProvider>()
                        .setUserRole(user.id, promoteToRole!);
                    onRefresh();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.successGreen,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Promote',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (demoteToRole != null) ...[
                TextButton(
                  onPressed: () async {
                    await context
                        .read<UserProvider>()
                        .setUserRole(user.id, demoteToRole!);
                    onRefresh();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.warningOrange,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Demote',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (showModerate)
                TextButton(
                  onPressed: () async {
                    final result =
                        await UserModerationDialog.show(context, user);
                    if (result == true) onRefresh();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryRed,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, bgColor, borderColor, textColor) = switch (role) {
      'superadmin' => (
          'Admin',
          AppTheme.primaryRed.withValues(alpha: 0.1),
          AppTheme.primaryRed.withValues(alpha: 0.3),
          AppTheme.primaryRed,
        ),
      'admin' => (
          'Moderator',
          AppTheme.warningOrange.withValues(alpha: 0.1),
          AppTheme.warningOrange.withValues(alpha: 0.3),
          AppTheme.warningOrange,
        ),
      _ => (
          'User',
          AppTheme.backgroundGrey,
          AppTheme.cardBorder,
          AppTheme.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
