import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class ContentVersionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _normalizeStoragePath(String rawPath, {required String bucket}) {
    final trimmed = rawPath.trim();
    final bucketPrefix = '$bucket/';
    if (trimmed.startsWith(bucketPrefix)) {
      return trimmed.substring(bucketPrefix.length);
    }

    return trimmed;
  }

  Future<String?> _freezePaperPdf({
    required Map<String, dynamic> paper,
    required String paperId,
    required int versionNumber,
  }) async {
    final rawPdfUrl = (paper['pdf_url'] as String?)?.trim();
    if (rawPdfUrl == null || rawPdfUrl.isEmpty) {
      return null;
    }

    if (rawPdfUrl.startsWith('http://') || rawPdfUrl.startsWith('https://')) {
      return rawPdfUrl;
    }

    final sourcePath = _normalizeStoragePath(rawPdfUrl, bucket: 'papers-pdf');

    final originalFileName = (paper['pdf_file_name'] as String?)?.trim();
    final ownerUserId =
        (paper['user_id'] as String?)?.trim() ??
        (_supabase.auth.currentUser?.id ?? '').trim();
    if (ownerUserId.isEmpty) {
      throw Exception('Could not determine document owner for PDF history.');
    }
    final extension = originalFileName != null && originalFileName.isNotEmpty
        ? path.extension(originalFileName)
        : path.extension(rawPdfUrl);
    final safePaperId = paperId.replaceAll('-', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final archivedPath =
        '$ownerUserId/history_${safePaperId}_v$versionNumber'
        '_$timestamp${extension.isEmpty ? '.pdf' : extension}';

    final pdfBytes = await _supabase.storage
        .from('papers-pdf')
        .download(sourcePath);
    await _supabase.storage
        .from('papers-pdf')
        .uploadBinary(
          archivedPath,
          pdfBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/pdf',
          ),
        );

    return archivedPath;
  }

  Future<int> _nextVersionNumber({
    required String table,
    required String foreignKey,
    required String contentId,
  }) async {
    final latest = await _supabase
        .from(table)
        .select('version_number')
        .eq(foreignKey, contentId)
        .order('version_number', ascending: false)
        .limit(1)
        .maybeSingle();

    if (latest == null) {
      return 1;
    }

    return (latest['version_number'] as int? ?? 0) + 1;
  }

  Future<void> archivePaperVersion({
    required Map<String, dynamic> paper,
    required List<Map<String, dynamic>> authors,
  }) async {
    final editorUserId = _supabase.auth.currentUser?.id;
    if (editorUserId == null) {
      throw Exception('Please sign in to edit this document.');
    }

    final paperId = '${paper['id']}';
    final versionNumber = await _nextVersionNumber(
      table: 'paper_versions',
      foreignKey: 'paper_id',
      contentId: paperId,
    );
    final archivedPdfUrl = await _freezePaperPdf(
      paper: paper,
      paperId: paperId,
      versionNumber: versionNumber,
    );

    await _supabase.from('paper_versions').insert({
      'paper_id': paperId,
      'version_number': versionNumber,
      'title': paper['title'],
      'abstract': paper['abstract'],
      'category_id': paper['category_id'],
      'category_name': paper['category_name'],
      'pdf_url': archivedPdfUrl,
      'pdf_file_name': paper['pdf_file_name'],
      'pdf_file_size': paper['pdf_file_size'],
      'owner_user_id': paper['user_id'],
      'editor_user_id': editorUserId,
      'authors_snapshot': authors,
    });
  }

  Future<void> archivePostVersion({
    required Map<String, dynamic> post,
    required List<Map<String, dynamic>> attachments,
  }) async {
    final editorUserId = _supabase.auth.currentUser?.id;
    if (editorUserId == null) {
      throw Exception('Please sign in to edit this question.');
    }

    final postId = '${post['id']}';
    final versionNumber = await _nextVersionNumber(
      table: 'post_versions',
      foreignKey: 'post_id',
      contentId: postId,
    );

    await _supabase.from('post_versions').insert({
      'post_id': postId,
      'version_number': versionNumber,
      'title': post['title'],
      'content': post['content'],
      'category_id': post['category_id'],
      'category_name': post['category_name'],
      'owner_user_id': post['user_id'],
      'editor_user_id': editorUserId,
      'attachments_snapshot': attachments,
    });
  }

  Future<List<Map<String, dynamic>>> loadPaperVersions(String paperId) async {
    final response = await _supabase
        .from('paper_versions')
        .select('''
          id,
          version_number,
          title,
          abstract,
          category_name,
          pdf_url,
          pdf_file_name,
          pdf_file_size,
          authors_snapshot,
          owner_user_id,
          editor_user_id,
          created_at
        ''')
        .eq('paper_id', paperId)
        .order('version_number', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> loadPostVersions(String postId) async {
    final response = await _supabase
        .from('post_versions')
        .select('''
          id,
          version_number,
          title,
          content,
          category_name,
          attachments_snapshot,
          owner_user_id,
          editor_user_id,
          created_at
        ''')
        .eq('post_id', postId)
        .order('version_number', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
