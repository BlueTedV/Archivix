import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/content_version_service.dart';

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final List<Map<String, dynamic>> attachments;

  const EditPostScreen({
    super.key,
    required this.post,
    required this.attachments,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _supabase = Supabase.instance.client;
  final _versionService = ContentVersionService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _existingAttachments = [];
  final List<Map<String, dynamic>> _removedAttachments = [];
  final List<PlatformFile> _newAttachments = [];
  String? _selectedCategoryId;
  bool _isLoadingCategories = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = '${widget.post['title'] ?? ''}';
    _contentController.text = '${widget.post['content'] ?? ''}';
    _existingAttachments = widget.attachments
        .map((attachment) => Map<String, dynamic>.from(attachment))
        .toList();
    _selectedCategoryId = widget.post['category_id'] as String?;
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

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'mp4',
          'mov',
          'pdf',
          'doc',
          'docx',
        ],
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result == null) return;

      final existingPendingSize = _newAttachments.fold<int>(
        0,
        (sum, file) => sum + file.size,
      );
      final totalSize =
          existingPendingSize +
          result.files.fold<int>(0, (sum, file) => sum + file.size);

      if (totalSize > 100 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Total file size too large. Maximum 100MB.'),
            backgroundColor: AppColors.errorDark,
          ),
        );
        return;
      }

      setState(() {
        _newAttachments.addAll(result.files);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick files: $error'),
          backgroundColor: AppColors.errorDark,
        ),
      );
    }
  }

  String _attachmentKey(Map<String, dynamic> attachment) {
    final id = attachment['id'];
    if (id != null) return '$id';

    final fileUrl = attachment['file_url'];
    if (fileUrl != null && '$fileUrl'.trim().isNotEmpty) {
      return '$fileUrl';
    }

    return '${attachment['file_name'] ?? 'attachment'}';
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

  void _removeExistingAttachment(Map<String, dynamic> attachment) {
    final attachmentKey = _attachmentKey(attachment);

    setState(() {
      _existingAttachments.removeWhere(
        (item) => _attachmentKey(item) == attachmentKey,
      );
      if (_removedAttachments.every(
        (item) => _attachmentKey(item) != attachmentKey,
      )) {
        _removedAttachments.add(Map<String, dynamic>.from(attachment));
      }
    });
  }

  void _removeNewAttachment(int index) {
    setState(() {
      _newAttachments.removeAt(index);
    });
  }

  Future<Map<String, dynamic>?> _findPersistedAttachment(
    Map<String, dynamic> attachment,
  ) async {
    final postId = widget.post['id'];
    final attachmentId = attachment['id'];
    final fileUrl = '${attachment['file_url'] ?? ''}'.trim();

    if (attachmentId != null) {
      final response = await _supabase
          .from('post_attachments')
          .select('id, file_url, file_name')
          .eq('post_id', postId)
          .eq('id', attachmentId)
          .maybeSingle();

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
    }

    if (fileUrl.isNotEmpty) {
      final response = await _supabase
          .from('post_attachments')
          .select('id, file_url, file_name')
          .eq('post_id', postId)
          .eq('file_url', fileUrl)
          .maybeSingle();

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
    }

    return null;
  }

  Future<void> _deleteRemovedAttachments() async {
    for (final attachment in _removedAttachments) {
      final persistedAttachment = await _findPersistedAttachment(attachment);
      final attachmentName =
          '${attachment['file_name'] ?? persistedAttachment?['file_name'] ?? 'attachment'}';

      if (persistedAttachment == null) {
        throw Exception(
          'Could not find "$attachmentName" in the database to delete it.',
        );
      }

      final deletedRows = List<Map<String, dynamic>>.from(
        await _supabase
            .from('post_attachments')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('id', persistedAttachment['id'])
            .select('id, file_url'),
      );

      if (deletedRows.isEmpty) {
        throw Exception(
          'Could not delete "$attachmentName". This is usually caused by a row not matching anymore or a missing delete policy on post_attachments.',
        );
      }

      final storagePath = _normalizeStoragePath(
        deletedRows.first['file_url'] ?? persistedAttachment['file_url'],
        bucket: 'post-attachments',
      );
      if (storagePath != null) {
        try {
          await _supabase.storage.from('post-attachments').remove([
            storagePath,
          ]);
        } catch (error) {
          debugPrint(
            'Could not remove attachment file "$storagePath": $error',
          );
        }
      }
    }
  }

  String _getFileType(String? extension) {
    if (extension == null) return 'document';

    final normalized = extension.toLowerCase();
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    const videoExtensions = ['mp4', 'mov', 'avi', 'mkv'];

    if (imageExtensions.contains(normalized)) return 'image';
    if (videoExtensions.contains(normalized)) return 'video';
    return 'document';
  }

  IconData _attachmentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      default:
        return Icons.attach_file_outlined;
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final hasAttachmentChanges =
        _newAttachments.isNotEmpty || _removedAttachments.isNotEmpty;
    final hasChanges =
        title != '${widget.post['title'] ?? ''}' ||
        content != '${widget.post['content'] ?? ''}' ||
        _selectedCategoryId != widget.post['category_id'] ||
        hasAttachmentChanges;

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

    setState(() {
      _isSaving = true;
    });

    try {
      await _versionService.archivePostVersion(
        post: widget.post,
        attachments: widget.attachments,
      );

      await _supabase
          .from('posts')
          .update({
            'title': title,
            'content': content,
            'category_id': _selectedCategoryId,
          })
          .eq('id', widget.post['id']);

      if (_removedAttachments.isNotEmpty) {
        await _deleteRemovedAttachments();
      }

      if (_newAttachments.isNotEmpty) {
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('Please sign in again.');
        }

        for (int i = 0; i < _newAttachments.length; i++) {
          final file = _newAttachments[i];
          final fileExt = path.extension(file.name);
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_edit_$i$fileExt';
          final filePath = '$userId/$fileName';

          if (kIsWeb) {
            if (file.bytes == null) {
              throw Exception('Selected web attachment is missing file bytes.');
            }
            await _supabase.storage
                .from('post-attachments')
                .uploadBinary(filePath, file.bytes!);
          } else {
            if (file.path == null) {
              throw Exception('Selected attachment is missing a local path.');
            }
            await _supabase.storage
                .from('post-attachments')
                .upload(filePath, File(file.path!));
          }

          await _supabase.from('post_attachments').insert({
            'post_id': widget.post['id'],
            'file_url': filePath,
            'file_name': file.name,
            'file_type': _getFileType(file.extension),
            'file_size': file.size,
            'mime_type': file.extension,
          });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Question')),
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
                    controller: _contentController,
                    minLines: 6,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Question Details',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter some details';
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
                          'Attachments',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_existingAttachments.isEmpty &&
                            _newAttachments.isEmpty)
                          const Text(
                            'No files attached to this question yet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        if (_existingAttachments.isNotEmpty) ...[
                          const Text(
                            'Current Files',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._existingAttachments.map((attachment) {
                            final type =
                                (attachment['file_type'] as String?) ??
                                _getFileType(
                                  path.extension(
                                    '${attachment['file_name'] ?? ''}',
                                  ).replaceAll('.', ''),
                                );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _attachmentIcon(type),
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${attachment['file_name'] ?? 'Unnamed file'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            type.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _removeExistingAttachment(attachment),
                                      icon: const Icon(
                                        Icons.close,
                                        color: AppColors.errorDark,
                                      ),
                                      tooltip: 'Remove file',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                        if (_newAttachments.isNotEmpty) ...[
                          const Text(
                            'New Files To Add',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_newAttachments.length, (index) {
                            final file = _newAttachments[index];
                            final type = _getFileType(file.extension);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _attachmentIcon(type),
                                      color: AppColors.slatePrimary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${type.toUpperCase()} · ${(file.size / 1024).toStringAsFixed(1)} KB',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _removeNewAttachment(index),
                                      icon: const Icon(
                                        Icons.close,
                                        color: AppColors.errorDark,
                                      ),
                                      tooltip: 'Remove pending file',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Add Files'),
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
                      'Saving now archives the previous title, content, category, and attachment snapshot before the live files are changed.',
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
