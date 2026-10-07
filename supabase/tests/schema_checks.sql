-- Run after migrations in a disposable database or fresh Supabase project.
do $$
declare
  table_count integer;
  rls_count integer;
  policy_count integer;
begin
  select count(*), count(*) filter (where c.relrowsecurity)
  into table_count, rls_count
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in
    ('profiles','guide_profiles','destinations','experiences',
     'guide_service_areas','bookings','favorites','reviews',
     'guide_verification_requests') and c.relkind='r';
  if table_count<>9 or rls_count<>9 then
    raise exception 'Expected 9 application tables with RLS; got %, %',
      table_count,rls_count;
  end if;

  select count(distinct tablename) into policy_count
  from pg_policies
  where schemaname='public' and tablename in
    ('profiles','guide_profiles','destinations','experiences',
     'guide_service_areas','bookings','favorites','reviews',
     'guide_verification_requests');
  if policy_count<>9 then
    raise exception 'Some application tables have no RLS policy';
  end if;

  if has_column_privilege('authenticated','public.profiles',
                          'role','UPDATE') then
    raise exception 'Client has role update privilege';
  end if;
  if has_table_privilege('authenticated','public.bookings','UPDATE')
     or has_table_privilege('anon','public.bookings','SELECT') then
    raise exception 'Unsafe bookings privilege';
  end if;
  if has_column_privilege('authenticated','public.guide_profiles',
                          'user_id','UPDATE') then
    raise exception 'Client has guide identity update privilege';
  end if;
  if (select count(*) from storage.buckets
      where id in ('avatars','destination-media','guide-verification'))<>3
     or (select public from storage.buckets
         where id='guide-verification')
     or (select public from storage.buckets
         where id='destination-media')
     or not (select public from storage.buckets
             where id='avatars') then
    raise exception 'Storage bucket visibility is wrong';
  end if;
  if has_function_privilege('anon',
       'public.transition_booking(uuid,public.booking_status)',
       'EXECUTE')
     or (select p.prosecdef from pg_proc p
         join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='transition_booking') then
    raise exception 'Booking RPC is exposed to anon or uses public SECURITY DEFINER';
  end if;
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='private' and p.prosecdef
      and not ('search_path=""'=any(coalesce(p.proconfig,array[]::text[])))
  ) then
    raise exception 'A private SECURITY DEFINER function lacks an empty search_path';
  end if;
end;
$$;
