# Gurkha Guides mobile

One Platform, All of Nepal.

A Flutter foundation for Android and iOS, with an optional web development
target. Home and Settings demonstrate localization, navigation, Riverpod, and
a language preference that survives app restarts. Explore Nepal currently
shows a localized placeholder message.

## Verified environment

- Flutter 3.47.6 stable / Dart 3.13.5.
- Windows development with Flutter available on PATH.
- Android build-tools 36.0.0 available.
- Android 17 / API 37 emulator, device ID emulator-5554.
- Android licenses accepted; Flutter doctor reports no issues.
- Android builds use Android Studio's bundled JDK.
- Android application ID and iOS bundle identifier: com.gurkhaguides.app.

iOS source is generated, but compiling or releasing iOS requires macOS/Xcode.
Windows desktop is not a target. The template icons and release signing must
be revisited before any store release.

## Run

From this directory:

~~~powershell
flutter pub get
flutter devices
flutter run -d emulator-5554
~~~

Start an emulator through Android Studio Device Manager, or select a connected
device from flutter devices. The device ID above is specific to this machine.
Optional web development uses flutter run -d chrome.

## Packages

| Package | Version | Choice |
| --- | --- | --- |
| flutter_riverpod | 3.4.3 | Async locale state and testable dependencies |
| go_router | 18.0.2 | Declarative route definitions |
| supabase_flutter | 2.18.0 | Prepared backend client |
| shared_preferences | 2.5.6 | Simple settings via SharedPreferencesAsync |
| intl | 0.20.3 | Flutter-generated localization |
| flutter_localizations | SDK | Material/framework localization |
| flutter_test | SDK | Widget/unit tests |
| flutter_lints | 6.0.0 | Static analysis rules |

The Dart solver selected stable compatible releases for this SDK. Commit
pubspec.lock to preserve application dependency resolution. A notice about
newer constrained transitive packages is not a build failure; avoid
dependency overrides merely to remove that notice.

## Structure and routing

~~~text
lib/
  main.dart                 Binding, optional Supabase init, ProviderScope
  app/
    app.dart                MaterialApp.router, locale/loading/error state
    router/app_router.dart  / redirects to /home; /settings
    theme/app_theme.dart    Basic Material 3 theme
  core/
    config/app_config.dart  Public compile-time configuration
    localization/           Riverpod locale controller
    services/               SharedPreferencesAsync language adapter
  features/
    home/                   Foundation home screen
    settings/               Language selector
  shared/widgets/           Reusable retry view
  l10n/                     ARB input and generated Dart translations
test/                       Widget and config tests
~~~

ProviderScope is at the app root. The locale AsyncNotifier reads/writes the
language preference through a small service boundary. Providers make this
state testable without global mutable settings. GoRouter is disposed with
its provider and remains stable when the language changes. There are no
authentication guards or product routes.

## Localization

Edit lib/l10n/app_en.arb and lib/l10n/app_ne.arb, then run:

~~~powershell
flutter gen-l10n
~~~

l10n.yaml writes translations to lib/l10n/generated. Generated Dart files are
committed; edit the ARBs rather than generated code. User-visible strings come
from AppLocalizations.

The saved language is loaded before showing Home. Settings offers English
and Nepali; saves use the current SharedPreferencesAsync API. Preferences are
for simple settings, not sensitive or critical records.

## Environment and Supabase

No configuration is needed to run the foundation. Missing configuration
disables backend initialization.

From the repository root, copy .env.example to .env and fill in
SUPABASE_URL and SUPABASE_ANON_KEY with the project URL and a public
anon/publishable key. Then, from mobile:

~~~powershell
flutter run -d emulator-5554 --dart-define-from-file=../.env
~~~

Flutter passes these values to String.fromEnvironment at compile time.
The .env file is ignored by Git and is not a bundled asset. The values
themselves are public in a compiled client. Never use Supabase service-role
or secret keys. Restart/rebuild when changing configuration; hot reload does
not change compile-time values.

Supabase 2.18.0 uses the publishableKey initialization argument; the configured
public key is passed there. The repository now has versioned schema, RLS,
and Storage migrations, but no live deployment or authentication flow.
The mobile screens do not access backend tables yet. If initialization
fails, the foundation UI still starts; these screens make no backend calls.

## Checks and Android build

~~~powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
~~~

Expected APK: build/app/outputs/flutter-apk/app-debug.apk.

Widget tests cover the home route, English copy, navigation to Settings,
Nepali switching, restoration from persisted storage in a fresh app scope,
loading before preferences arrive, retry after a read error, and retention
of the current language on a failed save. Config tests check missing,
placeholder, and public client configuration.
