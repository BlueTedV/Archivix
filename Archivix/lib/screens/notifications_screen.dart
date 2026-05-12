import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/notification_service.dart';
import 'papers/paper_detail_screen.dart';
import 'posts/post_detail_screen.dart';
import 'public_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  List<AppNotification> _notifications = [];
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
      final items = await _service.loadNotifications();
      if (mounted) setState(() => _notifications = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllAsRead();
    if (mounted) {
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
      });
    }
  }

  Future<void> _handleTap(AppNotification notification) async {
    // Mark as read.
    if (!notification.isRead) {
      await _service.markAsRead(notification.id);
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((n) {
            return n.id == notification.id ? n.copyWith(isRead: true) : n;
          }).toList();
        });
      }
    }

    if (!mounted) return;

    // Navigate based on notification type and data.
    final data = notification.data;
    final contentType = data['content_type'] as String?;
    final contentId = data['content_id'] as String?;
    final followerId = data['follower_id'] as String?;
    final authorId = data['author_id'] as String?;

    if (contentType == 'paper' && contentId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaperDetailScreen(paperId: contentId),
        ),
      );
    } else if (contentType == 'post' && contentId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: contentId),
        ),
      );
    } else if (followerId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(userId: followerId),
        ),
      );
    } else if (authorId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(userId: authorId),
        ),
      );
    }
  }

  Future<void> _delete(AppNotification notification) async {
    await _service.deleteNotification(notification.id);
    if (mounted) {
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slatePrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _notifications.isEmpty
            ? _buildEmpty()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) =>
                    _buildTile(_notifications[index]),
              ),
      ),
    );
  }

  Widget _buildTile(AppNotification notification) {
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.errorDark,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _delete(notification),
      child: InkWell(
        onTap: () => _handleTap(notification),
        child: Container(
          color: isUnread
              ? AppColors.slatePrimary.withValues(alpha: 0.05)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _iconBackground(notification.type),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconFor(notification.type),
                  size: 20,
                  color: _iconColor(notification.type),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.slatePrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                Icons.notifications_none_outlined,
                size: 56,
                color: AppColors.textSubtle,
              ),
              SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Activity on your content will show up here.',
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

  // ─── Helpers ─────────────────────────────────────────────────────────────

  IconData _iconFor(String type) {
    return switch (type) {
      'paper_approved' => Icons.verified_outlined,
      'paper_rejected' => Icons.cancel_outlined,
      'post_comment' => Icons.comment_outlined,
      'content_liked' => Icons.thumb_up_alt_outlined,
      'milestone_views' => Icons.bar_chart,
      'new_follower' => Icons.person_add_outlined,
      'following_upload' => Icons.upload_file_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  Color _iconColor(String type) {
    return switch (type) {
      'paper_approved' => AppColors.successDark,
      'paper_rejected' => AppColors.errorDark,
      'post_comment' => AppColors.slatePrimary,
      'content_liked' => AppColors.success,
      'milestone_views' => AppColors.amberDark,
      'new_follower' => AppColors.slatePrimary,
      'following_upload' => AppColors.amberDark,
      _ => AppColors.textMuted,
    };
  }

  Color _iconBackground(String type) {
    return switch (type) {
      'paper_approved' => AppColors.successLight,
      'paper_rejected' => AppColors.errorSurface,
      'post_comment' => const Color(0xFFE9EFF7),
      'content_liked' => AppColors.successLight,
      'milestone_views' => AppColors.amberSurface,
      'new_follower' => const Color(0xFFE9EFF7),
      'following_upload' => AppColors.amberSurface,
      _ => AppColors.surfaceLight,
    };
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
