-- Gurkha Guides V1 schema. RLS and grants deny clients until migration 2.
begin;
create schema if not exists private;
revoke all on schema private from public;

create type public.app_role as enum ('TOURIST','GUIDE','ADMIN');
create type public.guide_verification_status as enum
  ('PENDING','VERIFIED','REJECTED','SUSPENDED');
create type public.booking_status as enum
  ('REQUESTED','ACCEPTED','CONFIRMED','COMPLETED','CANCELLED','REJECTED');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Traveler'
    check (char_length(btrim(display_name)) between 1 and 80),
  avatar_path text check (avatar_path is null or
    (char_length(avatar_path)<=512 and
     split_part(avatar_path,'/',1)=id::text and
     split_part(avatar_path,'/',2)<>'')),
  preferred_language text not null default 'en'
    check (preferred_language in ('en','ne')),
  role public.app_role not null default 'TOURIST',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.guide_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  bio text not null default '' check (char_length(bio)<=4000),
  languages text[] not null default '{}'::text[] check (cardinality(languages)<=10),
  years_experience smallint not null default 0 check (years_experience between 0 and 80),
  is_available boolean not null default false,
  verification_status public.guide_verification_status not null default 'PENDING',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.destinations (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_en text not null check (char_length(btrim(name_en)) between 1 and 160),
  name_ne text not null check (char_length(btrim(name_ne)) between 1 and 160),
  description_en text not null default '',
  description_ne text not null default '',
  district text not null check (char_length(btrim(district)) between 1 and 120),
  province text not null check (char_length(btrim(province)) between 1 and 120),
  latitude numeric(9,6) check (latitude between -90 and 90),
  longitude numeric(9,6) check (longitude between -180 and 180),
  cover_image_path text check (cover_image_path is null or
    (char_length(cover_image_path)<=512 and
     split_part(cover_image_path,'/',1)=id::text and
     split_part(cover_image_path,'/',2)<>'')),
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint destination_coordinates_together
    check ((latitude is null)=(longitude is null))
);

create table public.experiences (
  id uuid primary key default gen_random_uuid(),
  destination_id uuid not null references public.destinations(id) on delete restrict,
  title_en text not null check (char_length(btrim(title_en)) between 1 and 160),
  title_ne text not null check (char_length(btrim(title_ne)) between 1 and 160),
  description_en text not null default '',
  description_ne text not null default '',
  latitude numeric(9,6) check (latitude between -90 and 90),
  longitude numeric(9,6) check (longitude between -180 and 180),
  duration_minutes integer check (duration_minutes between 1 and 10080),
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint experience_coordinates_together
    check ((latitude is null)=(longitude is null)),
  constraint experience_id_destination_unique unique (id,destination_id)
);

create table public.guide_service_areas (
  guide_id uuid not null references public.guide_profiles(user_id) on delete cascade,
  destination_id uuid not null references public.destinations(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (guide_id,destination_id)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  tourist_id uuid not null references public.profiles(id) on delete restrict,
  guide_id uuid not null references public.guide_profiles(user_id) on delete restrict,
  destination_id uuid not null references public.destinations(id) on delete restrict,
  experience_id uuid,
  requested_date date not null,
  party_size smallint not null check (party_size between 1 and 20),
  message text not null default '' check (char_length(message)<=2000),
  status public.booking_status not null default 'REQUESTED',
  accepted_at timestamptz,
  confirmed_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by uuid references public.profiles(id) on delete restrict,
  rejected_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint distinct_booking_participants check (tourist_id<>guide_id),
  constraint booking_experience_matches_destination
    foreign key (experience_id,destination_id)
    references public.experiences(id,destination_id) on delete restrict
);

create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  destination_id uuid references public.destinations(id) on delete cascade,
  experience_id uuid references public.experiences(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint favorite_one_target
    check ((destination_id is null)<>(experience_id is null))
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete restrict,
  guide_id uuid not null references public.guide_profiles(user_id) on delete restrict,
  rating smallint not null check (rating between 1 and 5),
  comment text not null default '' check (char_length(comment)<=4000),
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.guide_verification_requests (
  id uuid primary key default gen_random_uuid(),
  guide_id uuid not null references public.guide_profiles(user_id) on delete restrict,
  status public.guide_verification_status not null default 'PENDING'
    check (status in ('PENDING','VERIFIED','REJECTED')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete restrict
);

create unique index favorites_one_destination_per_user
  on public.favorites(user_id,destination_id) where destination_id is not null;
create unique index favorites_one_experience_per_user
  on public.favorites(user_id,experience_id) where experience_id is not null;
create unique index one_pending_verification_per_guide
  on public.guide_verification_requests(guide_id) where status='PENDING';
create index destinations_published_idx on public.destinations(is_published,slug);
create index experiences_destination_published_idx
  on public.experiences(destination_id,is_published);
create index guide_profiles_verification_idx
  on public.guide_profiles(verification_status);
create index guide_service_areas_destination_idx
  on public.guide_service_areas(destination_id,guide_id);
create index bookings_tourist_date_idx
  on public.bookings(tourist_id,requested_date desc);
create index bookings_guide_date_idx
  on public.bookings(guide_id,requested_date desc);
create index bookings_status_idx on public.bookings(status);
create index reviews_guide_created_idx on public.reviews(guide_id,created_at desc);
create index verification_requests_guide_idx
  on public.guide_verification_requests(guide_id,submitted_at desc);
create index verification_requests_status_idx
  on public.guide_verification_requests(status,submitted_at);

create function private.set_updated_at()
returns trigger language plpgsql set search_path='' as $$
begin
  new.updated_at:=now();
  return new;
end;
$$;
create trigger profiles_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();
create trigger guide_profiles_updated_at before update on public.guide_profiles
  for each row execute function private.set_updated_at();
create trigger destinations_updated_at before update on public.destinations
  for each row execute function private.set_updated_at();
create trigger experiences_updated_at before update on public.experiences
  for each row execute function private.set_updated_at();
create trigger bookings_updated_at before update on public.bookings
  for each row execute function private.set_updated_at();
create trigger reviews_updated_at before update on public.reviews
  for each row execute function private.set_updated_at();

-- Auth metadata is untrusted. Only the exact GUIDE request is recognized.
create function private.handle_new_user()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  requested_role public.app_role:='TOURIST';
begin
  if new.raw_user_meta_data->>'requested_role'='GUIDE' then
    requested_role:='GUIDE';
  end if;
  insert into public.profiles(id,display_name,role)
  values (
    new.id,
    coalesce(nullif(pg_catalog.btrim(pg_catalog.left(
      new.raw_user_meta_data->>'display_name',80)),''),'Traveler'),
    requested_role
  );
  if requested_role='GUIDE' then
    insert into public.guide_profiles(user_id) values(new.id);
  end if;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

alter table public.profiles enable row level security;
alter table public.guide_profiles enable row level security;
alter table public.destinations enable row level security;
alter table public.experiences enable row level security;
alter table public.guide_service_areas enable row level security;
alter table public.bookings enable row level security;
alter table public.favorites enable row level security;
alter table public.reviews enable row level security;
alter table public.guide_verification_requests enable row level security;
revoke all on table
  public.profiles,public.guide_profiles,public.destinations,
  public.experiences,public.guide_service_areas,public.bookings,
  public.favorites,public.reviews,public.guide_verification_requests
  from public,anon,authenticated;
revoke all on function private.set_updated_at() from public,anon,authenticated;
revoke all on function private.handle_new_user() from public,anon,authenticated;
commit;
