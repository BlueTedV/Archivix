import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/login_screen.dart';
import '../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoadingVerification = false;

  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isLoadingVerification = true;
    });

    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: supabase.auth.currentUser?.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: AppColors.errorDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVerification = false;
        });
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            'Change Password',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: currentPasswordController,
                  decoration: const InputDecoration(
                    hintText: 'Enter current password',
                    hintStyle: TextStyle(fontSize: 13),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'New Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    hintText: 'Enter new password',
                    hintStyle: TextStyle(fontSize: 13),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (value.length < 6) {
                      return 'Must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Confirm New Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    hintText: 'Confirm new password',
                    hintStyle: TextStyle(fontSize: 13),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (value != newPasswordController.text) {
                      return 'Passwords don\'t match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: AppColors.border),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() {
                        isLoading = true;
                      });

                      try {
                        // First, verify current password by attempting to sign in
                        final email = supabase.auth.currentUser?.email;
                        if (email == null) throw Exception('User not logged in');

                        await supabase.auth.signInWithPassword(
                          email: email,
                          password: currentPasswordController.text,
                        );

                        // If sign in successful, update password
                        await supabase.auth.updateUser(
                          UserAttributes(
                            password: newPasswordController.text,
                          ),
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } on AuthException catch (error) {
                        if (context.mounted) {
                          setState(() {
                            isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error.message),
                              backgroundColor: AppColors.errorDark,
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          setState(() {
                            isLoading = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${error.toString()}'),
                              backgroundColor: AppColors.errorDark,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slatePrimary,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to sign out?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.errorDark),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final isEmailConfirmed = user?.emailConfirmedAt != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.slatePrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Member since ${_formatDate(user?.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Email verification section
          Row(
            children: [
              Container(
                width: 3,
                height: 20,
                color: AppColors.slatePrimary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Account Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isEmailConfirmed 
                  ? AppColors.successLight 
                  : AppColors.amberSurface,
              border: Border.all(
                color: isEmailConfirmed 
                    ? Color(0xFF6EE7B7) 
                    : AppColors.amberBorder,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isEmailConfirmed ? Icons.check_circle : Icons.warning,
                      size: 20,
                      color: isEmailConfirmed 
                          ? Color(0xFF047857) 
                          : AppColors.amberDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEmailConfirmed 
                            ? 'Email Verified' 
                            : 'Email Not Verified',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isEmailConfirmed 
                              ? Color(0xFF047857) 
                              : AppColors.amberDark,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isEmailConfirmed) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Verify your email to unlock all app features:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.amberDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Submit research papers', style: TextStyle(fontSize: 11, color: AppColors.amberDark)),
                        Text('• Download papers', style: TextStyle(fontSize: 11, color: AppColors.amberDark)),
                        Text('• Comment & discuss', style: TextStyle(fontSize: 11, color: AppColors.amberDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _isLoadingVerification
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.amberDark,
                                ),
                              ),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: _sendVerificationEmail,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.amberDark),
                              foregroundColor: AppColors.amberDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'Resend Verification Email',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Settings options
          Row(
            children: [
              Container(
                width: 3,
                height: 20,
                color: AppColors.slatePrimary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          _buildSettingItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Configure notification preferences',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification settings not yet implemented'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 1),
          
          _buildSettingItem(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 1),
          
          _buildSettingItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle: 'Manage your privacy settings',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy settings not yet implemented'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 1),
          
          _buildSettingItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Help & Support not yet implemented'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          
          // Sign out button
          SizedBox(
            height: 42,
            child: OutlinedButton(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.errorDark),
                foregroundColor: AppColors.errorDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          Center(
            child: Text(
              'User ID: ${user?.id.substring(0, 8)}...',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSubtle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          left: BorderSide(color: AppColors.border, width: 1),
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.slatePrimary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSubtle,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}