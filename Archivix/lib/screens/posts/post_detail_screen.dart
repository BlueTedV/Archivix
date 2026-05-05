import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import '../papers/pdf_viewer_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/content_engagement_service.dart';
import '../../core/services/post_comment_service.dart';
import '../public_profile_screen.dart';
import 'edit_post_screen.dart';
import 'post_history_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// pubspec.yaml dependencies (add if not already present):
//   video_player: ^2.8.0
//   path_provider: ^2.1.0
//   permission_handler: ^11.0.0
//   http: ^1.1.0
//   device_info_plus: ^9.0.0
//
// Schema used (matches your SQL setup):
//   posts:            id, title, content, created_at, views_count, user_id, category_id
//   post_attachments: id, post_id, file_url, file_name, file_type ('image'|'video'|'document'),
//                     file_size, mime_type, created_at
//   Storage bucket:   'post-attachments' — PUBLIC (no signed URLs needed)
// ─────────────────────────────────────────────────────────────────────────────

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final supabase = Supabase.instance.client;
  final _engagementService = ContentEngagementService();
  final _postCommentService = PostCommentService();
  final TextEditingController _commentController = TextEditingController();

  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _attachments = [];
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isLoadingComments = false;
  String? _error;
  String? _commentsError;
  bool _isReacting = false;
  bool _isSubmittingComment = false;
  ContentEngagementSummary _engagementSummary =
      const ContentEngagementSummary();

  // attachment id → resolved public URL
  final Map<String, String> _publicUrls = {};
  // attachment id → VideoPlayerController (video type only)
  final Map<String, VideoPlayerController> _videoControllers = {};
  // attachment id → download in progress
  final Map<String, bool> _isDownloading = {};

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadPostDetails();
    _loadReactionSummary();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadReactionSummary() async {
    final summary = await _engagementService.loadSummary(
      contentType: 'post',
      contentId: widget.postId,
      userId: supabase.auth.currentUser?.id,
    );

    if (mounted) {
      setState(() {
        _engagementSummary = summary;
      });
    }
  }

  // ─── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadPostDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Fetch post with joined category
      final postResponse = await supabase
          .from('posts')
          .select('''
            id,
            title,
            content,
            category_id,
            created_at,
            views_count,
            user_id,
            categories (name)
          ''')
          .eq('id', widget.postId)
          .single();

      final commentCounts = await _postCommentService.loadCommentCounts([
        widget.postId,
      ]);
      postResponse['comments_count'] = commentCounts[widget.postId] ?? 0;

      // 2. Fetch attachments
      final attachmentsResponse = await supabase
          .from('post_attachments')
          .select('id, file_url, file_name, file_type, file_size, mime_type')
          .eq('post_id', widget.postId)
          .order('created_at');

      final attachments = List<Map<String, dynamic>>.from(attachmentsResponse);

      // 3. Resolve public URLs + initialise video controllers.
      //    Bucket is public → getPublicUrl() works without auth tokens.
      for (final attachment in attachments) {
        final id = attachment['id'] as String;
        final storagePath = attachment['file_url'] as String;
        final fileType = (attachment['file_type'] as String? ?? '')
            .toLowerCase();

        try {
          final publicUrl = supabase.storage
              .from('post-attachments')
              .getPublicUrl(storagePath);

          _publicUrls[id] = publicUrl;

          if (fileType == 'video') {
            final controller = VideoPlayerController.networkUrl(
              Uri.parse(publicUrl),
            );
            await controller.initialize();
            controller.addListener(() {
              if (mounted) setState(() {});
            });
            _videoControllers[id] = controller;
          }
        } catch (e) {
          debugPrint('Could not prepare attachment $id: $e');
        }
      }

      if (mounted) {
        postResponse['category_name'] =
            (postResponse['categories'] as Map?)?['name'] ?? 'Uncategorized';

        setState(() {
          _post = postResponse;
          _attachments = attachments;
          _isLoading = false;
        });

        _loadComments();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      await supabase.rpc(
        'increment_post_views',
        params: {'post_id': widget.postId},
      );
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  Future<void> _loadComments() async {
    if (mounted) {
      setState(() {
        _isLoadingComments = true;
        _commentsError = null;
      });
    }

    try {
      final comments = await _postCommentService.loadComments(widget.postId);
      final profiles = await _postCommentService.loadProfiles(
        comments.map((comment) => '${comment['user_id'] ?? ''}'),
      );

      if (!mounted) return;

      final enrichedComments = comments.map((comment) {
        final enriched = Map<String, dynamic>.from(comment);
        enriched['profile'] = profiles['${comment['user_id']}'];
        return enriched;
      }).toList();

      setState(() {
        _comments = enrichedComments;
        _commentsError = null;
        _isLoadingComments = false;
        if (_post != null) {
          _post!['comments_count'] = enrichedComments.length;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _commentsError = _friendlyCommentsError(error);
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final user = supabase.auth.currentUser;
    final body = _commentController.text.trim();

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to comment.'),
          backgroundColor: AppColors.errorDark,
        ),
      );
      return;
    }

    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write a comment before posting.'),
          backgroundColor: AppColors.errorDark,
        ),
      );
      return;
    }

    final authorLabel = _currentUserLabel(user);
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticComment = <String, dynamic>{
      'id': tempId,
      'post_id': widget.postId,
      'user_id': user.id,
      'author_label': authorLabel,
      'body': body,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'is_pending': true,
      'profile': _currentUserProfile(user),
    };

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmittingComment = true;
      _commentsError = null;
      _comments = [..._comments, optimisticComment];
      _commentController.clear();
      if (_post != null) {
        _post!['comments_count'] = _comments.length;
      }
    });

    try {
      final inserted = await _postCommentService.insertComment(
        postId: widget.postId,
        userId: user.id,
        body: body,
        authorLabel: authorLabel,
      );

      if (!mounted) return;

      setState(() {
        _comments = _comments
            .map(
              (comment) => comment['id'] == tempId
                  ? <String, dynamic>{
                      ...Map<String, dynamic>.from(inserted),
                      'profile': _currentUserProfile(user),
                    }
                  : comment,
            )
            .toList();
        if (_post != null) {
          _post!['comments_count'] = _comments.length;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _comments.removeWhere((comment) => comment['id'] == tempId);
        _commentsError = _friendlyCommentsError(error);
        if (_post != null) {
          _post!['comments_count'] = _comments.length;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyCommentsError(error)),
          backgroundColor: AppColors.errorDark,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  // ─── Document: open PDF in viewer ───────────────────────────────────────────

  Future<void> _toggleReaction(int reactionValue) async {
    final previousSummary = _engagementSummary;
    final optimisticSummary = previousSummary.toggledReaction(reactionValue);

    setState(() {
      _isReacting = true;
      _engagementSummary = optimisticSummary;
    });

    try {
      final summary = await _engagementService.toggleReaction(
        contentType: 'post',
        contentId: widget.postId,
        reactionValue: reactionValue,
      );

      if (mounted) {
        setState(() {
          _engagementSummary = summary;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _engagementSummary = previousSummary;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.errorDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReacting = false);
    }
  }

  bool get _isOwner =>
      _post != null && _post!['user_id'] == supabase.auth.currentUser?.id;

  Future<void> _openHistory() async {
    if (_post == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostHistoryScreen(
          postId: widget.postId,
          postTitle: _post!['title'] ?? 'Question History',
        ),
      ),
    );
  }

  Future<void> _openEdit() async {
    if (_post == null) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPostScreen(
          post: Map<String, dynamic>.from(_post!),
          attachments: List<Map<String, dynamic>>.from(_attachments),
        ),
      ),
    );

    if (updated == true) {
      _loadPostDetails();
    }
  }

  void _viewDocument(Map<String, dynamic> attachment) {
    final id = attachment['id'] as String;
    final publicUrl = _publicUrls[id];
    if (publicUrl == null) return;

    final mimeType = (attachment['mime_type'] as String? ?? '').toLowerCase();
    final fileName = attachment['file_name'] as String? ?? 'Document';

    // Route PDFs to the viewer; everything else falls through to download
    if (mimeType == 'application/pdf' ||
        fileName.toLowerCase().endsWith('.pdf')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(pdfUrl: publicUrl, title: fileName),
        ),
      );
    } else {
      _downloadAttachment(attachment);
    }
  }

  // ─── Download (saves file to device) ────────────────────────────────────────

  Future<void> _downloadAttachment(Map<String, dynamic> attachment) async {
    final id = attachment['id'] as String;
    final publicUrl = _publicUrls[id];
    if (publicUrl == null) return;

    // Android < 13 needs WRITE_EXTERNAL_STORAGE permission
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        PermissionStatus status = await Permission.storage.status;
        if (status.isDenied) status = await Permission.storage.request();

        if (status.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Storage permission is required to download files',
                ),
                backgroundColor: AppColors.errorDark,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        if (status.isPermanentlyDenied) {
          if (mounted) _showPermissionDialog();
          return;
        }
      }
    }

    setState(() => _isDownloading[id] = true);

    try {
      final response = await http.get(Uri.parse(publicUrl));

      if (response.statusCode == 200) {
        final fileName = attachment['file_name'] as String? ?? 'file';
        final String savedPath;

        if (Platform.isAndroid) {
          final dir = Directory('/storage/emulated/0/Download');
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          savedPath = file.path;
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          savedPath = file.path;
        }

        debugPrint('Saved to $savedPath');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ Download Complete!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(fileName, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text(
                    'Check your Downloads folder',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: AppColors.surfaceWhite,
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${error.toString()}'),
            backgroundColor: AppColors.errorDark,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading[id] = false);
    }
  }

  // ─── Permission dialog ───────────────────────────────────────────────────────

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Storage Permission Required',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'This app needs storage permission to download files. '
          'Please enable it in Settings → Permissions → Storage.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppColors.border),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.slatePrimary,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final diff = DateTime.now().difference(date);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'Unknown';

    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);
      final hh = date.hour.toString().padLeft(2, '0');
      final mm = date.minute.toString().padLeft(2, '0');

      if (difference.inMinutes < 1) {
        return 'Just now';
      }
      if (difference.inHours < 1) {
        return '${difference.inMinutes} min ago';
      }
      if (difference.inDays == 0) {
        return 'Today at $hh:$mm';
      }
      if (difference.inDays == 1) {
        return 'Yesterday at $hh:$mm';
      }
      if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      }
      return '${date.day}/${date.month}/${date.year} $hh:$mm';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _friendlyCommentsError(Object error) {
    final message = error.toString();
    final normalized = message.toLowerCase();
    if (normalized.contains(
          'relation "public.paper_comments" does not exist',
        ) ||
        normalized.contains('relation "paper_comments" does not exist') ||
        normalized.contains('column "post_id" does not exist') ||
        normalized.contains('could not find the table') ||
        normalized.contains('schema cache')) {
      return 'Comments are not ready yet. Run paper_comments_setup.sql in Supabase first.';
    }
    return 'Unable to load comments right now.\n$message';
  }

  Map<String, dynamic> _currentUserProfile(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return <String, dynamic>{
      'id': user.id,
      'username': metadata['username'],
      'full_name': metadata['full_name'] ?? metadata['name'],
      'avatar_path': metadata['avatar_path'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  String _currentUserLabel(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final candidate =
        [
              metadata['username'],
              metadata['full_name'],
              metadata['name'],
              metadata['display_name'],
            ]
            .whereType<String>()
            .map((value) => value.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    if (candidate.isNotEmpty) {
      return candidate;
    }

    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Researcher';
  }

  String _commentDisplayName(
    Map<String, dynamic>? profile,
    String? authorLabel,
  ) {
    final username = (profile?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    final fullName = (profile?['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final fallbackLabel = authorLabel?.trim();
    if (fallbackLabel != null && fallbackLabel.isNotEmpty) {
      return fallbackLabel;
    }

    return 'Researcher';
  }

  String? _commentSecondaryLabel(Map<String, dynamic>? profile) {
    final username = (profile?['username'] as String?)?.trim();
    final fullName = (profile?['full_name'] as String?)?.trim();

    if (username != null &&
        username.isNotEmpty &&
        fullName != null &&
        fullName.isNotEmpty) {
      return fullName;
    }

    return null;
  }

  String? _profileAvatarUrl(Map<String, dynamic>? profile) {
    final avatarPath = (profile?['avatar_path'] as String?)?.trim();
    if (avatarPath == null || avatarPath.isEmpty) {
      return null;
    }

    final updatedAt = (profile?['updated_at'] as String?) ?? '';
    final publicUrl = supabase.storage
        .from('profile-avatars')
        .getPublicUrl(avatarPath);
    return '$publicUrl?v=${Uri.encodeComponent(updatedAt)}';
  }

  Future<void> _openProfileViewer(Map<String, dynamic> comment) async {
    final userId = '${comment['user_id'] ?? ''}'.trim();
    if (userId.isEmpty) return;

    final initialProfile = comment['profile'] is Map<String, dynamic>
        ? comment['profile'] as Map<String, dynamic>
        : null;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PublicProfileScreen(userId: userId, initialProfile: initialProfile),
      ),
    );
  }

  Widget _buildDiscussionSection() {
    return Column(
      children: [
        _buildCommentComposer(),
        const SizedBox(height: 12),
        if (_isLoadingComments)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Loading discussion...',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          )
        else if (_commentsError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.errorSurface,
              border: Border.all(color: AppColors.errorBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Discussion unavailable',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.errorDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _commentsError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.errorDark,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadComments,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_comments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceFaint,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 40,
                  color: AppColors.textSubtle,
                ),
                SizedBox(height: 12),
                Text(
                  'No comments yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Start the discussion by asking a follow-up or sharing a helpful answer.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSubtle),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._comments.map(_buildCommentCard),
      ],
    );
  }

  Widget _buildCommentComposer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join the discussion',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText:
                  'Share a helpful answer, follow-up question, or extra context...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your current username and profile photo will be shown with this comment.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSubmittingComment ? null : _submitComment,
                icon: _isSubmittingComment
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
                    : const Icon(Icons.send, size: 16),
                label: Text(_isSubmittingComment ? 'Posting...' : 'Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final isPending = comment['is_pending'] == true;
    final isOwnComment =
        comment['user_id'] != null &&
        comment['user_id'] == supabase.auth.currentUser?.id;
    final profile = comment['profile'] as Map<String, dynamic>?;
    final avatarUrl = _profileAvatarUrl(profile);
    final displayName = _commentDisplayName(
      profile,
      comment['author_label'] as String?,
    );
    final secondaryLabel = _commentSecondaryLabel(profile);
    final initials = displayName.trim().isNotEmpty
        ? displayName.replaceFirst('@', '').substring(0, 1).toUpperCase()
        : '?';

    final authorButton = InkWell(
      onTap: isPending ? null : () => _openProfileViewer(comment),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.slatePrimary, Color(0xFF73829B)],
              ),
              border: Border.all(color: const Color(0xFF3F4857)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl == null
                ? Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  secondaryLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Opacity(
      opacity: isPending ? 0.7 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: authorButton),
                if (isOwnComment && !isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPending ? 'Sending...' : _formatDateTime(comment['created_at']),
              style: const TextStyle(fontSize: 11, color: AppColors.textSubtle),
            ),
            const SizedBox(height: 10),
            Text(
              comment['body'] ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ─── Section header ──────────────────────────────────────────────────────────

  Widget _buildReactionRow() {
    return Row(
      children: [
        _buildReactionChip(
          icon: Icons.thumb_up_alt_outlined,
          activeIcon: Icons.thumb_up_alt,
          count: _engagementSummary.likesCount,
          isActive: _engagementSummary.userReaction == 1,
          activeColor: AppColors.success,
          onTap: _isReacting ? null : () => _toggleReaction(1),
        ),
        const SizedBox(width: 8),
        _buildReactionChip(
          icon: Icons.thumb_down_alt_outlined,
          activeIcon: Icons.thumb_down_alt,
          count: _engagementSummary.dislikesCount,
          isActive: _engagementSummary.userReaction == -1,
          activeColor: AppColors.errorDark,
          onTap: _isReacting ? null : () => _toggleReaction(-1),
        ),
      ],
    );
  }

  Widget _buildReactionChip({
    required IconData icon,
    required IconData activeIcon,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.35)
                : AppColors.amberBorder,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 16,
              color: isActive ? activeColor : AppColors.amberDark,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : AppColors.amberDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 3, height: 20, color: AppColors.amberDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ─── Attachment dispatcher ───────────────────────────────────────────────────

  Widget _buildAttachmentWidget(Map<String, dynamic> attachment) {
    final fileType = (attachment['file_type'] as String? ?? '').toLowerCase();

    switch (fileType) {
      case 'image':
        return _buildImageAttachment(attachment);
      case 'video':
        return _buildVideoAttachment(attachment);
      case 'document':
        return _buildDocumentAttachment(attachment);
      default:
        return _buildGenericAttachment(attachment);
    }
  }

  // ── Image: full-width inline preview, tap → fullscreen ──────────────────────
  Widget _buildImageAttachment(Map<String, dynamic> attachment) {
    final id = attachment['id'] as String;
    final fileName = attachment['file_name'] as String? ?? 'Image';
    final publicUrl = _publicUrls[id];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: publicUrl != null
          ? GestureDetector(
              onTap: () => _openFullscreenImage(publicUrl, fileName),
              child: Stack(
                children: [
                  Image.network(
                    publicUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return _attachmentPlaceholder(
                        height: 220,
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          color: AppColors.slatePrimary,
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => _attachmentPlaceholder(
                      height: 220,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 40,
                            color: AppColors.textSubtle,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Could not load image',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom gradient: filename + expand icon
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xCC000000), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.photo,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.open_in_full,
                            size: 12,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _attachmentPlaceholder(
              height: 220,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
    );
  }

  void _openFullscreenImage(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              title,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }

  // ── Video: inline player with scrubber ──────────────────────────────────────
  Widget _buildVideoAttachment(Map<String, dynamic> attachment) {
    final id = attachment['id'] as String;
    final fileName = attachment['file_name'] as String? ?? 'Video';
    final fileSize = attachment['file_size'] as int?;
    final controller = _videoControllers[id];

    // Still initialising
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }

    final isPlaying = controller.value.isPlaying;
    final aspectRatio =
        controller.value.aspectRatio.isNaN || controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Video frame + tap-to-play overlay
          AspectRatio(
            aspectRatio: aspectRatio,
            child: GestureDetector(
              onTap: () => setState(
                () => isPlaying ? controller.pause() : controller.play(),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  AnimatedOpacity(
                    opacity: isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrubber
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: AppColors.amberDark,
              bufferedColor: AppColors.textMuted,
              backgroundColor: AppColors.textSecondary,
            ),
            padding: EdgeInsets.zero,
          ),

          // Controls row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(
                    () => isPlaying ? controller.pause() : controller.play(),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.slatePrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (_, value, _) => Text(
                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSubtle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.videocam,
                  size: 12,
                  color: AppColors.textSubtle,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fileSize != null)
                  Text(
                    _formatFileSize(fileSize),
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
    );
  }

  // ── Document (PDF + others): click-to-view / download card ──────────────────
  Widget _buildDocumentAttachment(Map<String, dynamic> attachment) {
    final id = attachment['id'] as String;
    final fileName = attachment['file_name'] as String? ?? 'Document';
    final fileSize = attachment['file_size'] as int?;
    final mimeType = (attachment['mime_type'] as String? ?? '').toLowerCase();
    final isDownloading = _isDownloading[id] ?? false;

    final isPdf =
        mimeType == 'application/pdf' ||
        fileName.toLowerCase().endsWith('.pdf');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFFED7AA)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.amberSurface,
              border: Border.all(color: AppColors.amberBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              color: AppColors.amberDark,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _formatFileSize(fileSize),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  isPdf
                      ? 'Tap "View" to open or download this PDF'
                      : 'Tap "Download" to save this file',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.amberDark,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // View button — PDF only
                    if (isPdf) ...[
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: isDownloading
                                ? null
                                : () => _viewDocument(attachment),
                            icon: const Icon(Icons.visibility, size: 14),
                            label: const Text(
                              'View PDF',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.slatePrimary,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Download button — always shown
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: isDownloading
                              ? null
                              : () => _downloadAttachment(attachment),
                          icon: isDownloading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.slatePrimary,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.download, size: 14),
                          label: Text(
                            isDownloading ? 'Saving...' : 'Download',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.slatePrimary,
                            side: const BorderSide(
                              color: AppColors.slatePrimary,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Generic fallback (unknown file_type value) ───────────────────────────────
  Widget _buildGenericAttachment(Map<String, dynamic> attachment) {
    final id = attachment['id'] as String;
    final fileName = attachment['file_name'] as String? ?? 'File';
    final mimeType = attachment['mime_type'] as String? ?? '';
    final fileSize = attachment['file_size'] as int?;
    final isDownloading = _isDownloading[id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.insert_drive_file,
              color: AppColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (mimeType.isNotEmpty || fileSize != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (mimeType.isNotEmpty)
                        mimeType.split('/').last.toUpperCase(),
                      if (fileSize != null) _formatFileSize(fileSize),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSubtle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: isDownloading
                  ? null
                  : () => _downloadAttachment(attachment),
              icon: isDownloading
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.slatePrimary,
                        ),
                      ),
                    )
                  : const Icon(Icons.download, size: 14),
              label: Text(
                isDownloading ? '...' : 'Save',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.slatePrimary,
                side: const BorderSide(color: AppColors.slatePrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared loading placeholder ───────────────────────────────────────────────
  Widget _attachmentPlaceholder({
    required double height,
    required Widget child,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppColors.surfaceLight,
      child: Center(child: child),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Detail'),
        actions: [
          if (_post != null)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _openHistory,
              tooltip: 'View History',
            ),
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEdit,
              tooltip: 'Edit Question',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadPostDetails,
              child: _buildContent(),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.errorDark,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.errorDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPostDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slatePrimary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Type badge ──────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.amberSurface,
                border: Border.all(color: AppColors.amberBorder),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.question_answer,
                    size: 12,
                    color: AppColors.amberDark,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'QUESTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amberDark,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Title ───────────────────────────────────────────────────────────
        Text(
          _post!['title'],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // ── Metadata card ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.amberSurface,
            border: Border.all(color: AppColors.amberBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.category,
                    size: 15,
                    color: AppColors.amberDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    (_post!['categories'] as Map?)?['name'] ?? 'Uncategorized',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.amberDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 15,
                    color: AppColors.amberDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(_post!['created_at']),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.amberDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.visibility,
                    size: 15,
                    color: AppColors.amberDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_post!['views_count'] ?? 0} views',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.amberDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.comment_outlined,
                    size: 15,
                    color: AppColors.amberDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_post!['comments_count'] ?? _comments.length} comments',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.amberDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildReactionRow(),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Content ─────────────────────────────────────────────────────────
        _buildSectionHeader('Content'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _post!['content'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ),

        // ── Attachments ─────────────────────────────────────────────────────
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Attachments (${_attachments.length})'),
          const SizedBox(height: 12),
          ..._attachments.map(_buildAttachmentWidget),
        ],

        const SizedBox(height: 24),

        // ── Discussion placeholder ───────────────────────────────────────────
        _buildSectionHeader('Discussion'),
        const SizedBox(height: 12),
        _buildDiscussionSection(),

        const SizedBox(height: 24),
      ],
    );
  }
}
