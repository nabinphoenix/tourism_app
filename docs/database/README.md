# Database documentation

The [V1 data model](../database.md) describes the tables, relationships,
constraints, indexes, and booking lifecycle. The [security model](../security.md)
covers grants, RLS, roles, verification, Storage, and validation scope.
Ordered executable SQL lives in supabase/migrations.

The three migrations were applied to a disposable hosted Supabase project and
validated with real Auth, Data API, RPC, and Storage requests on 2026-10-08.
Local and live procedures are documented in supabase/tests/README.md.
