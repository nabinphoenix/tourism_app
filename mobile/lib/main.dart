import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig.fromEnvironment();
  if (config.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabasePublicKey,
      );
    } catch (_) {
      // Do not print configuration values or exception payloads.
      debugPrint(
        'Supabase initialization failed; the foundation UI remains available.',
      );
    }
  }

  runApp(const ProviderScope(child: GurkhaGuidesApp()));
}
