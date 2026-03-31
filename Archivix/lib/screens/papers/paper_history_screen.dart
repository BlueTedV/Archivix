import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/content_version_service.dart';
import 'pdf_viewer_screen.dart';

class PaperHistoryScreen extends StatefulWidget {
  final String paperId;
  final String paperTitle;

  const PaperHistoryScreen({
    super.key,
    required this.paperId,
    required this.paperTitle,
  });

  @override
  State<PaperHistoryScreen> createState() => _PaperHistoryScreenState();
}

class _PaperHistoryScreenState extends State<PaperHistoryScreen> {
  final _versionService = ContentVersionService();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _versions = [];

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
      final versions = await _versionService.loadPaperVersions(widget.paperId);

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

  Future<void> _openArchivedPdf(Map<String, dynamic> version) async {
    final pdfUrl = version['pdf_url'] as String?;
    if (pdfUrl == null || pdfUrl.isEmpty) return;

    try {
      final trimmedPdfUrl = pdfUrl.trim();
      final viewerUrl =
          trimmedPdfUrl.startsWith('http://') ||
              trimmedPdfUrl.startsWith('https://')
          ? trimmedPdfUrl
          : await _supabase.storage
                .from('papers-pdf')
                .createSignedUrl(
                  trimmedPdfUrl.startsWith('papers-pdf/')
                      ? trimmedPdfUrl.substring('papers-pdf/'.length)
                      : trimmedPdfUrl,
                  3600,
                );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            pdfUrl: viewerUrl,
            title:
                version['pdf_file_name'] ?? version['title'] ?? 'Archived PDF',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open archived PDF: $error'),
          backgroundColor: AppColors.errorDark,
        ),
      );
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

  String _authorSummary(List<dynamic>? authors) {
    if (authors == null || authors.isEmpty) return 'No saved author snapshot';

    final names = authors
        .map((author) => author['name'] as String? ?? 'Unknown Author')
        .toList();

    if (names.length == 1) return names[0];
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names[0]} et al.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document History')),
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
                    widget.paperTitle,
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
                      final authors =
                          version['authors_snapshot'] as List<dynamic>?;
                      final abstract = '${version['abstract'] ?? ''}';

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
                                    color: AppColors.surfaceLight,
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Version ${version['version_number']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slatePrimary,
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
                              version['title'] ?? 'Untitled document',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _authorSummary(authors),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              abstract.isEmpty
                                  ? 'No abstract saved in this version.'
                                  : abstract,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if ((version['category_name'] as String?) !=
                                    null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      version['category_name'],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.slatePrimary,
                                      ),
                                    ),
                                  ),
                                if ((version['pdf_file_name'] as String?) !=
                                        null &&
                                    (version['pdf_file_name'] as String)
                                        .isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      version['pdf_file_name'],
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                if ((version['pdf_url'] as String?) != null &&
                                    (version['pdf_url'] as String).isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () => _openArchivedPdf(version),
                                    icon: const Icon(
                                      Icons.picture_as_pdf,
                                      size: 16,
                                    ),
                                    label: const Text('Open PDF'),
                                  ),
                              ],
                            ),
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
