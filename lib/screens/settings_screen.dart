import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

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
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: const Color(0xFF991B1B),
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
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Color(0xFF991B1B)),
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
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A5568),
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
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Member since ${_formatDate(user?.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
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
                color: const Color(0xFF4A5568),
              ),
              const SizedBox(width: 8),
              const Text(
                'Account Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isEmailConfirmed 
                  ? const Color(0xFFD1FAE5) 
                  : const Color(0xFFFEF3C7),
              border: Border.all(
                color: isEmailConfirmed 
                    ? const Color(0xFF6EE7B7) 
                    : const Color(0xFFFCD34D),
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
                          ? const Color(0xFF047857) 
                          : const Color(0xFF92400E),
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
                              ? const Color(0xFF047857) 
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isEmailConfirmed) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Please check your email and click the verification link.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
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
                                  Color(0xFF92400E),
                                ),
                              ),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: _sendVerificationEmail,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF92400E)),
                              foregroundColor: const Color(0xFF92400E),
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
                color: const Color(0xFF4A5568),
              ),
              const SizedBox(width: 8),
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
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
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password change not yet implemented'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
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
                side: const BorderSide(color: Color(0xFF991B1B)),
                foregroundColor: const Color(0xFF991B1B),
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
                color: Color(0xFF9CA3AF),
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
          left: BorderSide(color: Color(0xFFD1D5DB), width: 1),
          right: BorderSide(color: Color(0xFFD1D5DB), width: 1),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4A5568)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFF9CA3AF),
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