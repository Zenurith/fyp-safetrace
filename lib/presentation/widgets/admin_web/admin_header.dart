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

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Breadcrumb
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SafeTrace',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.cardBorder,
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Custom actions
          if (actions != null) ...actions!,

          // Export button
          Tooltip(
            message: 'Export Data',
            child: InkWell(
              onTap: () => ExportDialog.show(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.cardBorder),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_outlined,
                        size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: 5),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // User info
          if (currentUser != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(
                  photoUrl: currentUser.profilePhotoUrl,
                  initials: currentUser.initials,
                  radius: 14,
                  backgroundColor: AppTheme.primaryRed,
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.name,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const Text(
                      'Administrator',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: AppTheme.cardBorder),
            const SizedBox(width: 4),
          ],

          // Logout
          Tooltip(
            message: 'Sign Out',
            child: IconButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
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
                          style: AppTheme.bodyMedium
                              .copyWith(color: AppTheme.textSecondary),
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
              icon: const Icon(Icons.logout_rounded,
                  color: AppTheme.textSecondary, size: 18),
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
