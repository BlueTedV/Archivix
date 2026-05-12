import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FollowService {
  FollowService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // ─── Follow state ─────────────────────────────────────────────────────────

  /// Returns true if the current user is following [targetUserId].
  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final result = await _supabase
        .from('user_follows')
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    return result != null;
  }

  /// Returns follower and following counts for [userId].
  Future<({int followers, int following})> loadCounts(String userId) async {
    try {
      final results = await Future.wait([
        _supabase.rpc('get_follower_count', params: {'target_user_id': userId}),
        _supabase.rpc('get_following_count', params: {'target_user_id': userId}),
      ]);
      return (
        followers: (results[0] as int?) ?? 0,
        following: (results[1] as int?) ?? 0,
      );
    } catch (e) {
      debugPrint('FollowService.loadCounts error: $e');
      return (followers: 0, following: 0);
    }
  }

  /// Follows [targetUserId]. Throws on error.
  Future<void> follow(String targetUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Please sign in to follow users.');
    if (currentUserId == targetUserId) throw Exception('You cannot follow yourself.');

    await _supabase.from('user_follows').insert({
      'follower_id': currentUserId,
      'following_id': targetUserId,
    });
  }

  /// Unfollows [targetUserId]. Throws on error.
  Future<void> unfollow(String targetUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Please sign in.');

    await _supabase
        .from('user_follows')
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId);
  }

  /// Toggles follow state. Returns the new [isFollowing] value.
  Future<bool> toggle(String targetUserId) async {
    final currently = await isFollowing(targetUserId);
    if (currently) {
      await unfollow(targetUserId);
      return false;
    } else {
      await follow(targetUserId);
      return true;
    }
  }

  // ─── Follower / following lists ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadFollowers(String userId) async {
    final rows = await _supabase
        .from('user_follows')
        .select('follower_id, created_at, profiles!user_follows_follower_id_fkey(id, username, full_name, avatar_path, updated_at)')
        .eq('following_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadFollowing(String userId) async {
    final rows = await _supabase
        .from('user_follows')
        .select('following_id, created_at, profiles!user_follows_following_id_fkey(id, username, full_name, avatar_path, updated_at)')
        .eq('follower_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }
}
