# ADR 0007: Flutter compile-time client configuration

- Status: Accepted
- Decision: Use String.fromEnvironment and Flutter's
  --dart-define-from-file support for an ignored local .env file.
- Reason: The installed Flutter SDK supports dotenv input directly. This keeps
  setup simple and avoids another package or a mandatory configuration asset.
- Consequence: Configuration changes require a restart/rebuild. Only public
  client values belong here; compiled app configuration is extractable.
  Missing/placeholder values disable optional Supabase initialization.
- Interface: SUPABASE_URL and SUPABASE_ANON_KEY. The latter accepts a public
  anon/publishable client key and is passed to the SDK's publishableKey argument.
