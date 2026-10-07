// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Gurkha Guides';

  @override
  String get tagline => 'One Platform, All of Nepal.';

  @override
  String get home => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get nepali => 'Nepali';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get exploreNepal => 'Explore Nepal';

  @override
  String get explorePlaceholder =>
      'More ways to explore Nepal are coming soon.';

  @override
  String get preferencesLoadError => 'Couldn\'t load your preferences.';

  @override
  String get languageSaveError =>
      'Couldn\'t save your language. Please try again.';

  @override
  String get retry => 'Retry';
}
