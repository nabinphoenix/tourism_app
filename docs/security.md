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

## Validation scope

Migrations include deterministic schema, grants, policies, functions, and
buckets, but this repository has no live Supabase project credentials.
Supabase CLI is not currently installed and Docker Desktop's engine was not
running at inspection. The migrations and security scenarios passed in a disposable local
PostgreSQL 18 database with mock Supabase roles/schemas. This does not prove behavior
against real Auth and Storage services. These are local simulations, never
Supabase integration tests.

On a disposable Supabase instance, apply migrations in order, then exercise
these scenarios with real anon and authenticated JWTs:

1. TOURIST cannot update role to ADMIN.
2. GUIDE cannot set verification_status to VERIFIED or approve a request.
3. An unrelated user cannot SELECT a booking.
4. A tourist cannot INSERT for another tourist or insert non-REQUESTED status.
5. A guide cannot transition someone else's booking.
6. A non-completed booking cannot receive a review; a completed one can.
7. A second review for one booking is rejected.
8. Ordinary users cannot publish destinations or experiences.
9. Anonymous users cannot download guide-verification objects.
10. Owner reads, request creation, transitions, and private document reads work.

Also inspect pg_policies and information_schema.role_table_grants after
deployment. Run tests with the actual client roles; testing only as postgres
or service_role bypasses the key RLS boundary.
