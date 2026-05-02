import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/cubits/app_cubit.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import '../../theme/app_theme.dart';

// Import your AppCubit
// import '../../cubits/app_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(CupertinoIcons.back, size: 28, color: AppColors.pink),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),

              // Settings List
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.sun_max,
                        title: 'Change Theme',
                        onTap: () {
                          debugPrint('Change Theme tapped');
                          // Add your theme change logic
                        },
                      ),

                      const SizedBox(height: 12),

                      FutureBuilder<bool>(
                        future: ProfileService.hasPassword(),
                        builder: (context, snapshot) {
                          final hasPassword = snapshot.data ?? false;
                          final title = hasPassword ? 'Change Password' : 'Create Password';

                          return _buildSettingsItem(
                            context,
                            icon: CupertinoIcons.lock_shield,
                            title: title,
                            onTap: () {
                              context.push(Routes.passwordSettings.path);
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.link,
                        title: 'Linked Accounts',
                        onTap: () {
                          debugPrint('Linked Accounts tapped');
                          // Navigate to linked accounts page
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.tray,
                        title: 'Inbox',
                        onTap: () {
                          debugPrint('Inbox tapped');
                          // Navigate to inbox
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.globe,
                        title: 'Language',
                        onTap: () {
                          debugPrint('Language tapped');
                          // Navigate to language selection
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.star,
                        title: 'Review Us',
                        onTap: () {
                          debugPrint('Review Us tapped');
                          // Open app store review
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.chat_bubble_text,
                        title: 'Feedback',
                        onTap: () {
                          debugPrint('Feedback tapped');
                          context.push(Routes.feedback.path);
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.refresh_circled,
                        title: 'Check for Update',
                        onTap: () {
                          debugPrint('Check for Update tapped');
                          // Check for app updates
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildSettingsItem(
                        context,
                        icon: CupertinoIcons.info_circle,
                        title: 'About',
                        onTap: () {
                          debugPrint('About tapped');
                          // Show about dialog or navigate to about page
                        },
                      ),

                      const SizedBox(height: 30),

                      // Logout Button
                      _buildLogoutButton(context),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
          boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.pink.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.pink, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: Colors.white.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.pink.withValues(alpha: 0.3)),
            ),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Logout',
                  style: TextStyle(color: AppColors.pink, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          final appCubit = GetIt.I<AppCubit>();
          await appCubit.logout();
          if (context.mounted) {
            context.go(Routes.login.path);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [Colors.pink.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.3)]),
          border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1),
          boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(CupertinoIcons.square_arrow_right, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 16),
            const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
