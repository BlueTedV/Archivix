import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _service = NotificationService();
  NotificationPreferences _prefs = const NotificationPreferences();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final prefs = await _service.loadPreferences();
    if (mounted) setState(() {
      _prefs = prefs;
      _isLoading = false;
    });
  }

  Future<void> _save(NotificationPreferences updated) async {
    setState(() {
      _prefs = updated;
      _isSaving = true;
    });
    try {
      await _service.savePreferences(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: AppColors.errorDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('Your Content'),
                _buildToggle(
                  icon: Icons.verified_outlined,
                  iconColor: AppColors.successDark,
                  title: 'Document Approved',
                  subtitle: 'When an admin publishes your document',
                  value: _prefs.paperApproved,
                  onChanged: (v) =>
                      _save(_prefs.copyWith(paperApproved: v)),
                ),
                _buildToggle(
                  icon: Icons.cancel_outlined,
                  iconColor: AppColors.errorDark,
                  title: 'Document Rejected',
                  subtitle: 'When an admin returns your document with feedback',
                  value: _prefs.paperRejected,
                  onChanged: (v) =>
                      _save(_prefs.copyWith(paperRejected: v)),
                ),
                _buildToggle(
                  icon: Icons.comment_outlined,
                  iconColor: AppColors.slatePrimary,
                  title: 'New Comment',
                  subtitle: 'When someone comments on your content',
                  value: _prefs.postComment,
                  onChanged: (v) =>
                      _save(_prefs.copyWith(postComment: v)),
                ),
                _buildToggle(
                  icon: Icons.thumb_up_alt_outlined,
                  iconColor: AppColors.success,
                  title: 'Content Liked',
                  subtitle: 'When someone likes your document or question',
                  value: _prefs.contentLiked,
                  onChanged: (v) =>
                      _save(_prefs.copyWith(contentLiked: v)),
                ),
                _buildToggle(
                  icon: Icons.bar_chart,
                  iconColor: AppColors.amberDark,
                  title: 'View Milestones',
                  subtitle: 'When your content reaches 100, 500, 1 000 views…',
                  value: _prefs.milestoneViews,
                  onChanged: (v) =>
                      _save(_prefs.copyWith(milestoneViews: v)),
                ),
                const SizedBox(height: 8),
                _buildSectionHeader('Social'),
                _buildToggle(
                  icon: Icons.person_add_outlined,
                  iconColor: AppColors.slatePrimary,
                  title: 'New Follower',
                  subtitle: 'When someone starts following you',
                  value: _prefs.newFollower,
                  onChanged: (v) =>
                      _save(_prefs.copyWith(newFollower: v)),
                ),
                _buildToggle(
                  icon: Icons.upload_file_outlined,
                  iconColor: AppColors.amberDark,
                  title: 'Following Activity',
                  subtitle: 'When someone you follow uploads new content',
                  value: _prefs.followingUpload,
                  onChanged: (v) =>
                      _save(_prefs.copyWith(followingUpload: v)),
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

  Widget _buildToggle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        secondary: Container(
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
        value: value,
        activeColor: AppColors.slatePrimary,
        onChanged: _isSaving ? null : onChanged,
      ),
    );
  }
}
