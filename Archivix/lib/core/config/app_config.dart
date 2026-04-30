class AppConfig {
  // Prefer --dart-define in production, but keep local development working
  // with the same Supabase project that the web app already uses.
  static const _fallbackSupabaseUrl =
      'https://lbgqtschsdurqwutsmyl.supabase.co';
  static const _fallbackSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxiZ3F0c2Noc2R1cnF3dXRzbXlsIiwicm9sZSI6'
      'ImFub24iLCJpYXQiOjE3NzA3MDA3MjQsImV4cCI6MjA4NjI3NjcyNH0.'
      '2RIwCPqFhiOQgBouAGgOK_TPyWmIxQQv_JpKsJYJ5MM';

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _fallbackSupabaseUrl,
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _fallbackSupabaseAnonKey,
  );

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw const FormatException(
        'Missing Supabase config. Pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.',
      );
    }
  }
}
