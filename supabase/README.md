# Supabase workspace

The database foundation is versioned here; it has not been deployed to a live
Supabase project. Apply migrations in filename order to a fresh/disposable
Supabase project before production deployment.

- migrations/20261007000100_core_schema.sql: nine tables, constraints,
  indexes, safe RLS defaults, Auth profile trigger.
- migrations/20261007000200_access_workflows.sql: grants, RLS policies,
  trusted helpers, guide verification and booking/review workflows.
- migrations/20261007000300_storage.sql: three buckets and object policies.
- tests/: local mock/bootstrap and security assertions. These are not a
  substitute for real Supabase Auth and Storage integration tests.
- seed/: local data only. No destination fixture or fake auth account is seeded.
- functions/: reserved for later approved server-side needs.

Keep the private schema out of Supabase Data API exposed schemas. Never put
service-role credentials or verification documents in the Flutter client.
Read docs/database.md and docs/security.md before changing policies.
