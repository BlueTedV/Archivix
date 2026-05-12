import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A single in-app notification row.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: '${map['id']}',
      type: '${map['type']}',
      title: '${map['title']}',
      body: '${map['body'] ?? ''}',
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      isRead: map['is_read'] == true,
      createdAt: DateTime.tryParse('${map['created_at']}') ?? DateTime(1970),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

/// User notification preferences (mirrors the DB table columns).
class NotificationPreferences {
  final bool paperApproved;
  final bool paperRejected;
  final bool postComment;
  final bool contentLiked;
  final bool milestoneViews;
  final bool newFollower;
  final bool followingUpload;

  const NotificationPreferences({
    this.paperApproved = true,
    this.paperRejected = true,
    this.postComment = true,
    this.contentLiked = true,
    this.milestoneViews = true,
    this.newFollower = true,
    this.followingUpload = true,
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      paperApproved: map['paper_approved'] != false,
      paperRejected: map['paper_rejected'] != false,
      postComment: map['post_comment'] != false,
      contentLiked: map['content_liked'] != false,
      milestoneViews: map['milestone_views'] != false,
      newFollower: map['new_follower'] != false,
      followingUpload: map['following_upload'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    'paper_approved': paperApproved,
    'paper_rejected': paperRejected,
    'post_comment': postComment,
    'content_liked': contentLiked,
    'milestone_views': milestoneViews,
    'new_follower': newFollower,
    'following_upload': followingUpload,
  };

  NotificationPreferences copyWith({
    bool? paperApproved,
    bool? paperRejected,
    bool? postComment,
    bool? contentLiked,
    bool? milestoneViews,
    bool? newFollower,
    bool? followingUpload,
  }) {
    return NotificationPreferences(
      paperApproved: paperApproved ?? this.paperApproved,
      paperRejected: paperRejected ?? this.paperRejected,
      postComment: postComment ?? this.postComment,
      contentLiked: contentLiked ?? this.contentLiked,
      milestoneViews: milestoneViews ?? this.milestoneViews,
      newFollower: newFollower ?? this.newFollower,
      followingUpload: followingUpload ?? this.followingUpload,
    );
  }
}

class NotificationService {
  NotificationService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // ─── Load notifications ───────────────────────────────────────────────────

  Future<List<AppNotification>> loadNotifications({int limit = 50}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final rows = await _supabase
          .from('notifications')
          .select('id, type, title, body, data, is_read, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(rows)
          .map(AppNotification.fromMap)
          .toList();
    } catch (e) {
      debugPrint('NotificationService.loadNotifications error: $e');
      return [];
    }
  }

  /// Returns the count of unread notifications.
  Future<int> unreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final rows = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (rows as List).length;
    } catch (e) {
      debugPrint('NotificationService.unreadCount error: $e');
      return 0;
    }
  }

  // ─── Mark as read ─────────────────────────────────────────────────────────

  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }

  // ─── Preferences ─────────────────────────────────────────────────────────

  Future<NotificationPreferences> loadPreferences() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const NotificationPreferences();

    try {
      final row = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return const NotificationPreferences();
      return NotificationPreferences.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('NotificationService.loadPreferences error: $e');
      return const NotificationPreferences();
    }
  }

  Future<void> savePreferences(NotificationPreferences prefs) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('notification_preferences')
        .upsert({'user_id': userId, ...prefs.toMap()});
  }

  // ─── View milestone check ─────────────────────────────────────────────────

  /// Call this after incrementing views to check if a milestone was hit.
  Future<void> checkViewMilestone({
    required String contentType,
    required String contentId,
  }) async {
    try {
      await _supabase.rpc('check_and_notify_view_milestone', params: {
        'p_content_type': contentType,
        'p_content_id': contentId,
      });
    } catch (e) {
      // Non-critical — silently ignore.
      debugPrint('NotificationService.checkViewMilestone error: $e');
    }
  }
}
