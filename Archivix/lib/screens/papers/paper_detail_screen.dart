import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'pdf_viewer_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/content_engagement_service.dart';
import '../../core/services/comment_service.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/save_to_collection_sheet.dart';
import '../../core/utils/paper_review_status.dart';
import '../../widgets/comment_reply_dialog.dart';
import '../public_profile_screen.dart';
import 'edit_paper_screen.dart';
import 'paper_history_screen.dart';

class PaperDetailScreen extends StatefulWidget {
  final String paperId;

  const PaperDetailScreen({super.key, required this.paperId});

  @override
  State<PaperDetailScreen> createState() => _PaperDetailScreenState();
}

class _PaperDetailScreenState extends State<PaperDetailScreen> {
  final supabase = Supabase.instance.client;
  final _engagementService = ContentEngagementService();
  final _paperCommentService = CommentService(contentType: 'paper');
  final _notificationService = NotificationService();
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? _paper;
  List<Map<String, dynamic>> _authors = [];
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isLoadingComments = false;
  String? _error;
  String? _commentsError;
  bool _isDownloading = false;
  bool _isViewing = false;
  bool _isReacting = false;
  bool _isSubmittingComment = false;
  final Set<String> _reactingCommentIds = {};
  ContentEngagementSummary _engagementSummary =
      const ContentEngagementSummary();

  @override
  void initState() {
    super.initState();
    _loadPaperDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReactionSummary() async {
    if (_paper != null && !PaperReviewStatus.isPublished(_paper!['status'])) {
      return;
    }

    final summary = await _engagementService.loadSummary(
      contentType: 'paper',
      contentId: widget.paperId,
      userId: supabase.auth.currentUser?.id,
    );

    if (mounted) {
      setState(() {
        _engagementSummary = summary;
      });
    }
  }

  Future<void> _loadPaperDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch paper details
      final paperResponse = await supabase
          .from('papers')
          .select('''
            id,
            title,
            abstract,
            category_id,
            pdf_url,
            pdf_file_name,
            pdf_file_size,
            views_count,
            created_at,
            submitted_at,
            reviewed_at,
            published_at,
            status,
            rejection_reason,
            user_id,
            categories (name)
          ''')
          .eq('id', widget.paperId)
          .single();

      final commentCounts = await _paperCommentService.loadCommentCounts([
        widget.paperId,
      ]);
      paperResponse['comments_count'] = commentCounts[widget.paperId] ?? 0;
      final uploaderProfiles = await _paperCommentService.loadProfiles([
        '${paperResponse['user_id'] ?? ''}',
      ]);
      paperResponse['uploader_profile'] =
          uploaderProfiles['${paperResponse['user_id']}'];

      // Fetch authors
      final authorsResponse = await supabase
          .from('paper_authors')
          .select('name, email, affiliation, author_order')
          .eq('paper_id', widget.paperId)
          .order('author_order');

      if (mounted) {
        paperResponse['category_name'] =
            (paperResponse['categories'] as Map?)?['name'] ?? 'Uncategorized';
        final status = PaperReviewStatus.normalize(paperResponse['status']);

        setState(() {
          _paper = paperResponse;
          _authors = List<Map<String, dynamic>>.from(authorsResponse);
          _isLoading = false;
        });

        if (PaperReviewStatus.isPublished(status)) {
          _loadReactionSummary();
          _loadComments();
          _incrementViewCount();
        } else {
          setState(() {
            _engagementSummary = const ContentEngagementSummary();
            _comments = [];
            _commentsError = null;
            _isLoadingComments = false;
          });
        }
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
    if (_paper != null && !PaperReviewStatus.isPublished(_paper!['status'])) {
      return;
    }

    try {
      await supabase.rpc(
        'increment_paper_views',
        params: {'paper_id': widget.paperId},
      );
      // Check if a view milestone was just hit.
      await _notificationService.checkViewMilestone(
        contentType: 'paper',
        contentId: widget.paperId,
      );
    } catch (e) {
      // Silent fail - not critical
      debugPrint('Error incrementing views: $e');
    }
  }

  Future<void> _loadComments() async {
    if (_paper != null && !PaperReviewStatus.isPublished(_paper!['status'])) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingComments = true;
        _commentsError = null;
      });
    }

    try {
      final comments = await _paperCommentService.loadComments(widget.paperId);
      final profiles = await _paperCommentService.loadProfiles(
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
        _isLoadingComments = false;
        if (_paper != null) {
          _paper!['comments_count'] = enrichedComments.length;
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
      'paper_id': widget.paperId,
      'user_id': user.id,
      'author_label': authorLabel,
      'body': body,
      'parent_comment_id': null,
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
      if (_paper != null) {
        _paper!['comments_count'] = _comments.length;
      }
    });

    try {
      final inserted = await _paperCommentService.insertComment(
        contentId: widget.paperId,
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
        if (_paper != null) {
          _paper!['comments_count'] = _comments.length;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _comments.removeWhere((comment) => comment['id'] == tempId);
        _commentsError = _friendlyCommentsError(error);
        if (_paper != null) {
          _paper!['comments_count'] = _comments.length;
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

  Future<void> _submitReply(
    Map<String, dynamic> parentComment,
    String body,
  ) async {
    final user = supabase.auth.currentUser;
    final parentCommentId = '${parentComment['id'] ?? ''}'.trim();

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to reply.'),
          backgroundColor: AppColors.errorDark,
        ),
      );
      return;
    }

    if (parentCommentId.isEmpty || parentComment['is_pending'] == true) {
      return;
    }

    final authorLabel = _currentUserLabel(user);
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticReply = <String, dynamic>{
      'id': tempId,
      'paper_id': widget.paperId,
      'user_id': user.id,
      'author_label': authorLabel,
      'body': body,
      'parent_comment_id': parentCommentId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'is_pending': true,
      'profile': _currentUserProfile(user),
      'likes_count': 0,
      'dislikes_count': 0,
      'user_reaction': null,
    };

    setState(() {
      _commentsError = null;
      _comments = [..._comments, optimisticReply];
      if (_paper != null) {
        _paper!['comments_count'] = _comments.length;
      }
    });

    try {
      final inserted = await _paperCommentService.insertComment(
        contentId: widget.paperId,
        userId: user.id,
        body: body,
        authorLabel: authorLabel,
        parentCommentId: parentCommentId,
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
        if (_paper != null) {
          _paper!['comments_count'] = _comments.length;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _comments.removeWhere((comment) => comment['id'] == tempId);
        _commentsError = _friendlyCommentsError(error);
        if (_paper != null) {
          _paper!['comments_count'] = _comments.length;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyCommentsError(error)),
          backgroundColor: AppColors.errorDark,
        ),
      );
    }
  }

  Future<void> _showReplyDialog(Map<String, dynamic> parentComment) async {
    final body = await showDialog<String>(
      context: context,
      builder: (_) => const CommentReplyDialog(),
    );

    if (!mounted || body == null) return;
    await _submitReply(parentComment, body);
  }

  CommentReactionSummary _commentReactionSummary(
    Map<String, dynamic> comment,
  ) {
    return CommentReactionSummary(
      likesCount: comment['likes_count'] as int? ?? 0,
      dislikesCount: comment['dislikes_count'] as int? ?? 0,
      userReaction: comment['user_reaction'] as int?,
    );
  }

  void _updateCommentReaction(
    String commentId,
    CommentReactionSummary summary,
  ) {
    _comments = _comments.map((comment) {
      if (comment['id'] != commentId) return comment;
      return <String, dynamic>{
        ...comment,
        'likes_count': summary.likesCount,
        'dislikes_count': summary.dislikesCount,
        'user_reaction': summary.userReaction,
      };
    }).toList();
  }

  Future<void> _toggleCommentReaction(
    Map<String, dynamic> comment,
    int reactionValue,
  ) async {
    final commentId = '${comment['id'] ?? ''}'.trim();
    if (commentId.isEmpty || comment['is_pending'] == true) return;

    final previousSummary = _commentReactionSummary(comment);
    final optimisticSummary = previousSummary.toggledReaction(reactionValue);

    setState(() {
      _reactingCommentIds.add(commentId);
      _updateCommentReaction(commentId, optimisticSummary);
    });

    try {
      final summary = await _paperCommentService.toggleCommentReaction(
        commentId: commentId,
        reactionValue: reactionValue,
      );

      if (mounted) {
        setState(() {
          _updateCommentReaction(commentId, summary);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _updateCommentReaction(commentId, previousSummary);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyCommentsError(error)),
            backgroundColor: AppColors.errorDark,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _reactingCommentIds.remove(commentId);
        });
      }
    }
  }

  Future<void> _toggleReaction(int reactionValue) async {
    final previousSummary = _engagementSummary;
    final optimisticSummary = previousSummary.toggledReaction(reactionValue);

    setState(() {
      _isReacting = true;
      _engagementSummary = optimisticSummary;
    });

    try {
      final summary = await _engagementService.toggleReaction(
        contentType: 'paper',
        contentId: widget.paperId,
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
      if (mounted) {
        setState(() {
          _isReacting = false;
        });
      }
    }
  }

  bool get _isOwner =>
      _paper != null && _paper!['user_id'] == supabase.auth.currentUser?.id;

  bool get _canEditPaper =>
      _paper != null && _paper!['user_id'] == supabase.auth.currentUser?.id;

  bool get _isAdmin {
    final role = supabase.auth.currentUser?.appMetadata['role'];
    return role is String && role.toLowerCase() == 'admin';
  }

  bool _shouldShowStatusUi(String status) {
    return !PaperReviewStatus.isPublished(status) || _isAdmin;
  }

  Future<void> _openHistory() async {
    if (_paper == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaperHistoryScreen(
          paperId: widget.paperId,
          paperTitle: _paper!['title'] ?? 'Document History',
        ),
      ),
    );
  }

  Future<void> _openEdit() async {
    if (_paper == null) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPaperScreen(
          paper: Map<String, dynamic>.from(_paper!),
          authors: List<Map<String, dynamic>>.from(_authors),
        ),
      ),
    );

    if (updated == true) {
      _loadPaperDetails();
    }
  }

  Future<void> _viewPDF() async {
    if (_paper == null || _paper!['pdf_url'] == null) return;

    setState(() {
      _isViewing = true;
    });

    try {
      // Get signed URL for viewing
      final pdfUrl = _paper!['pdf_url'] as String;
      final signedUrl = await supabase.storage
          .from('papers-pdf')
          .createSignedUrl(pdfUrl, 3600); // 1 hour expiry

      if (mounted) {
        setState(() {
          _isViewing = false;
        });

        // Navigate to PDF viewer screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PdfViewerScreen(pdfUrl: signedUrl, title: _paper!['title']),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isViewing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: AppColors.errorDark,
          ),
        );
      }
    }
  }

  Future<void> _downloadPDF() async {
    if (_paper == null || _paper!['pdf_url'] == null) return;

    // Request storage permission on Android
    if (Platform.isAndroid) {
      // Check Android version
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt < 33) {
        // Android 12 and below - Need storage permission
        PermissionStatus status = await Permission.storage.status;

        if (status.isDenied) {
          // Request permission - this will show the popup automatically
          status = await Permission.storage.request();
        }

        if (status.isDenied) {
          // User denied permission
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
          // User denied permission permanently - show dialog to go to settings
          if (mounted) {
            _showPermissionDialog();
          }
          return;
        }
      }
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      // Get signed URL
      final pdfUrl = _paper!['pdf_url'] as String;
      final signedUrl = await supabase.storage
          .from('papers-pdf')
          .createSignedUrl(pdfUrl, 3600);

      // Download file
      final response = await http.get(Uri.parse(signedUrl));

      if (response.statusCode == 200) {
        final fileName = _paper!['pdf_file_name'] ?? 'paper.pdf';

        if (Platform.isAndroid) {
          // Save to PUBLIC Downloads folder (where users expect it!)
          final directory = Directory('/storage/emulated/0/Download');

          // Create file in Downloads
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
        } else {
          // iOS - use app documents directory
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
        }

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
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to download file');
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
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Storage Permission Required',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'This app needs storage permission to download PDF files. '
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
              openAppSettings(); // Opens app settings page
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
                : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 16,
              color: isActive ? activeColor : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
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
    if (normalized.contains('paper_comments') ||
        normalized.contains('parent_comment_id') ||
        normalized.contains('comment_reactions') ||
        normalized.contains('could not find the table') ||
        normalized.contains('schema cache')) {
      return 'Comments need the latest reply/reaction schema. Run comments_replies_reactions_setup.sql in Supabase first.';
    }
    return 'Unable to load comments right now.\n$message';
  }

  String _currentUserLabel(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final candidate =
        [
              metadata['full_name'],
              metadata['name'],
              metadata['username'],
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

  String _uploaderLabel() {
    final profile = _paper?['uploader_profile'] as Map<String, dynamic>?;
    final username = (profile?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    final fullName = (profile?['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    return 'Unknown user';
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

  List<Map<String, dynamic>> _topLevelComments() {
    return _comments
        .where((comment) => comment['parent_comment_id'] == null)
        .toList();
  }

  List<Map<String, dynamic>> _repliesFor(String commentId) {
    return _comments
        .where((comment) => '${comment['parent_comment_id'] ?? ''}' == commentId)
        .toList();
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PaperReviewStatus.backgroundColor(status),
        border: Border.all(color: PaperReviewStatus.borderColor(status)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PaperReviewStatus.icon(status),
            size: 14,
            color: PaperReviewStatus.textColor(status),
          ),
          const SizedBox(width: 6),
          Text(
            PaperReviewStatus.label(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: PaperReviewStatus.textColor(status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBanner(String status) {
    final rejectionReason = (_paper?['rejection_reason'] as String?)?.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaperReviewStatus.backgroundColor(status),
        border: Border.all(color: PaperReviewStatus.borderColor(status)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PaperReviewStatus.icon(status),
                size: 18,
                color: PaperReviewStatus.textColor(status),
              ),
              const SizedBox(width: 8),
              Text(
                'Status: ${PaperReviewStatus.label(status)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PaperReviewStatus.textColor(status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            PaperReviewStatus.ownerDescription(status),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (status == PaperReviewStatus.rejected &&
              rejectionReason != null &&
              rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                border: Border.all(color: AppColors.errorBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin feedback',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.errorDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rejectionReason,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscussionSection(String paperStatus) {
    if (!PaperReviewStatus.isPublished(paperStatus)) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceFaint,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Discussion opens after this document is published.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
      );
    }

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
            child: Column(
              children: const [
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
                  'Start the discussion by sharing a question, insight, or review.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSubtle),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._topLevelComments().map(_buildCommentCard),
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
                  'Share a question, insight, or feedback about this document...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Be constructive and keep it relevant to the research.',
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

  Widget _buildCommentCard(Map<String, dynamic> comment, {int depth = 0}) {
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
    final commentId = '${comment['id'] ?? ''}';
    final replies = _repliesFor(commentId);
    final summary = _commentReactionSummary(comment);
    final isCommentReacting = _reactingCommentIds.contains(commentId);

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
              const SizedBox(height: 3),
              RoleBadge(role: roleFromProfile(profile)),
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

    final card = Opacity(
      opacity: isPending ? 0.7 : 1,
      child: Container(
        margin: EdgeInsets.only(
          left: depth == 0 ? 0 : 18.0,
          bottom: depth == 0 ? 10 : 8,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: depth == 0 ? Colors.white : AppColors.surfaceFaint,
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildCommentReactionChip(
                  icon: Icons.thumb_up_alt_outlined,
                  activeIcon: Icons.thumb_up_alt,
                  count: summary.likesCount,
                  isActive: summary.userReaction == 1,
                  activeColor: AppColors.success,
                  onTap: isPending || isCommentReacting
                      ? null
                      : () => _toggleCommentReaction(comment, 1),
                ),
                _buildCommentReactionChip(
                  icon: Icons.thumb_down_alt_outlined,
                  activeIcon: Icons.thumb_down_alt,
                  count: summary.dislikesCount,
                  isActive: summary.userReaction == -1,
                  activeColor: AppColors.errorDark,
                  onTap: isPending || isCommentReacting
                      ? null
                      : () => _toggleCommentReaction(comment, -1),
                ),
                TextButton.icon(
                  onPressed: isPending ? null : () => _showReplyDialog(comment),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card,
        ...replies.map(
          (reply) => _buildCommentCard(
            reply,
            depth: depth >= 2 ? 2 : depth + 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentReactionChip({
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
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.35)
                : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 15,
              color: isActive ? activeColor : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paperStatus = _paper == null
        ? PaperReviewStatus.draft
        : PaperReviewStatus.normalize(_paper!['status']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Details'),
        actions: [
          // Save to collection
          if (_paper != null && PaperReviewStatus.isPublished(_paper!['status']))
            IconButton(
              icon: const Icon(Icons.star_border, color: Colors.white),
              tooltip: 'Save to Collection',
              onPressed: () => showSaveToCollectionSheet(
                context,
                contentType: 'paper',
                contentId: widget.paperId,
                contentTitle: _paper!['title'] ?? 'Document',
              ),
            ),
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: _openHistory,
              tooltip: 'View History',
            ),
          if (_canEditPaper)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: _openEdit,
              tooltip: 'Edit Document',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
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
                    Text(
                      'Error loading paper',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.errorDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadPaperDetails,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Title
                Text(
                  _paper!['title'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_shouldShowStatusUi(paperStatus)) ...[
                  _buildReviewBanner(paperStatus),
                  const SizedBox(height: 16),
                ],

                // Metadata
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.category,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (_paper!['categories'] as Map?)?['name'] ??
                                'Uncategorized',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Uploaded by ${_uploaderLabel()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_shouldShowStatusUi(paperStatus)) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            _buildStatusChip(paperStatus),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            paperStatus == PaperReviewStatus.published
                                ? 'Published: ${_formatDate(_paper!['published_at'])}'
                                : 'Created: ${_formatDate(_paper!['created_at'])}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (_paper!['submitted_at'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Submitted: ${_formatDate(_paper!['submitted_at'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.visibility,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_paper!['views_count'] ?? 0} views',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.comment_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_paper!['comments_count'] ?? _comments.length} comments',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (PaperReviewStatus.isPublished(paperStatus)) ...[
                        const SizedBox(height: 12),
                        _buildReactionRow(),
                      ],
                      if (_paper!['pdf_file_size'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PDF Size: ${_formatFileSize(_paper!['pdf_file_size'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Authors Section
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      color: AppColors.slatePrimary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Authors',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_authors.isEmpty)
                  const Text(
                    'No author information available',
                    style: TextStyle(fontSize: 13, color: AppColors.textSubtle),
                  )
                else
                  ..._authors.map((author) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author['name'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (author['email'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              author['email'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          if (author['affiliation'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              author['affiliation'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 20),

                // Abstract Section
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      color: AppColors.slatePrimary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Abstract',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _paper!['abstract'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // View and Download Buttons
                if (_paper!['pdf_url'] != null) ...[
                  Row(
                    children: [
                      // View PDF Button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isViewing ? null : _viewPDF,
                            icon: _isViewing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.visibility),
                            label: const Text(
                              'View PDF',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.slatePrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Download PDF Button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isDownloading ? null : _downloadPDF,
                            icon: _isDownloading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.slatePrimary,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.download),
                            label: const Text(
                              'Download',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.slatePrimary,
                              side: const BorderSide(
                                color: AppColors.slatePrimary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Comments Section
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      color: AppColors.slatePrimary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Discussion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDiscussionSection(paperStatus),
              ],
            ),
    );
  }
}
