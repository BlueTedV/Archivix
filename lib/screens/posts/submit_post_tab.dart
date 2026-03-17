import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

class SubmitPostTab extends StatefulWidget {
  const SubmitPostTab({Key? key}) : super(key: key);

  @override
  State<SubmitPostTab> createState() => _SubmitPostTabState();
}

class _SubmitPostTabState extends State<SubmitPostTab> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  
  // Multiple file attachments
  List<PlatformFile> _attachments = [];
  
  bool _isLoadingCategories = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  final supabase = Supabase.instance.client;
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
        setState(() {
          _isLoadingCategories = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: ${error.toString()}'),
            backgroundColor: const AppColors.errorDark,
          ),
        );
      }
    }
  }
  
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'pdf', 'doc', 'docx'],
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result != null) {
        // Check total size (max 100MB total)
        int totalSize = 0;
        for (var file in result.files) {
          totalSize += file.size;
        }
        
        if (totalSize > 100 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Total file size too large! Maximum 100MB'),
                backgroundColor: AppColors.errorDark,
              ),
            );
          }
          return;
        }
        
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: ${e.toString()}'),
            backgroundColor: const AppColors.errorDark,
          ),
        );
      }
    }
  }
  
  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }
  
  String _getFileType(String? extension) {
    if (extension == null) return 'document';
    
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    final videoExtensions = ['mp4', 'mov', 'avi', 'mkv'];
    
    if (imageExtensions.contains(extension.toLowerCase())) {
      return 'image';
    } else if (videoExtensions.contains(extension.toLowerCase())) {
      return 'video';
    } else {
      return 'document';
    }
  }
  
  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');
      
      // 1. Create post record
      setState(() {
        _uploadProgress = 0.2;
      });
      
      final postResponse = await supabase
          .from('posts')
          .insert({
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'category_id': _selectedCategoryId,
            'user_id': userId,
          })
          .select()
          .single();
      
      setState(() {
        _uploadProgress = 0.4;
      });
      
      // 2. Upload attachments if any
      if (_attachments.isNotEmpty) {
        final postId = postResponse['id'];
        
        for (int i = 0; i < _attachments.length; i++) {
          final file = _attachments[i];
          final fileExt = path.extension(file.name);
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i$fileExt';
          final filePath = '$userId/$fileName';
          
          // Upload to storage
          if (kIsWeb) {
            await supabase.storage
                .from('post-attachments')
                .uploadBinary(filePath, file.bytes!);
          } else {
            final ioFile = File(file.path!);
            await supabase.storage
                .from('post-attachments')
                .upload(filePath, ioFile);
          }
          
          // Create attachment record
          await supabase.from('post_attachments').insert({
            'post_id': postId,
            'file_url': filePath,
            'file_name': file.name,
            'file_type': _getFileType(fileExt.replaceAll('.', '')),
            'file_size': file.size,
            'mime_type': file.extension,
          });
          
          setState(() {
            _uploadProgress = 0.4 + (0.5 * (i + 1) / _attachments.length);
          });
        }
      }
      
      setState(() {
        _uploadProgress = 1.0;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question posted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Clear form
        _titleController.clear();
        _contentController.clear();
        setState(() {
          _attachments.clear();
          _uploadProgress = 0.0;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: const AppColors.errorDark,
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
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDEEBFF),
                  border: Border.all(color: const AppColors.slatePrimary),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: AppColors.slatePrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ask research-related questions and get answers from the community. You can attach images, videos, or documents.',
                        style: TextStyle(
                          fontSize: 12,
                          color: const AppColors.slatePrimary.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Question Title
              const Text(
                'Question Title',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'e.g., How do I analyze RNA-seq data?',
                  hintStyle: const TextStyle(color: AppColors.textSubtle, fontSize: 13),
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.slatePrimary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a question title';
                  }
                  if (value.trim().length < 10) {
                    return 'Title must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Question Content/Details
              const Text(
                'Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _contentController,
                maxLines: 8,
                maxLength: 5000,
                decoration: InputDecoration(
                  hintText: 'Provide more details about your question...',
                  hintStyle: const TextStyle(color: AppColors.textSubtle, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.slatePrimary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide some details';
                  }
                  if (value.trim().length < 20) {
                    return 'Details must be at least 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Category
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategoryId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['id'],
                      child: Text(
                        category['name'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              
              // Attachments section
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    color: const AppColors.slatePrimary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Attachments (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Add images, videos, or documents to support your question',
                style: TextStyle(
                  fontSize: 12,
                  color: const AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              
              // Add attachment button
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Add Files'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const AppColors.slatePrimary,
                  side: const BorderSide(color: AppColors.slatePrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              
              // Display attachments
              if (_attachments.isNotEmpty) ...[
                ...List.generate(_attachments.length, (index) {
                  final file = _attachments[index];
                  final extension = path.extension(file.name).replaceAll('.', '');
                  final fileType = _getFileType(extension);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const AppColors.surfaceLight,
                      border: Border.all(color: const AppColors.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        // File type icon
                        Icon(
                          fileType == 'image'
                              ? Icons.image
                              : fileType == 'video'
                                  ? Icons.videocam
                                  : Icons.insert_drive_file,
                          size: 24,
                          color: const AppColors.slatePrimary,
                        ),
                        const SizedBox(width: 12),
                        // File info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB • ${extension.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Remove button
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeAttachment(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: const AppColors.errorDark,
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              
              // Progress bar
              if (_isUploading) ...[
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.slatePrimary),
                  minHeight: 8,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Uploading... ${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const AppColors.slatePrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Post Question',
                          style: TextStyle(
                            fontSize: 15,
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