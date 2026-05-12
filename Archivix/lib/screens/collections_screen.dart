import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/services/collection_service.dart';
import 'collection_detail_screen.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final _service = CollectionService();
  List<CollectionModel> _collections = [];
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
      final collections = await _service.loadMyCollections();
      if (mounted) setState(() => _collections = collections);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createCollection() async {
    final result = await _showCreateDialog();
    if (result == null) return;
    try {
      final collection = await _service.createCollection(
        name: result.$1,
        description: result.$2,
        isPublic: result.$3,
      );
      if (mounted) setState(() => _collections.insert(0, collection));
    } catch (e) {
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

  Future<void> _deleteCollection(CollectionModel collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text(
          'Delete "${collection.name}"? This will not delete the saved content, only the collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.errorDark),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteCollection(collection.id);
      if (mounted) {
        setState(() => _collections.removeWhere((c) => c.id == collection.id));
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
    }
  }

  Future<(String, String?, bool)?> _showCreateDialog({
    CollectionModel? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(
      text: existing?.description ?? '',
    );
    bool isPublic = existing?.isPublic ?? false;

    final result = await showDialog<(String, String?, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New Collection' : 'Edit Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Research Papers, Reading List',
                ),
                maxLength: 80,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLength: 300,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Make public',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Others can view this collection',
                  style: TextStyle(fontSize: 12),
                ),
                value: isPublic,
                activeColor: AppColors.slatePrimary,
                onChanged: (v) => setDialogState(() => isPublic = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.of(context).pop((
                  name,
                  descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  isPublic,
                ));
              },
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    descController.dispose();
    return result;
  }

  Future<void> _editCollection(CollectionModel collection) async {
    final result = await _showCreateDialog(existing: collection);
    if (result == null) return;
    try {
      await _service.updateCollection(
        collectionId: collection.id,
        name: result.$1,
        description: result.$2,
        isPublic: result.$3,
      );
      if (mounted) {
        setState(() {
          final idx = _collections.indexWhere((c) => c.id == collection.id);
          if (idx != -1) {
            _collections[idx] = collection.copyWith(
              name: result.$1,
              description: result.$2,
              isPublic: result.$3,
            );
          }
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Collections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _createCollection,
            tooltip: 'New Collection',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _collections.isEmpty
            ? _buildEmpty()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _collections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildCollectionCard(_collections[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCollection,
        backgroundColor: AppColors.slatePrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Collection',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCollectionCard(CollectionModel collection) {
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CollectionDetailScreen(collection: collection),
          ),
        );
        _load(); // Refresh counts after returning.
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.collections_bookmark_outlined,
                size: 22,
                color: AppColors.slatePrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          collection.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: collection.isPublic
                              ? AppColors.successLight
                              : AppColors.surfaceLight,
                          border: Border.all(
                            color: collection.isPublic
                                ? const Color(0xFF6EE7B7)
                                : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          collection.isPublic ? 'Public' : 'Private',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: collection.isPublic
                                ? AppColors.successDark
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (collection.description != null &&
                      collection.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      collection.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${collection.itemCount} item${collection.itemCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.textMuted,
              ),
              onSelected: (value) {
                if (value == 'edit') _editCollection(collection);
                if (value == 'delete') _deleteCollection(collection);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: AppColors.errorDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Center(
          child: Column(
            children: [
              Icon(
                Icons.collections_bookmark_outlined,
                size: 56,
                color: AppColors.textSubtle,
              ),
              SizedBox(height: 16),
              Text(
                'No collections yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Tap + to create your first collection.',
                style: TextStyle(fontSize: 13, color: AppColors.textSubtle),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
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
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
