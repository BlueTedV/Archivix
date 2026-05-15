import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/services/collection_service.dart';
import 'papers/paper_detail_screen.dart';
import 'posts/post_detail_screen.dart';

class CollectionDetailScreen extends StatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collection,
    this.readOnly = false,
  });

  final CollectionModel collection;
  final bool readOnly;

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final _service = CollectionService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.loadCollectionItems(widget.collection.id);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    final contentType = item['content_type'] as String;
    final contentId = '${item['id']}';
    final itemId = '${item['item_id']}';

    setState(() => _items.removeWhere((i) => '${i['item_id']}' == itemId));

    try {
      await _service.removeFromCollection(
        collectionId: widget.collection.id,
        contentType: contentType,
        contentId: contentId,
      );
    } catch (e) {
      // Re-load on error.
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.errorDark,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  String _authorsLabel(List<dynamic>? authors) {
    if (authors == null || authors.isEmpty) return 'Unknown author';
    final names = authors.map((a) => '${a['name'] ?? ''}').toList();
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names[0]} et al.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
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
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.errorDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : _items.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.bookmark_border,
                          size: 56,
                          color: AppColors.textSubtle,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'This collection is empty',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.readOnly
                              ? 'Public saves from this collection will appear here.'
                              : 'Tap the star icon on any document or question to save it here.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSubtle,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildItemCard(_items[index]),
              ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final contentType = item['content_type'] as String? ?? 'post';
    final isPaper = contentType == 'paper';
    final category = item['categories'] as Map<String, dynamic>?;
    final authors = item['paper_authors'] as List<dynamic>?;

    final card = InkWell(
      onTap: () {
        if (isPaper) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaperDetailScreen(paperId: '${item['id']}'),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: '${item['id']}'),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPaper ? Colors.white : AppColors.amberCardBg,
          border: Border.all(
            color: isPaper ? AppColors.border : AppColors.amberBorder,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isPaper
                        ? AppColors.surfaceLight
                        : AppColors.amberSurface,
                    border: Border.all(
                      color: isPaper ? AppColors.border : AppColors.amberBorder,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaper
                            ? Icons.article_outlined
                            : Icons.question_answer_outlined,
                        size: 11,
                        color: isPaper
                            ? AppColors.slatePrimary
                            : AppColors.amberDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaper ? 'Document' : 'Question',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPaper
                              ? AppColors.slatePrimary
                              : AppColors.amberDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Saved ${_formatDate(item['added_at'] as String?)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${item['title'] ?? 'Untitled'}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isPaper && authors != null) ...[
              const SizedBox(height: 4),
              Text(
                _authorsLabel(authors),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              isPaper
                  ? '${item['abstract'] ?? ''}'
                  : '${item['content'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isPaper
                          ? AppColors.surfaceLight
                          : AppColors.amberSurface,
                      border: Border.all(
                        color: isPaper
                            ? AppColors.border
                            : AppColors.amberBorder,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${category['name']}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isPaper
                            ? AppColors.slatePrimary
                            : AppColors.amberDark,
                      ),
                    ),
                  ),
                const Spacer(),
                const Icon(
                  Icons.visibility_outlined,
                  size: 12,
                  color: AppColors.textSubtle,
                ),
                const SizedBox(width: 3),
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
    );

    if (widget.readOnly) return card;

    return Dismissible(
      key: Key('${item['item_id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.errorDark,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.bookmark_remove, color: Colors.white),
      ),
      onDismissed: (_) => _removeItem(item),
      child: card,
    );
  }
}
