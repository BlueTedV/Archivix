import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final supabase = Supabase.instance.client;

  Future<void> _copySupportSummary() async {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? 'unknown';
    final shortId = user == null ? 'unavailable' : '${user.id.substring(0, 8)}...';
    final summary =
        'Archivix support summary\n'
        'Account: $email\n'
        'User ID: $shortId\n'
        'Time: ${DateTime.now().toIso8601String()}\n';

    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support summary copied to clipboard.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 16),
          _buildSectionHeader('Quick Help'),
          _buildActionTile(
            icon: Icons.notifications_outlined,
            iconColor: AppColors.slatePrimary,
            title: 'Notification Settings',
            subtitle: 'Review alerts for approvals, comments, likes, and follows.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          _buildActionTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppColors.slatePrimary,
            title: 'Privacy Settings',
            subtitle: 'Adjust who can discover your profile and activity.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PrivacySettingsScreen(),
              ),
            ),
          ),
          _buildActionTile(
            icon: Icons.copy_all_outlined,
            iconColor: AppColors.successDark,
            title: 'Copy Support Summary',
            subtitle: 'Copy account details you can paste into a bug report.',
            onTap: _copySupportSummary,
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Common Questions'),
          _buildFaqTile(
            title: 'Why is my document not visible yet?',
            body:
                'Draft and under-review documents stay private until they are published. You can track their status from the activity section in your profile settings.',
          ),
          _buildFaqTile(
            title: 'How does professor verification work?',
            body:
                'Verification requests go through manual admin review. If your request is rejected, the admin note in your profile settings usually explains what needs to be updated before you submit again.',
          ),
          _buildFaqTile(
            title: 'How do I recover account access?',
            body:
                'If you still know your password, use the change-password option in settings. If you are locked out, use the Forgot Password flow from the login screen so Supabase can send a reset link.',
          ),
          _buildFaqTile(
            title: 'What should I include when reporting a problem?',
            body:
                'Share what you were trying to do, what happened instead, and whether it affected a paper, post, profile edit, or verification request. The support summary button above can help with account context.',
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Support Notes'),
          _buildInfoCard(
            icon: Icons.shield_outlined,
            iconColor: AppColors.slatePrimary,
            title: 'Privacy and account data',
            body:
                'Your email stays private, and verification files are intended for admins reviewing academic status.',
          ),
          _buildInfoCard(
            icon: Icons.sync_problem_outlined,
            iconColor: AppColors.amberDark,
            title: 'Refresh first',
            body:
                'If something looks stale, pull to refresh the profile screen before reporting it. That resolves most delayed counts and status updates.',
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.slatePrimary, size: 18),
              SizedBox(width: 8),
              Text(
                'Support Center',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'This screen brings the most common account, visibility, and publication help into one place so you can troubleshoot quickly before reaching out for deeper support.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: AppColors.slatePrimary),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: AppColors.textSubtle,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFaqTile({required String title, required String body}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: AppColors.slatePrimary,
        collapsedIconColor: AppColors.textMuted,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
