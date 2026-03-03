import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../providers/user_provider.dart';
import '../user_avatar.dart';
import '../export_dialog.dart';

class AdminHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const AdminHeader({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
          // Page title
          Expanded(
            child: Text(
              title,
              style: AppTheme.headingMedium.copyWith(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
              ),
            ),
          ),

          // Custom actions
          if (actions != null) ...actions!,

          // Export button
          IconButton(
            onPressed: () => ExportDialog.show(context),
            icon: Icon(
              Icons.download_outlined,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
            tooltip: 'Export Data',
          ),
          const SizedBox(width: 8),

          // User info
          if (currentUser != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkCardBorder.withValues(alpha: 0.3)
                    : AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    photoUrl: currentUser.profilePhotoUrl,
                    initials: currentUser.initials,
                    radius: 14,
                    backgroundColor: AppTheme.primaryRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentUser.name,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Logout button
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text('Sign Out', style: AppTheme.headingMedium),
                  content: Text(
                    'Are you sure you want to sign out?',
                    style: AppTheme.bodyMedium,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        'Cancel',
                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
              }
            },
            icon: Icon(
              Icons.logout,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
            tooltip: 'Sign Out',
          ),
        ],
      ),
    );
  }
}
