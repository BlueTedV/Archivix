import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaperCommentService {
  PaperCommentService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<Map<String, int>> loadCommentCounts(Iterable<String> paperIds) async {
    final normalizedIds = paperIds
        .map((paperId) => paperId.trim())
        .where((paperId) => paperId.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) {
      return const <String, int>{};
    }

    try {
      final response = await _supabase
          .from('paper_comments')
          .select('paper_id')
          .inFilter('paper_id', normalizedIds);

      final counts = <String, int>{};
      for (final row in response) {
        final comment = Map<String, dynamic>.from(row);
        final paperId = '${comment['paper_id']}';
        counts[paperId] = (counts[paperId] ?? 0) + 1;
      }
      return counts;
    } catch (error) {
      debugPrint('Unable to load paper comment counts: $error');
      return const <String, int>{};
    }
  }

  Future<void> attachCommentCounts(List<Map<String, dynamic>> papers) async {
    if (papers.isEmpty) return;

    final counts = await loadCommentCounts(
      papers.map((paper) => '${paper['id'] ?? ''}'),
    );

    for (final paper in papers) {
      paper['comments_count'] = counts['${paper['id']}'] ?? 0;
    }
  }

  Future<List<Map<String, dynamic>>> loadComments(String paperId) async {
    final response = await _supabase
        .from('paper_comments')
        .select(
          'id, paper_id, user_id, author_label, body, created_at, updated_at',
        )
        .eq('paper_id', paperId)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insertComment({
    required String paperId,
    required String userId,
    required String body,
    required String authorLabel,
  }) async {
    final response = await _supabase
        .from('paper_comments')
        .insert({
          'paper_id': paperId,
          'user_id': userId,
          'author_label': authorLabel,
          'body': body,
        })
        .select(
          'id, paper_id, user_id, author_label, body, created_at, updated_at',
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
