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
  Map<String, dynamic>? _paper;
  List<Map<String, dynamic>> _authors = [];
  bool _isLoading = true;
  String? _error;
  bool _isDownloading = false;
  bool _isReacting = false;
  ContentEngagementSummary _engagementSummary =
      const ContentEngagementSummary();

  @override
  void initState() {
    super.initState();
    _loadPaperDetails();
    _loadReactionSummary();
    _incrementViewCount();
  }

  Future<void> _loadReactionSummary() async {
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
            published_at,
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

        setState(() {
          _paper = paperResponse;
          _authors = List<Map<String, dynamic>>.from(authorsResponse);
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
      await supabase.rpc(
        'increment_paper_views',
        params: {'paper_id': widget.paperId},
      );
    } catch (e) {
      // Silent fail - not critical
      debugPrint('Error incrementing views: $e');
    }
  }

  Future<void> _toggleReaction(int reactionValue) async {
    setState(() {
      _isReacting = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper Details'),
        actions: [
          if (_paper != null)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _openHistory,
              tooltip: 'View History',
            ),
          if (_isOwner)
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
                            Icons.calendar_today,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Published: ${_formatDate(_paper!['published_at'])}',
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
                      const SizedBox(height: 12),
                      _buildReactionRow(),
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

                // Comments Section (Placeholder)
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

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFaint,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.comment_outlined,
                        size: 40,
                        color: AppColors.textSubtle,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Comments & Discussion',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Coming soon! You will be able to discuss this paper with other researchers.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSubtle,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
