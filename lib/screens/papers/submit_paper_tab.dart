import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

class SubmitPaperTab extends StatefulWidget {
  const SubmitPaperTab({Key? key}) : super(key: key);

  @override
  State<SubmitPaperTab> createState() => _SubmitPaperTabState();
}

class _SubmitPaperTabState extends State<SubmitPaperTab> {
  final _titleController = TextEditingController();
  final _abstractController = TextEditingController();
  final _authorNameController = TextEditingController();
  final _authorEmailController = TextEditingController();
  final _authorAffiliationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  
  File? _selectedFile;
  Uint8List? _selectedFileBytes; // For web platform
  String? _fileName;
  int? _fileSize;
  
  bool _isLoadingCategories = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  final supabase = Supabase.instance.client;
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }
  
  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    
    try {
      final response = await supabase
          .from('categories')
          .select('id, name')
          .order('name');
      
      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories[0]['id'];
        }
        _isLoadingCategories = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: ${error.toString()}'),
            backgroundColor: const Color(0xFF991B1B),
          ),
        );
      }
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }
  
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb, // Load file bytes on web
      );

      if (result != null) {
        int fileSize;
        
        if (kIsWeb) {
          // Web platform: use bytes
          final bytes = result.files.single.bytes;
          if (bytes == null) {
            throw Exception('Failed to read file');
          }
          
          fileSize = bytes.length;
          
          // Check file size (max 50MB)
          if (fileSize > 50 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File too large! Maximum size is 50MB'),
                  backgroundColor: Color(0xFF991B1B),
                ),
              );
            }
            return;
          }
          
          setState(() {
            _selectedFileBytes = bytes;
            _selectedFile = null;
            _fileName = result.files.single.name;
            _fileSize = fileSize;
          });
        } else {
          // Mobile/Desktop: use file path
          File file = File(result.files.single.path!);
          fileSize = await file.length();
          
          // Check file size (max 50MB)
          if (fileSize > 50 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File too large! Maximum size is 50MB'),
                  backgroundColor: Color(0xFF991B1B),
                ),
              );
            }
            return;
          }
          
          setState(() {
            _selectedFile = file;
            _selectedFileBytes = null;
            _fileName = result.files.single.name;
            _fileSize = fileSize;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: ${e.toString()}'),
            backgroundColor: const Color(0xFF991B1B),
          ),
        );
      }
    }
  }
  
  Future<void> _submitPaper() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedFile == null && _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file'),
          backgroundColor: Color(0xFF991B1B),
        ),
      );
      return;
    }
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      
      // 1. Upload PDF to storage
      final fileExt = path.extension(_fileName ?? '.pdf');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final filePath = '$userId/$fileName';
      
      setState(() {
        _uploadProgress = 0.3;
      });
      
      // Upload file based on platform
      if (kIsWeb) {
        // Web: upload bytes
        await supabase.storage
            .from('papers-pdf')
            .uploadBinary(filePath, _selectedFileBytes!);
      } else {
        // Mobile/Desktop: upload file
        await supabase.storage
            .from('papers-pdf')
            .upload(filePath, _selectedFile!);
      }
      
      setState(() {
        _uploadProgress = 0.6;
      });
      
      // 2. Insert paper record
      final paperResponse = await supabase
          .from('papers')
          .insert({
            'title': _titleController.text.trim(),
            'abstract': _abstractController.text.trim(),
            'category_id': _selectedCategoryId,
            'user_id': userId,
            'pdf_url': filePath,
            'pdf_file_name': _fileName,
            'pdf_file_size': _fileSize,
            'status': 'published',
            'published_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      setState(() {
        _uploadProgress = 0.8;
      });
      
      // 3. Insert author info
      if (_authorNameController.text.trim().isNotEmpty) {
        await supabase.from('paper_authors').insert({
          'paper_id': paperResponse['id'],
          'name': _authorNameController.text.trim(),
          'email': _authorEmailController.text.trim().isNotEmpty 
              ? _authorEmailController.text.trim() 
              : null,
          'affiliation': _authorAffiliationController.text.trim().isNotEmpty
              ? _authorAffiliationController.text.trim()
              : null,
          'author_order': 1,
        });
      }
      
      setState(() {
        _uploadProgress = 1.0;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paper submitted successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        
        // Clear form
        _titleController.clear();
        _abstractController.clear();
        _authorNameController.clear();
        _authorEmailController.clear();
        _authorAffiliationController.clear();
        setState(() {
          _selectedFile = null;
          _selectedFileBytes = null;
          _fileName = null;
          _fileSize = null;
          _uploadProgress = 0.0;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: const Color(0xFF991B1B),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    _authorNameController.dispose();
    _authorEmailController.dispose();
    _authorAffiliationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCategories) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const Text(
                  'Paper Title',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your paper title',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFF9CA3AF)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['id'],
                          child: Text(
                            category['name'],
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategoryId = newValue;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                const Text(
                  'Abstract',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _abstractController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your paper abstract',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an abstract';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Author Info Section
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      color: const Color(0xFF4A5568),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Author Information',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'Author Name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _authorNameController,
                  decoration: const InputDecoration(
                    hintText: 'Full name',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter author name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'Email (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _authorEmailController,
                  decoration: const InputDecoration(
                    hintText: 'author@email.com',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'Affiliation (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _authorAffiliationController,
                  decoration: const InputDecoration(
                    hintText: 'University or Institution',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                ),
                const SizedBox(height: 16),
                
                // PDF Upload Section
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      color: const Color(0xFF4A5568),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Upload PDF',
                      style: TextStyle(
                        fontSize: 15,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.attach_file, size: 18, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fileName ?? 'No file selected',
                              style: TextStyle(
                                fontSize: 13,
                                color: _fileName != null 
                                    ? const Color(0xFF374151)
                                    : const Color(0xFF9CA3AF),
                                fontWeight: _fileName != null 
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_fileSize != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Size: ${(_fileSize! / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isUploading ? null : _pickFile,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF9CA3AF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            'Choose PDF File',
                            style: TextStyle(color: Color(0xFF374151)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Upload Progress
                if (_isUploading) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A5568)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Uploading... ${(_uploadProgress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Submit Button
                SizedBox(
                  height: 42,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submitPaper,
                    child: const Text(
                      'Submit Paper',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
    );
  }
}