import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:archivix/core/constants/app_colors.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import '../papers/pdf_viewer_screen.dart';

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

  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _attachments = [];
  bool _isLoading = true;
  String? _error;

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
    _incrementViewCount();
  }

  @override
  void dispose() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
            created_at,
            views_count,
            user_id,
            categories (name)
          ''')
          .eq('id', widget.postId)
          .single();

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
        final fileType = (attachment['file_type'] as String? ?? '').toLowerCase();

        try {
          final publicUrl = supabase.storage
              .from('post-attachments')
              .getPublicUrl(storagePath);

          _publicUrls[id] = publicUrl;

          if (fileType == 'video') {
            final controller =
                VideoPlayerController.networkUrl(Uri.parse(publicUrl));
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
        setState(() {
          _post = postResponse;
          _attachments = attachments;
          _isLoading = false;
        });
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
      await supabase.rpc('increment_post_views', params: {
        'post_id': widget.postId,
      });
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  // ─── Document: open PDF in viewer ───────────────────────────────────────────

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
          builder: (_) => PdfViewerScreen(
            pdfUrl: publicUrl,
            title: fileName,
          ),
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
                content: Text('Storage permission is required to download files'),
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
            backgroundColor: const AppColors.errorDark,
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
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const AppColors.slatePrimary),
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

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ─── Section header ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 3, height: 20, color: const AppColors.amberDark),
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
        border: Border.all(color: const AppColors.border),
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
                          color: const AppColors.slatePrimary,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => _attachmentPlaceholder(
                      height: 220,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image,
                              size: 40, color: AppColors.textSubtle),
                          SizedBox(height: 8),
                          Text('Could not load image',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSubtle)),
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
                          horizontal: 10, vertical: 7),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xCC000000), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.photo,
                              size: 12, color: Colors.white70),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_full,
                              size: 12, color: Colors.white70),
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
            title: Text(title,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis),
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
          color: const AppColors.textPrimary,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }

    final isPlaying = controller.value.isPlaying;
    final aspectRatio = controller.value.aspectRatio.isNaN ||
            controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: const AppColors.border),
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
                  () => isPlaying ? controller.pause() : controller.play()),
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
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 36),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(
                      () => isPlaying ? controller.pause() : controller.play()),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: const AppColors.slatePrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (_, value, __) => Text(
                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSubtle),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.videocam,
                    size: 12, color: AppColors.textSubtle),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fileSize != null)
                  Text(
                    _formatFileSize(fileSize),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSubtle),
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

    final isPdf = mimeType == 'application/pdf' ||
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
              color: const AppColors.amberSurface,
              border: Border.all(color: const AppColors.amberBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              color: const AppColors.amberDark,
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
                        fontSize: 11, color: AppColors.textSubtle),
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
                            label: const Text('View PDF',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const AppColors.slatePrimary,
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
                                        AppColors.slatePrimary),
                                  ),
                                )
                              : const Icon(Icons.download, size: 14),
                          label: Text(
                            isDownloading ? 'Saving...' : 'Download',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const AppColors.slatePrimary,
                            side: const BorderSide(color: AppColors.slatePrimary),
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
        border: Border.all(color: const AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const AppColors.surfaceLight,
              border: Border.all(color: const AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.insert_drive_file,
                color: AppColors.textMuted, size: 24),
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
                        fontSize: 11, color: AppColors.textSubtle),
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.slatePrimary),
                      ),
                    )
                  : const Icon(Icons.download, size: 14),
              label: Text(
                isDownloading ? '...' : 'Save',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const AppColors.slatePrimary,
                side: const BorderSide(color: AppColors.slatePrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared loading placeholder ───────────────────────────────────────────────
  Widget _attachmentPlaceholder(
      {required double height, required Widget child}) {
    return Container(
      height: height,
      width: double.infinity,
      color: const AppColors.surfaceLight,
      child: Center(child: child),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Detail'),
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
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.errorDark),
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
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPostDetails,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const AppColors.slatePrimary),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const AppColors.amberSurface,
                border: Border.all(color: const AppColors.amberBorder),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.question_answer,
                      size: 12, color: AppColors.amberDark),
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
            color: const AppColors.amberSurface,
            border: Border.all(color: const AppColors.amberBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.category,
                    size: 15, color: AppColors.amberDark),
                const SizedBox(width: 6),
                Text(
                  (_post!['categories'] as Map?)?['name'] ??
                      'Uncategorized',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.amberDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.access_time,
                    size: 15, color: AppColors.amberDark),
                const SizedBox(width: 6),
                Text(
                  _formatDate(_post!['created_at']),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.amberDark),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.visibility,
                    size: 15, color: AppColors.amberDark),
                const SizedBox(width: 6),
                Text(
                  '${_post!['views_count'] ?? 0} views',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.amberDark),
                ),
              ]),
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
            border: Border.all(color: const AppColors.border),
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
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const AppColors.surfaceFaint,
            border: Border.all(color: const AppColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Column(
            children: [
              Icon(Icons.comment_outlined,
                  size: 40, color: AppColors.textSubtle),
              SizedBox(height: 12),
              Text(
                'Comments & Discussion',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Coming soon! You will be able to discuss this post with other researchers.',
                style: TextStyle(fontSize: 13, color: AppColors.textSubtle),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}