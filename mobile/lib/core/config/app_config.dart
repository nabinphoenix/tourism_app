class AppConfig {
  const AppConfig({this.supabaseUrl = '', this.supabasePublicKey = ''});

  const AppConfig.fromEnvironment()
    : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabasePublicKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  final String supabaseUrl;
  final String supabasePublicKey;

  // Client configuration is public in a compiled app. Server secrets do not
  // belong here. Missing values leave backend initialization disabled.
  bool get isSupabaseConfigured {
    final uri = Uri.tryParse(supabaseUrl);
    final key = supabasePublicKey.trim();
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        key.isNotEmpty &&
        !key.toLowerCase().startsWith('your_') &&
        !key.startsWith('sb_secret_');
  }
}
