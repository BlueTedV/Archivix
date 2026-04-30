import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/paper_review_status.dart';
import 'edit_profile_screen.dart';
import 'auth/login_screen.dart';
import 'papers/paper_detail_screen.dart';
import 'posts/post_detail_screen.dart';

enum _HistoryFilter { all, papers, posts }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;
  final ScrollController _historyScrollController = ScrollController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  bool _isLoadingHistory = true;
  String? _profileError;
  String? _historyError;
  _HistoryFilter _historyFilter = _HistoryFilter.all;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _userPapers = [];
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _refreshAllData();
  }

  @override
  void dispose() {
    _historyScrollController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    await Future.wait([_loadProfile(), _loadUserHistory()]);
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _profileError = 'User not authenticated.';
        _profile = null;
      });
      return;
    }

    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });

    try {
      final response = await supabase
          .from('profiles')
          .select('id, username, full_name, bio, avatar_path, created_at, updated_at')
          .eq('id', user.id)
          .maybeSingle();

      final profile = response == null
          ? <String, dynamic>{
              'id': user.id,
              'username': null,
              'full_name': null,
              'bio': null,
              'avatar_path': null,
            }
          : Map<String, dynamic>.from(response);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _usernameController.text = (profile['username'] as String?) ?? '';
        _fullNameController.text = (profile['full_name'] as String?) ?? '';
        _bioController.text = (profile['bio'] as String?) ?? '';
        _isLoadingProfile = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileError = _friendlyProfileError(error);
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadUserHistory() async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _historyError = 'User not authenticated.';
        _userPapers = [];
        _userPosts = [];
        _historyItems = [];
      });
      return;
    }

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final responses = await Future.wait([
        supabase
            .from('papers')
            .select('''
              id,
              title,
              abstract,
              created_at,
              submitted_at,
              reviewed_at,
              published_at,
              status,
              rejection_reason,
              views_count,
              categories (name),
              paper_authors (name)
            ''')
            .eq('user_id', userId)
            .order('created_at', ascending: false),
        supabase
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
            .order('created_at', ascending: false),
      ]);

      final papers = List<Map<String, dynamic>>.from(
        responses[0] as List<dynamic>,
      );
      final posts = List<Map<String, dynamic>>.from(
        responses[1] as List<dynamic>,
      );

      for (final paper in papers) {
        paper['content_type'] = 'paper';
      }
      for (final post in posts) {
        post['content_type'] = 'post';
      }

      final combined = [...papers, ...posts]
        ..sort((a, b) {
          final aDate =
              DateTime.tryParse('${a['created_at']}') ?? DateTime(1970);
          final bDate =
              DateTime.tryParse('${b['created_at']}') ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });

      if (!mounted) return;
      setState(() {
        _userPapers = papers;
        _userPosts = posts;
        _historyItems = combined;
        _isLoadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = error.toString();
        _isLoadingHistory = false;
      });
    }
  }

  Future<bool> _saveProfile({
    String? avatarPathOverride,
    bool clearAvatar = false,
    bool showSuccess = true,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Please sign in again to update your profile.', AppColors.errorDark);
      return false;
    }

    final username = _usernameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final bio = _bioController.text.trim();

    if (username.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(username)) {
      _showMessage(
        'Username must be 3-24 characters and use only letters, numbers, or underscores.',
        AppColors.errorDark,
      );
      return false;
    }

    if (fullName.length > 80) {
      _showMessage('Real name must be 80 characters or fewer.', AppColors.errorDark);
      return false;
    }

    if (bio.length > 240) {
      _showMessage('Bio must be 240 characters or fewer.', AppColors.errorDark);
      return false;
    }

    final nextAvatarPath = clearAvatar
        ? null
        : avatarPathOverride ?? (_profile?['avatar_path'] as String?);

    setState(() {
      _isSavingProfile = true;
      _profileError = null;
    });

    try {
      final payload = <String, dynamic>{
        'id': user.id,
        'username': username.isEmpty ? null : username,
        'full_name': fullName.isEmpty ? null : fullName,
        'bio': bio.isEmpty ? null : bio,
        'avatar_path': nextAvatarPath,
      };

      final savedProfile = await supabase
          .from('profiles')
          .upsert(payload)
          .select('id, username, full_name, bio, avatar_path, created_at, updated_at')
          .single();

      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'username': username,
            'full_name': fullName,
            'bio': bio,
            'avatar_path': nextAvatarPath ?? '',
          },
        ),
      );

      if (!mounted) return false;
      setState(() {
        _profile = Map<String, dynamic>.from(savedProfile);
      });

      if (showSuccess) {
        _showMessage('Profile updated successfully.', AppColors.success);
      }
      return true;
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _profileError = _friendlyProfileError(error);
        });
        _showMessage(_friendlyProfileError(error), AppColors.errorDark);
      }
      return false;
    } catch (error) {
      if (mounted) {
        setState(() {
          _profileError = _friendlyProfileError(error);
        });
        _showMessage(_friendlyProfileError(error), AppColors.errorDark);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Please sign in again to update your profile photo.', AppColors.errorDark);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      if (file.path == null) {
        _showMessage('Could not access the selected image file.', AppColors.errorDark);
        return;
      }

      final extension = p.extension(file.name).toLowerCase();
      final contentType = _contentTypeForExtension(extension);
      if (contentType == null) {
        _showMessage('Please select a JPG, PNG, or WEBP image.', AppColors.errorDark);
        return;
      }

      final storagePath = '${user.id}/avatar$extension';

      setState(() {
        _isUploadingAvatar = true;
        _profileError = null;
      });

      await supabase.storage.from('profile-avatars').upload(
        storagePath,
        File(file.path!),
        fileOptions: FileOptions(
          upsert: true,
          contentType: contentType,
        ),
      );

      final saved = await _saveProfile(
        avatarPathOverride: storagePath,
        showSuccess: false,
      );

      if (!mounted || !saved) return;
      _showMessage('Profile photo updated.', AppColors.success);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileError = _friendlyProfileError(error);
      });
      _showMessage(_friendlyProfileError(error), AppColors.errorDark);
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
      });
    }
  }

  Future<void> _removeAvatar() async {
    final currentAvatarPath = (_profile?['avatar_path'] as String?)?.trim();
    if (currentAvatarPath == null || currentAvatarPath.isEmpty) {
      return;
    }

    setState(() {
      _isUploadingAvatar = true;
      _profileError = null;
    });

    try {
      await supabase.storage.from('profile-avatars').remove([currentAvatarPath]);
    } catch (_) {
      // If the object is already gone, we still want to clear the profile field.
    }

    final saved = await _saveProfile(clearAvatar: true, showSuccess: false);

    if (!mounted) return;
    setState(() {
      _isUploadingAvatar = false;
    });
    if (saved) {
      _showMessage('Profile photo removed.', AppColors.success);
    }
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(initialProfile: _profile),
      ),
    );

    if (updated == true) {
      await _loadProfile();
      if (!mounted) return;
      _showMessage('Profile updated successfully.', AppColors.success);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text('Are you sure you want to sign out?'),
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
        );
      },
    );

    if (confirmed != true) return;

    await supabase.auth.signOut();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showMessage(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNotReadyMessage(String label) {
    _showMessage('$label is not implemented yet.', AppColors.slatePrimary);
  }

  List<Map<String, dynamic>> get _filteredHistoryItems {
    switch (_historyFilter) {
      case _HistoryFilter.papers:
        return _historyItems
            .where((item) => item['content_type'] == 'paper')
            .toList();
      case _HistoryFilter.posts:
        return _historyItems
            .where((item) => item['content_type'] == 'post')
            .toList();
      case _HistoryFilter.all:
        return _historyItems;
    }
  }

  int get _totalViews {
    return _historyItems.fold<int>(
      0,
      (sum, item) => sum + ((item['views_count'] as int?) ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          IconButton(
            onPressed: _refreshAllData,
            tooltip: 'Refresh activity',
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 900;
            final historyHeight = isCompact ? 430.0 : 360.0;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      children: [
                        _buildRetroOverview(
                          user: user,
                          isCompact: isCompact,
                        ),
                        const SizedBox(height: 18),
                        _buildActivityCenter(
                          visibleHistory: _filteredHistoryItems,
                          historyPanelHeight: historyHeight,
                        ),
                        const SizedBox(height: 18),
                        _buildPreferencesCenter(),
                        const SizedBox(height: 18),
                        _buildSessionPanel(user),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRetroOverview({
    required User? user,
    required bool isCompact,
  }) {
    final identityPanel = _buildIdentityPanel(user: user);
    final summaryPanel = _buildSummaryPanel(
      user: user,
      isCompact: isCompact,
    );

    return _buildWindowPanel(
      title: 'PROFILE CONSOLE',
      subtitle: 'Identity, activity totals, and quick controls',
      icon: Icons.person_outline,
      accentColor: AppColors.slatePrimary,
      child: isCompact
          ? Column(
              children: [
                identityPanel,
                const SizedBox(height: 12),
                summaryPanel,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 310, child: identityPanel),
                const SizedBox(width: 12),
                Expanded(child: summaryPanel),
              ],
            ),
    );
  }

  Widget _buildIdentityPanel({required User? user}) {
    final isAdmin = _isAdmin(user);
    final username = (_profile?['username'] as String?)?.trim();
    final fullName = (_profile?['full_name'] as String?)?.trim();
    final primaryLabel = _profileDisplayName(user);
    final secondaryLabel = username != null && username.isNotEmpty
        ? '@$username'
        : user?.email ?? 'Set up your profile';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _innerPanelDecoration(
        backgroundColor: const Color(0xFFE1E6EE),
        borderColor: const Color(0xFFAEB7C4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileAvatar(size: 74),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT USER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      primaryLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      secondaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amberCardBg,
                          border: Border.all(color: AppColors.amberBorder),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.amberDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFactRow('Username', username?.isNotEmpty == true ? '@$username' : 'Not set'),
          const SizedBox(height: 8),
          _buildFactRow('Real Name', fullName?.isNotEmpty == true ? fullName! : 'Not set'),
          const SizedBox(height: 8),
          _buildFactRow('Member Since', _formatDate(user?.createdAt)),
          const SizedBox(height: 8),
          _buildFactRow(
            'User ID',
            user == null ? 'Unavailable' : '${user.id.substring(0, 8)}...',
          ),
          const SizedBox(height: 8),
          _buildFactRow('Mailbox', user?.email ?? 'No email on record'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.slatePrimary,
                side: const BorderSide(color: AppColors.slatePrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel({
    required User? user,
    required bool isCompact,
  }) {
    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildStatCard(
              width: isCompact ? double.infinity : 180,
              label: 'DOCUMENTS',
              value: _userPapers.length.toString(),
              icon: Icons.description_outlined,
              backgroundColor: Colors.white,
              borderColor: AppColors.border,
              accentColor: AppColors.slatePrimary,
            ),
            _buildStatCard(
              width: isCompact ? double.infinity : 180,
              label: 'QUESTIONS',
              value: _userPosts.length.toString(),
              icon: Icons.question_answer_outlined,
              backgroundColor: AppColors.amberCardBg,
              borderColor: AppColors.amberBorder,
              accentColor: AppColors.amberDark,
            ),
            _buildStatCard(
              width: isCompact ? double.infinity : 180,
              label: 'TOTAL VIEWS',
              value: _totalViews.toString(),
              icon: Icons.visibility_outlined,
              backgroundColor: const Color(0xFFE9EFF7),
              borderColor: const Color(0xFFB9C6D8),
              accentColor: AppColors.slatePrimary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _innerPanelDecoration(
            backgroundColor: Colors.white,
            borderColor: const Color(0xFFB5BBC6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'QUICK COMMANDS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildCommandButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profile',
                    onPressed: _openEditProfile,
                    color: AppColors.slatePrimary,
                  ),
                  _buildCommandButton(
                    icon: Icons.refresh,
                    label: 'Refresh Activity',
                    onPressed: _refreshAllData,
                    color: AppColors.slatePrimary,
                    filled: true,
                  ),
                  _buildCommandButton(
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                    onPressed: _showChangePasswordDialog,
                    color: AppColors.slatePrimary,
                  ),
                  _buildCommandButton(
                    icon: Icons.help_outline,
                    label: 'Help',
                    onPressed: () => _showNotReadyMessage('Help & Support'),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFactRow('Joined', _formatDate(user?.createdAt)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCenter({
    required List<Map<String, dynamic>> visibleHistory,
    required double historyPanelHeight,
  }) {
    return _buildWindowPanel(
      title: 'ACTIVITY LEDGER',
      subtitle: 'Your drafts, submissions, published documents, and questions',
      icon: Icons.history,
      accentColor: AppColors.slatePrimary,
      trailing: _buildHistoryFilterBar(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoBadge(
                icon: Icons.inventory_2_outlined,
                label: 'Visible',
                value: '${visibleHistory.length} items',
              ),
              _buildInfoBadge(
                icon: Icons.filter_alt_outlined,
                label: 'Mode',
                value: _historyFilterLabel(_historyFilter),
              ),
              _buildInfoBadge(
                icon: Icons.stacked_line_chart,
                label: 'Lifetime',
                value: '${_historyItems.length} records',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: historyPanelHeight,
            decoration: _innerPanelDecoration(
              backgroundColor: Colors.white,
              borderColor: const Color(0xFFB5BBC6),
            ),
            child: _buildHistoryPanel(visibleHistory),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCustomizationPanel({
    required User? user,
    required bool isCompact,
  }) {
    return _buildWindowPanel(
      title: 'PROFILE STUDIO',
      subtitle: 'Customize your name, handle, photo, and short bio',
      icon: Icons.badge_outlined,
      accentColor: AppColors.slatePrimary,
      child: _isLoadingProfile
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: _innerPanelDecoration(
                backgroundColor: Colors.white,
                borderColor: const Color(0xFFB5BBC6),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Loading your profile...',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : _profileError != null
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _innerPanelDecoration(
                backgroundColor: AppColors.errorSurface,
                borderColor: AppColors.errorBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile setup is unavailable',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.errorDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _profileError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.errorDark,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loadProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : isCompact
          ? Column(
              children: [
                _buildProfileCard(user),
                const SizedBox(height: 12),
                _buildProfileEditor(user),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: _buildProfileCard(user)),
                const SizedBox(width: 12),
                Expanded(child: _buildProfileEditor(user)),
              ],
            ),
    );
  }

  Widget _buildProfileCard(User? user) {
    final username = (_profile?['username'] as String?)?.trim();
    final fullName = (_profile?['full_name'] as String?)?.trim();
    final bio = (_profile?['bio'] as String?)?.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _innerPanelDecoration(
        backgroundColor: const Color(0xFFE1E6EE),
        borderColor: const Color(0xFFAEB7C4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: _buildProfileAvatar(size: 124),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _profileDisplayName(user),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              username != null && username.isNotEmpty
                  ? '@$username'
                  : 'No username yet',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildFactRow('Real Name', fullName?.isNotEmpty == true ? fullName! : 'Not set'),
          const SizedBox(height: 8),
          _buildFactRow('Email', user?.email ?? 'No email on record'),
          const SizedBox(height: 8),
          _buildFactRow(
            'Bio',
            bio?.isNotEmpty == true ? bio! : 'Introduce yourself to the research community.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCommandButton(
                icon: Icons.photo_camera_back_outlined,
                label: _isUploadingAvatar ? 'Uploading...' : 'Change Photo',
                onPressed: _isUploadingAvatar ? null : _pickAvatar,
                color: AppColors.slatePrimary,
                filled: true,
              ),
              if (_avatarUrl != null)
                _buildCommandButton(
                  icon: Icons.delete_outline,
                  label: 'Remove Photo',
                  onPressed: _isUploadingAvatar ? null : _removeAvatar,
                  color: AppColors.errorDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileEditor(User? user) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _innerPanelDecoration(
        backgroundColor: Colors.white,
        borderColor: const Color(0xFFB5BBC6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EDIT PUBLIC PROFILE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _buildDialogFieldLabel('Username'),
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'your_handle',
              prefixText: '@',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '3-24 characters. Letters, numbers, and underscores only.',
            style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
          ),
          const SizedBox(height: 14),
          _buildDialogFieldLabel('Real Name'),
          TextField(
            controller: _fullNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Your actual name or research alias',
            ),
          ),
          const SizedBox(height: 14),
          _buildDialogFieldLabel('Short Bio'),
          TextField(
            controller: _bioController,
            minLines: 3,
            maxLines: 5,
            maxLength: 240,
            decoration: const InputDecoration(
              hintText: 'Share your field, interests, or what you research.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildCommandButton(
                icon: Icons.save_outlined,
                label: _isSavingProfile ? 'Saving...' : 'Save Profile',
                onPressed: _isSavingProfile || _isUploadingAvatar
                    ? null
                    : () => _saveProfile(),
                color: AppColors.slatePrimary,
                filled: true,
              ),
              _buildCommandButton(
                icon: Icons.refresh,
                label: 'Reload',
                onPressed: _isSavingProfile || _isUploadingAvatar
                    ? null
                    : _loadProfile,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFactRow(
            'Display Name',
            _profileDisplayName(user),
          ),
          const SizedBox(height: 8),
          _buildFactRow(
            'Comment Label',
            _profileCommentLabel(user),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCenter() {
    return _buildWindowPanel(
      title: 'SETTINGS DRAWER',
      subtitle: 'Preferences, security, and support',
      icon: Icons.tune,
      accentColor: AppColors.slatePrimary,
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Configure your notification preferences',
            accentColor: AppColors.slatePrimary,
            onTap: () => _showNotReadyMessage('Notifications'),
          ),
          const SizedBox(height: 10),
          _buildSettingItem(
            icon: Icons.lock_outline,
            title: 'Password',
            subtitle: 'Update your account password',
            accentColor: AppColors.slatePrimary,
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 10),
          _buildSettingItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle: 'Manage privacy and visibility controls',
            accentColor: AppColors.slatePrimary,
            onTap: () => _showNotReadyMessage('Privacy settings'),
          ),
          const SizedBox(height: 10),
          _buildSettingItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Find guidance and contact support',
            accentColor: AppColors.slatePrimary,
            onTap: () => _showNotReadyMessage('Help & Support'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPanel(User? user) {
    return _buildWindowPanel(
      title: 'SESSION',
      subtitle: 'Current sign-in and account controls',
      icon: Icons.logout,
      accentColor: AppColors.errorDark,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _innerPanelDecoration(
          backgroundColor: const Color(0xFFF7F7F4),
          borderColor: const Color(0xFFB5BBC6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Signed in as:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              user?.email ?? 'Unknown User',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildFactRow(
              'User ID',
              user == null ? 'Unavailable' : '${user.id.substring(0, 8)}...',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorDark,
                  side: const BorderSide(color: AppColors.errorDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePasswordDialog(),
    );

    if (changed == true && mounted) {
      _showMessage('Password changed successfully!', AppColors.success);
    }
  }

  // ─── Shared panel / UI components ────────────────────────────────────────

  Widget _buildWindowPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF7E8794)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 0,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accentColor, accentColor.withOpacity(0.84)],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withOpacity(0.18),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFECECE7),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _innerPanelDecoration({
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14FFFFFF),
          blurRadius: 0,
          offset: Offset(-1, -1),
        ),
      ],
    );
  }

  Widget _buildHistoryFilterBar() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildFilterTab(
          label: 'All',
          selected: _historyFilter == _HistoryFilter.all,
          onTap: () => setState(() => _historyFilter = _HistoryFilter.all),
        ),
        _buildFilterTab(
          label: 'Documents',
          selected: _historyFilter == _HistoryFilter.papers,
          onTap: () => setState(() => _historyFilter = _HistoryFilter.papers),
        ),
        _buildFilterTab(
          label: 'Questions',
          selected: _historyFilter == _HistoryFilter.posts,
          onTap: () => setState(() => _historyFilter = _HistoryFilter.posts),
        ),
      ],
    );
  }

  Widget _buildFilterTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFD7DCE4),
          border: Border.all(
            color: selected ? Colors.white : const Color(0xFF98A3B1),
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1FFFFFFF),
                    blurRadius: 0,
                    offset: Offset(-1, -1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.slatePrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _innerPanelDecoration(
        backgroundColor: Colors.white,
        borderColor: const Color(0xFFB5BBC6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.slatePrimary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommandButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    bool filled = false,
  }) {
    return SizedBox(
      height: 36,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: filled ? Colors.white : color,
          backgroundColor: filled ? color : Colors.white,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildFactRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _innerPanelDecoration(
        backgroundColor: Colors.white.withOpacity(0.88),
        borderColor: const Color(0xFFD0D4DB),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: _innerPanelDecoration(
            backgroundColor: Colors.white,
            borderColor: const Color(0xFFB5BBC6),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryPanel(List<Map<String, dynamic>> visibleHistory) {
    if (_isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
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
      controller: _historyScrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _historyScrollController,
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
                status: '${item['status'] ?? PaperReviewStatus.draft}',
                rejectionReason: item['rejection_reason'] as String?,
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
            onPressed: _refreshAllData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    final title = switch (_historyFilter) {
      _HistoryFilter.papers => 'No documents yet',
      _HistoryFilter.posts => 'No questions yet',
      _HistoryFilter.all => 'No history yet',
    };

    final subtitle = switch (_historyFilter) {
      _HistoryFilter.papers =>
        'Your drafts, review submissions, and published documents appear here.',
      _HistoryFilter.posts => 'Questions you post will appear here.',
      _HistoryFilter.all =>
        'Your document workflow and posted questions will appear here.',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _innerPanelDecoration(
        backgroundColor: Colors.white,
        borderColor: AppColors.border,
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
    required double width,
    required String label,
    required String value,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Color accentColor,
  }) {
    return SizedBox(
      width: width.isFinite ? width : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _innerPanelDecoration(
          backgroundColor: backgroundColor,
          borderColor: borderColor,
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    required String status,
    required String? rejectionReason,
  }) {
    final preview =
        abstract.trim().isEmpty ? 'No abstract provided.' : abstract;

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
        decoration: _innerPanelDecoration(
          backgroundColor: Colors.white,
          borderColor: AppColors.border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PaperReviewStatus.icon(status),
                  size: 16,
                  color: PaperReviewStatus.textColor(status),
                ),
                const SizedBox(width: 6),
                Text(
                  'Document',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PaperReviewStatus.textColor(status),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                _buildPaperStatusTag(status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (PaperReviewStatus.normalize(status) ==
                    PaperReviewStatus.rejected &&
                rejectionReason != null &&
                rejectionReason.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  border: Border.all(color: AppColors.errorBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Admin feedback: $rejectionReason',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.errorDark,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetaTag(
                  label: category,
                  textColor: AppColors.slatePrimary,
                  backgroundColor: AppColors.surfaceLight,
                  borderColor: AppColors.border,
                ),
                const SizedBox(width: 8),
                if (PaperReviewStatus.isPublished(status)) ...[
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
                ] else
                  Expanded(
                    child: Text(
                      PaperReviewStatus.ownerDescription(status),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
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
        decoration: _innerPanelDecoration(
          backgroundColor: AppColors.amberCardBg,
          borderColor: AppColors.amberBorder,
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
                    fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              preview.length > 150
                  ? '${preview.substring(0, 150)}...'
                  : preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetaTag(
                  label: category,
                  textColor: AppColors.amberDark,
                  backgroundColor: AppColors.amberSurface,
                  borderColor: AppColors.amberBorder,
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

  Widget _buildMetaTag({
    required String label,
    required Color textColor,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPaperStatusTag(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PaperReviewStatus.backgroundColor(status),
        border: Border.all(color: PaperReviewStatus.borderColor(status)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        PaperReviewStatus.label(status),
        style: TextStyle(
          fontSize: 11,
          color: PaperReviewStatus.textColor(status),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProfileAvatar({required double size}) {
    final avatarUrl = _avatarUrl;
    final displayName = _profileDisplayName(supabase.auth.currentUser);
    final initials = displayName.isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.slatePrimary, Color(0xFF73829B)],
        ),
        border: Border.all(color: const Color(0xFF3F4857)),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (avatarUrl != null)
            Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildAvatarFallback(initials, size),
            )
          else
            _buildAvatarFallback(initials, size),
          if (_isUploadingAvatar)
            Container(
              color: Colors.black.withOpacity(0.28),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String initials, double size) {
    final fontSize = size >= 100 ? 34.0 : 28.0;
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  String _profileDisplayName(User? user) {
    final fullName = (_profile?['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final username = (_profile?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    return user?.email ?? 'Unknown User';
  }

  String _profileCommentLabel(User? user) {
    final fullName = (_profile?['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final username = (_profile?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }

    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Researcher';
  }

  String? get _avatarUrl {
    final avatarPath = (_profile?['avatar_path'] as String?)?.trim();
    if (avatarPath == null || avatarPath.isEmpty) {
      return null;
    }

    final updatedAt = (_profile?['updated_at'] as String?) ?? '';
    final publicUrl = supabase.storage.from('profile-avatars').getPublicUrl(
      avatarPath,
    );
    return '$publicUrl?v=${Uri.encodeComponent(updatedAt)}';
  }

  String? _contentTypeForExtension(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  String _friendlyProfileError(Object error) {
    final message = error.toString();
    if (message.contains('duplicate key') ||
        message.contains('idx_profiles_username_unique')) {
      return 'That username is already taken. Try another one.';
    }
    if (message.contains('profile-avatars')) {
      return 'Profile photo storage is not ready yet. Run profiles_setup.sql in Supabase first.';
    }
    if (message.contains('profiles')) {
      return 'Profile customization is not ready yet. Run profiles_setup.sql in Supabase first.';
    }
    return 'Unable to update profile right now.';
  }

  String _historyFilterLabel(_HistoryFilter filter) {
    switch (filter) {
      case _HistoryFilter.all:
        return 'All activity';
      case _HistoryFilter.papers:
        return 'Documents only';
      case _HistoryFilter.posts:
        return 'Questions only';
    }
  }

  String _getAuthors(List<dynamic>? authors) {
    if (authors == null || authors.isEmpty) return 'Unknown Author';
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

      if (difference.inDays == 0) return 'Today';
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Unknown';
    }
  }

  bool _isAdmin(User? user) {
    final role = user?.appMetadata['role'];
    return role is String && role.toLowerCase() == 'admin';
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final supabase = Supabase.instance.client;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = supabase.auth.currentUser?.email;
      if (email == null) {
        throw Exception('User not logged in');
      }

      await supabase.auth.signInWithPassword(
        email: email,
        password: _currentPasswordController.text,
      );

      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (!mounted) return;
      FocusScope.of(context).unfocus();
      Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, AppColors.errorDark);
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('Error: ${error.toString()}', AppColors.errorDark);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Dialog(
      insetPadding: EdgeInsets.fromLTRB(
        16,
        24,
        16,
        24 + viewInsets.bottom,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.slatePrimary, Color(0xFF66758D)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Change Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ChangePasswordFieldLabel('Current Password'),
                      TextFormField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Enter current password',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const _ChangePasswordFieldLabel('New Password'),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Enter new password',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value.length < 6) {
                            return 'Must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      const _ChangePasswordFieldLabel('Confirm New Password'),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                        decoration: const InputDecoration(
                          hintText: 'Confirm new password',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (value != _newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              Navigator.of(context).pop(false);
                            },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Save Password'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordFieldLabel extends StatelessWidget {
  const _ChangePasswordFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
