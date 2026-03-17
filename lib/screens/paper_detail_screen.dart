import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'pdf_viewer_screen.dart';

class PaperDetailScreen extends StatefulWidget {
  final String paperId;

  const PaperDetailScreen({Key? key, required this.paperId}) : super(key: key);

  @override
  State<PaperDetailScreen> createState() => _PaperDetailScreenState();
}

class _PaperDetailScreenState extends State<PaperDetailScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _paper;
  List<Map<String, dynamic>> _authors = [];
  bool _isLoading = true;
  String? _error;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadPaperDetails();
    _incrementViewCount();
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
      await supabase.rpc('increment_paper_views', params: {
        'paper_id': widget.paperId,
      });
    } catch (e) {
      // Silent fail - not critical
      print('Error incrementing views: $e');
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
            builder: (_) => PdfViewerScreen(
              pdfUrl: signedUrl,
              title: _paper!['title'],
            ),
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
            backgroundColor: const Color(0xFF991B1B),
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
                content: Text('Storage permission is required to download files'),
                backgroundColor: Color(0xFF991B1B),
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
        String filePath;

        if (Platform.isAndroid) {
          // Save to PUBLIC Downloads folder (where users expect it!)
          final directory = Directory('/storage/emulated/0/Download');
          
          // Create file in Downloads
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          filePath = file.path;
        } else {
          // iOS - use app documents directory
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          filePath = file.path;
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
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Check your Downloads folder',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
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
            backgroundColor: const Color(0xFF991B1B),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'This app needs storage permission to download PDF files. '
          'Please enable it in Settings → Permissions → Storage.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings(); // Opens app settings page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A5568),
            ),
            child: const Text('Open Settings'),
          ),
        ],
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
          if (_paper != null && _paper!['pdf_url'] != null)
            IconButton(
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              onPressed: _isDownloading ? null : _viewPDF,
              tooltip: 'View PDF',
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
                          color: Color(0xFF991B1B),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading paper',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
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
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Metadata
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.category, size: 16, color: Color(0xFF6B7280)),
                              const SizedBox(width: 6),
                              Text(
                                (_paper!['categories'] as Map?)?['name'] ?? 'Uncategorized',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF374151),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6B7280)),
                              const SizedBox(width: 6),
                              Text(
                                'Published: ${_formatDate(_paper!['published_at'])}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.visibility, size: 16, color: Color(0xFF6B7280)),
                              const SizedBox(width: 6),
                              Text(
                                '${_paper!['views_count'] ?? 0} views',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          if (_paper!['pdf_file_size'] != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.insert_drive_file, size: 16, color: Color(0xFF6B7280)),
                                const SizedBox(width: 6),
                                Text(
                                  'PDF Size: ${_formatFileSize(_paper!['pdf_file_size'])}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
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
                          color: const Color(0xFF4A5568),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Authors',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_authors.isEmpty)
                      const Text(
                        'No author information available',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      )
                    else
                      ..._authors.map((author) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFD1D5DB)),
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
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              if (author['email'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  author['email'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                              if (author['affiliation'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  author['affiliation'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    
                    const SizedBox(height: 20),

                    // Abstract Section
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 20,
                          color: const Color(0xFF4A5568),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Abstract',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _paper!['abstract'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
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
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                                  backgroundColor: const Color(0xFF4A5568),
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
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A5568)),
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
                                  foregroundColor: const Color(0xFF4A5568),
                                  side: const BorderSide(color: Color(0xFF4A5568), width: 2),
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
                          color: const Color(0xFF4A5568),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Discussion',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.comment_outlined,
                            size: 40,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Comments & Discussion',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Coming soon! You will be able to discuss this paper with other researchers.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
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