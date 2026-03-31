import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import 'auth/login_screen.dart';
import 'papers/paper_detail_screen.dart';
import 'posts/post_detail_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoadingVerification = false;
  bool _isLoadingHistory = true;
  String? _historyError;
  String _historyFilter = 'all';
  List<Map<String, dynamic>> _userPapers = [];
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _loadUserHistory();
  }

  Future<void> _loadUserHistory() async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _historyError = 'User not authenticated.';
          _userPapers = [];
          _userPosts = [];
          _historyItems = [];
        });
      }
      return;
    }

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final papersResponse = await supabase
          .from('papers')
          .select('''
            id,
            title,
            abstract,
            created_at,
            views_count,
            categories (name),
            paper_authors (name)
          ''')
          .eq('user_id', userId)
          .eq('status', 'published')
          .order('created_at', ascending: false);

      final postsResponse = await supabase
          .from('posts')
          .select('''
            id,
            title,
            content,
            created_at,
            views_count,
            categories (name)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final papers = List<Map<String, dynamic>>.from(papersResponse);
      final posts = List<Map<String, dynamic>>.from(postsResponse);

      for (final paper in papers) {
        paper['content_type'] = 'paper';
      }

      for (final post in posts) {
        post['content_type'] = 'post';
      }

      final combined = [...papers, ...posts];
      combined.sort((a, b) {
        final aDate = DateTime.tryParse('${a['created_at']}') ?? DateTime(1970);
        final bDate = DateTime.tryParse('${b['created_at']}') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _userPapers = papers;
          _userPosts = posts;
          _historyItems = combined;
          _isLoadingHistory = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _historyError = error.toString();
          _isLoadingHistory = false;
        });
      }
    }
  }

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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
                        if (email == null) {
                          throw Exception('User not logged in');
                        }

                        await supabase.auth.signInWithPassword(
                          email: email,
                          password: currentPasswordController.text,
                        );

                        // If sign in successful, update password
                        await supabase.auth.updateUser(
                          UserAttributes(password: newPasswordController.text),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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

  List<Map<String, dynamic>> get _filteredHistoryItems {
    if (_historyFilter == 'papers') {
      return _historyItems
          .where((item) => item['content_type'] == 'paper')
          .toList();
    }

    if (_historyFilter == 'posts') {
      return _historyItems
          .where((item) => item['content_type'] == 'post')
          .toList();
    }

    return _historyItems;
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final isEmailConfirmed = user?.emailConfirmedAt != null;
    final visibleHistory = _filteredHistoryItems;
    final historyPanelHeight = (MediaQuery.of(context).size.height * 0.4).clamp(
      240.0,
      380.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadUserHistory,
            tooltip: 'Refresh history',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'Documents',
                    value: _userPapers.length.toString(),
                    icon: Icons.description_outlined,
                    backgroundColor: AppColors.surfaceLight,
                    borderColor: AppColors.border,
                    accentColor: AppColors.slatePrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    label: 'Questions',
                    value: _userPosts.length.toString(),
                    icon: Icons.question_answer_outlined,
                    backgroundColor: AppColors.amberSurface,
                    borderColor: AppColors.amberBorder,
                    accentColor: AppColors.amberDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Container(width: 3, height: 20, color: AppColors.slatePrimary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Your History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.slatePrimary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    value: _historyFilter,
                    underline: const SizedBox(),
                    isDense: true,
                    icon: const Icon(
                      Icons.filter_list,
                      size: 16,
                      color: AppColors.slatePrimary,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'papers',
                        child: Text('Documents'),
                      ),
                      DropdownMenuItem(
                        value: 'posts',
                        child: Text('Questions'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _historyFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${visibleHistory.length} items',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              height: historyPanelHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildHistoryPanel(visibleHistory),
            ),
            const SizedBox(height: 8),

            // Email verification section
            Row(
              children: [
                Container(width: 3, height: 20, color: AppColors.slatePrimary),
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
                          Text(
                            '• Submit research papers',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.amberDark,
                            ),
                          ),
                          Text(
                            '• Download papers',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.amberDark,
                            ),
                          ),
                          Text(
                            '• Comment & discuss',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.amberDark,
                            ),
                          ),
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
                                side: const BorderSide(
                                  color: AppColors.amberDark,
                                ),
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
                Container(width: 3, height: 20, color: AppColors.slatePrimary),
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Center(
              child: Text(
                user == null
                    ? 'User ID unavailable'
                    : 'User ID: ${user.id.substring(0, 8)}...',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSubtle,
                ),
              ),
            ),
          ],
        ),
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
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSubtle),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }

  Widget _buildHistoryPanel(List<Map<String, dynamic>> visibleHistory) {
    if (_isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_historyError != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: _buildHistoryError(),
      );
    }

    if (visibleHistory.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: _buildEmptyHistoryState(),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: visibleHistory.length,
        itemBuilder: (context, index) {
          final item = visibleHistory[index];

          if (item['content_type'] == 'paper') {
            final category = item['categories'] as Map<String, dynamic>?;
            final authors = item['paper_authors'] as List<dynamic>?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPaperHistoryCard(
                paperId: '${item['id']}',
                title: '${item['title'] ?? 'Untitled Document'}',
                authors: _getAuthors(authors),
                category: category?['name'] ?? 'Uncategorized',
                date: _formatHistoryDate('${item['created_at']}'),
                views: item['views_count'] ?? 0,
                abstract: '${item['abstract'] ?? ''}',
              ),
            );
          }

          final category = item['categories'] as Map<String, dynamic>?;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPostHistoryCard(
              postId: '${item['id']}',
              title: '${item['title'] ?? 'Untitled Question'}',
              content: '${item['content'] ?? ''}',
              category: category?['name'] ?? 'Uncategorized',
              date: _formatHistoryDate('${item['created_at']}'),
              views: item['views_count'] ?? 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        border: Border.all(color: AppColors.errorBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorDark),
          const SizedBox(height: 8),
          const Text(
            'Error loading your history',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.errorDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _historyError!,
            style: const TextStyle(fontSize: 12, color: AppColors.errorDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadUserHistory,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    final title = _historyFilter == 'papers'
        ? 'No documents yet'
        : _historyFilter == 'posts'
        ? 'No questions yet'
        : 'No history yet';

    final subtitle = _historyFilter == 'papers'
        ? 'Documents you publish will appear here.'
        : _historyFilter == 'posts'
        ? 'Questions you post will appear here.'
        : 'Your published documents and posted questions will appear here.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Icon(Icons.history, size: 42, color: AppColors.textSubtle),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperHistoryCard({
    required String paperId,
    required String title,
    required String authors,
    required String category,
    required String date,
    required int views,
    required String abstract,
  }) {
    final preview = abstract.trim().isEmpty
        ? 'No abstract provided.'
        : abstract;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaperDetailScreen(paperId: paperId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: AppColors.slatePrimary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Document',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slatePrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              authors,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              preview.length > 150
                  ? '${preview.substring(0, 150)}...'
                  : preview,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.slatePrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.visibility,
                  size: 12,
                  color: AppColors.textSubtle,
                ),
                const SizedBox(width: 4),
                Text(
                  '$views',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSubtle,
                  ),
                ),
                const Spacer(),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHistoryCard({
    required String postId,
    required String title,
    required String content,
    required String category,
    required String date,
    required int views,
  }) {
    final preview = content.trim().isEmpty ? 'No details provided.' : content;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.amberCardBg,
          border: Border.all(color: AppColors.amberBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.question_answer,
                  size: 16,
                  color: AppColors.amberDark,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Question',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amberDark,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              preview.length > 150
                  ? '${preview.substring(0, 150)}...'
                  : preview,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberSurface,
                    border: Border.all(color: AppColors.amberBorder),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.amberDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.visibility,
                  size: 12,
                  color: AppColors.textSubtle,
                ),
                const SizedBox(width: 4),
                Text(
                  '$views',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSubtle,
                  ),
                ),
                const Spacer(),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getAuthors(List<dynamic>? authors) {
    if (authors == null || authors.isEmpty) {
      return 'Unknown Author';
    }

    final names = authors
        .map((author) => author['name'] as String? ?? 'Unknown Author')
        .toList();

    if (names.length == 1) return names[0];
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names[0]} et al.';
  }

  String _formatHistoryDate(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      }

      if (difference.inDays == 1) {
        return 'Yesterday';
      }

      if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
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
