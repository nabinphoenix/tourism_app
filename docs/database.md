# V1 database model

Status: designed for the first Supabase migration milestone. These files define
the database foundation; the Flutter screens still do not query it.

## Entity relationships

~~~mermaid
erDiagram
    AUTH_USERS ||--|| PROFILES : owns
    PROFILES ||--o| GUIDE_PROFILES : guide
    GUIDE_PROFILES ||--o{ GUIDE_SERVICE_AREAS : serves
    DESTINATIONS ||--o{ GUIDE_SERVICE_AREAS : area
    DESTINATIONS ||--o{ EXPERIENCES : contains
    PROFILES ||--o{ BOOKINGS : tourist
    GUIDE_PROFILES ||--o{ BOOKINGS : assigned_guide
    DESTINATIONS ||--o{ BOOKINGS : destination
    EXPERIENCES o|--o{ BOOKINGS : optional_experience
    PROFILES ||--o{ FAVORITES : saves
    DESTINATIONS o|--o{ FAVORITES : saved_destination
    EXPERIENCES o|--o{ FAVORITES : saved_experience
    BOOKINGS ||--o| REVIEWS : completed_review
    GUIDE_PROFILES ||--o{ GUIDE_VERIFICATION_REQUESTS : submits
~~~

## Tables and ownership

| Table | Key and relationships | Purpose |
| --- | --- | --- |
| profiles | id references auth.users | Public display name and avatar path, language, trusted role. No phone or private identity material. |
| guide_profiles | user_id references profiles | Guide biography, languages, experience, availability, and trusted verification status. |
| destinations | UUID id, unique slug | Bilingual destination content and publication flag. |
| experiences | UUID id, destination_id references destinations | Bilingual experience content; visible only with a published parent destination. |
| guide_service_areas | (guide_id, destination_id) primary key | Normalized guide-to-destination coverage. |
| bookings | UUID id; tourist, guide, destination, optional experience references | One durable request-to-completion record. |
| favorites | UUID id; owner and exactly one destination or experience | Personal saved content. |
| reviews | UUID id, unique booking_id, guide_id derived from booking | One rating for one completed booking. |
| guide_verification_requests | UUID id, guide_id, reviewer | Private application and decision metadata. Documents live in private Storage. |

Foreign keys to destinations, experiences, guides, and bookings use RESTRICT
for history-bearing data. User-owned favorites and service-area rows can be
removed with their parent. Auth user deletion cascades to the profile only when retained booking and
verification references permit it. Production account deletion must first
address retention, Storage cleanup, and booking-history obligations.

Coordinates are decimal degrees with range checks. Text and rating/party
size have bounds. Experience bookings use a composite foreign key so an
experience cannot be paired with a different destination. Favorites have an
exclusive-or target check and separate unique indexes. Only one pending
verification request per guide is allowed.

## Roles and statuses

- app_role: TOURIST, GUIDE, ADMIN. Signup metadata may request GUIDE;
  every other value, including ADMIN, becomes TOURIST. Only trusted SQL can
  elevate an existing profile to ADMIN.
- guide_verification_status: PENDING, VERIFIED, REJECTED, SUSPENDED.
  A GUIDE account is not automatically verified.
- booking_status: REQUESTED, ACCEPTED, CONFIRMED, COMPLETED, CANCELLED,
  REJECTED.
- A verification request uses PENDING, VERIFIED, or REJECTED. SUSPENDED is a
  guide-profile moderation state, not a request outcome.

Guide languages remain a bounded text array because V1 does not require
language-specific joins. Service areas are normalized because destinations
are real entities and need FK validation and filtering.

## Booking lifecycle

| From | To | Actor |
| --- | --- | --- |
| REQUESTED | ACCEPTED or REJECTED | Assigned guide |
| ACCEPTED | CONFIRMED | Booking tourist |
| REQUESTED, ACCEPTED, CONFIRMED | CANCELLED | Booking tourist |
| CONFIRMED | COMPLETED | Assigned verified guide, on or after the requested date in Nepal |
| Any | supported target status | ADMIN support override |

A tourist inserts only request fields; status defaults to REQUESTED.
Authenticated clients have no direct UPDATE or DELETE privilege on bookings.
The public SECURITY INVOKER RPC delegates to a private SECURITY DEFINER
function, which locks the row, checks the JWT user and trusted profile role,
validates the transition, and sets the corresponding lifecycle timestamp.
The private schema must never be exposed in Supabase Data API settings.
Admin overrides use the same checked function.

## Review and verification lifecycle

A review INSERT accepts booking_id, rating, and comment only. The database
checks that the caller is the tourist on a COMPLETED booking and fills guide_id
from that booking. The booking_id unique constraint prevents a second review.
Only visible reviews of still-completed bookings are public. Admin can hide a
review; tourist edit/delete is deferred.

A GUIDE profile starts PENDING. A guide may submit a private PENDING
verification request while their profile is PENDING or REJECTED. Only ADMIN can change its decision; a trigger records
the reviewer and time and synchronizes the guide profile to VERIFIED or
REJECTED. ADMIN may separately set SUSPENDED on the guide profile.
Verification documents never enter guide_profiles or public buckets.

## Indexes

Unique slug, guide-service-area key, one review per booking, one pending
verification request per guide, and per-owner favorite uniqueness are backed
by indexes. Additional indexes support published destination/experience
lists, guide verification filtering, participant/date booking lists, guide
service-area lookups, public reviews by guide, and verification queues.

## Migration and seed boundaries

Apply the ordered SQL in supabase/migrations to a fresh Supabase project using
the Supabase CLI or reviewed SQL migration tooling. Do not paste isolated
fragments or apply later files first. Local seed content, if added later, must
stay in supabase/seed and never invent auth users or a real admin.
See docs/security.md for grants, RLS, Storage, and validation.
