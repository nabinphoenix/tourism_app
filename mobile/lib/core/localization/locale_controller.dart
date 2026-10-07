import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gurkha_guides/core/services/language_preferences.dart';

final localeProvider = AsyncNotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends AsyncNotifier<Locale> {
  @override
  Future<Locale> build() async {
    final preferences = ref.watch(languagePreferencesProvider);
    final code = await preferences.readLanguageCode();
    return code == 'ne' ? const Locale('ne') : const Locale('en');
  }

  Future<bool> setLocale(Locale locale) async {
    final code = locale.languageCode;
    if (code != 'en' && code != 'ne') return false;

    try {
      await ref.read(languagePreferencesProvider).writeLanguageCode(code);
      if (!ref.mounted) return false;
      state = AsyncData(Locale(code));
      return true;
    } catch (_) {
      // Retain the current locale when persistence fails.
      return false;
    }
  }
}
