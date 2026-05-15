import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollectionModel {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final bool isPublic;
  final int itemCount;
  final DateTime createdAt;

  const CollectionModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    required this.isPublic,
    this.itemCount = 0,
    required this.createdAt,
  });

  factory CollectionModel.fromMap(Map<String, dynamic> map) {
    return CollectionModel(
      id: '${map['id']}',
      userId: '${map['user_id']}',
      name: '${map['name']}',
      description: map['description'] as String?,
      isPublic: map['is_public'] == true,
      itemCount: (map['item_count'] as int?) ?? 0,
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime(1970),
    );
  }

  CollectionModel copyWith({
    String? name,
    String? description,
    bool? isPublic,
  }) {
    return CollectionModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      itemCount: itemCount,
      createdAt: createdAt,
    );
  }
}

class CollectionService {
  CollectionService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // ─── Collections CRUD ────────────────────────────────────────────────────

  Future<List<CollectionModel>> loadMyCollections() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _supabase
          .from('collections')
          .select('id, user_id, name, description, is_public, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final collections = List<Map<String, dynamic>>.from(
        rows,
      ).map(CollectionModel.fromMap).toList();

      // Attach item counts.
      if (collections.isNotEmpty) {
        final ids = collections.map((c) => c.id).toList();
        final countRows = await _supabase
            .from('collection_items')
            .select('collection_id')
            .inFilter('collection_id', ids);

        final counts = <String, int>{};
        for (final row in countRows) {
          final cid = '${row['collection_id']}';
          counts[cid] = (counts[cid] ?? 0) + 1;
        }

        return collections
            .map(
              (c) => CollectionModel(
                id: c.id,
                userId: c.userId,
                name: c.name,
                description: c.description,
                isPublic: c.isPublic,
                itemCount: counts[c.id] ?? 0,
                createdAt: c.createdAt,
              ),
            )
            .toList();
      }

      return collections;
    } catch (e) {
      debugPrint('CollectionService.loadMyCollections error: $e');
      return [];
    }
  }

  Future<List<CollectionModel>> loadPublicCollectionsForUser(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return [];

    try {
      final rows = await _supabase
          .from('collections')
          .select('id, user_id, name, description, is_public, created_at')
          .eq('user_id', normalizedUserId)
          .eq('is_public', true)
          .order('created_at', ascending: false);

      final collections = List<Map<String, dynamic>>.from(
        rows,
      ).map(CollectionModel.fromMap).toList();

      return _attachItemCounts(collections);
    } catch (e) {
      debugPrint('CollectionService.loadPublicCollectionsForUser error: $e');
      return [];
    }
  }

  Future<List<CollectionModel>> _attachItemCounts(
    List<CollectionModel> collections,
  ) async {
    if (collections.isEmpty) return collections;

    final ids = collections.map((c) => c.id).toList();
    final countRows = await _supabase
        .from('collection_items')
        .select('collection_id')
        .inFilter('collection_id', ids);

    final counts = <String, int>{};
    for (final row in countRows) {
      final cid = '${row['collection_id']}';
      counts[cid] = (counts[cid] ?? 0) + 1;
    }

    return collections
        .map(
          (c) => CollectionModel(
            id: c.id,
            userId: c.userId,
            name: c.name,
            description: c.description,
            isPublic: c.isPublic,
            itemCount: counts[c.id] ?? 0,
            createdAt: c.createdAt,
          ),
        )
        .toList();
  }

  Future<CollectionModel> createCollection({
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Please sign in to create collections.');
    }

    final row = await _supabase
        .from('collections')
        .insert({
          'user_id': userId,
          'name': name.trim(),
          'description': description?.trim().isEmpty == true
              ? null
              : description?.trim(),
          'is_public': isPublic,
        })
        .select('id, user_id, name, description, is_public, created_at')
        .single();

    return CollectionModel.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> updateCollection({
    required String collectionId,
    required String name,
    String? description,
    required bool isPublic,
  }) async {
    await _supabase
        .from('collections')
        .update({
          'name': name.trim(),
          'description': description?.trim().isEmpty == true
              ? null
              : description?.trim(),
          'is_public': isPublic,
        })
        .eq('id', collectionId);
  }

  Future<void> deleteCollection(String collectionId) async {
    await _supabase.from('collections').delete().eq('id', collectionId);
  }

  // ─── Collection items ─────────────────────────────────────────────────────

  /// Returns the set of collection IDs that contain this content item.
  Future<Set<String>> collectionsContaining({
    required String contentType,
    required String contentId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};

    try {
      // Only check the user's own collections.
      final myCollectionIds = await _supabase
          .from('collections')
          .select('id')
          .eq('user_id', userId);

      final ids = List<Map<String, dynamic>>.from(
        myCollectionIds,
      ).map((r) => '${r['id']}').toList();

      if (ids.isEmpty) return {};

      final rows = await _supabase
          .from('collection_items')
          .select('collection_id')
          .inFilter('collection_id', ids)
          .eq('content_type', contentType)
          .eq('content_id', contentId);

      return List<Map<String, dynamic>>.from(
        rows,
      ).map((r) => '${r['collection_id']}').toSet();
    } catch (e) {
      debugPrint('CollectionService.collectionsContaining error: $e');
      return {};
    }
  }

  Future<void> addToCollection({
    required String collectionId,
    required String contentType,
    required String contentId,
  }) async {
    await _supabase.from('collection_items').insert({
      'collection_id': collectionId,
      'content_type': contentType,
      'content_id': contentId,
    });
  }

  Future<void> removeFromCollection({
    required String collectionId,
    required String contentType,
    required String contentId,
  }) async {
    await _supabase
        .from('collection_items')
        .delete()
        .eq('collection_id', collectionId)
        .eq('content_type', contentType)
        .eq('content_id', contentId);
  }

  /// Loads all items in a collection with their content details.
  Future<List<Map<String, dynamic>>> loadCollectionItems(
    String collectionId,
  ) async {
    try {
      final rows = await _supabase
          .from('collection_items')
          .select('id, content_type, content_id, added_at')
          .eq('collection_id', collectionId)
          .order('added_at', ascending: false);

      final items = List<Map<String, dynamic>>.from(rows);

      final paperIds = items
          .where((i) => i['content_type'] == 'paper')
          .map((i) => '${i['content_id']}')
          .toList();
      final postIds = items
          .where((i) => i['content_type'] == 'post')
          .map((i) => '${i['content_id']}')
          .toList();

      final Map<String, Map<String, dynamic>> contentMap = {};

      if (paperIds.isNotEmpty) {
        final papers = await _supabase
            .from('papers')
            .select(
              'id, title, abstract, created_at, published_at, views_count, status, categories(name), paper_authors(name)',
            )
            .inFilter('id', paperIds);
        for (final p in papers) {
          contentMap['paper:${p['id']}'] = Map<String, dynamic>.from(p)
            ..['content_type'] = 'paper';
        }
      }

      if (postIds.isNotEmpty) {
        final posts = await _supabase
            .from('posts')
            .select(
              'id, title, content, created_at, views_count, categories(name)',
            )
            .inFilter('id', postIds);
        for (final p in posts) {
          contentMap['post:${p['id']}'] = Map<String, dynamic>.from(p)
            ..['content_type'] = 'post';
        }
      }

      return items
          .map((item) {
            final key = '${item['content_type']}:${item['content_id']}';
            return <String, dynamic>{
              'item_id': item['id'],
              'added_at': item['added_at'],
              ...?contentMap[key],
            };
          })
          .where((item) => item.containsKey('id'))
          .toList();
    } catch (e) {
      debugPrint('CollectionService.loadCollectionItems error: $e');
      return [];
    }
  }
}
