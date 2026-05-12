import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/services/professor_verification_service.dart';

class ProfessorVerificationScreen extends StatefulWidget {
  const ProfessorVerificationScreen({super.key});

  @override
  State<ProfessorVerificationScreen> createState() =>
      _ProfessorVerificationScreenState();
}

class _ProfessorVerificationScreenState
    extends State<ProfessorVerificationScreen> {
  final _service = ProfessorVerificationService();
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _institutionalEmailController = TextEditingController();
  final _positionController = TextEditingController();
  final _departmentController = TextEditingController();
  final _notesController = TextEditingController();

  PlatformFile? _proofFile;
  String _proofType = 'Faculty ID card';
  bool _isSubmitting = false;

  static const _proofTypes = [
    'Faculty ID card',
    'Employment letter',
    'University profile screenshot',
    'Staff directory screenshot',
    'Research portal screenshot',
    'Other affiliation proof',
  ];

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _institutionalEmailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _institutionController.dispose();
    _institutionalEmailController.dispose();
    _positionController.dispose();
    _departmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    setState(() => _proofFile = result.files.single);
  }

  Future<void> _submit() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showMessage(
        'Please sign in again before submitting verification.',
        AppColors.errorDark,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final proofFile = _proofFile;
    if (proofFile == null ||
        (proofFile.path == null && proofFile.bytes == null)) {
      _showMessage('Upload a proof of affiliation first.', AppColors.errorDark);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final proofPath = await _service.uploadProof(
        userId: user.id,
        file: proofFile.path == null ? null : File(proofFile.path!),
        bytes: proofFile.bytes,
        originalFileName: proofFile.name,
      );

      await _service.submitRequest(
        legalName: _legalNameController.text.trim(),
        institution: _institutionController.text.trim(),
        institutionalEmail: _institutionalEmailController.text.trim(),
        academicPosition: _positionController.text.trim(),
        department: _departmentController.text.trim(),
        proofType: _proofType,
        proofFilePath: proofPath,
        notes: _notesController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error), AppColors.errorDark);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validateInstitutionalEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Required';
    if (!ProfessorVerificationService.isInstitutionalEmail(email)) {
      return 'Use an academic email domain such as .edu, .ac.id, or .ac.uk';
    }
    return null;
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('professor_verification_requests') ||
        message.contains('professor-verification-proofs') ||
        message.contains('schema cache')) {
      return 'Professor verification is not ready yet. Run professor_verification_setup.sql in Supabase first.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  void _showMessage(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Professor Verification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceFaint,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Apply to be recognized as a verified professor. Admins review each request manually, so use your legal academic details and a clear affiliation proof.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Full Legal Name'),
                TextFormField(
                  controller: _legalNameController,
                  textInputAction: TextInputAction.next,
                  validator: _requiredText,
                ),
                const SizedBox(height: 14),
                _fieldLabel('Academic Institution'),
                TextFormField(
                  controller: _institutionController,
                  textInputAction: TextInputAction.next,
                  validator: _requiredText,
                ),
                const SizedBox(height: 14),
                _fieldLabel('Institutional Email'),
                TextFormField(
                  controller: _institutionalEmailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateInstitutionalEmail,
                ),
                const SizedBox(height: 14),
                _fieldLabel('Academic Position'),
                TextFormField(
                  controller: _positionController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Professor, lecturer, researcher, etc.',
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 14),
                _fieldLabel('Department or Faculty'),
                TextFormField(
                  controller: _departmentController,
                  textInputAction: TextInputAction.next,
                  validator: _requiredText,
                ),
                const SizedBox(height: 14),
                _fieldLabel('Proof Type'),
                DropdownButtonFormField<String>(
                  value: _proofType,
                  items: _proofTypes
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _proofType = value!),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Proof of Affiliation'),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickProof,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_proofFile == null ? 'Choose file' : 'Change file'),
                ),
                if (_proofFile != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _proofFile!.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                const Text(
                  'Accepted: JPG, PNG, WEBP, or PDF. Use a faculty ID, employment letter, profile screenshot, staff directory, research portal, or similar proof.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Notes for Admin (Optional)'),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 600,
                  decoration: const InputDecoration(
                    hintText:
                        'Add a directory link, research profile URL, or context that helps confirm your affiliation.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
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
                        : const Icon(Icons.verified_outlined),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit for Review',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
