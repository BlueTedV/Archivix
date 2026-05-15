import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/services/collection_service.dart';

/// Shows a bottom sheet that lets the user save content to one or more
/// collections, or create a new collection on the spot.
///
/// Returns `true` if any change was made (add or remove).
Future<bool?> showSaveToCollectionSheet(
  BuildContext context, {
  required String contentType,
  required String contentId,
  required String contentTitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SaveToCollectionSheet(
      contentType: contentType,
      contentId: contentId,
      contentTitle: contentTitle,
    ),
  );
}

class _SaveToCollectionSheet extends StatefulWidget {
  const _SaveToCollectionSheet({
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
  });

  final String contentType;
  final String contentId;
  final String contentTitle;

  @override
  State<_SaveToCollectionSheet> createState() => _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState extends State<_SaveToCollectionSheet> {
  final _service = CollectionService();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  List<CollectionModel> _collections = [];
  Set<String> _savedIn = {};
  bool _isLoading = true;
  bool _isCreating = false;
  bool _showCreateForm = false;
  bool _newIsPublic = false;
  bool _anyChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _service.loadMyCollections(),
      _service.collectionsContaining(
        contentType: widget.contentType,
        contentId: widget.contentId,
      ),
    ]);
    if (mounted) {
      setState(() {
        _collections = results[0] as List<CollectionModel>;
        _savedIn = results[1] as Set<String>;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggle(CollectionModel collection) async {
    final isSaved = _savedIn.contains(collection.id);

    // Optimistic update.
    setState(() {
      if (isSaved) {
        _savedIn.remove(collection.id);
      } else {
        _savedIn.add(collection.id);
      }
      _anyChanged = true;
    });

    try {
      if (isSaved) {
        await _service.removeFromCollection(
          collectionId: collection.id,
          contentType: widget.contentType,
          contentId: widget.contentId,
        );
      } else {
        await _service.addToCollection(
          collectionId: collection.id,
          contentType: widget.contentType,
          contentId: widget.contentId,
        );
      }
    } catch (e) {
      // Roll back on error.
      if (mounted) {
        setState(() {
          if (isSaved) {
            _savedIn.add(collection.id);
          } else {
            _savedIn.remove(collection.id);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.errorDark,
          ),
        );
      }
    }
  }

  Future<void> _createAndAdd() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final collection = await _service.createCollection(
        name: name,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        isPublic: _newIsPublic,
      );
      await _service.addToCollection(
        collectionId: collection.id,
        contentType: widget.contentType,
        contentId: widget.contentId,
      );

      if (mounted) {
        setState(() {
          _collections.insert(0, collection);
          _savedIn.add(collection.id);
          _showCreateForm = false;
          _anyChanged = true;
          _nameController.clear();
          _descController.clear();
          _newIsPublic = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.errorDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_border,
                  size: 20,
                  color: AppColors.slatePrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Save to Collection',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.contentTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(_anyChanged),
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Collections list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _collections.isEmpty && !_showCreateForm
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.collections_bookmark_outlined,
                          size: 40,
                          color: AppColors.textSubtle,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No collections yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Create your first collection below.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _collections.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 56),
                    itemBuilder: (context, index) {
                      final collection = _collections[index];
                      final isSaved = _savedIn.contains(collection.id);
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSaved
                                ? AppColors.slatePrimary.withValues(alpha: 0.1)
                                : AppColors.surfaceLight,
                            border: Border.all(
                              color: isSaved
                                  ? AppColors.slatePrimary.withValues(
                                      alpha: 0.3,
                                    )
                                  : AppColors.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: isSaved
                                ? AppColors.slatePrimary
                                : AppColors.textMuted,
                          ),
                        ),
                        title: Text(
                          collection.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSaved
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${collection.itemCount} items · ${collection.isPublic ? 'Public' : 'Private'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: isSaved
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.slatePrimary,
                                size: 20,
                              )
                            : null,
                        onTap: () => _toggle(collection),
                      );
                    },
                  ),
          ),
          // Create form
          if (_showCreateForm) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Collection',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Collection name',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Description (optional)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch(
                        value: _newIsPublic,
                        onChanged: (v) => setState(() => _newIsPublic = v),
                        activeThumbColor: AppColors.slatePrimary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Make public',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showCreateForm = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isCreating ? null : _createAndAdd,
                        child: _isCreating
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
                            : const Text('Create & Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          // Footer
          if (!_showCreateForm) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showCreateForm = true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Collection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.slatePrimary,
                    side: const BorderSide(color: AppColors.slatePrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
        ],
      ),
    );
  }
}
