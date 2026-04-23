import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/content_version_service.dart';
import '../papers/pdf_viewer_screen.dart';

class PostHistoryScreen extends StatefulWidget {
  final String postId;
  final String postTitle;

  const PostHistoryScreen({
    super.key,
    required this.postId,
    required this.postTitle,
  });

  @override
  State<PostHistoryScreen> createState() => _PostHistoryScreenState();
}

class _PostHistoryScreenState extends State<PostHistoryScreen> {
  final _versionService = ContentVersionService();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _versions = [];
  final Map<String, bool> _isDownloading = {};

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final versions = await _versionService.loadPostVersions(widget.postId);

      if (mounted) {
        setState(() {
          _versions = versions;
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';

    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _attachmentUrl(Map<String, dynamic> attachment) {
    final fileUrl = '${attachment['file_url'] ?? ''}'.trim();
    if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
      return fileUrl;
    }

    return _supabase.storage.from('post-attachments').getPublicUrl(fileUrl);
  }

  Future<void> _openArchivedAttachment(Map<String, dynamic> attachment) async {
    final publicUrl = _attachmentUrl(attachment);
    final fileType = '${attachment['file_type'] ?? 'document'}'.toLowerCase();
    final fileName = '${attachment['file_name'] ?? 'Attachment'}';
    final mimeType = '${attachment['mime_type'] ?? ''}'.toLowerCase();

    if (mimeType == 'application/pdf' || fileName.toLowerCase().endsWith('.pdf')) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(pdfUrl: publicUrl, title: fileName),
        ),
      );
      return;
    }

    if (fileType == 'image') {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            child: Image.network(
              publicUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not open archived image.'),
              ),
            ),
          ),
        ),
      );
      return;
    }

    await _downloadArchivedAttachment(attachment);
  }

  Future<void> _downloadArchivedAttachment(
    Map<String, dynamic> attachment,
  ) async {
    final attachmentId = '${attachment['id'] ?? attachment['file_name'] ?? ''}';
    final publicUrl = _attachmentUrl(attachment);

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        PermissionStatus status = await Permission.storage.status;
        if (status.isDenied) {
          status = await Permission.storage.request();
        }

        if (status.isDenied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to download files.'),
              backgroundColor: AppColors.errorDark,
            ),
          );
          return;
        }

        if (status.isPermanentlyDenied) {
          if (!mounted) return;
          _showPermissionDialog();
          return;
        }
      }
    }

    setState(() {
      _isDownloading[attachmentId] = true;
    });

    try {
      final response = await http.get(Uri.parse(publicUrl));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final fileName = '${attachment['file_name'] ?? 'attachment'}';
      final savedPath = await _saveDownloadedFile(
        fileName: fileName,
        bytes: response.bodyBytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded to $savedPath'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download archived file: $error'),
          backgroundColor: AppColors.errorDark,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading[attachmentId] = false;
        });
      }
    }
  }

  Future<String> _saveDownloadedFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  void _showPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Storage Permission Required',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'This app needs storage permission to download archived files. Please enable it in Settings.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Question History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                      style: const TextStyle(color: AppColors.errorDark),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadVersions,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadVersions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.postTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_versions.length} archived version${_versions.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_versions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 40,
                            color: AppColors.textSubtle,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No previous versions yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._versions.map((version) {
                      final attachments =
                          version['attachments_snapshot'] as List<dynamic>? ??
                          [];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.amberSurface,
                                    border: Border.all(
                                      color: AppColors.amberBorder,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Version ${version['version_number']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.amberDark,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(version['created_at']),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSubtle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              version['title'] ?? 'Untitled question',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              version['content'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((version['category_name'] as String?) !=
                                    null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.amberSurface,
                                      border: Border.all(
                                        color: AppColors.amberBorder,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      version['category_name'],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.amberDark,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  '${attachments.length} attachment${attachments.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            if (attachments.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: attachments.map((attachment) {
                                  final attachmentMap =
                                      Map<String, dynamic>.from(
                                        attachment as Map,
                                      );
                                  final fileName =
                                      attachmentMap['file_name'] ??
                                      'Attachment';
                                  final fileType =
                                      '${attachmentMap['file_type'] ?? 'document'}';
                                  final actionKey =
                                      '${attachmentMap['id'] ?? fileName}';

                                  return OutlinedButton.icon(
                                    onPressed: _isDownloading[actionKey] == true
                                        ? null
                                        : () => _openArchivedAttachment(
                                              attachmentMap,
                                            ),
                                    icon: _isDownloading[actionKey] == true
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            fileType == 'image'
                                                ? Icons.image_outlined
                                                : fileName
                                                          .toLowerCase()
                                                          .endsWith('.pdf')
                                                    ? Icons.picture_as_pdf
                                                    : Icons.attach_file,
                                            size: 16,
                                          ),
                                    label: Text(
                                      fileName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textSecondary,
                                      side: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                      backgroundColor: AppColors.surfaceLight,
                                      textStyle: const TextStyle(fontSize: 11),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
