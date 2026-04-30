import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/content_version_service.dart';
import '../../core/utils/paper_review_status.dart';

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
  bool _removeCurrentPdf = false;

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
          _removeCurrentPdf = false;
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

  void _clearReplacementPdf() {
    setState(() {
      _selectedFile = null;
      _selectedFileBytes = null;
      _selectedFileName = null;
      _selectedFileSize = null;
    });
  }

  String? _normalizeStoragePath(dynamic rawPath, {required String bucket}) {
    if (rawPath == null) return null;

    final trimmed = '$rawPath'.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return null;
    }

    final bucketPrefix = '$bucket/';
    if (trimmed.startsWith(bucketPrefix)) {
      return trimmed.substring(bucketPrefix.length);
    }

    return trimmed;
  }

  Future<void> _saveChanges({required String targetStatus}) async {
    final normalizedCurrentStatus = PaperReviewStatus.normalize(
      widget.paper['status'],
    );
    final isSubmittingForReview = targetStatus == PaperReviewStatus.submitted;
    final isSavingDraft = targetStatus == PaperReviewStatus.draft;
    final requiresValidation =
        isSubmittingForReview || normalizedCurrentStatus == PaperReviewStatus.published;

    if (requiresValidation && !_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final abstract = _abstractController.text.trim();
    final currentPdfPath = (widget.paper['pdf_url'] as String?)?.trim();
    final hasExistingPdf = currentPdfPath != null && currentPdfPath.isNotEmpty;
    final hasPdfReplacement =
        _selectedFile != null || _selectedFileBytes != null;
    final hasPdfRemoval = _removeCurrentPdf && hasExistingPdf;
    final hasPdfAfterSave = hasPdfReplacement || (hasExistingPdf && !hasPdfRemoval);

    if (isSavingDraft && title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a title before saving this draft.'),
          backgroundColor: AppColors.errorDark,
        ),
      );
      return;
    }

    if (isSubmittingForReview && !hasPdfAfterSave) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A PDF is required before submitting for review.'),
          backgroundColor: AppColors.errorDark,
        ),
      );
      return;
    }

    final statusChanged = normalizedCurrentStatus != targetStatus;
    final hasChanges =
        title != '${widget.paper['title'] ?? ''}' ||
        abstract != '${widget.paper['abstract'] ?? ''}' ||
        _selectedCategoryId != widget.paper['category_id'] ||
        hasPdfReplacement ||
        hasPdfRemoval ||
        statusChanged;

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

      if (normalizedCurrentStatus != PaperReviewStatus.published) {
        updatePayload['status'] = targetStatus;
        updatePayload['rejection_reason'] = null;

        if (targetStatus == PaperReviewStatus.submitted) {
          updatePayload['submitted_at'] = DateTime.now().toIso8601String();
          updatePayload['reviewed_at'] = null;
          updatePayload['reviewed_by'] = null;
        } else if (targetStatus == PaperReviewStatus.draft) {
          updatePayload['submitted_at'] = null;
          updatePayload['reviewed_at'] = null;
          updatePayload['reviewed_by'] = null;
        }
      }

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
      } else if (hasPdfRemoval) {
        updatePayload['pdf_url'] = null;
        updatePayload['pdf_file_name'] = null;
        updatePayload['pdf_file_size'] = null;
      }

      await _supabase
          .from('papers')
          .update(updatePayload)
          .eq('id', widget.paper['id']);

      if (hasPdfReplacement || hasPdfRemoval) {
        final previousStoragePath = _normalizeStoragePath(
          currentPdfPath,
          bucket: 'papers-pdf',
        );
        if (previousStoragePath != null) {
          try {
            await _supabase.storage.from('papers-pdf').remove([
              previousStoragePath,
            ]);
          } catch (error) {
            debugPrint(
              'Could not remove previous PDF "$previousStoragePath": $error',
            );
          }
        }
      }

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
    final currentPdfPath = (widget.paper['pdf_url'] as String?)?.trim();
    final hasExistingPdf = currentPdfPath != null && currentPdfPath.isNotEmpty;
    final hasReplacementSelected =
        _selectedFile != null || _selectedFileBytes != null;
    final displayedPdfName = _removeCurrentPdf
        ? 'Current PDF will be removed'
        : _selectedFileName ??
              '${widget.paper['pdf_file_name'] ?? 'No PDF attached'}';

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
                          displayedPdfName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_removeCurrentPdf) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Save changes to remove this PDF from the document.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.errorDark,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickReplacementPdf,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            hasReplacementSelected
                                ? 'Choose Different PDF'
                                : hasExistingPdf && !_removeCurrentPdf
                                ? 'Replace PDF'
                                : 'Choose PDF',
                          ),
                        ),
                        if (hasReplacementSelected) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _clearReplacementPdf,
                            icon: const Icon(Icons.close),
                            label: const Text('Clear Selected PDF'),
                          ),
                        ] else if (hasExistingPdf) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _removeCurrentPdf = !_removeCurrentPdf;
                              });
                            },
                            icon: Icon(
                              _removeCurrentPdf
                                  ? Icons.undo_outlined
                                  : Icons.delete_outline,
                            ),
                            label: Text(
                              _removeCurrentPdf
                                  ? 'Keep Current PDF'
                                  : 'Remove Current PDF',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: _removeCurrentPdf
                                  ? AppColors.slatePrimary
                                  : AppColors.errorDark,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text(
                            'This document currently has no attached PDF.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: PaperReviewStatus.backgroundColor(
                        widget.paper['status'],
                      ),
                      border: Border.all(
                        color: PaperReviewStatus.borderColor(widget.paper['status']),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          PaperReviewStatus.icon(widget.paper['status']),
                          size: 18,
                          color: PaperReviewStatus.textColor(widget.paper['status']),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current status: ${PaperReviewStatus.label(widget.paper['status'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: PaperReviewStatus.textColor(widget.paper['status']),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                PaperReviewStatus.ownerDescription(widget.paper['status']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              if ((widget.paper['rejection_reason'] as String?) !=
                                      null &&
                                  '${widget.paper['rejection_reason']}'.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Admin feedback: ${widget.paper['rejection_reason']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.errorDark,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
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
                  if (PaperReviewStatus.normalize(widget.paper['status']) ==
                      PaperReviewStatus.published)
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _saveChanges(
                                targetStatus: PaperReviewStatus.published,
                              ),
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
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => _saveChanges(
                                      targetStatus: PaperReviewStatus.draft,
                                    ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.slatePrimary,
                                side: const BorderSide(
                                  color: AppColors.slatePrimary,
                                ),
                              ),
                              child: const Text('Save Draft'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => _saveChanges(
                                      targetStatus: PaperReviewStatus.submitted,
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.slatePrimary,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      PaperReviewStatus.normalize(
                                                widget.paper['status'],
                                              ) ==
                                              PaperReviewStatus.rejected
                                          ? 'Resubmit for Review'
                                          : 'Submit for Review',
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
