import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/privacy_settings_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _service = PrivacySettingsService();

  PrivacyPreferences _prefs = const PrivacyPreferences();
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
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _isLoading = false;
    });
  }

  Future<void> _save(PrivacyPreferences updated) async {
    setState(() {
      _prefs = updated;
      _isSaving = true;
    });

    try {
      await _service.savePreferences(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Privacy preferences saved.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save privacy settings: $error'),
          backgroundColor: AppColors.errorDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy'),
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
                _buildOverviewCard(),
                const SizedBox(height: 16),
                _buildSectionHeader('Profile Visibility'),
                _buildToggle(
                  icon: Icons.search_outlined,
                  iconColor: AppColors.slatePrimary,
                  title: 'Appear in Search',
                  subtitle:
                      'Let other Archivix users discover your profile in search results.',
                  value: _prefs.discoverableProfile,
                  onChanged: (value) => _save(
                    _prefs.copyWith(discoverableProfile: value),
                  ),
                ),
                _buildToggle(
                  icon: Icons.insights_outlined,
                  iconColor: AppColors.slatePrimary,
                  title: 'Show Public Activity Summary',
                  subtitle:
                      'Display your document and question counts on public-facing profile views.',
                  value: _prefs.showActivitySummary,
                  onChanged: (value) =>
                      _save(_prefs.copyWith(showActivitySummary: value)),
                ),
                _buildToggle(
                  icon: Icons.collections_bookmark_outlined,
                  iconColor: AppColors.amberDark,
                  title: 'Show Public Collections',
                  subtitle:
                      'Allow saved collections to appear when public profile features reference them.',
                  value: _prefs.showCollectionsPublicly,
                  onChanged: (value) =>
                      _save(_prefs.copyWith(showCollectionsPublicly: value)),
                ),
                _buildToggle(
                  icon: Icons.person_add_alt_1_outlined,
                  iconColor: AppColors.successDark,
                  title: 'Allow New Followers',
                  subtitle:
                      'Permit other users to follow your profile for future activity updates.',
                  value: _prefs.allowFollowers,
                  onChanged: (value) => _save(
                    _prefs.copyWith(allowFollowers: value),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Always Private'),
                _buildInfoCard(
                  icon: Icons.mail_outline,
                  iconColor: AppColors.slatePrimary,
                  title: 'Email Address',
                  body:
                      'Your sign-in email stays private and is not shown on public profile surfaces.',
                ),
                _buildInfoCard(
                  icon: Icons.article_outlined,
                  iconColor: AppColors.amberDark,
                  title: 'Draft Content',
                  body:
                      'Draft and under-review documents remain private until they are published.',
                ),
                _buildInfoCard(
                  icon: Icons.verified_user_outlined,
                  iconColor: AppColors.successDark,
                  title: 'Verification Files',
                  body:
                      'Professor verification submissions are intended for admin review only.',
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewCard() {
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
              Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.slatePrimary,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Privacy Controls',
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
            'Choose how visible your profile is inside Archivix. These preferences are saved to your account so your settings stay with you across sessions.',
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
        activeThumbColor: AppColors.slatePrimary,
        onChanged: _isSaving ? null : onChanged,
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
