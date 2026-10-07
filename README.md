# Gurkha Guides

One Platform, All of Nepal.

Gurkha Guides is a tourism mobile application for Nepal, built from one Flutter
codebase for Android and iOS. The runnable client has Home, Settings,
English/Nepali localization, persisted language selection, routing, and
optional Supabase initialization.

V1 schema, access-control, and Storage migrations are versioned under
supabase/migrations, but have not been applied to a live Supabase project.
Product UI features and the admin dashboard have not been initialized.

## Environment and stack

Verified on Windows on 2026-10-06 with Flutter **3.47.6 stable** and Dart
**3.13.5**. Flutter doctor reported no issues. Android build-tools 36.0.0
and an Android 17/API 37 emulator were verified.
Flutter uses Android Studio's bundled JDK for Android builds.

| Dependency | Resolved version | Purpose |
| --- | --- | --- |
| flutter_riverpod | 3.4.3 | Locale state and dependency injection |
| go_router | 18.0.2 | Home and Settings navigation |
| supabase_flutter | 2.18.0 | Optional public client initialization |
| shared_preferences | 2.5.6 | Language persistence using SharedPreferencesAsync |
| intl | 0.20.3 | Generated localization support |
| flutter_localizations | Flutter SDK | Material and framework localization |
| flutter_lints | 6.0.0 | Development analysis rules |

The application lockfile is committed. Flutter's built-in compile-time
configuration avoids an additional environment package.

## Repository structure

~~~text
mobile/                   Flutter Android/iOS client; web target for development
  android/                Android native project
  ios/                    iOS native project
  web/                    Optional development target
  lib/
    app/                  App composition, router, Material 3 theme
    core/                 Configuration, locale state, preferences service
    features/home/        Foundation home screen
    features/settings/    Language selector
    shared/widgets/       Loading/error support
    l10n/                 English/Nepali ARB and generated localization code
  test/                   Widget and configuration tests
admin/                    Later dashboard
supabase/
  migrations/             V1 schema, RLS, workflow, and Storage migrations
  seed/                   Future local seed data
  functions/              Future Edge Functions
docs/
  requirements/
  architecture/decisions/
  database/
  research/
  legal/
.github/
~~~

## Prerequisites

Install Flutter stable and add its bin directory to your user PATH. The
Flutter SDK bin directory must be on PATH. A Flutter IDE plugin alone does
not install the SDK.

Android development requires Android Studio, the Android SDK/platform tools,
accepted SDK licenses, and a physical device or emulator for launch testing.
Run flutter doctor -v to identify missing components. Android license review
uses flutter doctor --android-licenses.

Official setup guides:
[Flutter](https://docs.flutter.dev/install/manual),
[Android](https://docs.flutter.dev/platform-integration/android/setup).

The Android application ID and iOS bundle identifier are both
**com.gurkhaguides.app**. Confirm ownership before store distribution; changing
them after release affects app identity and integrations.

The iOS project files are generated and committed. **iOS production builds
cannot be produced on Windows; macOS and Xcode are required.** Windows desktop
is not a client target. Web remains available for development.

## Run

From the repository root:

~~~powershell
cd mobile
flutter pub get
flutter run -d emulator-5554
~~~

Use flutter devices to find the correct ID if your emulator/device differs.
Create and start an emulator through Android Studio's Device Manager if needed.
For optional browser development, use flutter run -d chrome.

## Supabase configuration

The app runs without backend configuration. V1 schema, policies, and bucket
definitions are versioned but not deployed to a live project. There are no
real credentials or authentication screens.

When a Supabase project is available, copy .env.example to .env in the
repository root and supply SUPABASE_URL and SUPABASE_ANON_KEY. Use only a
public anon/publishable client key. From mobile, run:

~~~powershell
flutter run -d emulator-5554 --dart-define-from-file=../.env
~~~

The same flag can be passed to flutter build. Flutter reads the ignored local
file at build time; it is not a required app asset. The public configuration is
extractable from the compiled app. Never supply service-role keys, secret
keys, private credentials, or database passwords.

Missing or placeholder configuration skips Supabase initialization. The SDK
initialization uses its current publishableKey parameter while retaining the
requested SUPABASE_ANON_KEY configuration name for public anon/publishable keys.

## Database and security foundation

Ordered SQL under supabase/migrations defines nine application tables,
role and verification enums, profile creation from Auth, RLS and grants,
a checked booking-transition RPC, review ownership checks, and three Storage
buckets. No production data or first-admin identity is seeded.

See [data model](docs/database.md), [security model](docs/security.md),
and [Supabase workspace](supabase/README.md). The SQL was executed and
security-simulated against a disposable local PostgreSQL mock; real Supabase
Auth/Storage integration remains to be run after a project is provisioned.

## Localization

English and Nepali copy is stored in mobile/lib/l10n/app_en.arb and app_ne.arb.
Flutter gen-l10n produces lib/l10n/generated. Regenerate after editing ARBs:

~~~powershell
cd mobile
flutter gen-l10n
~~~

Settings changes the language through Riverpod and persists it using
SharedPreferencesAsync. Startup waits for the saved language. A preference
read error offers Retry; a failed write preserves the current language.

## Verification

From mobile:

~~~powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
~~~

The debug APK is written to mobile/build/app/outputs/flutter-apk/app-debug.apk.
Tests cover startup, English copy, Home/Settings navigation, Nepali selection
and restoration, preference errors, and optional backend configuration.

See [mobile/README.md](mobile/README.md) for details and
[the architecture overview](docs/architecture/overview.md) for boundaries.

## Security and release notes

Local environment files, SDK paths, build output, IDE files, signing keys,
and private credentials are ignored. Public client keys do not replace
server authorization. The versioned RLS policies and grants must be applied
and integration-tested on a disposable Supabase project before product use.

Launcher icons and release signing remain Flutter template defaults.
This milestone produces a debug build, not a store release. The LICENSE
notice remains provisional pending the owner's license decision.

## Next milestones

Deploy the V1 migrations to a disposable Supabase project and test with real
Auth and Storage roles before adding product UI. Implement product features in
separately approved milestones. Firebase Cloud Messaging,
OpenStreetMap/flutter_map,
and a Next.js admin are future integrations. FastAPI is not part of the
initial system and will only be considered for demonstrated server-side needs.
