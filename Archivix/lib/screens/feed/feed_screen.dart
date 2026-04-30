import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/content_engagement_service.dart';
import '../papers/paper_detail_screen.dart';
import '../posts/post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback onNavigateToSettings;

  const FeedScreen({super.key, required this.onNavigateToSettings});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final supabase = Supabase.instance.client;
  final _engagementService = ContentEngagementService();
  final Set<String> _pendingReactionKeys = <String>{};
  List<Map<String, dynamic>> _papers = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _combinedItems = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all'; // 'all', 'papers', 'posts'
  String _sortMode = 'recent'; // 'recent', 'popular', 'quality'

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> papers = [];
      List<Map<String, dynamic>> posts = [];

      // Load papers if needed
      if (_filter == 'all' || _filter == 'papers') {
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
            .eq('status', 'published')
            .order('created_at', ascending: false)
            .limit(100);

        papers = List<Map<String, dynamic>>.from(papersResponse);
        // Add type marker
        for (var paper in papers) {
          paper['content_type'] = 'paper';
        }
      }

      // Load posts if needed
      if (_filter == 'all' || _filter == 'posts') {
        final postsResponse = await supabase
            .from('posts')
            .select('''
              id,
              title,
              content,
              created_at,
              views_count,
              user_id,
              categories (name)
            ''')
            .order('created_at', ascending: false)
            .limit(100);

        posts = List<Map<String, dynamic>>.from(postsResponse);
        // Add type marker
        for (var post in posts) {
          post['content_type'] = 'post';
        }
      }

      await _attachEngagementData(papers, 'paper');
      await _attachEngagementData(posts, 'post');

      List<Map<String, dynamic>> combined = [...papers, ...posts];
      _sortCombinedItems(combined);

      if (mounted) {
        setState(() {
          _papers = papers;
          _posts = posts;
          _combinedItems = combined;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getAuthors(List<dynamic>? authors) {
    if (authors == null || authors.isEmpty) return 'Unknown Author';

    final names = authors.map((a) => a['name'] as String).toList();
    if (names.length == 1) return names[0];
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names[0]} et al.';
  }

  Future<void> _attachEngagementData(
    List<Map<String, dynamic>> items,
    String contentType,
  ) async {
    if (items.isEmpty) return;

    final summaries = await _engagementService.loadSummaries(
      contentType: contentType,
      contentIds: items.map((item) => '${item['id']}').toList(),
      userId: supabase.auth.currentUser?.id,
    );

    for (final item in items) {
      final summary =
          summaries['${item['id']}'] ?? const ContentEngagementSummary();
      _applyEngagementSummary(item, summary);
    }
  }

  void _applyEngagementSummary(
    Map<String, dynamic> item,
    ContentEngagementSummary summary,
  ) {
    final viewsCount = item['views_count'] ?? 0;
    item['likes_count'] = summary.likesCount;
    item['dislikes_count'] = summary.dislikesCount;
    item['user_reaction'] = summary.userReaction;
    item['popularity_score'] = _engagementService.popularityScore(
      likesCount: summary.likesCount,
      dislikesCount: summary.dislikesCount,
      viewsCount: viewsCount,
    );
    item['quality_score'] = _engagementService.qualityScore(
      likesCount: summary.likesCount,
      dislikesCount: summary.dislikesCount,
      viewsCount: viewsCount,
    );
  }

  ContentEngagementSummary _summaryFromItem(Map<String, dynamic> item) {
    return ContentEngagementSummary(
      likesCount: item['likes_count'] ?? 0,
      dislikesCount: item['dislikes_count'] ?? 0,
      userReaction: item['user_reaction'],
    );
  }

  String _reactionKey(String contentType, String contentId) {
    return '$contentType:$contentId';
  }

  void _sortCombinedItems(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      if (_sortMode == 'popular') {
        final scoreCompare = (b['popularity_score'] ?? 0).compareTo(
          a['popularity_score'] ?? 0,
        );
        if (scoreCompare != 0) return scoreCompare;
      } else if (_sortMode == 'quality') {
        final scoreCompare = (b['quality_score'] ?? 0).compareTo(
          a['quality_score'] ?? 0,
        );
        if (scoreCompare != 0) return scoreCompare;
      }

      final aDate = DateTime.tryParse('${a['created_at']}') ?? DateTime(1970);
      final bDate = DateTime.tryParse('${b['created_at']}') ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
  }

  Future<void> _handleFeedReaction({
    required String contentType,
    required String contentId,
    required int reactionValue,
  }) async {
    final key = _reactionKey(contentType, contentId);
    if (_pendingReactionKeys.contains(key)) {
      return;
    }

    Map<String, dynamic>? referenceItem;
    for (final item in _combinedItems) {
      if (item['content_type'] == contentType && '${item['id']}' == contentId) {
        referenceItem = item;
        break;
      }
    }

    if (referenceItem == null) {
      return;
    }

    final previousSummary = _summaryFromItem(referenceItem);
    final optimisticSummary = previousSummary.toggledReaction(reactionValue);

    if (mounted) {
      setState(() {
        _pendingReactionKeys.add(key);
        for (final collection in [_papers, _posts, _combinedItems]) {
          for (final item in collection) {
            if (item['content_type'] == contentType &&
                '${item['id']}' == contentId) {
              _applyEngagementSummary(item, optimisticSummary);
            }
          }
        }

        _sortCombinedItems(_combinedItems);
      });
    }

    try {
      final summary = await _engagementService.toggleReaction(
        contentType: contentType,
        contentId: contentId,
        reactionValue: reactionValue,
      );

      if (!mounted) return;

      setState(() {
        for (final collection in [_papers, _posts, _combinedItems]) {
          for (final item in collection) {
            if (item['content_type'] == contentType &&
                '${item['id']}' == contentId) {
              _applyEngagementSummary(item, summary);
            }
          }
        }

        _pendingReactionKeys.remove(key);
        _sortCombinedItems(_combinedItems);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        for (final collection in [_papers, _posts, _combinedItems]) {
          for (final item in collection) {
            if (item['content_type'] == contentType &&
                '${item['id']}' == contentId) {
              _applyEngagementSummary(item, previousSummary);
            }
          }
        }

        _pendingReactionKeys.remove(key);
        _sortCombinedItems(_combinedItems);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.errorDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final isEmailConfirmed = user?.emailConfirmedAt != null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.archive, size: 20),
            const SizedBox(width: 8),
            const Text('ArchivIX'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadContent,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadContent,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Email verification reminder banner
            if (!isEmailConfirmed)
              InkWell(
                onTap: widget.onNavigateToSettings,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.amberSurface,
                    border: Border.all(color: AppColors.amberBorder),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.amberDark,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Email Not Verified',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.amberDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Check your email or tap here to resend verification.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.amberDark.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: AppColors.amberDark,
                      ),
                    ],
                  ),
                ),
              ),

            // Welcome banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slateBanner,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.textSecondary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'User',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section header with filters
            Row(
              children: [
                Container(width: 3, height: 20, color: AppColors.slatePrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sortMode == 'popular'
                        ? 'Popular Activity'
                        : _sortMode == 'quality'
                        ? 'Quality Activity'
                        : 'Recent Activity',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownShell(
                    child: DropdownButton<String>(
                      value: _sortMode,
                      underline: const SizedBox(),
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(
                        Icons.auto_graph,
                        size: 16,
                        color: AppColors.slatePrimary,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'recent',
                          child: Text('Recent'),
                        ),
                        DropdownMenuItem(
                          value: 'popular',
                          child: Text('Popular'),
                        ),
                        DropdownMenuItem(
                          value: 'quality',
                          child: Text('Quality'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _sortMode = value;
                          _sortCombinedItems(_combinedItems);
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownShell(
                    child: DropdownButton<String>(
                      value: _filter,
                      underline: const SizedBox(),
                      isExpanded: true,
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
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Content'),
                        ),
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
                          _filter = value;
                        });
                        _loadContent();
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_combinedItems.length} items',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),

            // Papers list
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Container(
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
                    Text(
                      'Error loading papers',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.errorDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadContent,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_combinedItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: AppColors.textSubtle,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _filter == 'papers'
                          ? 'No papers yet'
                          : _filter == 'posts'
                          ? 'No questions yet'
                          : 'No content yet',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _filter == 'papers'
                          ? 'Be the first to submit a paper!'
                          : _filter == 'posts'
                          ? 'Be the first to ask a question!'
                          : 'Be the first to contribute!',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._combinedItems.map((item) {
                final contentType = item['content_type'];

                if (contentType == 'paper') {
                  final category = item['categories'] as Map<String, dynamic>?;
                  final authors = item['paper_authors'] as List<dynamic>?;
                  final reactionKey = _reactionKey('paper', '${item['id']}');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPaperCard(
                      paperId: item['id'],
                      title: item['title'],
                      authors: _getAuthors(authors),
                      category: category?['name'] ?? 'Uncategorized',
                      date: _formatDate(item['created_at']),
                      views: item['views_count'] ?? 0,
                      abstract: item['abstract'],
                      likesCount: item['likes_count'] ?? 0,
                      dislikesCount: item['dislikes_count'] ?? 0,
                      userReaction: item['user_reaction'],
                      isReactionPending: _pendingReactionKeys.contains(
                        reactionKey,
                      ),
                      onLike: () => _handleFeedReaction(
                        contentType: 'paper',
                        contentId: '${item['id']}',
                        reactionValue: 1,
                      ),
                      onDislike: () => _handleFeedReaction(
                        contentType: 'paper',
                        contentId: '${item['id']}',
                        reactionValue: -1,
                      ),
                    ),
                  );
                } else {
                  // Post card
                  final category = item['categories'] as Map<String, dynamic>?;
                  final reactionKey = _reactionKey('post', '${item['id']}');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPostCard(
                      postId: item['id'],
                      title: item['title'],
                      content: item['content'],
                      category: category?['name'] ?? 'Uncategorized',
                      date: _formatDate(item['created_at']),
                      views: item['views_count'] ?? 0,
                      likesCount: item['likes_count'] ?? 0,
                      dislikesCount: item['dislikes_count'] ?? 0,
                      userReaction: item['user_reaction'],
                      isReactionPending: _pendingReactionKeys.contains(
                        reactionKey,
                      ),
                      onLike: () => _handleFeedReaction(
                        contentType: 'post',
                        contentId: '${item['id']}',
                        reactionValue: 1,
                      ),
                      onDislike: () => _handleFeedReaction(
                        contentType: 'post',
                        contentId: '${item['id']}',
                        reactionValue: -1,
                      ),
                    ),
                  );
                }
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperCard({
    required String paperId,
    required String title,
    required String authors,
    required String category,
    required String date,
    required int views,
    required String abstract,
    required int likesCount,
    required int dislikesCount,
    required int? userReaction,
    required bool isReactionPending,
    required VoidCallback onLike,
    required VoidCallback onDislike,
  }) {
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
              abstract.length > 150
                  ? '${abstract.substring(0, 150)}...'
                  : abstract,
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
            const SizedBox(height: 12),
            Row(
              children: [
                _buildReactionButton(
                  icon: Icons.thumb_up_alt_outlined,
                  activeIcon: Icons.thumb_up_alt,
                  count: likesCount,
                  isActive: userReaction == 1,
                  isPending: isReactionPending,
                  activeColor: AppColors.success,
                  onTap: isReactionPending ? null : onLike,
                ),
                const SizedBox(width: 8),
                _buildReactionButton(
                  icon: Icons.thumb_down_alt_outlined,
                  activeIcon: Icons.thumb_down_alt,
                  count: dislikesCount,
                  isActive: userReaction == -1,
                  isPending: isReactionPending,
                  activeColor: AppColors.errorDark,
                  onTap: isReactionPending ? null : onDislike,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard({
    required String postId,
    required String title,
    required String content,
    required String category,
    required String date,
    required int views,
    required int likesCount,
    required int dislikesCount,
    required int? userReaction,
    required bool isReactionPending,
    required VoidCallback onLike,
    required VoidCallback onDislike,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.amberCardBg, // Light yellow tint to differentiate
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
              content.length > 150
                  ? '${content.substring(0, 150)}...'
                  : content,
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
            const SizedBox(height: 12),
            Row(
              children: [
                _buildReactionButton(
                  icon: Icons.thumb_up_alt_outlined,
                  activeIcon: Icons.thumb_up_alt,
                  count: likesCount,
                  isActive: userReaction == 1,
                  isPending: isReactionPending,
                  activeColor: AppColors.success,
                  onTap: isReactionPending ? null : onLike,
                ),
                const SizedBox(width: 8),
                _buildReactionButton(
                  icon: Icons.thumb_down_alt_outlined,
                  activeIcon: Icons.thumb_down_alt,
                  count: dislikesCount,
                  isActive: userReaction == -1,
                  isPending: isReactionPending,
                  activeColor: AppColors.errorDark,
                  onTap: isReactionPending ? null : onDislike,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.slatePrimary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }

  Widget _buildReactionButton({
    required IconData icon,
    required IconData activeIcon,
    required int count,
    required bool isActive,
    required bool isPending,
    required Color activeColor,
    required VoidCallback? onTap,
  }) {
    final color = isActive ? activeColor : AppColors.textMuted;
    final backgroundColor = isActive
        ? activeColor.withValues(alpha: 0.12)
        : AppColors.surfaceLight;

    return Material(
      color: Colors.transparent,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isPending ? 0.65 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(
                color: isActive
                    ? activeColor.withValues(alpha: 0.3)
                    : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isActive ? activeIcon : icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
