import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentReactionSummary {
  final int likesCount;
  final int dislikesCount;
  final int? userReaction;

  const CommentReactionSummary({
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.userReaction,
  });

  CommentReactionSummary copyWith({
    int? likesCount,
    int? dislikesCount,
    int? userReaction,
    bool clearUserReaction = false,
  }) {
    return CommentReactionSummary(
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      userReaction: clearUserReaction
          ? null
          : userReaction ?? this.userReaction,
    );
  }

  CommentReactionSummary toggledReaction(int reactionValue) {
    var nextLikesCount = likesCount;
    var nextDislikesCount = dislikesCount;
    int? nextUserReaction = userReaction;

    if (userReaction == reactionValue) {
      if (reactionValue == 1) {
        nextLikesCount = nextLikesCount > 0 ? nextLikesCount - 1 : 0;
      } else {
        nextDislikesCount = nextDislikesCount > 0 ? nextDislikesCount - 1 : 0;
      }
      nextUserReaction = null;
    } else {
      if (userReaction == 1) {
        nextLikesCount = nextLikesCount > 0 ? nextLikesCount - 1 : 0;
      } else if (userReaction == -1) {
        nextDislikesCount = nextDislikesCount > 0 ? nextDislikesCount - 1 : 0;
      }

      if (reactionValue == 1) {
        nextLikesCount += 1;
      } else {
        nextDislikesCount += 1;
      }

      nextUserReaction = reactionValue;
    }

    return CommentReactionSummary(
      likesCount: nextLikesCount,
      dislikesCount: nextDislikesCount,
      userReaction: nextUserReaction,
    );
  }
}

/// Unified comment service for both papers and posts.
///
/// Both content types share the `paper_comments` table, distinguished by
/// which FK column is populated (`paper_id` vs `post_id`).
///
/// Usage:
///   final service = CommentService(contentType: 'paper');
///   final service = CommentService(contentType: 'post');
class CommentService {
  CommentService({required this.contentType, SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client,
      _idColumn = contentType == 'paper' ? 'paper_id' : 'post_id';

  final String contentType;
  final SupabaseClient _supabase;
  final String _idColumn;

  // ─── Comment counts ──────────────────────────────────────────────────────

  Future<Map<String, int>> loadCommentCounts(
    Iterable<String> contentIds,
  ) async {
    final normalizedIds = contentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) return const <String, int>{};

    try {
      final response = await _supabase
          .from('paper_comments')
          .select(_idColumn)
          .inFilter(_idColumn, normalizedIds);

      final counts = <String, int>{};
      for (final row in response) {
        final id = '${row[_idColumn]}';
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (error) {
      debugPrint('Unable to load $contentType comment counts: $error');
      return const <String, int>{};
    }
  }

  Future<void> attachCommentCounts(
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) return;

    final counts = await loadCommentCounts(
      items.map((item) => '${item['id'] ?? ''}'),
    );

    for (final item in items) {
      item['comments_count'] = counts['${item['id']}'] ?? 0;
    }
  }

  // ─── Load comments ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadComments(String contentId) async {
    final response = await _supabase
        .from('paper_comments')
        .select(
          'id, $_idColumn, user_id, author_label, body, parent_comment_id, created_at, updated_at',
        )
        .eq(_idColumn, contentId)
        .order('created_at');

    final comments = List<Map<String, dynamic>>.from(response);
    final reactionSummaries = await loadCommentReactionSummaries(
      comments.map((comment) => '${comment['id'] ?? ''}'),
      userId: _supabase.auth.currentUser?.id,
    );

    for (final comment in comments) {
      final summary =
          reactionSummaries['${comment['id']}'] ??
          const CommentReactionSummary();
      comment['likes_count'] = summary.likesCount;
      comment['dislikes_count'] = summary.dislikesCount;
      comment['user_reaction'] = summary.userReaction;
    }

    return comments;
  }

  // ─── Insert comment ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> insertComment({
    required String contentId,
    required String userId,
    required String body,
    required String authorLabel,
    String? parentCommentId,
  }) async {
    final response = await _supabase
        .from('paper_comments')
        .insert({
          _idColumn: contentId,
          'user_id': userId,
          'author_label': authorLabel,
          'body': body,
          if (parentCommentId != null) 'parent_comment_id': parentCommentId,
        })
        .select(
          'id, $_idColumn, user_id, author_label, body, parent_comment_id, created_at, updated_at',
        )
        .single();

    final comment = Map<String, dynamic>.from(response);
    comment['likes_count'] = 0;
    comment['dislikes_count'] = 0;
    comment['user_reaction'] = null;
    return comment;
  }

  // ─── Delete comment ──────────────────────────────────────────────────────

  Future<void> deleteComment(String commentId) async {
    await _supabase.from('paper_comments').delete().eq('id', commentId);
  }

  // ─── Update comment ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> updateComment({
    required String commentId,
    required String body,
  }) async {
    final response = await _supabase
        .from('paper_comments')
        .update({'body': body})
        .eq('id', commentId)
        .select(
          'id, $_idColumn, user_id, author_label, body, parent_comment_id, created_at, updated_at',
        )
        .single();

    return Map<String, dynamic>.from(response);
  }

  // ─── Comment reactions ───────────────────────────────────────────────────

  Future<Map<String, CommentReactionSummary>> loadCommentReactionSummaries(
    Iterable<String> commentIds, {
    required String? userId,
  }) async {
    final normalizedIds = commentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final summaries = {
      for (final id in normalizedIds) id: const CommentReactionSummary(),
    };

    if (normalizedIds.isEmpty) return summaries;

    try {
      final response = await _supabase
          .from('comment_reactions')
          .select('comment_id, user_id, reaction_value')
          .inFilter('comment_id', normalizedIds);

      for (final row in response) {
        final commentId = '${row['comment_id']}';
        final existing =
            summaries[commentId] ?? const CommentReactionSummary();
        final reactionValue = row['reaction_value'] as int;

        summaries[commentId] = existing.copyWith(
          likesCount: existing.likesCount + (reactionValue == 1 ? 1 : 0),
          dislikesCount: existing.dislikesCount + (reactionValue == -1 ? 1 : 0),
          userReaction: row['user_id'] == userId
              ? reactionValue
              : existing.userReaction,
        );
      }
    } catch (error) {
      debugPrint('Unable to load comment reactions: $error');
    }

    return summaries;
  }

  Future<CommentReactionSummary> toggleCommentReaction({
    required String commentId,
    required int reactionValue,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Please sign in to react to comments.');
    }

    final existing = await _supabase
        .from('comment_reactions')
        .select('id, reaction_value')
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('comment_reactions').insert({
        'comment_id': commentId,
        'user_id': userId,
        'reaction_value': reactionValue,
      });
    } else if (existing['reaction_value'] == reactionValue) {
      await _supabase.from('comment_reactions').delete().eq('id', existing['id']);
    } else {
      await _supabase
          .from('comment_reactions')
          .update({'reaction_value': reactionValue})
          .eq('id', existing['id']);
    }

    final summaries = await loadCommentReactionSummaries(
      [commentId],
      userId: userId,
    );
    return summaries[commentId] ?? const CommentReactionSummary();
  }

  // ─── Profiles ────────────────────────────────────────────────────────────

  Future<Map<String, Map<String, dynamic>>> loadProfiles(
    Iterable<String> userIds,
  ) async {
    final normalizedIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) return const <String, Map<String, dynamic>>{};

    final response = await _supabase
        .from('profiles')
        .select(
          'id, username, full_name, avatar_path, updated_at, '
          'is_verified_professor, professor_position, professor_institution',
        )
        .inFilter('id', normalizedIds);

    final profiles = <String, Map<String, dynamic>>{};
    for (final row in response) {
      final profile = Map<String, dynamic>.from(row);
      profiles['${profile['id']}'] = profile;
    }
    return profiles;
  }
}
