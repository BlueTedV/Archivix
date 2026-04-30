import 'package:supabase_flutter/supabase_flutter.dart';

class ContentEngagementSummary {
  final int likesCount;
  final int dislikesCount;
  final int? userReaction;

  const ContentEngagementSummary({
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.userReaction,
  });

  double qualityScoreForViews(int viewsCount) =>
      (likesCount * 3) - (dislikesCount * 2) + (viewsCount * 0.25);

  ContentEngagementSummary copyWith({
    int? likesCount,
    int? dislikesCount,
    int? userReaction,
    bool clearUserReaction = false,
  }) {
    return ContentEngagementSummary(
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      userReaction: clearUserReaction
          ? null
          : userReaction ?? this.userReaction,
    );
  }

  ContentEngagementSummary toggledReaction(int reactionValue) {
    var nextLikesCount = likesCount;
    var nextDislikesCount = dislikesCount;
    int? nextUserReaction = userReaction;

    if (userReaction == reactionValue) {
      if (reactionValue == 1) {
        nextLikesCount = nextLikesCount > 0 ? nextLikesCount - 1 : 0;
      } else {
        nextDislikesCount =
            nextDislikesCount > 0 ? nextDislikesCount - 1 : 0;
      }
      nextUserReaction = null;
    } else {
      if (userReaction == 1) {
        nextLikesCount = nextLikesCount > 0 ? nextLikesCount - 1 : 0;
      } else if (userReaction == -1) {
        nextDislikesCount =
            nextDislikesCount > 0 ? nextDislikesCount - 1 : 0;
      }

      if (reactionValue == 1) {
        nextLikesCount += 1;
      } else {
        nextDislikesCount += 1;
      }

      nextUserReaction = reactionValue;
    }

    return ContentEngagementSummary(
      likesCount: nextLikesCount,
      dislikesCount: nextDislikesCount,
      userReaction: nextUserReaction,
    );
  }
}

class ContentEngagementService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _tableForType(String contentType) {
    return contentType == 'paper' ? 'paper_reactions' : 'post_reactions';
  }

  String _idColumnForType(String contentType) {
    return contentType == 'paper' ? 'paper_id' : 'post_id';
  }

  int popularityScore({
    required int likesCount,
    required int dislikesCount,
    required int viewsCount,
  }) {
    return (likesCount * 2) + (dislikesCount * 2) + viewsCount;
  }

  double qualityScore({
    required int likesCount,
    required int dislikesCount,
    required int viewsCount,
  }) {
    return (likesCount * 3) - (dislikesCount * 2) + (viewsCount * 0.25);
  }

  Future<Map<String, ContentEngagementSummary>> loadSummaries({
    required String contentType,
    required List<String> contentIds,
    required String? userId,
  }) async {
    final summaries = {
      for (final id in contentIds) id: const ContentEngagementSummary(),
    };

    if (contentIds.isEmpty) {
      return summaries;
    }

    try {
      final table = _tableForType(contentType);
      final idColumn = _idColumnForType(contentType);

      final response = await _supabase
          .from(table)
          .select('$idColumn, user_id, reaction_value')
          .inFilter(idColumn, contentIds);

      for (final row in response) {
        final contentId = '${row[idColumn]}';
        final existing =
            summaries[contentId] ?? const ContentEngagementSummary();
        final reactionValue = row['reaction_value'] as int;

        summaries[contentId] = existing.copyWith(
          likesCount: existing.likesCount + (reactionValue == 1 ? 1 : 0),
          dislikesCount: existing.dislikesCount + (reactionValue == -1 ? 1 : 0),
          userReaction: row['user_id'] == userId
              ? reactionValue
              : existing.userReaction,
        );
      }
    } catch (_) {
      return summaries;
    }

    return summaries;
  }

  Future<ContentEngagementSummary> loadSummary({
    required String contentType,
    required String contentId,
    required String? userId,
  }) async {
    final summaries = await loadSummaries(
      contentType: contentType,
      contentIds: [contentId],
      userId: userId,
    );

    return summaries[contentId] ?? const ContentEngagementSummary();
  }

  Future<ContentEngagementSummary> toggleReaction({
    required String contentType,
    required String contentId,
    required int reactionValue,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Please sign in to react to content.');
    }

    final table = _tableForType(contentType);
    final idColumn = _idColumnForType(contentType);

    final existing = await _supabase
        .from(table)
        .select('id, reaction_value')
        .eq(idColumn, contentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from(table).insert({
        idColumn: contentId,
        'user_id': userId,
        'reaction_value': reactionValue,
      });
    } else if (existing['reaction_value'] == reactionValue) {
      await _supabase.from(table).delete().eq('id', existing['id']);
    } else {
      await _supabase
          .from(table)
          .update({'reaction_value': reactionValue})
          .eq('id', existing['id']);
    }

    return loadSummary(
      contentType: contentType,
      contentId: contentId,
      userId: userId,
    );
  }
}
