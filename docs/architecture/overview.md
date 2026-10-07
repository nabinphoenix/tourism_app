# Architecture overview

## Client foundation

~~~mermaid
flowchart TD
    App[Flutter Android and iOS client] --> Router[go_router: Home and Settings]
    App --> State[Riverpod locale state]
    State --> Preferences[SharedPreferencesAsync]
    App -. optional public configuration .-> Supabase[Supabase client]
    Supabase -. future features .-> Auth[Auth]
    Supabase -. future features .-> Database[PostgreSQL with RLS]
    Supabase -. future features .-> Storage[Storage]
~~~

Flutter provides one Dart codebase and generated Android/iOS projects.
The web target is available for development. Native identifiers are
com.gurkhaguides.app. iOS builds require macOS/Xcode.

The runnable client currently has Home and Settings. The root route redirects
to Home. Riverpod manages locale loading and persistence; go_router manages
navigation. Flutter gen-l10n supplies English and Nepali strings from ARBs.
SharedPreferencesAsync stores only the selected language.

## Source boundaries

- app/: composition, router, and Material 3 theme.
- core/config/: public compile-time environment values.
- core/localization/: locale state.
- core/services/: preferences persistence adapter.
- features/: Home and Settings presentation.
- shared/widgets/: reusable error/retry presentation.
- l10n/: ARB resources and generated translations.

Create new feature folders when implementing approved features. Keep shared
abstractions small and driven by actual reuse.

## Configuration and failure handling

Flutter's built-in dart-define-from-file loads an ignored local .env file;
String.fromEnvironment reads the values in Dart. Only a Supabase public
anon/publishable key and URL belong in the client. The app starts without them,
and no environment asset or dotenv package is required.

Supabase initialization is conditional. The UI also remains available if
initialization throws. Backend-dependent state and errors will be designed
with the features that use them.

Startup waits for the persisted locale. Preference read failures offer Retry;
write failures leave the current locale intact and show a localized message.
Tests replace the preferences adapter with memory storage, while Android launch
verification exercises the native plugin.

## Backend and future integrations

Supabase is the initial backend for Auth, PostgreSQL, and Storage. No production
tables, authentication flows, storage buckets, or policies are defined here.
Design and review RLS with the schema before exposing application data.

Future integrations are Firebase Cloud Messaging, OpenStreetMap/flutter_map,
and a Next.js admin dashboard. FastAPI is not part of the initial architecture;
consider a custom service only for demonstrated server-side requirements.

## Repository boundaries

- mobile/: Flutter client.
- supabase/migrations/: future ordered schema and policy changes.
- supabase/seed/: future local development data.
- supabase/functions/: future narrowly scoped Edge Functions.
- admin/: reserved dashboard.
- docs/: requirements, architecture, database planning, research, and legal.
