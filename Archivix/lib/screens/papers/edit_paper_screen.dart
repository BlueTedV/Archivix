import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/content_version_service.dart';

class EditPaperScreen extends StatefulWidget {
  final Map<String, dynamic> paper;
  final List<Map<String, dynamic>> authors;

  const EditPaperScreen({
    super.key,
    required this.paper,
    required this.authors,
  });

  @override
  State<EditPaperScreen> createState() => _EditPaperScreenState();
}

class _EditPaperScreenState extends State<EditPaperScreen> {
  final _supabase = Supabase.instance.client;
  final _versionService = ContentVersionService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _abstractController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  bool _isLoadingCategories = true;
  bool _isSaving = false;

  File? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  int? _selectedFileSize;

  @override
  void initState() {
    super.initState();
    _titleController.text = '${widget.paper['title'] ?? ''}';
    _abstractController.text = '${widget.paper['abstract'] ?? ''}';
    _selectedCategoryId = widget.paper['category_id'] as String?;
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final response = await _supabase
          .from('categories')
          .select('id, name')
          .order('name');

      final categories = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _categories = categories;
          _selectedCategoryId ??= categories.isNotEmpty
              ? categories.first['id'] as String
              : null;
          _isLoadingCategories = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load categories: $error'),
            backgroundColor: AppColors.errorDark,
          ),
        );
      }
    }
  }

  Future<void> _pickReplacementPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb,
      );

      if (result == null) return;

      final picked = result.files.single;
      final fileSize = picked.size;
      if (fileSize > 50 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File too large. Maximum size is 50MB.'),
            backgroundColor: AppColors.errorDark,
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _selectedFileName = picked.name;
          _selectedFileSize = fileSize;
          if (kIsWeb) {
            _selectedFileBytes = picked.bytes;
            _selectedFile = null;
          } else {
            _selectedFile = File(picked.path!);
            _selectedFileBytes = null;
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick PDF: $error'),
          backgroundColor: AppColors.errorDark,
        ),
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final abstract = _abstractController.text.trim();
    final hasPdfReplacement =
        _selectedFile != null || _selectedFileBytes != null;
    final hasChanges =
        title != '${widget.paper['title'] ?? ''}' ||
        abstract != '${widget.paper['abstract'] ?? ''}' ||
        _selectedCategoryId != widget.paper['category_id'] ||
        hasPdfReplacement;

    if (!hasChanges) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again.'),
          backgroundColor: AppColors.errorDark,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _versionService.archivePaperVersion(
        paper: widget.paper,
        authors: widget.authors,
      );

      final updatePayload = <String, dynamic>{
        'title': title,
        'abstract': abstract,
        'category_id': _selectedCategoryId,
      };

      if (hasPdfReplacement) {
        final extension = path.extension(_selectedFileName ?? '.pdf');
        final storageFileName =
            '${DateTime.now().millisecondsSinceEpoch}_edit$extension';
        final storagePath = '$userId/$storageFileName';

        if (kIsWeb) {
          await _supabase.storage
              .from('papers-pdf')
              .uploadBinary(storagePath, _selectedFileBytes!);
        } else {
          await _supabase.storage
              .from('papers-pdf')
              .upload(storagePath, _selectedFile!);
        }

        updatePayload['pdf_url'] = storagePath;
        updatePayload['pdf_file_name'] = _selectedFileName;
        updatePayload['pdf_file_size'] = _selectedFileSize;
      }

      await _supabase
          .from('papers')
          .update(updatePayload)
          .eq('id', widget.paper['id']);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save changes: $error'),
          backgroundColor: AppColors.errorDark,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Document')),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category['id'] as String,
                            child: Text(category['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _abstractController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Abstract',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an abstract';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PDF File',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFileName ??
                              '${widget.paper['pdf_file_name'] ?? 'Current PDF'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickReplacementPdf,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _selectedFileName == null
                                ? 'Replace PDF'
                                : 'Choose Different PDF',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Authors are kept from the current document version for now. Every save archives the previous title, abstract, category, PDF, and author snapshot.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.slatePrimary,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
