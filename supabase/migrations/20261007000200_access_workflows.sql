-- Gurkha Guides V1: trusted helpers, RLS, narrow grants, and state transitions.
begin;

grant usage on schema private to anon, authenticated;
grant usage on type public.app_role, public.guide_verification_status,
  public.booking_status to anon, authenticated;

-- These helpers run as the migration owner to avoid recursive RLS checks.
-- The private schema must not be exposed through the Supabase Data API.
create function private.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'ADMIN'
  );
$$;

create function private.is_guide()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'GUIDE'
  );
$$;

create function private.is_verified_guide(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.guide_profiles g
    join public.profiles p on p.id = g.user_id
    where g.user_id = p_user_id
      and p.role = 'GUIDE'
      and g.verification_status = 'VERIFIED'
  );
$$;

create function private.is_published_destination(p_destination_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.destinations d
    where d.id = p_destination_id and d.is_published
  );
$$;

create function private.is_published_experience(p_experience_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.experiences e
    join public.destinations d on d.id = e.destination_id
    where e.id = p_experience_id and e.is_published and d.is_published
  );
$$;

create function private.can_request_booking(
  p_tourist_id uuid, p_guide_id uuid, p_destination_id uuid,
  p_experience_id uuid, p_requested_date date
)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) = p_tourist_id
    and p_tourist_id <> p_guide_id
    and exists (
      select 1 from public.profiles p
      where p.id = p_tourist_id and p.role = 'TOURIST'
    )
    and private.is_verified_guide(p_guide_id)
    and private.is_published_destination(p_destination_id)
    and exists (
      select 1 from public.guide_service_areas a
      where a.guide_id = p_guide_id
        and a.destination_id = p_destination_id
    )
    and (p_experience_id is null or
      exists (
        select 1 from public.experiences e
        where e.id = p_experience_id
          and e.destination_id = p_destination_id
          and e.is_published
      ))
    and p_requested_date >= (now() at time zone 'Asia/Kathmandu')::date;
$$;

create function private.can_review_booking(p_booking_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.bookings b
    where b.id = p_booking_id
      and b.tourist_id = (select auth.uid())
      and b.status = 'COMPLETED'
  );
$$;

create function private.review_booking_completed(p_booking_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.bookings b
    where b.id = p_booking_id and b.status = 'COMPLETED'
  );
$$;

revoke all on function private.is_admin() from public, anon, authenticated;
revoke all on function private.is_guide() from public, anon, authenticated;
revoke all on function private.is_verified_guide(uuid) from public, anon, authenticated;
revoke all on function private.is_published_destination(uuid) from public, anon, authenticated;
revoke all on function private.is_published_experience(uuid) from public, anon, authenticated;
revoke all on function private.can_request_booking(uuid, uuid, uuid, uuid, date)
  from public, anon, authenticated;
revoke all on function private.can_review_booking(uuid) from public, anon, authenticated;
revoke all on function private.review_booking_completed(uuid)
  from public, anon, authenticated;

grant execute on function private.is_admin() to anon, authenticated;
grant execute on function private.is_guide() to authenticated;
grant execute on function private.is_verified_guide(uuid) to anon, authenticated;
grant execute on function private.is_published_destination(uuid) to anon, authenticated;
grant execute on function private.is_published_experience(uuid) to authenticated;
grant execute on function private.can_request_booking(uuid, uuid, uuid, uuid, date)
  to authenticated;
grant execute on function private.can_review_booking(uuid) to authenticated;
grant execute on function private.review_booking_completed(uuid) to anon, authenticated;

-- A normal GUIDE may edit presentation fields, never verification_status.
create function private.guard_guide_verification_status()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.verification_status is distinct from old.verification_status
     and current_user = 'authenticated'
     and not private.is_admin() then
    raise exception 'Only an admin can change guide verification status'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger guard_guide_verification_status
  before update on public.guide_profiles
  for each row execute function private.guard_guide_verification_status();
revoke all on function private.guard_guide_verification_status()
  from public, anon, authenticated;

-- A review's guide ID is taken from the completed booking, not client input.
create function private.fill_review_guide()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select b.guide_id into new.guide_id
  from public.bookings b
  where b.id = new.booking_id
    and b.tourist_id = (select auth.uid())
    and b.status = 'COMPLETED';

  if not found then
    raise exception 'Only the tourist may review a completed booking'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger fill_review_guide before insert on public.reviews
  for each row execute function private.fill_review_guide();
revoke all on function private.fill_review_guide() from public, anon, authenticated;

-- Admin decisions synchronize the public guide verification status.
create function private.apply_verification_decision()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  if old.status <> 'PENDING'
     or new.status not in ('VERIFIED', 'REJECTED') then
    raise exception 'Invalid verification decision transition'
      using errcode = '23514';
  end if;
  if current_setting('role', true) = 'authenticated'
     and not private.is_admin() then
    raise exception 'Only an admin can review guide verification'
      using errcode = '42501';
  end if;

  new.reviewed_at := now();
  new.reviewed_by := (select auth.uid());
  update public.guide_profiles
    set verification_status = new.status
    where user_id = new.guide_id;
  return new;
end;
$$;

create trigger apply_verification_decision
  before update on public.guide_verification_requests
  for each row execute function private.apply_verification_decision();
revoke all on function private.apply_verification_decision()
  from public, anon, authenticated;

-- All booking state writes pass through this checked, row-locked function.
create function private.transition_booking_impl(
  p_booking_id uuid, p_target public.booking_status
)
returns public.bookings
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := (select auth.uid());
  booking public.bookings%rowtype;
  actor_is_admin boolean;
  allowed boolean := false;
begin
  if actor_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into booking from public.bookings
    where id = p_booking_id for update;
  if not found then
    raise exception 'Booking unavailable or transition not permitted'
      using errcode = '42501';
  end if;
  if booking.tourist_id <> actor_id
     and booking.guide_id <> actor_id
     and not private.is_admin() then
    raise exception 'Booking unavailable or transition not permitted'
      using errcode = '42501';
  end if;
  if booking.status = p_target then
    raise exception 'Booking is already in that state' using errcode = '23514';
  end if;

  actor_is_admin := private.is_admin();
  if actor_is_admin then
    allowed := true;
  elsif booking.guide_id = actor_id
       and private.is_verified_guide(actor_id) then
    allowed :=
      (booking.status = 'REQUESTED' and p_target in ('ACCEPTED', 'REJECTED'))
      or (booking.status = 'CONFIRMED' and p_target = 'COMPLETED'
          and booking.requested_date <=
            (now() at time zone 'Asia/Kathmandu')::date);
  elsif booking.tourist_id = actor_id then
    allowed :=
      (booking.status = 'ACCEPTED' and p_target = 'CONFIRMED')
      or (booking.status in ('REQUESTED', 'ACCEPTED', 'CONFIRMED')
          and p_target = 'CANCELLED');
  end if;
  if not allowed then
    raise exception 'Booking transition is not allowed'
      using errcode = '42501';
  end if;

  update public.bookings
  set status = p_target,
      accepted_at = case when p_target = 'ACCEPTED' then now()
                         else accepted_at end,
      confirmed_at = case when p_target = 'CONFIRMED' then now()
                          else confirmed_at end,
      completed_at = case when p_target = 'COMPLETED' then now()
                          else completed_at end,
      cancelled_at = case when p_target = 'CANCELLED' then now()
                          else cancelled_at end,
      cancelled_by = case when p_target = 'CANCELLED' then actor_id
                          else cancelled_by end,
      rejected_at = case when p_target = 'REJECTED' then now()
                         else rejected_at end
  where id = p_booking_id
  returning * into booking;
  return booking;
end;
$$;

revoke all on function private.transition_booking_impl(uuid, public.booking_status)
  from public, anon, authenticated;
grant execute on function private.transition_booking_impl(uuid, public.booking_status)
  to authenticated;

create function public.transition_booking(
  p_booking_id uuid, p_target public.booking_status
)
returns public.bookings
language sql security invoker set search_path = '' as $$
  select private.transition_booking_impl(p_booking_id, p_target);
$$;

revoke all on function public.transition_booking(uuid, public.booking_status)
  from public, anon, authenticated;
grant execute on function public.transition_booking(uuid, public.booking_status)
  to authenticated;

-- Narrow table grants work together with the RLS policies below.
grant select on public.profiles, public.guide_profiles,
  public.destinations, public.experiences, public.guide_service_areas,
  public.reviews to anon, authenticated;
grant select on public.bookings, public.favorites,
  public.guide_verification_requests to authenticated;

grant update (display_name, avatar_path, preferred_language)
  on public.profiles to authenticated;
grant update (bio, languages, years_experience, is_available,
  verification_status) on public.guide_profiles to authenticated;
grant insert (guide_id, destination_id), delete
  on public.guide_service_areas to authenticated;
grant insert (tourist_id, guide_id, destination_id, experience_id,
  requested_date, party_size, message) on public.bookings to authenticated;
grant insert (user_id, destination_id, experience_id), delete
  on public.favorites to authenticated;
grant insert (booking_id, rating, comment), update (is_visible)
  on public.reviews to authenticated;
grant insert (guide_id), update (status)
  on public.guide_verification_requests to authenticated;
grant insert, update, delete on public.destinations, public.experiences
  to authenticated;

create policy profiles_public_guides on public.profiles
  for select to anon, authenticated
  using (private.is_verified_guide(id));
create policy profiles_own_or_admin on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or private.is_admin());
create policy profiles_safe_update on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy guides_public_verified on public.guide_profiles
  for select to anon, authenticated
  using (private.is_verified_guide(user_id));
create policy guides_own_or_admin on public.guide_profiles
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_admin());
create policy guides_own_update on public.guide_profiles
  for update to authenticated
  using (user_id = (select auth.uid()) and private.is_guide())
  with check (user_id = (select auth.uid()) and private.is_guide());
create policy guides_admin_update on public.guide_profiles
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

create policy destinations_public_published on public.destinations
  for select to anon, authenticated using (is_published);
create policy destinations_admin_select on public.destinations
  for select to authenticated using (private.is_admin());
create policy destinations_admin_insert on public.destinations
  for insert to authenticated with check (private.is_admin());
create policy destinations_admin_update on public.destinations
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy destinations_admin_delete on public.destinations
  for delete to authenticated using (private.is_admin());

create policy experiences_public_published on public.experiences
  for select to anon, authenticated
  using (is_published and private.is_published_destination(destination_id));
create policy experiences_admin_select on public.experiences
  for select to authenticated using (private.is_admin());
create policy experiences_admin_insert on public.experiences
  for insert to authenticated with check (private.is_admin());
create policy experiences_admin_update on public.experiences
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());
create policy experiences_admin_delete on public.experiences
  for delete to authenticated using (private.is_admin());

create policy service_areas_public on public.guide_service_areas
  for select to anon, authenticated
  using (private.is_verified_guide(guide_id)
    and private.is_published_destination(destination_id));
create policy service_areas_own_or_admin on public.guide_service_areas
  for select to authenticated
  using (guide_id = (select auth.uid()) or private.is_admin());
create policy service_areas_guide_insert on public.guide_service_areas
  for insert to authenticated
  with check (guide_id = (select auth.uid())
    and private.is_guide()
    and private.is_published_destination(destination_id));
create policy service_areas_admin_insert on public.guide_service_areas
  for insert to authenticated with check (private.is_admin());
create policy service_areas_guide_delete on public.guide_service_areas
  for delete to authenticated
  using (guide_id = (select auth.uid()) and private.is_guide());
create policy service_areas_admin_delete on public.guide_service_areas
  for delete to authenticated using (private.is_admin());

create policy bookings_participants_and_admin on public.bookings
  for select to authenticated
  using (tourist_id = (select auth.uid())
    or guide_id = (select auth.uid()) or private.is_admin());
create policy bookings_tourist_request on public.bookings
  for insert to authenticated
  with check (status = 'REQUESTED'
    and private.can_request_booking(
      tourist_id, guide_id, destination_id, experience_id, requested_date));

create policy favorites_owner_select on public.favorites
  for select to authenticated using (user_id = (select auth.uid()));
create policy favorites_owner_insert on public.favorites
  for insert to authenticated
  with check (user_id = (select auth.uid()) and (
    (destination_id is not null
      and private.is_published_destination(destination_id))
    or (experience_id is not null
      and private.is_published_experience(experience_id))));
create policy favorites_owner_delete on public.favorites
  for delete to authenticated using (user_id = (select auth.uid()));

create policy reviews_public_visible on public.reviews
  for select to anon, authenticated
  using (is_visible and private.review_booking_completed(booking_id));
create policy reviews_admin_select on public.reviews
  for select to authenticated using (private.is_admin());
create policy reviews_completed_tourist_insert on public.reviews
  for insert to authenticated
  with check (private.can_review_booking(booking_id));
create policy reviews_admin_hide on public.reviews
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

create policy verification_own_or_admin on public.guide_verification_requests
  for select to authenticated
  using (guide_id = (select auth.uid()) or private.is_admin());
create policy verification_guide_submit on public.guide_verification_requests
  for insert to authenticated
  with check (guide_id = (select auth.uid())
    and private.is_guide() and status = 'PENDING'
    and exists (
      select 1 from public.guide_profiles g
      where g.user_id = guide_id
        and g.verification_status in ('PENDING', 'REJECTED')
    ));
create policy verification_admin_review on public.guide_verification_requests
  for update to authenticated
  using (private.is_admin()) with check (private.is_admin());

commit;
