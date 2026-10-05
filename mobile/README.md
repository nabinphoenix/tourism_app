# Mobile application

The target is one Flutter application for Android and iOS, with web available
for development if useful. This directory is not yet a generated Flutter
project because Flutter and Dart are missing from the current machine.

After installing Flutter stable and configuring Android Studio/Android SDK,
generate the platform project here:

~~~powershell
cd mobile
flutter create --project-name gurkha_guides --org com.gurkhaguides --platforms=android,ios,web .
~~~

Use com.gurkhaguides.app as the Android application ID and iOS bundle
identifier. Flutter derives native identifiers from the organization and
Dart project name, so update the generated Android applicationId and iOS
PRODUCT_BUNDLE_IDENTIFIER before the first build. Changing identifiers after
a public release can affect store identity, signing, deep links, and
integrations. Add the version-compatible foundation dependencies only after
checking pub.dev constraints against the installed Flutter/Dart version:

- supabase_flutter: Supabase client.
- flutter_riverpod: application state and dependency injection.
- go_router: declarative routes.
- shared_preferences: persisted language preference.
- flutter_localizations and intl: Flutter localization support.
- flutter_dotenv: local development configuration for the public Supabase URL
  and client key, if the final setup uses dotenv assets.

No Supabase credentials are configured. Keep local .env files out of source
control. Never put a service_role key in this client.

English and Nepali ARB resources are in lib/l10n. The app should remain usable
without configured Supabase credentials and report a clear development
configuration state when backend-dependent behavior is eventually introduced.

## Intended source layout

~~~text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router/
│   └── theme/
├── core/
│   ├── config/
│   ├── constants/
│   ├── errors/
│   ├── localization/
│   └── services/
├── shared/
│   ├── models/
│   └── widgets/
└── features/
    ├── auth/
    ├── onboarding/
    ├── profile/
    ├── destinations/
    ├── experiences/
    ├── guides/
    ├── bookings/
    ├── offline/
    ├── safety/
    ├── reviews/
    └── favorites/
~~~

Create feature folders when a feature is implemented; avoid empty boilerplate.

