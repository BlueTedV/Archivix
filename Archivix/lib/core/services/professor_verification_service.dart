import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfessorVerificationService {
  ProfessorVerificationService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const proofBucket = 'professor-verification-proofs';

  static bool isInstitutionalEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final atIndex = normalized.lastIndexOf('@');
    if (atIndex <= 0 || atIndex == normalized.length - 1) return false;

    final domain = normalized.substring(atIndex + 1);
    if (domain.endsWith('.edu') || domain.contains('.edu.')) return true;
    if (domain.endsWith('.ac.id') || domain.contains('.ac.')) return true;

    const acceptedInstitutionalSuffixes = [
      '.edu.au',
      '.edu.sg',
      '.edu.my',
      '.edu.ph',
      '.edu.cn',
      '.edu.hk',
      '.edu.br',
      '.edu.mx',
      '.edu.tr',
      '.edu.sa',
      '.edu.in',
      '.edu.pk',
      '.edu.bd',
      '.edu.eg',
      '.edu.vn',
      '.edu.pl',
      '.edu.ng',
      '.edu.gh',
      '.ac.uk',
      '.ac.jp',
      '.ac.kr',
      '.ac.nz',
      '.ac.th',
    ];

    return acceptedInstitutionalSuffixes.any(
      (suffix) => domain.endsWith(suffix),
    );
  }

  static String? contentTypeForProofExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>?> loadLatestForCurrentUser() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('professor_verification_requests')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response == null ? null : Map<String, dynamic>.from(response);
  }

  Future<String> uploadProof({
    required String userId,
    File? file,
    Uint8List? bytes,
    required String originalFileName,
  }) async {
    final extension = p.extension(originalFileName).toLowerCase();
    final contentType = contentTypeForProofExtension(extension);
    if (contentType == null) {
      throw Exception('Please upload a JPG, PNG, WEBP, or PDF proof file.');
    }

    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final storagePath = '$userId/$timestamp$extension';

    final fileOptions = FileOptions(upsert: false, contentType: contentType);

    if (bytes != null) {
      await _supabase.storage
          .from(proofBucket)
          .uploadBinary(storagePath, bytes, fileOptions: fileOptions);
    } else if (file != null) {
      await _supabase.storage
          .from(proofBucket)
          .upload(storagePath, file, fileOptions: fileOptions);
    } else {
      throw Exception('Could not read the selected proof file.');
    }

    return storagePath;
  }

  Future<Map<String, dynamic>> submitRequest({
    required String legalName,
    required String institution,
    required String institutionalEmail,
    required String academicPosition,
    required String department,
    required String proofType,
    required String proofFilePath,
    String? notes,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Please sign in again before submitting verification.');
    }

    if (!isInstitutionalEmail(institutionalEmail)) {
      throw Exception(
        'Use an institutional email such as .edu, .ac.id, .ac.uk, or another academic domain.',
      );
    }

    final response = await _supabase
        .from('professor_verification_requests')
        .insert({
          'user_id': userId,
          'legal_name': legalName,
          'institution': institution,
          'institutional_email': institutionalEmail,
          'academic_position': academicPosition,
          'department': department,
          'proof_type': proofType,
          'proof_file_path': proofFilePath,
          'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }

  Future<String> createProofSignedUrl(String proofFilePath) {
    return _supabase.storage
        .from(proofBucket)
        .createSignedUrl(proofFilePath, 60 * 10);
  }
}
