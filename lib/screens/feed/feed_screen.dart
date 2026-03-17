import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../papers/paper_detail_screen.dart';
import '../posts/post_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  final VoidCallback onNavigateToSettings;
  
  const FeedScreen({Key? key, required this.onNavigateToSettings}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _papers = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _combinedItems = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all'; // 'all', 'papers', 'posts'

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
            .limit(20);
        
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
            .limit(20);
        
        posts = List<Map<String, dynamic>>.from(postsResponse);
        // Add type marker
        for (var post in posts) {
          post['content_type'] = 'post';
        }
      }

      // Combine and sort by date
      List<Map<String, dynamic>> combined = [...papers, ...posts];
      combined.sort((a, b) {
        final aDate = DateTime.parse(a['created_at']);
        final bDate = DateTime.parse(b['created_at']);
        return bDate.compareTo(aDate); // Most recent first
      });

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
                    color: const Color(0xFFFEF3C7),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Color(0xFF92400E),
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
                                color: Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Check your email or tap here to resend verification.',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF92400E).withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Color(0xFF92400E),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Welcome banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4A5568),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF374151)),
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
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Section header with filter
            Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  color: const Color(0xFF4A5568),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _filter == 'all' 
                        ? 'Recent Activity'
                        : _filter == 'papers'
                            ? 'Recent Papers'
                            : 'Recent Questions',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                // Filter dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF4A5568)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    value: _filter,
                    underline: const SizedBox(),
                    isDense: true,
                    icon: const Icon(Icons.filter_list, size: 16, color: Color(0xFF4A5568)),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All'),
                      ),
                      DropdownMenuItem(
                        value: 'papers',
                        child: Text('Papers'),
                      ),
                      DropdownMenuItem(
                        value: 'posts',
                        child: Text('Questions'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _filter = value;
                        });
                        _loadContent();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_combinedItems.length} items',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
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
                  color: const Color(0xFFFEE2E2),
                  border: Border.all(color: const Color(0xFFEF4444)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFF991B1B)),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading papers',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF991B1B),
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
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: Color(0xFF9CA3AF),
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
                        color: Color(0xFF6B7280),
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
                        color: Color(0xFF9CA3AF),
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
                    ),
                  );
                } else {
                  // Post card
                  final category = item['categories'] as Map<String, dynamic>?;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildPostCard(
                      postId: item['id'],
                      title: item['title'],
                      content: item['content'],
                      category: category?['name'] ?? 'Uncategorized',
                      date: _formatDate(item['created_at']),
                      views: item['views_count'] ?? 0,
                    ),
                  );
                }
              }).toList(),
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
          border: Border.all(color: const Color(0xFFD1D5DB)),
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
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              authors,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              abstract.length > 150 
                  ? '${abstract.substring(0, 150)}...' 
                  : abstract,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.visibility, size: 12, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  '$views',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const Spacer(),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
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
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: postId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E6), // Light yellow tint to differentiate
          border: Border.all(color: const Color(0xFFFCD34D)),
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
                  color: Color(0xFF92400E),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Question',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
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
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content.length > 150 
                  ? '${content.substring(0, 150)}...' 
                  : content,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.visibility, size: 12, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  '$views',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const Spacer(),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}