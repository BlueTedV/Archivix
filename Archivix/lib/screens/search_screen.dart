import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/services/comment_service.dart';
import 'papers/paper_detail_screen.dart';
import 'posts/post_detail_screen.dart';
import 'public_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _supabase = Supabase.instance.client;
  final _paperCommentService = CommentService(contentType: 'paper');
  final _postCommentService = CommentService(contentType: 'post');
  final _searchController = TextEditingController();

  Timer? _debounce;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  String? _error;
  String _contentFilter = 'all';
  String _selectedCategoryId = 'all';

  @override
  void initState() {
    super.initState();
    _initializeSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeSearch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categoriesResponse = await _supabase
          .from('categories')
          .select('id, name')
          .order('name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(categoriesResponse);
        });
      }

      await _performSearch();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _performSearch);
  }

  Future<void> _performSearch() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final normalizedQuery = _searchController.text.trim();
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _loadPapers(normalizedQuery),
        _loadPosts(normalizedQuery),
        _loadUsers(normalizedQuery),
      ]);

      final combined = [...results[0], ...results[1], ...results[2]];

      combined.sort((a, b) => _compareResults(a, b, normalizedQuery));

      if (!mounted) return;

      setState(() {
        _results = combined;
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

  Future<List<Map<String, dynamic>>> _loadPapers(String query) async {
    if (_contentFilter == 'posts' || _contentFilter == 'users') {
      return [];
    }

    var papersQuery = _supabase
        .from('papers')
        .select('''
          id,
          title,
          abstract,
          created_at,
          published_at,
          views_count,
          category_id,
          user_id,
          categories (name),
          paper_authors (name)
        ''')
        .eq('status', 'published');

    if (_selectedCategoryId != 'all') {
      papersQuery = papersQuery.eq('category_id', _selectedCategoryId);
    }

    if (query.isNotEmpty) {
      final escaped = _escapeForIlike(query);
      papersQuery = papersQuery.or(
        'title.ilike.%$escaped%,abstract.ilike.%$escaped%',
      );
    }

    final response = await papersQuery
        .order('published_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(60);

    final papers = List<Map<String, dynamic>>.from(response);
    await _paperCommentService.attachCommentCounts(papers);
    await _attachUploaderProfiles(papers);
    for (final paper in papers) {
      paper['content_type'] = 'paper';
    }
    return papers;
  }

  Future<List<Map<String, dynamic>>> _loadPosts(String query) async {
    if (_contentFilter == 'papers' || _contentFilter == 'users') {
      return [];
    }

    var postsQuery = _supabase.from('posts').select('''
          id,
          title,
          content,
          created_at,
          views_count,
          category_id,
          user_id,
          categories (name)
        ''');

    if (_selectedCategoryId != 'all') {
      postsQuery = postsQuery.eq('category_id', _selectedCategoryId);
    }

    if (query.isNotEmpty) {
      final escaped = _escapeForIlike(query);
      postsQuery = postsQuery.or(
        'title.ilike.%$escaped%,content.ilike.%$escaped%',
      );
    }

    final response = await postsQuery
        .order('created_at', ascending: false)
        .limit(60);

    final posts = List<Map<String, dynamic>>.from(response);
    await _postCommentService.attachCommentCounts(posts);
    await _attachUploaderProfiles(posts);
    for (final post in posts) {
      post['content_type'] = 'post';
    }
    return posts;
  }

  Future<void> _attachUploaderProfiles(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;

    final profiles = await _paperCommentService.loadProfiles(
      items.map((item) => '${item['user_id'] ?? ''}'),
    );

    for (final item in items) {
      item['uploader_profile'] = profiles['${item['user_id']}'];
    }
  }

  Future<List<Map<String, dynamic>>> _loadUsers(String query) async {
    if (_contentFilter == 'papers' || _contentFilter == 'posts') {
      return [];
    }

    if (query.isEmpty && _contentFilter != 'users') {
      return [];
    }

    var profilesQuery = _supabase
        .from('profiles')
        .select(
          'id, username, full_name, bio, avatar_path, created_at, updated_at',
        );

    if (query.isNotEmpty) {
      final escaped = _escapeForIlike(query);
      profilesQuery = profilesQuery.or(
        'username.ilike.%$escaped%,full_name.ilike.%$escaped%,bio.ilike.%$escaped%',
      );
    }

    final response = await profilesQuery
        .order('updated_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(40);

    final profiles = List<Map<String, dynamic>>.from(response);
    for (final profile in profiles) {
      profile['content_type'] = 'user';
    }
    return profiles;
  }

  int _compareResults(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    String query,
  ) {
    final aScore = _searchScore(a, query);
    final bScore = _searchScore(b, query);
    if (aScore != bScore) {
      return aScore.compareTo(bScore);
    }

    final aDate = _parseTimestamp(
      a['published_at'] as String? ??
          a['updated_at'] as String? ??
          a['created_at'] as String?,
    );
    final bDate = _parseTimestamp(
      b['published_at'] as String? ??
          b['updated_at'] as String? ??
          b['created_at'] as String?,
    );
    return bDate.compareTo(aDate);
  }

  int _searchScore(Map<String, dynamic> item, String query) {
    if (query.isEmpty) {
      return switch (item['content_type']) {
        'user' => 2,
        'paper' => 0,
        'post' => 1,
        _ => 3,
      };
    }

    final normalizedQuery = query.toLowerCase();
    final contentType = item['content_type'] as String? ?? '';

    if (contentType == 'user') {
      final username = '${item['username'] ?? ''}'.toLowerCase();
      final fullName = '${item['full_name'] ?? ''}'.toLowerCase();
      final bio = '${item['bio'] ?? ''}'.toLowerCase();

      if (username == normalizedQuery || fullName == normalizedQuery) return 0;
      if (username.startsWith(normalizedQuery) ||
          fullName.startsWith(normalizedQuery)) {
        return 1;
      }
      if (username.contains(normalizedQuery) ||
          fullName.contains(normalizedQuery)) {
        return 2;
      }
      if (bio.contains(normalizedQuery)) return 3;
      return 4;
    }

    final title = '${item['title'] ?? ''}'.toLowerCase();
    final secondary = contentType == 'paper'
        ? '${item['abstract'] ?? ''}'.toLowerCase()
        : '${item['content'] ?? ''}'.toLowerCase();

    if (title == normalizedQuery) return 5;
    if (title.startsWith(normalizedQuery)) return 6;
    if (title.contains(normalizedQuery)) return 7;
    if (secondary.contains(normalizedQuery)) return 8;
    return 9;
  }

  DateTime _parseTimestamp(String? rawValue) {
    return DateTime.tryParse(rawValue ?? '') ?? DateTime(1970);
  }

  String _escapeForIlike(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll(',', r'\,');
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';

    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) return 'Today';
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays} days ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Unknown date';
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

  String _uploaderLabel(Map<String, dynamic> item) {
    final profile = item['uploader_profile'] as Map<String, dynamic>?;
    final username = (profile?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    final fullName = (profile?['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    return 'Unknown user';
  }

  String _profileDisplayName(Map<String, dynamic> profile) {
    final fullName = (profile['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final username = (profile['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    return 'Archivix Member';
  }

  String _profileDescription(Map<String, dynamic> profile) {
    final bio = (profile['bio'] as String?)?.trim();
    if (bio != null && bio.isNotEmpty) {
      return bio;
    }

    return 'No public description yet.';
  }

  String? _profileUsername(Map<String, dynamic> profile) {
    final username = (profile['username'] as String?)?.trim();
    if (username == null || username.isEmpty) {
      return null;
    }
    return '@$username';
  }

  String? _profileAvatarUrl(Map<String, dynamic> profile) {
    final avatarPath = (profile['avatar_path'] as String?)?.trim();
    if (avatarPath == null || avatarPath.isEmpty) {
      return null;
    }

    final updatedAt = (profile['updated_at'] as String?) ?? '';
    final publicUrl = _supabase.storage
        .from('profile-avatars')
        .getPublicUrl(avatarPath);
    return '$publicUrl?v=${Uri.encodeComponent(updatedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Search Archive')),
      body: RefreshIndicator(
        onRefresh: _performSearch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSearchBox(),
            const SizedBox(height: 16),
            _buildFilterRow(),
            const SizedBox(height: 16),
            _buildResultHeader(query),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildErrorState()
            else if (_results.isEmpty)
              _buildEmptyState(query)
            else
              ..._results.map(_buildResultCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find people, documents, and questions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search by name, username, title, abstract, or question content, then narrow by category or result type.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) {
              setState(() {});
              _scheduleSearch();
            },
            onSubmitted: (_) => _performSearch(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Try a researcher, keyword, or title...',
              hintStyle: const TextStyle(color: AppColors.textSubtle),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _performSearch();
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final isUsersOnly = _contentFilter == 'users';

    final contentTypeDropdown = DropdownButtonFormField<String>(
      initialValue: _contentFilter,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Result Type',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('All'),
        ),
        DropdownMenuItem(value: 'papers', child: Text('Documents only')),
        DropdownMenuItem(value: 'posts', child: Text('Questions only')),
        DropdownMenuItem(value: 'users', child: Text('People only')),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _contentFilter = value;
        });
        _performSearch();
      },
    );

    final categoryDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: isUsersOnly ? 'Category (not used for people)' : 'Category',
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('All categories')),
        ..._categories.map(
          (category) => DropdownMenuItem<String>(
            value: '${category['id']}',
            child: Text('${category['name']}', overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: isUsersOnly
          ? null
          : (value) {
              if (value == null) return;
              setState(() {
                _selectedCategoryId = value;
              });
              _performSearch();
            },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = constraints.maxWidth < 700;

        if (shouldStack) {
          return Column(
            children: [
              contentTypeDropdown,
              const SizedBox(height: 12),
              categoryDropdown,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: contentTypeDropdown),
            const SizedBox(width: 12),
            Expanded(child: categoryDropdown),
          ],
        );
      },
    );
  }

  Widget _buildResultHeader(String query) {
    final resultLabel = _results.length == 1 ? 'result' : 'results';
    final contentLabel = switch (_contentFilter) {
      'papers' => 'documents',
      'posts' => 'questions',
      'users' => 'people',
      _ => 'documents, questions, and people',
    };

    final defaultLabel = switch (_contentFilter) {
      'users' => 'community members',
      _ => contentLabel,
    };

    return Row(
      children: [
        Container(width: 3, height: 20, color: AppColors.slatePrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                query.isEmpty ? 'Explore Search' : 'Search Results',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                query.isEmpty
                    ? 'Showing ${_results.length} recent $defaultLabel'
                    : '${_results.length} $resultLabel for "$query"',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        border: Border.all(color: AppColors.errorBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorDark, size: 32),
          const SizedBox(height: 8),
          const Text(
            'Could not load search results',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.errorDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.errorDark),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _performSearch, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    final message = switch (_contentFilter) {
      'papers' =>
        query.isEmpty
            ? 'No documents match the current filters yet.'
            : 'No documents matched "$query".',
      'posts' =>
        query.isEmpty
            ? 'No questions match the current filters yet.'
            : 'No questions matched "$query".',
      'users' =>
        query.isEmpty
            ? 'No community profiles are available yet.'
            : 'No people matched "$query".',
      _ =>
        query.isEmpty
            ? 'No documents, questions, or people match the current filters yet.'
            : 'No documents, questions, or people matched "$query".',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 42, color: AppColors.textSubtle),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _contentFilter == 'users'
                ? 'Try a different name, handle, or description keyword.'
                : 'Try changing the category filter, switching result type, or using a different keyword.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSubtle),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    return switch (item['content_type']) {
      'paper' => _buildPaperResultCard(item),
      'post' => _buildPostResultCard(item),
      'user' => _buildUserResultCard(item),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildPaperResultCard(Map<String, dynamic> item) {
    final category = item['categories'] as Map<String, dynamic>?;
    final authors = item['paper_authors'] as List<dynamic>?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaperDetailScreen(paperId: '${item['id']}'),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeBadge(
                label: 'Document',
                icon: Icons.article_outlined,
                color: AppColors.slatePrimary,
                background: AppColors.surfaceLight,
                border: AppColors.border,
              ),
              const SizedBox(height: 10),
              Text(
                '${item['title'] ?? 'Untitled Document'}',
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
              const SizedBox(height: 4),
              Text(
                'Uploaded by ${_uploaderLabel(item)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${item['abstract'] ?? ''}',
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
                      item['published_at'] as String? ??
                          item['created_at'] as String?,
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
                    '${item['views_count'] ?? 0}',
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
                    '${item['comments_count'] ?? 0}',
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

  Widget _buildPostResultCard(Map<String, dynamic> item) {
    final category = item['categories'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: '${item['id']}'),
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
              _buildTypeBadge(
                label: 'Question',
                icon: Icons.question_answer_outlined,
                color: AppColors.amberDark,
                background: AppColors.amberSurface,
                border: AppColors.amberBorder,
              ),
              const SizedBox(height: 10),
              Text(
                '${item['title'] ?? 'Untitled Question'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Uploaded by ${_uploaderLabel(item)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${item['content'] ?? ''}',
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
                    _formatDate(item['created_at'] as String?),
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
                    '${item['views_count'] ?? 0}',
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

  Widget _buildUserResultCard(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PublicProfileScreen(
                userId: '${item['id']}',
                initialProfile: item,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3F8),
            border: Border.all(color: const Color(0xFFB7C2D1)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserAvatar(item, size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTypeBadge(
                      label: 'Person',
                      icon: Icons.person_outline,
                      color: AppColors.slatePrimary,
                      background: Colors.white,
                      border: const Color(0xFFB7C2D1),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _profileDisplayName(item),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_profileUsername(item) != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _profileUsername(item)!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _profileDescription(item),
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
                        _buildMetaChip('Profile'),
                        const SizedBox(width: 8),
                        Text(
                          'Joined ${_formatDate(item['created_at'] as String?)}',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic> profile, {double size = 52}) {
    final avatarUrl = _profileAvatarUrl(profile);
    final label = _profileDisplayName(profile);
    final initials = label.trim().isNotEmpty
        ? label.trim().substring(0, 1).toUpperCase()
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
        borderRadius: BorderRadius.circular(8),
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

  Widget _buildTypeBadge({
    required String label,
    required IconData icon,
    required Color color,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
}
