-- Disposable local security simulation, run after local_bootstrap + all migrations.
-- Uses mocked Supabase auth/storage objects; ROLLBACK leaves no fixture rows.
begin;

insert into auth.users (id,raw_user_meta_data) values
 ('00000000-0000-4000-8000-000000000001','{"requested_role":"TOURIST","display_name":"Tourist One"}'),
 ('00000000-0000-4000-8000-000000000002','{"requested_role":"ADMIN","display_name":"Tourist Two"}'),
 ('00000000-0000-4000-8000-000000000003','{"requested_role":"GUIDE","display_name":"Guide One"}'),
 ('00000000-0000-4000-8000-000000000004','{"requested_role":"GUIDE","display_name":"Guide Two"}'),
 ('00000000-0000-4000-8000-000000000005','{"requested_role":"ADMIN","display_name":"Admin"}'),
 ('00000000-0000-4000-8000-000000000006','{"requested_role":"GUIDE","display_name":"Pending Guide"}');

do $$
begin
  if (select role from public.profiles
      where id='00000000-0000-4000-8000-000000000005') <> 'TOURIST'
     or (select verification_status from public.guide_profiles
      where user_id='00000000-0000-4000-8000-000000000003') <> 'PENDING' then
    raise exception 'Untrusted signup metadata granted a privileged state';
  end if;
end;
$$;

-- Trusted database operator action; client role cannot perform this update.
update public.profiles set role='ADMIN'
  where id='00000000-0000-4000-8000-000000000005';
update public.guide_profiles set verification_status='VERIFIED'
  where user_id in ('00000000-0000-4000-8000-000000000003',
                    '00000000-0000-4000-8000-000000000004');

insert into public.destinations
 (id,slug,name_en,name_ne,district,province,is_published) values
 ('10000000-0000-4000-8000-000000000001','test-published',
  'Published','Published NE','Kathmandu','Bagmati',true),
 ('10000000-0000-4000-8000-000000000002','test-draft',
  'Draft','Draft NE','Kathmandu','Bagmati',false);
insert into public.experiences
 (id,destination_id,title_en,title_ne,is_published) values
 ('20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001','Walk','Walk NE',true);
insert into public.guide_service_areas (guide_id,destination_id) values
 ('00000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000001');
insert into storage.objects (bucket_id,name) values
 ('destination-media',
  '10000000-0000-4000-8000-000000000001/cover.jpg'),
 ('destination-media',
  '10000000-0000-4000-8000-000000000002/draft.jpg');

set role authenticated;
set request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
do $$
declare denied boolean:=false;
begin
  begin
    update public.profiles set role='ADMIN'
    where id='00000000-0000-4000-8000-000000000001';
  exception when insufficient_privilege then denied:=true;
  end;
  if not denied then raise exception 'Tourist role update was accepted'; end if;
end;
$$;
update public.profiles set display_name='Tourist One Edited'
  where id='00000000-0000-4000-8000-000000000001';
do $$
begin
  if (select display_name from public.profiles
      where id='00000000-0000-4000-8000-000000000001')
      <> 'Tourist One Edited' then
    raise exception 'Owner profile update failed';
  end if;
end;
$$;

insert into public.bookings
 (tourist_id,guide_id,destination_id,experience_id,requested_date,party_size)
values
 ('00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  (now() at time zone 'Asia/Kathmandu')::date,2);

do $$
declare denied boolean:=false;
begin
  begin
    update public.bookings set status='COMPLETED'
    where tourist_id='00000000-0000-4000-8000-000000000001';
  exception when insufficient_privilege then denied:=true;
  end;
  if not denied then raise exception 'Tourist directly updated booking status'; end if;
end;
$$;

reset role;
select set_config('test.booking_id',id::text,true)
from public.bookings
where tourist_id='00000000-0000-4000-8000-000000000001';

set role authenticated;
set request.jwt.claim.sub='00000000-0000-4000-8000-000000000002';
do $$
declare denied boolean:=false;
begin
  if (select count(*) from public.bookings) <> 0 then
    raise exception 'Unrelated tourist read a booking';
  end if;
  begin
    insert into public.bookings
      (tourist_id,guide_id,destination_id,requested_date,party_size)
    values ('00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000003',
      '10000000-0000-4000-8000-000000000001',
      (now() at time zone 'Asia/Kathmandu')::date,1);
  exception when insufficient_privilege then denied:=true;
  end;
  if not denied then raise exception 'Cross-tourist booking was accepted'; end if;
  update public.destinations set is_published=true
    where id='10000000-0000-4000-8000-000000000002';
  if found then raise exception 'Tourist published a destination'; end if;
end;
$$;

set request.jwt.claim.sub='00000000-0000-4000-8000-000000000004';
do $$
declare denied boolean:=false;
begin
  begin
    perform public.transition_booking(
      current_setting('test.booking_id')::uuid,'ACCEPTED');
  exception when insufficient_privilege then denied:=true;
  end;
  if not denied then raise exception 'Other guide changed booking'; end if;
end;
$$;

set request.jwt.claim.sub='00000000-0000-4000-8000-000000000003';
do $$
declare denied boolean:=false;
begin
  begin
    update public.guide_profiles set verification_status='SUSPENDED'
      where user_id='00000000-0000-4000-8000-000000000003';
  exception when insufficient_privilege then denied:=true;
  end;
  if not denied then raise exception 'Guide changed own verification'; end if;
end;
$$;

set request.jwt.claim.sub='00000000-0000-4000-8000-000000000006';
do $$
declare denied boolean:=false;
begin
  begin
    update public.guide_profiles set verification_status='VERIFIED'
    where user_id='00000000-0000-4000-8000-000000000006';
  exception when insufficient_privilege then denied:=true;
  end;
  if not denied then raise exception 'Pending guide self-verified'; end if;
end;
$$;
insert into public.guide_verification_requests (guide_id)
values ('00000000-0000-4000-8000-000000000006');
do $$
begin
  update public.guide_verification_requests set status='VERIFIED'
    where guide_id='00000000-0000-4000-8000-000000000006';
  if found then raise exception 'Guide approved own request'; end if;
end;
$$;

insert into storage.objects (bucket_id,name)
values ('guide-verification',
  '00000000-0000-4000-8000-000000000006/local-test.pdf');
do $$
begin
  if (select count(*) from storage.objects
      where bucket_id='guide-verification') <> 1 then
    raise exception 'Owning guide could not read own verification object';
  end if;
end;
$$;
set request.jwt.claim.sub='00000000-0000-4000-8000-000000000004';
do $$
begin
  if (select count(*) from storage.objects
      where bucket_id='guide-verification') <> 0 then
    raise exception 'Other guide read private verification object';
  end if;
end;
$$;
set request.jwt.claim.sub='00000000-0000-4000-8000-000000000003';
select public.transition_booking(
  current_setting('test.booking_id')::uuid,'ACCEPTED');

set request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
do $$
declare denied boolean:=false;
begin
  begin
    insert into public.reviews (booking_id,rating,comment)
    values (current_setting('test.booking_id')::uuid,5,'Too early');
  exception when insufficient_privilege then denied:=true;
  end;
  if not denied then raise exception 'Review before completion accepted'; end if;
end;
$$;
select public.transition_booking(
  current_setting('test.booking_id')::uuid,'CONFIRMED');

set request.jwt.claim.sub='00000000-0000-4000-8000-000000000003';
select public.transition_booking(
  current_setting('test.booking_id')::uuid,'COMPLETED');

set request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
insert into public.reviews (booking_id,rating,comment)
values (current_setting('test.booking_id')::uuid,5,'Completed trip');
do $$
begin
  if (select guide_id from public.reviews
      where booking_id=current_setting('test.booking_id')::uuid)
      <> '00000000-0000-4000-8000-000000000003' then
    raise exception 'Review guide was not derived from the booking';
  end if;
end;
$$;
do $$
declare denied boolean:=false;
begin
  begin
    insert into public.reviews (booking_id,rating,comment)
    values (current_setting('test.booking_id')::uuid,4,'Duplicate');
  exception when unique_violation then denied:=true;
  end;
  if not denied then raise exception 'Duplicate review accepted'; end if;
end;
$$;
insert into public.favorites (user_id,destination_id)
values ('00000000-0000-4000-8000-000000000001',
        '10000000-0000-4000-8000-000000000001');

reset role;
set role anon;
set request.jwt.claim.sub='';
do $$
begin
  if (select count(*) from storage.objects
      where bucket_id='guide-verification') <> 0 then
    raise exception 'Anonymous user read private verification metadata';
  end if;
  if (select count(*) from public.destinations) <> 1 then
    raise exception 'Anonymous destination visibility is wrong';
  end if;
  if (select count(*) from storage.objects
      where bucket_id='destination-media') <> 1 then
    raise exception 'Draft destination media was exposed';
  end if;

end;
$$;

reset role;
do $$
begin
  if (select public from storage.buckets
      where id='guide-verification') then
    raise exception 'Verification bucket is public';
  end if;
end;
$$;
set role authenticated;
set request.jwt.claim.sub='00000000-0000-4000-8000-000000000005';
update public.guide_verification_requests set status='REJECTED'
where guide_id='00000000-0000-4000-8000-000000000006';
do $$
begin
  if (select verification_status from public.guide_profiles
      where user_id='00000000-0000-4000-8000-000000000006') <> 'REJECTED' then
    raise exception 'Admin decision did not sync guide status';
  end if;
end;
$$;
update public.guide_profiles set verification_status='SUSPENDED'
  where user_id='00000000-0000-4000-8000-000000000006';
do $$
begin
  if (select verification_status from public.guide_profiles
      where user_id='00000000-0000-4000-8000-000000000006') <> 'SUSPENDED' then
    raise exception 'Admin suspension failed';
  end if;
end;
$$;

reset role;
rollback;
