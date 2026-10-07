-- Gurkha Guides V1: buckets and Storage object access.
-- Supabase Storage owns storage.objects; use Storage APIs for file operations.
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880,
    array['image/jpeg', 'image/png', 'image/webp']),
  ('destination-media', 'destination-media', false, 10485760,
    array['image/jpeg', 'image/png', 'image/webp']),
  ('guide-verification', 'guide-verification', false, 10485760,
    array['image/jpeg', 'image/png', 'application/pdf']);

create function private.destination_media_path_valid(p_name text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  folder text := pg_catalog.split_part(p_name, '/', 1);
begin
  if folder !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     or pg_catalog.split_part(p_name, '/', 2) = '' then
    return false;
  end if;
  return exists (
    select 1 from public.destinations d where d.id = folder::uuid
  );
end;
$$;

create function private.destination_media_visible(p_name text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  folder text := pg_catalog.split_part(p_name, '/', 1);
begin
  if folder !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     or pg_catalog.split_part(p_name, '/', 2) = '' then
    return false;
  end if;
  return private.is_published_destination(folder::uuid);
end;
$$;

revoke all on function private.destination_media_path_valid(text)
  from public, anon, authenticated;
revoke all on function private.destination_media_visible(text)
  from public, anon, authenticated;
grant execute on function private.destination_media_path_valid(text)
  to authenticated;
grant execute on function private.destination_media_visible(text)
  to anon, authenticated;

-- Avatars are intentionally public. Owners control their UUID folder.
create policy gurkha_avatars_read on storage.objects
  for select to anon, authenticated using (bucket_id = 'avatars');
create policy gurkha_avatars_insert on storage.objects
  for insert to authenticated with check (
    bucket_id = 'avatars'
    and pg_catalog.split_part(name, '/', 1) = (select auth.uid())::text
    and pg_catalog.split_part(name, '/', 2) <> ''
  );
create policy gurkha_avatars_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars'
    and (pg_catalog.split_part(name, '/', 1) = (select auth.uid())::text
      or private.is_admin()))
  with check (bucket_id = 'avatars'
    and (pg_catalog.split_part(name, '/', 1) = (select auth.uid())::text
      or private.is_admin()));
create policy gurkha_avatars_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars'
    and (pg_catalog.split_part(name, '/', 1) = (select auth.uid())::text
      or private.is_admin()));

-- This bucket is private: draft destination files are not public URLs.
create policy gurkha_destination_media_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'destination-media'
    and (private.destination_media_visible(name) or private.is_admin()));
create policy gurkha_destination_media_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'destination-media'
    and private.is_admin()
    and private.destination_media_path_valid(name));
create policy gurkha_destination_media_update on storage.objects
  for update to authenticated
  using (bucket_id = 'destination-media' and private.is_admin())
  with check (bucket_id = 'destination-media'
    and private.is_admin()
    and private.destination_media_path_valid(name));
create policy gurkha_destination_media_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'destination-media' and private.is_admin());

-- Verification evidence is never served by a permanent public URL.
create policy gurkha_verification_read on storage.objects
  for select to authenticated
  using (bucket_id = 'guide-verification'
    and ((private.is_guide()
      and pg_catalog.split_part(name, '/', 1) = (select auth.uid())::text)
      or private.is_admin()));
create policy gurkha_verification_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'guide-verification'
    and private.is_guide()
    and pg_catalog.split_part(name, '/', 1) = (select auth.uid())::text
    and pg_catalog.split_part(name, '/', 2) <> '');
create policy gurkha_verification_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'guide-verification' and private.is_admin());

commit;
