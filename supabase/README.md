# Supabase workspace

This directory is reserved for Supabase project configuration and future
database work. No production schema has been invented in this foundation
milestone.

- migrations/: ordered SQL schema and policy migrations, reviewed before
  application.
- seed/: local development seed data only; never place production secrets
  here.
- functions/: Supabase Edge Functions added for specific server-side needs.

Write schema and Row Level Security policies together. Do not disable database
security to make the client work. Keep service-role credentials outside the
mobile app and out of source control.

