import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostCommentService {
  PostCommentService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<Map<String, int>> loadCommentCounts(Iterable<String> postIds) async {
    final normalizedIds = postIds
        .map((postId) => postId.trim())
        .where((postId) => postId.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) {
      return const <String, int>{};
    }

    try {
      final response = await _supabase
          .from('paper_comments')
          .select('post_id')
          .inFilter('post_id', normalizedIds);

      final counts = <String, int>{};
      for (final row in response) {
        final comment = Map<String, dynamic>.from(row);
        final postId = '${comment['post_id']}';
        counts[postId] = (counts[postId] ?? 0) + 1;
      }
      return counts;
    } catch (error) {
      debugPrint('Unable to load post comment counts: $error');
      return const <String, int>{};
    }
  }

  Future<void> attachCommentCounts(List<Map<String, dynamic>> posts) async {
    if (posts.isEmpty) return;

    final counts = await loadCommentCounts(
      posts.map((post) => '${post['id'] ?? ''}'),
    );

    for (final post in posts) {
      post['comments_count'] = counts['${post['id']}'] ?? 0;
    }
  }

  Future<List<Map<String, dynamic>>> loadComments(String postId) async {
    final response = await _supabase
        .from('paper_comments')
        .select(
          'id, post_id, user_id, author_label, body, created_at, updated_at',
        )
        .eq('post_id', postId)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insertComment({
    required String postId,
    required String userId,
    required String body,
    required String authorLabel,
  }) async {
    final response = await _supabase
        .from('paper_comments')
        .insert({
          'post_id': postId,
          'user_id': userId,
          'author_label': authorLabel,
          'body': body,
        })
        .select(
          'id, post_id, user_id, author_label, body, created_at, updated_at',
        )
        .single();

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, Map<String, dynamic>>> loadProfiles(
    Iterable<String> userIds,
  ) async {
    final normalizedIds = userIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) {
      return const <String, Map<String, dynamic>>{};
    }

    final response = await _supabase
        .from('profiles')
        .select('id, username, full_name, avatar_path, updated_at')
        .inFilter('id', normalizedIds);

    final profiles = <String, Map<String, dynamic>>{};
    for (final row in response) {
      final profile = Map<String, dynamic>.from(row);
      profiles['${profile['id']}'] = profile;
    }
    return profiles;
  }
}
