# Architecture overview

## Initial system

~~~mermaid
flowchart TD
    Mobile[Flutter mobile app<br/>Android and iOS] --> AppState[Riverpod state]
    AppState --> Routes[go_router navigation]
    Routes --> Client[Supabase Flutter client]
    Client --> Auth[Supabase Auth]
    Client --> Postgres[Supabase PostgreSQL<br/>Row Level Security]
    Client --> Storage[Supabase Storage]
~~~

Flutter provides one Dart application and shared feature code for Android and
iOS. Flutter can also keep its generated web target for development; web is
not the primary client.

Supabase is the initial backend. The mobile app uses only public client
configuration. PostgreSQL authorization must be enforced by reviewed Row
Level Security policies. No application tables, policies, or production
migrations are defined yet.

Riverpod owns app state and dependencies. go_router owns route declarations
and navigation. Flutter gen-l10n will load English and Nepali strings from
ARB resources. shared_preferences is intended for the selected language and
other simple local settings, not sensitive data.

## Configuration and errors

The app must start without Supabase credentials. Supabase initialization
should be conditional on valid public client configuration, with a clear
development state when configuration is absent. Backend errors should be
represented at the service boundary and surfaced through explicit loading,
empty, and error UI states when backend features are added.

Local environment files are ignored by Git. Never embed service-role keys,
database passwords, or other server secrets in Flutter assets or source.

## Future integrations

These are future directions, not dependencies for this foundation:

- Firebase Cloud Messaging for push notifications.
- OpenStreetMap with flutter_map for maps when map requirements are defined.
- A Next.js admin application after admin workflows are defined.

FastAPI is not part of the initial architecture. Add a custom server only if
future business logic requires capabilities that Supabase cannot reasonably
provide.

## Repository boundaries

- mobile/: Flutter Android/iOS client.
- supabase/migrations/: reviewed, ordered schema and policy changes.
- supabase/seed/: local-only development seed data.
- supabase/functions/: narrowly scoped Edge Functions.
- admin/: reserved for a later dashboard.
- docs/: requirements, architecture decisions, database planning, research,
  and legal materials.

