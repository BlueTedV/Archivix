import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import 'papers/paper_detail_screen.dart';
import 'posts/post_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _supabase = Supabase.instance.client;
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
      final papers = await _loadPapers(normalizedQuery);
      final posts = await _loadPosts(normalizedQuery);
      final combined = [...papers, ...posts];

      combined.sort((a, b) {
        final aDate = DateTime.tryParse('${a['created_at']}') ?? DateTime(1970);
        final bDate = DateTime.tryParse('${b['created_at']}') ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

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
    if (_contentFilter == 'posts') {
      return [];
    }

    var papersQuery = _supabase
        .from('papers')
        .select('''
          id,
          title,
          abstract,
          created_at,
          views_count,
          category_id,
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
        .order('created_at', ascending: false)
        .limit(60);

    final papers = List<Map<String, dynamic>>.from(response);
    for (final paper in papers) {
      paper['content_type'] = 'paper';
    }
    return papers;
  }

  Future<List<Map<String, dynamic>>> _loadPosts(String query) async {
    if (_contentFilter == 'papers') {
      return [];
    }

    var postsQuery = _supabase.from('posts').select('''
          id,
          title,
          content,
          created_at,
          views_count,
          category_id,
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
    for (final post in posts) {
      post['content_type'] = 'post';
    }
    return posts;
  }

  String _escapeForIlike(String value) {
    return value.replaceAll('%', r'\%').replaceAll(',', r'\,');
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
            'Find documents and questions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search by title, abstract, or question content, then narrow by category or content type.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) => _scheduleSearch(),
            onSubmitted: (_) => _performSearch(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Try a topic, keyword, or title...',
              hintStyle: const TextStyle(color: AppColors.textSubtle),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
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
    final contentTypeDropdown = DropdownButtonFormField<String>(
      initialValue: _contentFilter,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Content Type',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('Documents + Questions', overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(value: 'papers', child: Text('Documents only')),
        DropdownMenuItem(value: 'posts', child: Text('Questions only')),
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
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
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
      onChanged: (value) {
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
      _ => 'documents and questions',
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
                query.isEmpty ? 'Explore Content' : 'Search Results',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                query.isEmpty
                    ? 'Showing ${_results.length} recent $contentLabel'
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
    final message = query.isEmpty
        ? 'No content matches the current filters yet.'
        : 'No documents or questions matched "$query".';

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
          const Text(
            'Try changing the category filter, switching content type, or using a different keyword.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    if (item['content_type'] == 'paper') {
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
