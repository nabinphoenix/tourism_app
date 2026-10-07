import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LanguagePreferences {
  Future<String?> readLanguageCode();
  Future<void> writeLanguageCode(String code);
}

class SharedPreferencesLanguagePreferences implements LanguagePreferences {
  SharedPreferencesLanguagePreferences()
    : _preferences = SharedPreferencesAsync();

  static const _key = 'app_locale';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readLanguageCode() => _preferences.getString(_key);

  @override
  Future<void> writeLanguageCode(String code) =>
      _preferences.setString(_key, code);
}

final languagePreferencesProvider = Provider<LanguagePreferences>(
  (ref) => SharedPreferencesLanguagePreferences(),
);
