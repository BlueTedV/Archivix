import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initialProfile,
  });

  final Map<String, dynamic>? initialProfile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  Map<String, dynamic>? _profile;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile == null
        ? null
        : Map<String, dynamic>.from(widget.initialProfile!);
    _usernameController.text = (_profile?['username'] as String?) ?? '';
    _fullNameController.text = (_profile?['full_name'] as String?) ?? '';
    _bioController.text = (_profile?['bio'] as String?) ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<bool> _saveProfile({
    String? avatarPathOverride,
    bool clearAvatar = false,
    bool closeAfterSave = true,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Please sign in again to update your profile.', AppColors.errorDark);
      return false;
    }

    final username = _usernameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final bio = _bioController.text.trim();

    if (username.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(username)) {
      _showMessage(
        'Username must be 3-24 characters and use only letters, numbers, or underscores.',
        AppColors.errorDark,
      );
      return false;
    }

    if (fullName.length > 80) {
      _showMessage('Real name must be 80 characters or fewer.', AppColors.errorDark);
      return false;
    }

    if (bio.length > 240) {
      _showMessage('Bio must be 240 characters or fewer.', AppColors.errorDark);
      return false;
    }

    final nextAvatarPath = clearAvatar
        ? null
        : avatarPathOverride ?? (_profile?['avatar_path'] as String?);

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final savedProfile = await supabase
          .from('profiles')
          .upsert({
            'id': user.id,
            'username': username.isEmpty ? null : username,
            'full_name': fullName.isEmpty ? null : fullName,
            'bio': bio.isEmpty ? null : bio,
            'avatar_path': nextAvatarPath,
          })
          .select('id, username, full_name, bio, avatar_path, created_at, updated_at')
          .single();

      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'username': username,
            'full_name': fullName,
            'bio': bio,
            'avatar_path': nextAvatarPath ?? '',
          },
        ),
      );

      if (!mounted) return false;

      setState(() {
        _profile = Map<String, dynamic>.from(savedProfile);
      });

      if (closeAfterSave) {
        Navigator.of(context).pop(true);
      } else {
        _showMessage('Profile updated successfully.', AppColors.success);
      }
      return true;
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyProfileError(error);
        });
        _showMessage(_friendlyProfileError(error), AppColors.errorDark);
      }
      return false;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyProfileError(error);
        });
        _showMessage(_friendlyProfileError(error), AppColors.errorDark);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Please sign in again to update your profile photo.', AppColors.errorDark);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      if (file.path == null) {
        _showMessage('Could not access the selected image file.', AppColors.errorDark);
        return;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path!,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) {
        return;
      }

      final previousAvatarPath = (_profile?['avatar_path'] as String?)?.trim();
      final storagePath =
          '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      setState(() {
        _isUploadingAvatar = true;
        _error = null;
      });

      await supabase.storage.from('profile-avatars').upload(
        storagePath,
        File(croppedFile.path),
        fileOptions: FileOptions(
          upsert: false,
          contentType: 'image/jpeg',
        ),
      );

      final saved = await _saveProfile(
        avatarPathOverride: storagePath,
        closeAfterSave: false,
      );

      if (saved &&
          previousAvatarPath != null &&
          previousAvatarPath.isNotEmpty &&
          previousAvatarPath != storagePath) {
        try {
          await supabase.storage.from('profile-avatars').remove([
            previousAvatarPath,
          ]);
        } catch (_) {
          // Non-critical cleanup.
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyProfileError(error);
      });
      _showMessage(_friendlyProfileError(error), AppColors.errorDark);
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
      });
    }
  }

  Future<void> _removeAvatar() async {
    final currentAvatarPath = (_profile?['avatar_path'] as String?)?.trim();
    if (currentAvatarPath == null || currentAvatarPath.isEmpty) {
      return;
    }

    setState(() {
      _isUploadingAvatar = true;
      _error = null;
    });

    try {
      await supabase.storage.from('profile-avatars').remove([currentAvatarPath]);
    } catch (_) {
      // If the image is already missing, still clear the profile reference.
    }

    final saved = await _saveProfile(clearAvatar: true, closeAfterSave: false);
    if (!mounted) return;
    setState(() {
      _isUploadingAvatar = false;
    });
    if (saved) {
      _showMessage('Profile photo removed.', AppColors.success);
    }
  }

  void _showMessage(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyProfileError(Object error) {
    final message = error.toString();
    if (message.contains('duplicate key') ||
        message.contains('idx_profiles_username_unique')) {
      return 'That username is already taken. Try another one.';
    }
    if (message.contains('profile-avatars')) {
      return 'Profile photo storage is not ready yet. Run profiles_setup.sql in Supabase first.';
    }
    if (message.contains('profiles')) {
      return 'Profile customization is not ready yet. Run profiles_setup.sql in Supabase first.';
    }
    return 'Unable to update profile right now.';
  }

  String? get _avatarUrl {
    final avatarPath = (_profile?['avatar_path'] as String?)?.trim();
    if (avatarPath == null || avatarPath.isEmpty) {
      return null;
    }

    final updatedAt = (_profile?['updated_at'] as String?) ?? '';
    final publicUrl = supabase.storage.from('profile-avatars').getPublicUrl(
      avatarPath,
    );
    return '$publicUrl?v=${Uri.encodeComponent(updatedAt)}';
  }

  String _displayName() {
    final fullName = (_profile?['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final username = (_profile?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    return supabase.auth.currentUser?.email ?? 'Unknown User';
  }

  @override
  Widget build(BuildContext context) {
    final username = (_profile?['username'] as String?)?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving || _isUploadingAvatar ? null : () => _saveProfile(),
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.slatePrimary, Color(0xFF73829B)],
                      ),
                      border: Border.all(color: const Color(0xFF3F4857)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_avatarUrl != null)
                          Image.network(
                            _avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                          )
                        else
                          _buildAvatarFallback(),
                        if (_isUploadingAvatar)
                          Container(
                            color: Colors.black.withOpacity(0.28),
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _displayName(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    username != null && username.isNotEmpty
                        ? '@$username'
                        : supabase.auth.currentUser?.email ?? 'No username yet',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isUploadingAvatar ? null : _pickAvatar,
                        icon: const Icon(Icons.photo_camera_back_outlined),
                        label: Text(
                          _isUploadingAvatar ? 'Uploading...' : 'Change Photo',
                        ),
                      ),
                      if (_avatarUrl != null)
                        OutlinedButton.icon(
                          onPressed: _isUploadingAvatar ? null : _removeAvatar,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove Photo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorDark,
                            side: const BorderSide(color: AppColors.errorDark),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'your_handle',
                      prefixText: '@',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '3-24 characters. Letters, numbers, and underscores only.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Real Name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _fullNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Your actual name or research alias',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Short Bio',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _bioController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      hintText: 'Share your field, interests, or what you research.',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  border: Border.all(color: AppColors.errorBorder),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.errorDark,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final label = _displayName();
    final initials = label.isNotEmpty
        ? label.trim().substring(0, 1).toUpperCase()
        : '?';

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
