import 'package:flutter_test/flutter_test.dart';
import 'package:gurkha_guides/core/config/app_config.dart';

void main() {
  test('missing or placeholder config leaves Supabase disabled', () {
    expect(const AppConfig().isSupabaseConfigured, isFalse);
    expect(
      const AppConfig(
        supabaseUrl: 'your_supabase_project_url',
        supabasePublicKey: 'your_public_supabase_key',
      ).isSupabaseConfigured,
      isFalse,
    );
    expect(
      const AppConfig(supabaseUrl: 'https://example.supabase.co')
          .isSupabaseConfigured,
      isFalse,
    );
  });

  test('a well-formed public client config enables initialization', () {
    expect(
      const AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublicKey: 'sb_publishable_test_placeholder',
      ).isSupabaseConfigured,
      isTrue,
    );
  });

  test('server secret keys are not accepted as public client config', () {
    expect(
      const AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublicKey: 'sb_secret_test_placeholder',
      ).isSupabaseConfigured,
      isFalse,
    );
  });
}
