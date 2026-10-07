# Database validation

These files are tests, not production migrations or seed data.

- local_bootstrap.sql supplies minimal mock auth and storage schemas/roles for
  a disposable PostgreSQL database. It is never applied to Supabase.
- schema_checks.sql asserts nine RLS-enabled tables, policy coverage, narrow
  grants, private bucket flags, and empty SECURITY DEFINER search paths.
- local_security.sql runs synthetic role scenarios in a transaction and rolls
  them back: signup metadata, profile ownership, booking access/creation,
  status transitions, reviews, publication, guide verification, favorites,
  and private Storage object visibility.

Run the mock check against a disposable PostgreSQL database, never a database
holding real users or content. Create the database using your own local
PostgreSQL setup, then from the repository root apply:

~~~text
psql -v ON_ERROR_STOP=1 -d <disposable-db> -f supabase/tests/local_bootstrap.sql
psql -v ON_ERROR_STOP=1 -d <disposable-db> -f supabase/migrations/20261007000100_core_schema.sql
psql -v ON_ERROR_STOP=1 -d <disposable-db> -f supabase/migrations/20261007000200_access_workflows.sql
psql -v ON_ERROR_STOP=1 -d <disposable-db> -f supabase/migrations/20261007000300_storage.sql
psql -v ON_ERROR_STOP=1 -d <disposable-db> -f supabase/tests/schema_checks.sql
psql -v ON_ERROR_STOP=1 -d <disposable-db> -f supabase/tests/local_security.sql
~~~

The mock cannot prove Supabase Auth registration, Data API exposure settings,
Storage HTTP downloads, signed URL behavior, or bucket ownership rules.
After provisioning a disposable Supabase project, install the official CLI
using its supported method, link the project, review its migration history,
and run supabase db push. Apply schema_checks.sql as a trusted SQL check,
then perform the JWT-based scenarios in docs/security.md against real
Auth/Storage endpoints. Keep the private schema out of exposed schemas.
Do not run db reset against a linked/shared project.

Supabase migration workflow:
https://supabase.com/docs/guides/deployment/database-migrations
