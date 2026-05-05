import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/services/paper_comment_service.dart';
import '../core/services/post_comment_service.dart';
import 'papers/paper_detail_screen.dart';
import 'posts/post_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.initialProfile,
  });

  final String userId;
  final Map<String, dynamic>? initialProfile;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _paperCommentService = PaperCommentService();
  final _postCommentService = PostCommentService();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _papers = [];
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile == null
        ? null
        : Map<String, dynamic>.from(widget.initialProfile!);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final responses = await Future.wait<dynamic>([
        _supabase
            .from('profiles')
            .select(
              'id, username, full_name, bio, avatar_path, created_at, updated_at',
            )
            .eq('id', widget.userId)
            .maybeSingle(),
        _supabase
            .from('papers')
            .select('''
              id,
              title,
              abstract,
              created_at,
              published_at,
              views_count,
              categories (name),
              paper_authors (name)
            ''')
            .eq('user_id', widget.userId)
            .eq('status', 'published')
            .order('published_at', ascending: false)
            .order('created_at', ascending: false),
        _supabase
            .from('posts')
            .select('''
              id,
              title,
              content,
              created_at,
              views_count,
              categories (name)
            ''')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: false),
      ]);

      final profileResponse = responses[0] as Map<String, dynamic>?;
      final papers = List<Map<String, dynamic>>.from(responses[1] as List);
      final posts = List<Map<String, dynamic>>.from(responses[2] as List);
      await _paperCommentService.attachCommentCounts(papers);
      await _postCommentService.attachCommentCounts(posts);

      if (!mounted) return;

      setState(() {
        _profile = profileResponse == null
            ? (_profile ??
                  <String, dynamic>{
                    'id': widget.userId,
                    'username': null,
                    'full_name': null,
                    'bio': null,
                    'avatar_path': null,
                    'created_at': null,
                    'updated_at': null,
                  })
            : Map<String, dynamic>.from(profileResponse);
        _papers = papers;
        _posts = posts;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  String _displayName() {
    final fullName = (_profile?['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final username = (_profile?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    return 'Archivix Member';
  }

  String? _usernameLabel() {
    final username = (_profile?['username'] as String?)?.trim();
    if (username == null || username.isEmpty) {
      return null;
    }
    return '@$username';
  }

  String _description() {
    final bio = (_profile?['bio'] as String?)?.trim();
    if (bio != null && bio.isNotEmpty) {
      return bio;
    }
    return 'This researcher has not added a public description yet.';
  }

  String? _avatarUrl() {
    final avatarPath = (_profile?['avatar_path'] as String?)?.trim();
    if (avatarPath == null || avatarPath.isEmpty) {
      return null;
    }

    final updatedAt = (_profile?['updated_at'] as String?) ?? '';
    final publicUrl = _supabase.storage
        .from('profile-avatars')
        .getPublicUrl(avatarPath);
    return '$publicUrl?v=${Uri.encodeComponent(updatedAt)}';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';

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

  String _authorsLabel(List<dynamic>? authors) {
    if (authors == null || authors.isEmpty) {
      return 'Unknown author';
    }

    final names = authors
        .map((author) => '${author['name'] ?? 'Unknown author'}')
        .toList();

    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names[0]} et al.';
  }

  Widget _buildAvatar({double size = 108}) {
    final avatarUrl = _avatarUrl();
    final initials = _displayName().trim().isNotEmpty
        ? _displayName().trim().substring(0, 1).toUpperCase()
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
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null
          ? Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                );
              },
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
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 3, height: 20, color: AppColors.slatePrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaperCard(Map<String, dynamic> paper) {
    final category = paper['categories'] as Map<String, dynamic>?;
    final authors = paper['paper_authors'] as List<dynamic>?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaperDetailScreen(paperId: '${paper['id']}'),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 13,
                      color: AppColors.slatePrimary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Document',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slatePrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${paper['title'] ?? 'Untitled Document'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _authorsLabel(authors),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${paper['abstract'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMetaChip(category?['name'] ?? 'Uncategorized'),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(
                      paper['published_at'] as String? ??
                          paper['created_at'] as String?,
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSubtle,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: AppColors.textSubtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${paper['views_count'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSubtle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.comment_outlined,
                    size: 14,
                    color: AppColors.textSubtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${paper['comments_count'] ?? 0}',
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
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final category = post['categories'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: '${post['id']}'),
            ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.amberSurface,
                  border: Border.all(color: AppColors.amberBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.question_answer_outlined,
                      size: 13,
                      color: AppColors.amberDark,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Question',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amberDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${post['title'] ?? 'Untitled Question'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${post['content'] ?? ''}',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMetaChip(
                    category?['name'] ?? 'Uncategorized',
                    useAmber: true,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(post['created_at'] as String?),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSubtle,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: AppColors.textSubtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post['views_count'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSubtle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.comment_outlined,
                    size: 14,
                    color: AppColors.textSubtle,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post['comments_count'] ?? 0}',
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
      ),
    );
  }

  Widget _buildMetaChip(String label, {bool useAmber = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: useAmber ? AppColors.amberSurface : AppColors.surfaceLight,
        border: Border.all(
          color: useAmber ? AppColors.amberBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: useAmber ? AppColors.amberDark : AppColors.slatePrimary,
        ),
      ),
    );
  }

  Widget _buildEmptySection({
    required IconData icon,
    required String title,
    required String subtitle,
    bool useAmber = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: useAmber ? AppColors.amberSurface : Colors.white,
        border: Border.all(
          color: useAmber ? AppColors.amberBorder : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textSubtle),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.errorDark,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load this profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.errorDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showLoadingOnly = _isLoading && _profile == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Researcher Profile')),
      body: showLoadingOnly
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _profile == null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6ECF4),
                      border: Border.all(color: const Color(0xFFB7C2D1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        _buildAvatar(),
                        const SizedBox(height: 12),
                        Text(
                          _displayName(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_usernameLabel() != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _usernameLabel()!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          _description(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildFactColumn(
                                  'Joined',
                                  _formatDate(
                                    _profile?['created_at'] as String?,
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: AppColors.border,
                              ),
                              Expanded(
                                child: _buildFactColumn(
                                  'Published Docs',
                                  '${_papers.length}',
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: AppColors.border,
                              ),
                              Expanded(
                                child: _buildFactColumn(
                                  'Questions',
                                  '${_posts.length}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        border: Border.all(color: AppColors.errorBorder),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.errorDark,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final shouldStack = constraints.maxWidth < 700;
                      final papersStat = _buildStatCard(
                        label: 'DOCUMENTS',
                        value: '${_papers.length}',
                        icon: Icons.description_outlined,
                        backgroundColor: Colors.white,
                        borderColor: AppColors.border,
                        accentColor: AppColors.slatePrimary,
                      );
                      final postsStat = _buildStatCard(
                        label: 'QUESTIONS',
                        value: '${_posts.length}',
                        icon: Icons.question_answer_outlined,
                        backgroundColor: AppColors.amberCardBg,
                        borderColor: AppColors.amberBorder,
                        accentColor: AppColors.amberDark,
                      );

                      if (shouldStack) {
                        return Column(
                          children: [
                            papersStat,
                            const SizedBox(height: 12),
                            postsStat,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: papersStat),
                          const SizedBox(width: 12),
                          Expanded(child: postsStat),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Published Documents'),
                  const SizedBox(height: 12),
                  if (_papers.isEmpty)
                    _buildEmptySection(
                      icon: Icons.article_outlined,
                      title: 'No published documents yet',
                      subtitle:
                          'Published research from this user will appear here.',
                    )
                  else
                    ..._papers.map(_buildPaperCard),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Questions'),
                  const SizedBox(height: 12),
                  if (_posts.isEmpty)
                    _buildEmptySection(
                      icon: Icons.question_answer_outlined,
                      title: 'No questions yet',
                      subtitle:
                          'Community questions from this user will appear here.',
                      useAmber: true,
                    )
                  else
                    ..._posts.map(_buildPostCard),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }

  Widget _buildFactColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
