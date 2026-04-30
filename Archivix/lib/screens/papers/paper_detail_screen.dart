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
import '../../core/utils/paper_review_status.dart';
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
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? _paper;
  List<Map<String, dynamic>> _authors = [];
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isLoadingComments = false;
  String? _error;
  String? _commentsError;
  bool _isDownloading = false;
  bool _isReacting = false;
  bool _isSubmittingComment = false;
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
      final response = await supabase
          .from('paper_comments')
          .select('id, paper_id, user_id, author_label, body, created_at, updated_at')
          .eq('paper_id', widget.paperId)
          .order('created_at');

      if (!mounted) return;

      setState(() {
        _comments = List<Map<String, dynamic>>.from(response);
        _isLoadingComments = false;
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
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'is_pending': true,
    };

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmittingComment = true;
      _commentsError = null;
      _comments = [..._comments, optimisticComment];
      _commentController.clear();
    });

    try {
      final inserted = await supabase
          .from('paper_comments')
          .insert({
            'paper_id': widget.paperId,
            'user_id': user.id,
            'author_label': authorLabel,
            'body': body,
          })
          .select('id, paper_id, user_id, author_label, body, created_at, updated_at')
          .single();

      if (!mounted) return;

      setState(() {
        _comments = _comments
            .map(
              (comment) => comment['id'] == tempId
                  ? Map<String, dynamic>.from(inserted)
                  : comment,
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _comments.removeWhere((comment) => comment['id'] == tempId);
        _commentsError = _friendlyCommentsError(error);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyCommentsError(error)),
          backgroundColor: AppColors.errorDark,
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSubmittingComment = false;
      });
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
      _isOwner &&
      _paper != null &&
      PaperReviewStatus.isOwnerEditable(_paper!['status']);

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
      _isDownloading = true;
    });

    try {
      // Get signed URL for viewing
      final pdfUrl = _paper!['pdf_url'] as String;
      final signedUrl = await supabase.storage
          .from('papers-pdf')
          .createSignedUrl(pdfUrl, 3600); // 1 hour expiry

      if (mounted) {
        setState(() {
          _isDownloading = false;
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
          _isDownloading = false;
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
    if (message.contains('paper_comments')) {
      return 'Comments are not ready yet. Run paper_comments_setup.sql in Supabase first.';
    }
    return 'Unable to load comments right now.';
  }

  String _currentUserLabel(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final candidate = [
      metadata['full_name'],
      metadata['name'],
      metadata['username'],
      metadata['display_name'],
    ].whereType<String>().map((value) => value.trim()).firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );

    if (candidate.isNotEmpty) {
      return candidate;
    }

    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Researcher';
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
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSubtle,
                  ),
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
              hintText: 'Share a question, insight, or feedback about this document...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Be constructive and keep it relevant to the research.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSubtle,
                  ),
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
              children: [
                Expanded(
                  child: Text(
                    comment['author_label'] ?? 'Researcher',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
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
            const SizedBox(height: 6),
            Text(
              isPending ? 'Sending...' : _formatDateTime(comment['created_at']),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSubtle,
              ),
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

  @override
  Widget build(BuildContext context) {
    final paperStatus = _paper == null
        ? PaperReviewStatus.draft
        : PaperReviewStatus.normalize(_paper!['status']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Details'),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _openHistory,
              tooltip: 'View History',
            ),
          if (_canEditPaper)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
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
                _buildReviewBanner(paperStatus),
                const SizedBox(height: 16),

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
                            Icons.flag_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          _buildStatusChip(paperStatus),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                            onPressed: _isDownloading ? null : _viewPDF,
                            icon: _isDownloading
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
