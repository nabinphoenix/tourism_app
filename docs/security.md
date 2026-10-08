# V1 database security

## Trust boundary

The Flutter client uses a Supabase URL and public anon/publishable key.
Neither is an authorization secret. PostgreSQL grants, RLS, constrained
writes, and checked functions enforce access. Never place a service-role
key, database password, or verification document in Flutter or Git.

The private schema contains SECURITY DEFINER helpers with an empty
search_path and schema-qualified references. Keep private out of the
Supabase exposed-schemas setting. Only narrow public SECURITY INVOKER
entry points are callable by the mobile client.

## Table access

| Table | Anonymous | Authenticated owner/participant | ADMIN |
| --- | --- | --- | --- |
| profiles | Verified guide display profiles | Own profile; verified guide profiles | Read all |
| guide_profiles | VERIFIED guide-facing rows | Own row; editable columns only | Read and moderate |
| destinations | Published | Published | CRUD/publish |
| experiences | Published under published destination | Same | CRUD/publish |
| guide_service_areas | Published areas of verified guides | Same plus own areas; guide manages own links | Read/manage |
| bookings | None | Tourist or assigned guide read; tourist creates request; transitions via RPC | Read and override via RPC |
| favorites | None | Owner SELECT/INSERT/DELETE | No client moderation needed |
| reviews | Visible reviews of completed bookings | Same; completed-booking tourist may insert once | Hide/read |
| guide_verification_requests | None | Guide sees/submits own request, without update rights | Read/review |

RLS is enabled on every application table. Grants are explicitly revoked
before narrow grants are applied; RLS policies are a second check. Profile
role and identity columns cannot be updated by clients. Guide verification
status has a database guard against non-admin changes. Booking status has no
direct client UPDATE grant or UPDATE policy. User-controlled metadata never
grants ADMIN or VERIFIED.

## Profile creation and first ADMIN

An auth.users AFTER INSERT trigger creates one profile. It accepts only the
literal GUIDE signup request; missing/unknown/ADMIN values become TOURIST.
GUIDE signup also creates a guide_profiles row with PENDING verification.
A failed trigger transaction prevents a half-created account; monitor signup
errors after migrations are deployed.

Promote the first ADMIN only through a trusted database-admin SQL session
after verifying the intended auth user out of band. Example, with a
placeholder that must be replaced by the operator:

~~~sql
begin;
update public.profiles
set role = 'ADMIN'
where id = '<verified-auth-user-uuid>'::uuid;
commit;
~~~

The dashboard/SQL session must have trusted database privileges. Do not
expose a role-promotion RPC and do not store a real ID in migrations.

## Booking and review checks

The booking RPC accepts a booking ID and target status, never an actor ID.
The private implementation obtains auth.uid(), locks the booking, evaluates
the trusted role, and changes only allowed states. COMPLETED requires the
assigned guide and a reached trip date, or an ADMIN override. Direct table
UPDATE remains denied to the client. Reviews have one-booking uniqueness
and a database-derived guide_id, so a client cannot assert another owner or
guide.

## Storage

| Bucket | Visibility | Write | Read |
| --- | --- | --- | --- |
| avatars | Public; images only, 5 MiB | Authenticated owner under own UUID folder | Public URL |
| destination-media | Private; images only, 10 MiB | ADMIN under destination UUID folder | Published destination folder; ADMIN |
| guide-verification | Private; image/PDF, 10 MiB | GUIDE under own UUID folder, INSERT only | Owning GUIDE and ADMIN |

Storage object policies enforce bucket and path ownership. Bucket management
is not granted to clients. A private verification object must be downloaded
with a valid user JWT or a deliberately short-lived signed URL; never store
or publish a permanent public URL. A guide cannot overwrite or delete a
submitted file; ADMIN can remove it for retention/moderation. Storage
metadata is not the same as the underlying file bytes; use Storage APIs for
deletion, not direct SQL deletion from storage.objects.

Destination media lives in a private bucket so unpublished content is not
served by a public URL. RLS allows reads only when the destination folder
matches a published destination. Admin may upload drafts. The app will need
an authenticated or anon-key Storage download request when that UI is built.

## Live disposable-project validation

On 2026-10-08 the three ordered migrations applied successfully to an empty,
user-confirmed disposable hosted Supabase project. Migration history showed
all three versions. `supabase/tests/schema_checks.sql` passed against the
hosted PostgreSQL 17 database: nine application tables with RLS, narrow
grants, private `destination-media` and `guide-verification` buckets, and safe
`SECURITY DEFINER` search paths. The live project had 35 application RLS
policies, 11 Gurkha Guides Storage object policies, one Auth profile trigger,
and three buckets after deployment. Earlier PostgreSQL 18 mock tests remain **local
simulations**, separate from these live checks.

The reproducible harness in `supabase/tests/live_integration.mjs` used actual
Auth signup and signed-in user JWTs against the Data API, booking RPC, and
Storage API. A real anonymous request checked published content and private
file access. The authenticated actors were a TOURIST, a GUIDE, and a second
test user whose database role was temporarily promoted to ADMIN by trusted
SQL. No service-role or secret API key was used in the HTTP RLS checks.
Trusted CLI SQL handled disposable role setup, verification assertions, and
cleanup; it was never counted as proof of RLS behavior.

The final run passed **18/18 scenarios**, with **0 failed** and **0 untested**:

| # | Live assertion | Result |
| --- | --- | --- |
| 1 | Client cannot self-promote to ADMIN | Pass |
| 2 | ADMIN signup metadata defaults to TOURIST | Pass |
| 3 | GUIDE cannot self-verify | Pass |
| 4 | Unrelated tourist cannot read a booking | Pass |
| 5 | Tourist cannot book for another tourist | Pass |
| 6 | Unrelated guide cannot transition a booking | Pass |
| 7 | Direct client booking status update is blocked | Pass |
| 8 | REQUESTED → ACCEPTED → CONFIRMED → COMPLETED succeeds through RPC | Pass |
| 9 | Invalid booking transition fails | Pass |
| 10 | Review before completion fails | Pass |
| 11 | Completed-booking tourist review succeeds | Pass |
| 12 | Duplicate booking review fails | Pass |
| 13 | Ordinary user cannot publish a destination | Pass |
| 14 | Trusted ADMIN can publish a destination | Pass |
| 15 | Verification object has no public read URL | Pass |
| 16 | Anonymous/unrelated download and unrelated signed-URL creation fail | Pass |
| 17 | Owning GUIDE and ADMIN read evidence; owner signed URL downloads | Pass |
| 18 | Own profile/guide edits, favorite insert/delete, avatar and destination-media operations work as allowed | Pass |

The harness additionally observed Auth-trigger profile creation, GUIDE
`PENDING` initialization, private verification submission, denied guide
self-approval, ADMIN approval, and synchronized `VERIFIED` status. Its final
cleanup reported no warnings; read-only counts afterward showed zero test
Auth users, destinations, experiences, bookings, reviews, verification
requests, and Storage objects. The JSON test report is local and Git-ignored.

The first live attempt was blocked before user creation by hosted Auth's email
quota. Temporarily disabling **Confirm email** on the disposable project
enabled fake-user signup without sending confirmation email. A later attempt
reached signed-URL validation but used an incorrect URL prefix in the test
harness; the harness was corrected and all 18 scenarios passed. Neither issue
required a migration change. Restore **Confirm email** after testing and
verify `mailer_autoconfirm=false` before using the project for other work.

The 18 scenarios do not exhaust every policy branch. In particular, this run
did not exercise rejection/cancellation booking paths, unpublished destination
media, all negative favorite cases, or every Storage mutation. These remain
future regression cases. No production project was tested or deployed.

### Reproduce on a disposable project

Use the pinned Supabase CLI after `npm ci` and `npx supabase login`. Verify the
project identity and empty/new state first, then link and review a dry run:

~~~powershell
npx supabase link --project-ref <disposable-project-ref>
npx supabase migration list --linked
npx supabase db push --linked --dry-run --skip-vault
~~~

Only after explicit approval, deploy with
`npx supabase db push --linked --skip-vault`. Run
`npx supabase db query --linked --file supabase/tests/schema_checks.sql` and
the live harness as documented in `supabase/tests/README.md`. The harness
requires a temporary no-confirmation setting on a disposable project and a
logged-in CLI; it never commits public or privileged keys. Restore the original
Auth setting afterward. Never use the SQL-only mock as a substitute for user
JWT and Storage API tests.
