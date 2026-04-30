import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/paper_review_status.dart';
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

  bool _isLoadingHistory = true;
  String? _historyError;
  _HistoryFilter _historyFilter = _HistoryFilter.all;
  bool _isLoadingAdminQueue = false;
  bool _isProcessingAdminAction = false;
  String? _adminQueueError;

  List<Map<String, dynamic>> _userPapers = [];
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _historyItems = [];
  List<Map<String, dynamic>> _adminQueuePapers = [];

  @override
  void initState() {
    super.initState();
    _refreshAllData();
  }

  Future<void> _refreshAllData() async {
    await _loadUserHistory();
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

  Future<void> _loadAdminQueue() async {
    if (!_isAdmin(supabase.auth.currentUser)) return;

    setState(() {
      _isLoadingAdminQueue = true;
      _adminQueueError = null;
    });

    try {
      final response = await supabase
          .from('papers')
          .select('''
            id,
            title,
            abstract,
            created_at,
            submitted_at,
            status,
            rejection_reason,
            user_id,
            categories (name),
            paper_authors (name)
          ''')
          .inFilter('status', PaperReviewStatus.reviewQueueStatuses)
          .order('submitted_at', ascending: true)
          .order('created_at', ascending: true);

      if (!mounted) return;

      setState(() {
        _adminQueuePapers = List<Map<String, dynamic>>.from(response);
        _isLoadingAdminQueue = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _adminQueueError = error.toString();
        _isLoadingAdminQueue = false;
      });
    }
  }

  Future<void> _updatePaperReviewStatus({
    required String paperId,
    required String targetStatus,
    String? rejectionReason,
  }) async {
    if (_isProcessingAdminAction) return;

    setState(() {
      _isProcessingAdminAction = true;
    });

    try {
      final payload = <String, dynamic>{
        'status': targetStatus,
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': supabase.auth.currentUser?.id,
        'rejection_reason': null,
      };

      if (targetStatus == PaperReviewStatus.underReview) {
        payload['published_at'] = null;
      } else if (targetStatus == PaperReviewStatus.published) {
        payload['published_at'] = DateTime.now().toIso8601String();
      } else if (targetStatus == PaperReviewStatus.rejected) {
        payload['published_at'] = null;
        payload['rejection_reason'] = rejectionReason?.trim();
      }

      await supabase.from('papers').update(payload).eq('id', paperId);
      await Future.wait([_loadAdminQueue(), _loadUserHistory()]);

      if (!mounted) return;
      _showMessage(
        'Document moved to ${PaperReviewStatus.label(targetStatus)}.',
        targetStatus == PaperReviewStatus.rejected
            ? AppColors.errorDark
            : AppColors.success,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not update review status: $error', AppColors.errorDark);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAdminAction = false;
        });
      }
    }
  }

  Future<void> _showRejectDialog(Map<String, dynamic> paper) async {
    final controller = TextEditingController();

    Future<void> dismissDialogSafely(
      BuildContext dialogContext, {
      String? result,
    }) async {
      FocusScope.of(dialogContext).unfocus();
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop(result);
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text('Reject Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${paper['title'] ?? 'Untitled Document'}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add a short reason so the author knows what to fix.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Example: Please improve the abstract and replace the PDF with the final revision.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async => dismissDialogSafely(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  return;
                }
                await dismissDialogSafely(dialogContext, result: value);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorDark,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null || reason.trim().isEmpty) return;

    await _updatePaperReviewStatus(
      paperId: '${paper['id']}',
      targetStatus: PaperReviewStatus.rejected,
      rejectionReason: reason,
    );
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
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.slatePrimary, Color(0xFF73829B)],
                  ),
                  border: Border.all(color: const Color(0xFF3F4857)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.person_2_outlined,
                  size: 38,
                  color: Colors.white,
                ),
              ),
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
                      user?.email ?? 'Unknown User',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
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
          _buildFactRow('Member Since', _formatDate(user?.createdAt)),
          const SizedBox(height: 8),
          _buildFactRow(
            'User ID',
            user == null ? 'Unavailable' : '${user.id.substring(0, 8)}...',
          ),
          const SizedBox(height: 8),
          _buildFactRow('Mailbox', user?.email ?? 'No email on record'),
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

  Widget _buildAdminReviewCenter() {
    return _buildWindowPanel(
      title: 'REVIEW QUEUE',
      subtitle: 'Admin review for submitted documents',
      icon: Icons.fact_check_outlined,
      accentColor: AppColors.amberDark,
      trailing: _buildInfoBadge(
        icon: Icons.inventory_2_outlined,
        label: 'Pending',
        value: '${_adminQueuePapers.length} docs',
      ),
      child: Container(
        height: 320,
        decoration: _innerPanelDecoration(
          backgroundColor: Colors.white,
          borderColor: const Color(0xFFB5BBC6),
        ),
        child: _buildAdminQueuePanel(),
      ),
    );
  }

  Widget _buildAdminQueuePanel() {
    if (_isLoadingAdminQueue) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_adminQueueError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.errorDark,
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                _adminQueueError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.errorDark,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadAdminQueue,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_adminQueuePapers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                color: AppColors.textSubtle,
                size: 40,
              ),
              SizedBox(height: 10),
              Text(
                'No documents waiting for review',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _adminQueuePapers.length,
        itemBuilder: (context, index) {
          final paper = _adminQueuePapers[index];
          final status = PaperReviewStatus.normalize(paper['status']);
          final category = paper['categories'] as Map<String, dynamic>?;
          final authors = paper['paper_authors'] as List<dynamic>?;
          final abstract = '${paper['abstract'] ?? ''}'.trim();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: _innerPanelDecoration(
              backgroundColor: AppColors.surfaceWhite,
              borderColor: PaperReviewStatus.borderColor(status),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${paper['title'] ?? 'Untitled Document'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getAuthors(authors),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPaperStatusTag(status),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaTag(
                      label: category?['name'] ?? 'Uncategorized',
                      textColor: AppColors.slatePrimary,
                      backgroundColor: AppColors.surfaceLight,
                      borderColor: AppColors.border,
                    ),
                    _buildMetaTag(
                      label: 'Owner ${('${paper['user_id']}').substring(0, 8)}',
                      textColor: AppColors.textSecondary,
                      backgroundColor: Colors.white,
                      borderColor: AppColors.border,
                    ),
                    _buildMetaTag(
                      label:
                          'Submitted ${_formatHistoryDate('${paper['submitted_at'] ?? paper['created_at']}')}',
                      textColor: AppColors.textSecondary,
                      backgroundColor: Colors.white,
                      borderColor: AppColors.border,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  abstract.isEmpty
                      ? 'No abstract provided yet.'
                      : (abstract.length > 160
                            ? '${abstract.substring(0, 160)}...'
                            : abstract),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (status != PaperReviewStatus.underReview)
                      _buildCommandButton(
                        icon: Icons.rule_folder_outlined,
                        label: 'Under Review',
                        onPressed: _isProcessingAdminAction
                            ? null
                            : () => _updatePaperReviewStatus(
                                paperId: '${paper['id']}',
                                targetStatus: PaperReviewStatus.underReview,
                              ),
                        color: AppColors.slatePrimary,
                      ),
                    _buildCommandButton(
                      icon: Icons.verified_outlined,
                      label: 'Publish',
                      onPressed: _isProcessingAdminAction
                          ? null
                          : () => _updatePaperReviewStatus(
                              paperId: '${paper['id']}',
                              targetStatus: PaperReviewStatus.published,
                            ),
                      color: AppColors.success,
                      filled: true,
                    ),
                    _buildCommandButton(
                      icon: Icons.block_outlined,
                      label: 'Reject',
                      onPressed: _isProcessingAdminAction
                          ? null
                          : () => _showRejectDialog(paper),
                      color: AppColors.errorDark,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isLoading = false;
    Future<void> dismissDialogSafely(BuildContext dialogContext) async {
      FocusScope.of(dialogContext).unfocus();
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop();
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: AppColors.border),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogFieldLabel('Current Password'),
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
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
                    _buildDialogFieldLabel('New Password'),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
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
                    _buildDialogFieldLabel('Confirm New Password'),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Confirm new password',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async => dismissDialogSafely(dialogContext),
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

                          setDialogState(() => isLoading = true);

                          try {
                            final email = supabase.auth.currentUser?.email;
                            if (email == null) {
                              throw Exception('User not logged in');
                            }

                            await supabase.auth.signInWithPassword(
                              email: email,
                              password: currentPasswordController.text,
                            );

                            await supabase.auth.updateUser(
                              UserAttributes(
                                password: newPasswordController.text,
                              ),
                            );

                            if (!mounted || !dialogContext.mounted) return;
                            await dismissDialogSafely(dialogContext);
                            if (!mounted) return;
                            _showMessage(
                              'Password changed successfully!',
                              AppColors.success,
                            );
                          } on AuthException catch (error) {
                            if (!mounted) return;
                            _showMessage(error.message, AppColors.errorDark);
                            setDialogState(() => isLoading = false);
                          } catch (error) {
                            if (!mounted) return;
                            _showMessage(
                              'Error: ${error.toString()}',
                              AppColors.errorDark,
                            );
                            setDialogState(() => isLoading = false);
                          }
                        },
                  child: isLoading
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
            );
          },
        );
      },
    ).whenComplete(() {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
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
