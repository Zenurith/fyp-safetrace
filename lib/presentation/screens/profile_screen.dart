import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../providers/user_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                      // Avatar
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.teal,
                          border: Border.all(color: Colors.amber, width: 3),
                        ),
                        child: Center(
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
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
                const SizedBox(height: 24),

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
