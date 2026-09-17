-- ==========================================================================
-- AUTO-GENERATED COMPLETE SCHEMA FOR OPEN HOTEL PMS
-- Total Migrations Combined: 184
-- ==========================================================================


-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260219_000001_init_core.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create extension if not exists "pgcrypto";

do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type public.user_role as enum ('admin', 'frontdesk', 'maid', 'supervisor');
  end if;

  if not exists (select 1 from pg_type where typname = 'booking_source') then
    create type public.booking_source as enum ('walkin', 'ota', 'direct', 'agent');
  end if;

  if not exists (select 1 from pg_type where typname = 'reservation_status') then
    create type public.reservation_status as enum ('active', 'cancelled', 'checked_out', 'no_show');
  end if;

  if not exists (select 1 from pg_type where typname = 'housekeeping_status') then
    create type public.housekeeping_status as enum ('dirty', 'in_progress', 'paused', 'cleaned', 'approved');
  end if;
end $$;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'frontdesk',
  full_name text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.room_types (
  id bigserial primary key,
  code text not null unique,
  name_en text not null,
  name_local text,
  sort_order int not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  room_number text not null unique,
  room_type_id bigint not null references public.room_types (id),
  is_sellable boolean not null default true,
  is_visible_on_board boolean not null default true,
  closure_reason text,
  sort_order int not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.room_layouts (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id) on delete cascade,
  view_type text not null check (view_type in ('month', 'week', 'day')),
  grid_x int,
  grid_y int,
  zone text not null default 'default',
  sort_order int not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (room_id, view_type)
);

create table if not exists public.rate_templates (
  id uuid primary key default gen_random_uuid(),
  stay_date date not null,
  room_id uuid not null references public.rooms (id) on delete cascade,
  price numeric(10, 2) not null default 0,
  updated_by uuid references public.profiles (user_id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (stay_date, room_id)
);

create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  booking_code text not null unique,
  guest_name text not null,
  phone text,
  source public.booking_source not null default 'walkin',
  status public.reservation_status not null default 'active',
  checkin_date date not null,
  checkout_date date not null,
  checkin_time text,
  note text,
  total_price numeric(10, 2) not null default 0,
  created_by uuid references public.profiles (user_id),
  updated_by uuid references public.profiles (user_id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint reservation_date_range check (checkout_date > checkin_date)
);

create table if not exists public.reservation_nights (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.reservations (id) on delete cascade,
  room_id uuid not null references public.rooms (id),
  stay_date date not null,
  nightly_price numeric(10, 2) not null default 0,
  is_ota boolean not null default false,
  cancelled_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists uq_reservation_nights_active_room_day
  on public.reservation_nights (room_id, stay_date)
  where cancelled_at is null;

create table if not exists public.housekeeping_tasks (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms (id),
  stay_date date not null,
  reservation_night_id uuid references public.reservation_nights (id),
  status public.housekeeping_status not null default 'dirty',
  assigned_maid uuid references public.profiles (user_id),
  requested_by uuid references public.profiles (user_id),
  approved_by uuid references public.profiles (user_id),
  started_at timestamptz,
  finished_at timestamptz,
  approved_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists uq_housekeeping_tasks_room_day
  on public.housekeeping_tasks (room_id, stay_date);

create table if not exists public.housekeeping_logs (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.housekeeping_tasks (id) on delete cascade,
  status public.housekeeping_status not null,
  actor_user_id uuid references public.profiles (user_id),
  note text,
  checklist jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles (user_id),
  action text not null,
  entity_type text not null,
  entity_id text not null,
  before_json jsonb,
  after_json jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_room_types_updated_at on public.room_types;
create trigger trg_room_types_updated_at
before update on public.room_types
for each row execute function public.set_updated_at();

drop trigger if exists trg_rooms_updated_at on public.rooms;
create trigger trg_rooms_updated_at
before update on public.rooms
for each row execute function public.set_updated_at();

drop trigger if exists trg_room_layouts_updated_at on public.room_layouts;
create trigger trg_room_layouts_updated_at
before update on public.room_layouts
for each row execute function public.set_updated_at();

drop trigger if exists trg_rate_templates_updated_at on public.rate_templates;
create trigger trg_rate_templates_updated_at
before update on public.rate_templates
for each row execute function public.set_updated_at();

drop trigger if exists trg_reservations_updated_at on public.reservations;
create trigger trg_reservations_updated_at
before update on public.reservations
for each row execute function public.set_updated_at();

drop trigger if exists trg_housekeeping_tasks_updated_at on public.housekeeping_tasks;
create trigger trg_housekeeping_tasks_updated_at
before update on public.housekeeping_tasks
for each row execute function public.set_updated_at();

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select p.role
  from public.profiles p
  where p.user_id = auth.uid() and p.is_active = true
  limit 1;
$$;

create or replace function public.has_any_role(roles public.user_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = any(roles), false);
$$;

grant execute on function public.current_user_role() to authenticated;
grant execute on function public.has_any_role(public.user_role[]) to authenticated;

alter table public.profiles enable row level security;
alter table public.room_types enable row level security;
alter table public.rooms enable row level security;
alter table public.room_layouts enable row level security;
alter table public.rate_templates enable row level security;
alter table public.reservations enable row level security;
alter table public.reservation_nights enable row level security;
alter table public.housekeeping_tasks enable row level security;
alter table public.housekeeping_logs enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_select_policy on public.profiles
for select to authenticated
using (user_id = auth.uid() or public.has_any_role(array['admin', 'supervisor']::public.user_role[]));

create policy profiles_insert_policy on public.profiles
for insert to authenticated
with check (user_id = auth.uid() or public.has_any_role(array['admin']::public.user_role[]));

create policy profiles_update_policy on public.profiles
for update to authenticated
using (user_id = auth.uid() or public.has_any_role(array['admin']::public.user_role[]))
with check (user_id = auth.uid() or public.has_any_role(array['admin']::public.user_role[]));

create policy room_types_read_policy on public.room_types
for select to authenticated using (true);

create policy room_types_write_policy on public.room_types
for all to authenticated
using (public.has_any_role(array['admin', 'supervisor']::public.user_role[]))
with check (public.has_any_role(array['admin', 'supervisor']::public.user_role[]));

create policy rooms_read_policy on public.rooms
for select to authenticated using (true);

create policy rooms_write_policy on public.rooms
for all to authenticated
using (public.has_any_role(array['admin', 'supervisor']::public.user_role[]))
with check (public.has_any_role(array['admin', 'supervisor']::public.user_role[]));

create policy room_layouts_read_policy on public.room_layouts
for select to authenticated using (true);

create policy room_layouts_write_policy on public.room_layouts
for all to authenticated
using (public.has_any_role(array['admin', 'supervisor']::public.user_role[]))
with check (public.has_any_role(array['admin', 'supervisor']::public.user_role[]));

create policy rate_templates_read_policy on public.rate_templates
for select to authenticated using (true);

create policy rate_templates_write_policy on public.rate_templates
for all to authenticated
using (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]))
with check (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]));

create policy reservations_read_policy on public.reservations
for select to authenticated using (true);

create policy reservations_write_policy on public.reservations
for all to authenticated
using (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]))
with check (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]));

create policy reservation_nights_read_policy on public.reservation_nights
for select to authenticated using (true);

create policy reservation_nights_write_policy on public.reservation_nights
for all to authenticated
using (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]))
with check (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]));

create policy housekeeping_tasks_read_policy on public.housekeeping_tasks
for select to authenticated using (true);

create policy housekeeping_tasks_write_policy on public.housekeeping_tasks
for all to authenticated
using (public.has_any_role(array['admin', 'frontdesk', 'maid', 'supervisor']::public.user_role[]))
with check (public.has_any_role(array['admin', 'frontdesk', 'maid', 'supervisor']::public.user_role[]));

create policy housekeeping_logs_read_policy on public.housekeeping_logs
for select to authenticated using (true);

create policy housekeeping_logs_write_policy on public.housekeeping_logs
for insert to authenticated
with check (public.has_any_role(array['admin', 'maid', 'supervisor']::public.user_role[]));

create policy audit_logs_read_policy on public.audit_logs
for select to authenticated
using (public.has_any_role(array['admin', 'supervisor']::public.user_role[]));

create policy audit_logs_insert_policy on public.audit_logs
for insert to authenticated
with check (public.has_any_role(array['admin', 'frontdesk', 'maid', 'supervisor']::public.user_role[]));

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260223_000002_booking_workflows.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create or replace function public.generate_booking_code()
returns text
language plpgsql
set search_path = public
as $$
declare
  v_code text;
  v_try int := 0;
begin
  loop
    v_try := v_try + 1;
    v_code := 'BK-' || to_char(timezone('utc', now()), 'YYYYMMDDHH24MISSMS') || '-' || upper(substring(gen_random_uuid()::text from 1 for 6));
    exit when not exists (select 1 from public.reservations where booking_code = v_code);

    if v_try >= 20 then
      raise exception 'Cannot generate unique booking code';
    end if;
  end loop;

  return v_code;
end;
$$;

create or replace function public.booking_create_reservation(
  p_guest_name text,
  p_room_number text,
  p_checkin_date date,
  p_checkout_date date,
  p_source public.booking_source default 'walkin',
  p_phone text default null,
  p_checkin_time text default null,
  p_note text default null,
  p_ota_prices numeric[] default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_room public.rooms%rowtype;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_reservation_id uuid;
  v_booking_code text;
  v_conflict_date date;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
begin
  if p_guest_name is null or btrim(p_guest_name) = '' then
    raise exception 'guest_name is required';
  end if;

  if p_room_number is null or btrim(p_room_number) = '' then
    raise exception 'room_number is required';
  end if;

  if p_checkout_date <= p_checkin_date then
    raise exception 'checkout_date must be after checkin_date';
  end if;

  select *
  into v_room
  from public.rooms
  where room_number = btrim(p_room_number)
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  if not v_room.is_sellable then
    raise exception 'Room % is not sellable', v_room.room_number;
  end if;

  select coalesce(array_agg(day::date order by day::date), array[]::date[])
  into v_night_dates
  from generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - interval '1 day')::timestamp,
    interval '1 day'
  ) as day;

  v_nights_count := cardinality(v_night_dates);
  if v_nights_count = 0 then
    raise exception 'No nights generated for selected date range';
  end if;

  select rn.stay_date
  into v_conflict_date
  from public.reservation_nights rn
  where rn.room_id = v_room.id
    and rn.cancelled_at is null
    and rn.stay_date = any(v_night_dates)
  limit 1;

  if v_conflict_date is not null then
    raise exception 'Room % already booked on %', v_room.room_number, v_conflict_date;
  end if;

  if p_source = 'ota' then
    if p_ota_prices is null or cardinality(p_ota_prices) <> v_nights_count then
      raise exception 'OTA bookings require ota_prices length = %', v_nights_count;
    end if;

    select coalesce(array_agg(round(coalesce(ota.price, 0)::numeric, 2) order by ota.idx), array[]::numeric[])
    into v_prices
    from unnest(p_ota_prices) with ordinality as ota(price, idx);
  else
    select coalesce(array_agg(coalesce(rt.price, 0)::numeric(10, 2) order by d.stay_date), array[]::numeric[])
    into v_prices
    from unnest(v_night_dates) as d(stay_date)
    left join public.rate_templates rt
      on rt.room_id = v_room.id
     and rt.stay_date = d.stay_date;
  end if;

  select round(coalesce(sum(coalesce(price, 0)), 0)::numeric, 2)
  into v_total_price
  from unnest(v_prices) as p(price);

  v_booking_code := public.generate_booking_code();
  v_normalized_phone := nullif(btrim(coalesce(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(coalesce(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(coalesce(p_note, '')), '');

  insert into public.reservations (
    booking_code,
    guest_name,
    phone,
    source,
    status,
    checkin_date,
    checkout_date,
    checkin_time,
    note,
    total_price,
    created_by,
    updated_by
  )
  values (
    v_booking_code,
    btrim(p_guest_name),
    v_normalized_phone,
    p_source,
    'active',
    p_checkin_date,
    p_checkout_date,
    v_normalized_checkin_time,
    v_normalized_note,
    v_total_price,
    p_actor_user_id,
    p_actor_user_id
  )
  returning id into v_reservation_id;

  insert into public.reservation_nights (
    reservation_id,
    room_id,
    stay_date,
    nightly_price,
    is_ota
  )
  select
    v_reservation_id,
    v_room.id,
    d.stay_date,
    round(coalesce(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  from unnest(v_night_dates) with ordinality as d(stay_date, idx)
  join unnest(v_prices) with ordinality as pr(price, idx)
    on pr.idx = d.idx;

  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    p_actor_user_id,
    'booking_created',
    'reservation',
    v_reservation_id::text,
    jsonb_build_object(
      'booking_code', v_booking_code,
      'room_number', v_room.room_number,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price
    )
  );

  return jsonb_build_object(
    'id', v_reservation_id,
    'booking_code', v_booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', v_room.room_number,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
end;
$$;

create or replace function public.booking_update_reservation(
  p_reservation_id uuid,
  p_guest_name text,
  p_room_number text,
  p_checkin_date date,
  p_checkout_date date,
  p_source public.booking_source default 'walkin',
  p_phone text default null,
  p_checkin_time text default null,
  p_note text default null,
  p_ota_prices numeric[] default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_room public.rooms%rowtype;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_replaced_nights int;
  v_cancelled_at timestamptz;
  v_before jsonb;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
begin
  if p_guest_name is null or btrim(p_guest_name) = '' then
    raise exception 'guest_name is required';
  end if;

  if p_room_number is null or btrim(p_room_number) = '' then
    raise exception 'room_number is required';
  end if;

  if p_checkout_date <= p_checkin_date then
    raise exception 'checkout_date must be after checkin_date';
  end if;

  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'active' then
    raise exception 'Reservation is not active';
  end if;

  select *
  into v_room
  from public.rooms
  where room_number = btrim(p_room_number)
  for update;

  if not found then
    raise exception 'Room not found';
  end if;

  if not v_room.is_sellable then
    raise exception 'Room % is not sellable', v_room.room_number;
  end if;

  select coalesce(array_agg(day::date order by day::date), array[]::date[])
  into v_night_dates
  from generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - interval '1 day')::timestamp,
    interval '1 day'
  ) as day;

  v_nights_count := cardinality(v_night_dates);
  if v_nights_count = 0 then
    raise exception 'No nights generated for selected date range';
  end if;

  select rn.stay_date
  into v_conflict_date
  from public.reservation_nights rn
  where rn.room_id = v_room.id
    and rn.cancelled_at is null
    and rn.stay_date = any(v_night_dates)
    and rn.reservation_id <> p_reservation_id
  limit 1;

  if v_conflict_date is not null then
    raise exception 'Room % already booked on %', v_room.room_number, v_conflict_date;
  end if;

  if p_source = 'ota' then
    if p_ota_prices is null or cardinality(p_ota_prices) <> v_nights_count then
      raise exception 'OTA bookings require ota_prices length = %', v_nights_count;
    end if;

    select coalesce(array_agg(round(coalesce(ota.price, 0)::numeric, 2) order by ota.idx), array[]::numeric[])
    into v_prices
    from unnest(p_ota_prices) with ordinality as ota(price, idx);
  else
    select coalesce(array_agg(coalesce(rt.price, 0)::numeric(10, 2) order by d.stay_date), array[]::numeric[])
    into v_prices
    from unnest(v_night_dates) as d(stay_date)
    left join public.rate_templates rt
      on rt.room_id = v_room.id
     and rt.stay_date = d.stay_date;
  end if;

  select round(coalesce(sum(coalesce(price, 0)), 0)::numeric, 2)
  into v_total_price
  from unnest(v_prices) as p(price);

  v_before := jsonb_build_object(
    'guest_name', v_reservation.guest_name,
    'source', v_reservation.source,
    'checkin_date', v_reservation.checkin_date,
    'checkout_date', v_reservation.checkout_date,
    'total_price', v_reservation.total_price
  );

  v_cancelled_at := timezone('utc', now());
  update public.reservation_nights
  set cancelled_at = v_cancelled_at
  where reservation_id = p_reservation_id
    and cancelled_at is null;
  get diagnostics v_replaced_nights = row_count;

  v_normalized_phone := nullif(btrim(coalesce(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(coalesce(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(coalesce(p_note, '')), '');

  update public.reservations
  set
    guest_name = btrim(p_guest_name),
    phone = v_normalized_phone,
    source = p_source,
    checkin_date = p_checkin_date,
    checkout_date = p_checkout_date,
    checkin_time = v_normalized_checkin_time,
    note = v_normalized_note,
    total_price = v_total_price,
    updated_by = coalesce(p_actor_user_id, updated_by)
  where id = p_reservation_id;

  insert into public.reservation_nights (
    reservation_id,
    room_id,
    stay_date,
    nightly_price,
    is_ota
  )
  select
    p_reservation_id,
    v_room.id,
    d.stay_date,
    round(coalesce(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  from unnest(v_night_dates) with ordinality as d(stay_date, idx)
  join unnest(v_prices) with ordinality as pr(price, idx)
    on pr.idx = d.idx;

  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  values (
    p_actor_user_id,
    'booking_updated',
    'reservation',
    p_reservation_id::text,
    v_before,
    jsonb_build_object(
      'room_number', v_room.room_number,
      'source', p_source,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price,
      'replaced_nights', v_replaced_nights
    )
  );

  return jsonb_build_object(
    'id', p_reservation_id,
    'booking_code', v_reservation.booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', v_room.room_number,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
end;
$$;

create or replace function public.booking_cancel_reservation(
  p_reservation_id uuid,
  p_cancel_reason text default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_cancelled_at timestamptz;
  v_cancelled_nights int;
  v_note text;
  v_reason text;
begin
  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'active' then
    raise exception 'Reservation is not active';
  end if;

  v_cancelled_at := timezone('utc', now());
  v_reason := nullif(btrim(coalesce(p_cancel_reason, '')), '');
  v_note := nullif(btrim(coalesce(v_reservation.note, '')), '');

  if v_reason is not null then
    v_note := concat_ws(E'\n', v_note, 'Cancelled: ' || v_reason);
  end if;

  update public.reservations
  set
    status = 'cancelled',
    note = v_note,
    updated_by = coalesce(p_actor_user_id, updated_by)
  where id = p_reservation_id;

  update public.reservation_nights
  set cancelled_at = v_cancelled_at
  where reservation_id = p_reservation_id
    and cancelled_at is null;
  get diagnostics v_cancelled_nights = row_count;

  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  values (
    p_actor_user_id,
    'booking_cancelled',
    'reservation',
    p_reservation_id::text,
    jsonb_build_object(
      'status', 'active'
    ),
    jsonb_build_object(
      'status', 'cancelled',
      'cancelled_nights', v_cancelled_nights
    )
  );

  return jsonb_build_object(
    'id', p_reservation_id,
    'booking_code', v_reservation.booking_code,
    'status', 'cancelled',
    'cancelled_nights', v_cancelled_nights
  );
end;
$$;

grant execute on function public.generate_booking_code() to authenticated, service_role;
grant execute on function public.booking_create_reservation(text, text, date, date, public.booking_source, text, text, text, numeric[], uuid) to authenticated, service_role;
grant execute on function public.booking_update_reservation(uuid, text, text, date, date, public.booking_source, text, text, text, numeric[], uuid) to authenticated, service_role;
grant execute on function public.booking_cancel_reservation(uuid, text, uuid) to authenticated, service_role;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260224_floating_bookings_fix.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>




-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260227_add_missing_floor3_renovation_rooms.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Add missing renovation rooms on Floor 3 Right wing
-- Required for Room Diary ordering after 334 => 332, 330, 328

BEGIN;

WITH closed_type AS (
  SELECT id
  FROM public.room_types
  WHERE code = 'CLOSED'
  UNION ALL
  SELECT room_type_id AS id
  FROM public.rooms
  WHERE room_number = '334'
  LIMIT 1
),
target_rooms AS (
  SELECT *
  FROM (
    VALUES
      ('332'::text, 10::int),
      ('330'::text, 11::int),
      ('328'::text, 12::int)
  ) AS v(room_number, sort_order)
)
INSERT INTO public.rooms (
  room_number,
  room_type_id,
  is_sellable,
  is_visible_on_board,
  closure_reason,
  floor_number,
  wing,
  sort_order
)
SELECT
  tr.room_number,
  ct.id,
  false,
  true,
  'Renovation',
  3,
  'R',
  tr.sort_order
FROM target_rooms tr
CROSS JOIN closed_type ct
ON CONFLICT (room_number) DO UPDATE
SET
  room_type_id = EXCLUDED.room_type_id,
  is_sellable = EXCLUDED.is_sellable,
  is_visible_on_board = EXCLUDED.is_visible_on_board,
  closure_reason = EXCLUDED.closure_reason,
  floor_number = EXCLUDED.floor_number,
  wing = EXCLUDED.wing,
  sort_order = EXCLUDED.sort_order;

INSERT INTO public.room_layouts (room_id, view_type, grid_x, grid_y, zone, sort_order)
SELECT
  r.id,
  vt.view_type,
  NULL,
  NULL,
  'building',
  r.sort_order
FROM public.rooms r
CROSS JOIN (
  VALUES
    ('month'::text),
    ('week'::text),
    ('day'::text)
) AS vt(view_type)
WHERE r.room_number IN ('332', '330', '328')
ON CONFLICT (room_id, view_type) DO UPDATE
SET
  zone = EXCLUDED.zone,
  sort_order = EXCLUDED.sort_order;

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260306_phase13_night_audit_noshow.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Phase 13: Night Audit + No-Show + Dashboard KPI
-- ============================================================

ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS no_show_fee numeric(10,2) DEFAULT NULL;

COMMENT ON COLUMN reservations.no_show_fee IS
  'Optional no-show penalty amount. NULL = no fee. Set per booking.';

ALTER TABLE daily_snapshots
  ADD COLUMN IF NOT EXISTS no_show_count int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS no_show_fee_total numeric(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pos_revenue numeric(12,2) DEFAULT 0;

COMMENT ON COLUMN daily_snapshots.no_show_count IS
  'Number of reservations marked no-show on this business date.';
COMMENT ON COLUMN daily_snapshots.no_show_fee_total IS
  'Total no-show fees charged on this business date.';
COMMENT ON COLUMN daily_snapshots.pos_revenue IS
  'POS revenue for this business date (from pos_orders completed).';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'daily_snapshots'
      AND column_name = 'eod_run_by'
  ) THEN
    ALTER TABLE daily_snapshots
      ADD COLUMN eod_run_by uuid REFERENCES profiles(user_id);
  END IF;
END $$;

COMMENT ON COLUMN folio_payments.revenue_category IS
  'Valid: room_revenue, pos_revenue, extra_charge, deposit, no_show_fee';

CREATE INDEX IF NOT EXISTS idx_reservations_noshow_pending
  ON reservations (checkin_date, status)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_daily_snapshots_date_desc
  ON daily_snapshots (business_date DESC);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260308_phase18_group_checkin_wizard.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Phase 18: Group Check-in Wizard Drafts
-- ============================================================

create table if not exists public.group_checkin_wizard_drafts (
  id uuid primary key default gen_random_uuid(),
  booking_group_id uuid not null references public.booking_groups(id) on delete cascade,
  business_date date not null,
  status text not null default 'draft' check (status in ('draft', 'completed', 'cancelled')),
  current_step smallint not null default 1 check (current_step between 1 and 4),
  draft_json jsonb not null default '{}'::jsonb,
  last_committed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (booking_group_id, business_date)
);

comment on table public.group_checkin_wizard_drafts is
  'Stateful draft storage for group check-in wizard by booking_group and business date.';

comment on column public.group_checkin_wizard_drafts.status is
  'draft = active wizard, completed = fully checked in, cancelled = manually or force cancelled.';

create index if not exists idx_group_checkin_wizard_drafts_status_business_date
  on public.group_checkin_wizard_drafts (status, business_date);

create or replace function public.touch_group_checkin_wizard_drafts_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_group_checkin_wizard_drafts_updated_at on public.group_checkin_wizard_drafts;
create trigger trg_group_checkin_wizard_drafts_updated_at
before update on public.group_checkin_wizard_drafts
for each row execute function public.touch_group_checkin_wizard_drafts_updated_at();

alter table public.group_checkin_wizard_drafts enable row level security;
drop policy if exists service_full on public.group_checkin_wizard_drafts;
create policy service_full
  on public.group_checkin_wizard_drafts
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260309_phase19_reservation_capacity_guard.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Phase 19: Reservation Capacity Guard (Hard Stop)
-- Enforce non-dayuse room-type capacity at DB level to prevent overbook.
-- ============================================================

BEGIN;

-- Backfill room_type_id for rows that already have room_id.
UPDATE public.reservation_nights rn
SET room_type_id = r.room_type_id
FROM public.rooms r
WHERE rn.room_id = r.id
  AND rn.room_type_id IS NULL;

CREATE OR REPLACE FUNCTION public.enforce_reservation_night_capacity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_reservation record;
  v_room record;
  v_effective_room_type_id bigint;
  v_capacity int;
  v_occupied int;
BEGIN
  IF NEW.cancelled_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT id, status, is_dayuse
  INTO v_reservation
  FROM public.reservations
  WHERE id = NEW.reservation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reservation not found for reservation_night %', NEW.reservation_id;
  END IF;

  -- Only enforce against active reservations.
  IF v_reservation.status <> 'active' THEN
    RETURN NEW;
  END IF;

  IF NEW.room_id IS NOT NULL THEN
    SELECT id, room_number, room_type_id, is_sellable, is_dayuse
    INTO v_room
    FROM public.rooms
    WHERE id = NEW.room_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Room not found';
    END IF;

    v_effective_room_type_id := COALESCE(NEW.room_type_id, v_room.room_type_id);
    NEW.room_type_id := v_effective_room_type_id;

    IF v_reservation.is_dayuse THEN
      IF COALESCE(v_room.is_dayuse, false) = false THEN
        RAISE EXCEPTION 'Day-use reservation must use a day-use room.';
      END IF;
      RETURN NEW;
    END IF;

    IF COALESCE(v_room.is_dayuse, false) = true THEN
      RAISE EXCEPTION 'Cannot assign overnight reservation to day-use room %', v_room.room_number;
    END IF;

    IF COALESCE(v_room.is_sellable, false) = false THEN
      RAISE EXCEPTION 'Room % is not sellable', v_room.room_number;
    END IF;
  ELSE
    -- Floating reservation night: require room_type_id and enforce capacity.
    v_effective_room_type_id := NEW.room_type_id;
    IF v_effective_room_type_id IS NULL THEN
      RAISE EXCEPTION 'room_type_id is required for floating reservation night';
    END IF;

    IF v_reservation.is_dayuse THEN
      RAISE EXCEPTION 'Day-use reservation night must reference a room_id.';
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_capacity
  FROM public.rooms r
  WHERE r.room_type_id = v_effective_room_type_id
    AND r.is_sellable = true
    AND COALESCE(r.is_dayuse, false) = false
    AND NOT EXISTS (
      SELECT 1
      FROM public.room_blocks rb
      WHERE rb.room_id = r.id
        AND rb.block_type = 'OOO'
        AND rb.start_date <= NEW.stay_date
        AND rb.end_date > NEW.stay_date
    );

  IF v_capacity <= 0 THEN
    RAISE EXCEPTION 'No availability: all 0 rooms of this type are fully booked on %', NEW.stay_date;
  END IF;

  SELECT COUNT(DISTINCT rn.reservation_id) INTO v_occupied
  FROM public.reservation_nights rn
  JOIN public.reservations rs
    ON rs.id = rn.reservation_id
  LEFT JOIN public.rooms rr
    ON rr.id = rn.room_id
  WHERE rn.cancelled_at IS NULL
    AND rn.stay_date = NEW.stay_date
    AND rn.reservation_id <> NEW.reservation_id
    AND rs.status = 'active'
    AND COALESCE(rs.is_dayuse, false) = false
    AND (
      rn.room_type_id = v_effective_room_type_id
      OR (
        rr.room_type_id = v_effective_room_type_id
        AND COALESCE(rr.is_dayuse, false) = false
      )
    );

  IF v_occupied >= v_capacity THEN
    RAISE EXCEPTION 'No availability: all % rooms of this type are fully booked on %', v_capacity, NEW.stay_date;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_reservation_night_capacity ON public.reservation_nights;
CREATE TRIGGER trg_enforce_reservation_night_capacity
BEFORE INSERT OR UPDATE OF reservation_id, room_id, room_type_id, stay_date, cancelled_at
ON public.reservation_nights
FOR EACH ROW
EXECUTE FUNCTION public.enforce_reservation_night_capacity();

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260316_hk_task_seq.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- HK Task Seq: Allow multiple HK tasks per room per day
-- Scenario: room cleaned (C/O), new guest checks in, problem occurs,
--           guest moves to another room → old room becomes dirty again.
--           Both the completed task AND the new dirty task must be preserved.
--
-- Solution: add task_seq SMALLINT (default 1) to unique key.
-- Existing rows stay as seq=1. New tasks after a completed seq=1 get seq=2, etc.

ALTER TABLE public.housekeeping_tasks
  ADD COLUMN IF NOT EXISTS task_seq SMALLINT NOT NULL DEFAULT 1;

-- Drop old unique index
DROP INDEX IF EXISTS uq_housekeeping_tasks_room_day;

-- New composite unique index
CREATE UNIQUE INDEX IF NOT EXISTS uq_housekeeping_tasks_room_day_seq
  ON public.housekeeping_tasks (room_id, stay_date, task_seq);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260328_phase50_group_ocr.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 50: Group OCR via Mobile
-- Lead lock:
-- - passport_scans links to booking_groups + guest_profiles
-- - pool_status lifecycle: ready | ocr_failed | assigned (or NULL for non-group scans)

alter table public.passport_scans
  add column if not exists booking_group_id uuid
    references public.booking_groups(id) on delete set null;

create index if not exists idx_passport_scans_group
  on public.passport_scans (booking_group_id)
  where booking_group_id is not null;

alter table public.passport_scans
  add column if not exists guest_profile_id uuid
    references public.guest_profiles(id) on delete set null;

create index if not exists idx_passport_scans_guest_profile
  on public.passport_scans (guest_profile_id)
  where guest_profile_id is not null;

alter table public.passport_scans
  add column if not exists pool_status text default null;

-- Backward compatibility if a previous draft used ready_low_confidence
update public.passport_scans
set pool_status = 'ready'
where pool_status = 'ready_low_confidence';

alter table public.passport_scans
  drop constraint if exists chk_pool_status;

alter table public.passport_scans
  add constraint chk_pool_status
  check (
    pool_status is null
    or pool_status in ('ready', 'ocr_failed', 'assigned')
  );

create index if not exists idx_passport_scans_group_pool_created
  on public.passport_scans (booking_group_id, pool_status, created_at desc)
  where booking_group_id is not null;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260329_phase51_guest_migration.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 51: Guest Profile Migration

-- 1) Add legacy_night_count to guest_profiles
ALTER TABLE public.guest_profiles
  ADD COLUMN IF NOT EXISTS legacy_night_count integer DEFAULT NULL;

-- 2) Legacy stays (historical only, read-only context data)
CREATE TABLE IF NOT EXISTS public.legacy_stays (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guest_profile_id uuid NOT NULL REFERENCES public.guest_profiles(id) ON DELETE CASCADE,
  date_in          date NOT NULL,
  date_out         date NOT NULL,
  nights           integer NOT NULL DEFAULT 1,
  room_number      text,
  source_file      text,
  notes            text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_legacy_stays_guest
  ON public.legacy_stays(guest_profile_id);

CREATE INDEX IF NOT EXISTS idx_legacy_stays_date
  ON public.legacy_stays(date_in DESC);

ALTER TABLE public.legacy_stays ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS legacy_stays_service_role ON public.legacy_stays;
CREATE POLICY legacy_stays_service_role
  ON public.legacy_stays
  FOR ALL
  USING (true)
  WITH CHECK (true);




-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240001_deposit_tracking.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Migration: Deposit Tracking
-- Date:      2026-02-24
-- Purpose:
--   Add deposit fields to reservations table:
--     deposit_amount  — amount requested at booking time
--     deposit_paid_at — when it was collected
--     deposit_note    — payment method or reference
-- ============================================================

alter table public.reservations
  add column if not exists deposit_amount  numeric(10, 2) not null default 0,
  add column if not exists deposit_paid_at timestamptz,
  add column if not exists deposit_note    text;

-- Optional: partial index to quickly find unpaid deposits
create index if not exists idx_reservations_unpaid_deposit
  on public.reservations (checkin_date)
  where deposit_amount > 0 and deposit_paid_at is null;

-- ============================================================
-- VERIFY:
--   SELECT id, booking_code, guest_name, deposit_amount,
--          deposit_paid_at, deposit_note
--   FROM public.reservations
--   ORDER BY created_at DESC LIMIT 5;
-- ============================================================



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240002_eod_system.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Migration: Hotel Settings & Daily Snapshots (EOD System)
-- Date:      2026-02-24
-- ============================================================

-- Part 1: Extend hotel_settings with EOD fields
-- (Assumes hotel_settings table already exists from init migration)
create table if not exists public.hotel_settings (
  id                  int primary key default 1,              -- singleton row
  hotel_name          text not null default 'My Hotel',
  hotel_timezone      text not null default 'Asia/Bangkok',
  sellable_rooms      int  not null default 0,
  business_date       date not null default current_date,
  eod_reminder_time   time not null default '02:00',
  check_in_time       time not null default '14:00',
  check_out_time      time not null default '12:00',
  late_checkout_fee   numeric(10,2) not null default 0,
  updated_at          timestamptz not null default timezone('utc', now()),
  constraint hotel_settings_singleton check (id = 1)
);

-- Ensure exactly 1 row exists
insert into public.hotel_settings (id) values (1)
on conflict (id) do nothing;

-- Add columns if table already had rows
alter table public.hotel_settings
  add column if not exists business_date       date not null default current_date,
  add column if not exists eod_reminder_time   time not null default '02:00',
  add column if not exists hotel_name          text,
  add column if not exists hotel_timezone      text not null default 'Asia/Bangkok',
  add column if not exists sellable_rooms      int  not null default 0,
  add column if not exists check_in_time       time not null default '14:00',
  add column if not exists check_out_time      time not null default '12:00',
  add column if not exists late_checkout_fee   numeric(10,2) not null default 0;

-- Part 2: Daily Snapshots  
create table if not exists public.daily_snapshots (
  id               uuid primary key default gen_random_uuid(),
  business_date    date unique not null,
  -- Revenue (accrual basis from reservation_nights.stay_date)
  total_revenue    numeric(12, 2) not null default 0,
  occupied_nights  int           not null default 0,
  room_nights      int           not null default 0,
  occupancy_pct    numeric(5, 2) not null default 0,
  adr              numeric(10, 2) not null default 0,
  revpar           numeric(10, 2) not null default 0,
  by_source        jsonb         not null default '{}',
  -- Payments (cash basis from folio_payments.paid_date)
  payment_cash     numeric(12, 2) not null default 0,
  payment_transfer numeric(12, 2) not null default 0,
  payment_card     numeric(12, 2) not null default 0,
  payment_other    numeric(12, 2) not null default 0,
  payment_total    numeric(12, 2) not null default 0,
  -- Metadata
  eod_run_at       timestamptz not null default timezone('utc', now()),
  eod_run_by       uuid references public.profiles(user_id),
  notes            text
);

create index if not exists idx_daily_snapshots_date
  on public.daily_snapshots (business_date desc);

-- ============================================================
-- VERIFY:
--   SELECT * FROM public.hotel_settings;
--   SELECT * FROM public.daily_snapshots ORDER BY business_date DESC LIMIT 5;
-- ============================================================



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240003_floating_bookings.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Recreate booking_create_reservation to support floating assignments
create or replace function public.booking_create_reservation(
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text default null,
  p_room_type_id bigint default null,
  p_source public.booking_source default 'walkin',
  p_phone text default null,
  p_checkin_time text default null,
  p_note text default null,
  p_ota_prices numeric[] default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_reservation_id uuid;
  v_booking_code text;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
begin
  if p_guest_name is null or btrim(p_guest_name) = '' then
    raise exception 'guest_name is required';
  end if;

  if (p_room_number is null or btrim(p_room_number) = '') and p_room_type_id is null then
    raise exception 'Either room_number or room_type_id is required';
  end if;

  if p_checkout_date <= p_checkin_date then
    raise exception 'checkout_date must be after checkin_date';
  end if;

  -- 1. Resolve Room & Room Type
  if p_room_number is not null and btrim(p_room_number) <> '' then
    select * into v_room
    from public.rooms
    where room_number = btrim(p_room_number)
    for update;

    if not found then
      raise exception 'Room not found: %', p_room_number;
    end if;

    if not v_room.is_sellable then
      raise exception 'Room % is not sellable', v_room.room_number;
    end if;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  else
    v_room_id := null;
    v_effective_room_type_id := p_room_type_id;
    
    -- Pick any room of this type to use for pricing templates
    select id into v_pricing_room_id
    from public.rooms
    where room_type_id = p_room_type_id
    limit 1;
    
    if v_pricing_room_id is null then
      raise exception 'No rooms found for room_type_id: %', p_room_type_id;
    end if;
  end if;

  -- 2. Generate Dates
  select coalesce(array_agg(day::date order by day::date), array[]::date[])
  into v_night_dates
  from generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - interval '1 day')::timestamp,
    interval '1 day'
  ) as day;

  v_nights_count := cardinality(v_night_dates);
  if v_nights_count = 0 then
    raise exception 'No nights generated for selected date range';
  end if;

  -- 3. Check Conflicts (Only if assigning a specific room immediately)
  if v_room_id is not null then
    select rn.stay_date
    into v_conflict_date
    from public.reservation_nights rn
    where rn.room_id = v_room_id
      and rn.cancelled_at is null
      and rn.stay_date = any(v_night_dates)
    limit 1;

    if v_conflict_date is not null then
      raise exception 'Room % already booked on %', v_room.room_number, v_conflict_date;
    end if;
  end if;

  -- 4. Calculate Prices
  if p_source = 'ota' then
    if p_ota_prices is null or cardinality(p_ota_prices) <> v_nights_count then
      raise exception 'OTA bookings require ota_prices length = %', v_nights_count;
    end if;

    select coalesce(array_agg(round(coalesce(ota.price, 0)::numeric, 2) order by ota.idx), array[]::numeric[])
    into v_prices
    from unnest(p_ota_prices) with ordinality as ota(price, idx);
  else
    select coalesce(array_agg(coalesce(rt.price, 0)::numeric(10, 2) order by d.stay_date), array[]::numeric[])
    into v_prices
    from unnest(v_night_dates) as d(stay_date)
    left join public.rate_templates rt
      on rt.room_id = v_pricing_room_id
     and rt.stay_date = d.stay_date;
  end if;

  select round(coalesce(sum(coalesce(price, 0)), 0)::numeric, 2)
  into v_total_price
  from unnest(v_prices) as p(price);

  -- 5. Insert Reservation
  v_booking_code := public.generate_booking_code();
  v_normalized_phone := nullif(btrim(coalesce(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(coalesce(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(coalesce(p_note, '')), '');

  insert into public.reservations (
    booking_code,
    guest_name,
    phone,
    source,
    status,
    checkin_date,
    checkout_date,
    checkin_time,
    note,
    total_price,
    created_by,
    updated_by,
    room_number
  )
  values (
    v_booking_code,
    btrim(p_guest_name),
    v_normalized_phone,
    p_source,
    'active',
    p_checkin_date,
    p_checkout_date,
    v_normalized_checkin_time,
    v_normalized_note,
    v_total_price,
    p_actor_user_id,
    p_actor_user_id,
    nullif(btrim(p_room_number), '')
  )
  returning id into v_reservation_id;

  -- 6. Insert Reservation Nights
  insert into public.reservation_nights (
    reservation_id,
    room_id,
    room_type_id,
    stay_date,
    nightly_price,
    is_ota
  )
  select
    v_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(coalesce(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  from unnest(v_night_dates) with ordinality as d(stay_date, idx)
  join unnest(v_prices) with ordinality as pr(price, idx)
    on pr.idx = d.idx;

  -- 7. Audit Log
  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    p_actor_user_id,
    'booking_created',
    'reservation',
    v_reservation_id::text,
    jsonb_build_object(
      'booking_code', v_booking_code,
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price
    )
  );

  return jsonb_build_object(
    'id', v_reservation_id,
    'booking_code', v_booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
end;
$$;


-- Recreate booking_update_reservation to support floating assignments
create or replace function public.booking_update_reservation(
  p_reservation_id uuid,
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text default null,
  p_room_type_id bigint default null,
  p_source public.booking_source default 'walkin',
  p_phone text default null,
  p_checkin_time text default null,
  p_note text default null,
  p_ota_prices numeric[] default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_replaced_nights int;
  v_cancelled_at timestamptz;
  v_before jsonb;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
begin
  if p_guest_name is null or btrim(p_guest_name) = '' then
    raise exception 'guest_name is required';
  end if;

  if (p_room_number is null or btrim(p_room_number) = '') and p_room_type_id is null then
    raise exception 'Either room_number or room_type_id is required';
  end if;

  if p_checkout_date <= p_checkin_date then
    raise exception 'checkout_date must be after checkin_date';
  end if;

  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'active' then
    raise exception 'Reservation is not active';
  end if;

  -- 1. Resolve Room & Room Type
  if p_room_number is not null and btrim(p_room_number) <> '' then
    select * into v_room
    from public.rooms
    where room_number = btrim(p_room_number)
    for update;

    if not found then
      raise exception 'Room not found: %', p_room_number;
    end if;

    if not v_room.is_sellable then
      raise exception 'Room % is not sellable', v_room.room_number;
    end if;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  else
    v_room_id := null;
    v_effective_room_type_id := p_room_type_id;
    
    select id into v_pricing_room_id
    from public.rooms
    where room_type_id = p_room_type_id
    limit 1;
    
    if v_pricing_room_id is null then
      raise exception 'No rooms found for room_type_id: %', p_room_type_id;
    end if;
  end if;

  -- 2. Generate Dates
  select coalesce(array_agg(day::date order by day::date), array[]::date[])
  into v_night_dates
  from generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - interval '1 day')::timestamp,
    interval '1 day'
  ) as day;

  v_nights_count := cardinality(v_night_dates);
  if v_nights_count = 0 then
    raise exception 'No nights generated for selected date range';
  end if;

  -- 3. Check Conflicts (Only if assigning specific room)
  if v_room_id is not null then
    select rn.stay_date
    into v_conflict_date
    from public.reservation_nights rn
    where rn.room_id = v_room_id
      and rn.cancelled_at is null
      and rn.stay_date = any(v_night_dates)
      and rn.reservation_id <> p_reservation_id
    limit 1;

    if v_conflict_date is not null then
      raise exception 'Room % already booked on %', v_room.room_number, v_conflict_date;
    end if;
  end if;

  -- 4. Calculate Prices
  if p_source = 'ota' then
    if p_ota_prices is null or cardinality(p_ota_prices) <> v_nights_count then
      raise exception 'OTA bookings require ota_prices length = %', v_nights_count;
    end if;

    select coalesce(array_agg(round(coalesce(ota.price, 0)::numeric, 2) order by ota.idx), array[]::numeric[])
    into v_prices
    from unnest(p_ota_prices) with ordinality as ota(price, idx);
  else
    select coalesce(array_agg(coalesce(rt.price, 0)::numeric(10, 2) order by d.stay_date), array[]::numeric[])
    into v_prices
    from unnest(v_night_dates) as d(stay_date)
    left join public.rate_templates rt
      on rt.room_id = v_pricing_room_id
     and rt.stay_date = d.stay_date;
  end if;

  select round(coalesce(sum(coalesce(price, 0)), 0)::numeric, 2)
  into v_total_price
  from unnest(v_prices) as p(price);

  v_before := jsonb_build_object(
    'guest_name', v_reservation.guest_name,
    'source', v_reservation.source,
    'checkin_date', v_reservation.checkin_date,
    'checkout_date', v_reservation.checkout_date,
    'total_price', v_reservation.total_price
  );

  -- 5. Cancel old nights
  v_cancelled_at := timezone('utc', now());
  update public.reservation_nights
  set cancelled_at = v_cancelled_at
  where reservation_id = p_reservation_id
    and cancelled_at is null;
  get diagnostics v_replaced_nights = row_count;

  -- 6. Update Reservation
  v_normalized_phone := nullif(btrim(coalesce(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(coalesce(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(coalesce(p_note, '')), '');

  update public.reservations
  set
    guest_name = btrim(p_guest_name),
    phone = v_normalized_phone,
    source = p_source,
    checkin_date = p_checkin_date,
    checkout_date = p_checkout_date,
    checkin_time = v_normalized_checkin_time,
    note = v_normalized_note,
    total_price = v_total_price,
    room_number = nullif(btrim(p_room_number), ''),
    updated_by = coalesce(p_actor_user_id, updated_by)
  where id = p_reservation_id;

  -- 7. Insert New Nights
  insert into public.reservation_nights (
    reservation_id,
    room_id,
    room_type_id,
    stay_date,
    nightly_price,
    is_ota
  )
  select
    p_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(coalesce(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  from unnest(v_night_dates) with ordinality as d(stay_date, idx)
  join unnest(v_prices) with ordinality as pr(price, idx)
    on pr.idx = d.idx;

  -- 8. Audit Log
  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  values (
    p_actor_user_id,
    'booking_updated',
    'reservation',
    p_reservation_id::text,
    v_before,
    jsonb_build_object(
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'source', p_source,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price,
      'replaced_nights', v_replaced_nights
    )
  );

  return jsonb_build_object(
    'id', p_reservation_id,
    'booking_code', v_reservation.booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
end;
$$;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240004_floating_bookings_fix.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Recreate booking_create_reservation to fix column error
create or replace function public.booking_create_reservation(
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text default null,
  p_room_type_id bigint default null,
  p_source public.booking_source default 'walkin',
  p_phone text default null,
  p_checkin_time text default null,
  p_note text default null,
  p_ota_prices numeric[] default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_reservation_id uuid;
  v_booking_code text;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
begin
  if p_guest_name is null or btrim(p_guest_name) = '' then
    raise exception 'guest_name is required';
  end if;

  if (p_room_number is null or btrim(p_room_number) = '') and p_room_type_id is null then
    raise exception 'Either room_number or room_type_id is required';
  end if;

  if p_checkout_date <= p_checkin_date then
    raise exception 'checkout_date must be after checkin_date';
  end if;

  -- 1. Resolve Room & Room Type
  if p_room_number is not null and btrim(p_room_number) <> '' then
    select * into v_room
    from public.rooms
    where room_number = btrim(p_room_number)
    for update;

    if not found then
      raise exception 'Room not found: %', p_room_number;
    end if;

    if not v_room.is_sellable then
      raise exception 'Room % is not sellable', v_room.room_number;
    end if;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  else
    v_room_id := null;
    v_effective_room_type_id := p_room_type_id;
    
    -- Pick any room of this type to use for pricing templates
    select id into v_pricing_room_id
    from public.rooms
    where room_type_id = p_room_type_id
    limit 1;
    
    if v_pricing_room_id is null then
      raise exception 'No rooms found for room_type_id: %', p_room_type_id;
    end if;
  end if;

  -- 2. Generate Dates
  select coalesce(array_agg(day::date order by day::date), array[]::date[])
  into v_night_dates
  from generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - interval '1 day')::timestamp,
    interval '1 day'
  ) as day;

  v_nights_count := cardinality(v_night_dates);
  if v_nights_count = 0 then
    raise exception 'No nights generated for selected date range';
  end if;

  -- 3. Check Conflicts (Only if assigning a specific room immediately)
  if v_room_id is not null then
    select rn.stay_date
    into v_conflict_date
    from public.reservation_nights rn
    where rn.room_id = v_room_id
      and rn.cancelled_at is null
      and rn.stay_date = any(v_night_dates)
    limit 1;

    if v_conflict_date is not null then
      raise exception 'Room % already booked on %', v_room.room_number, v_conflict_date;
    end if;
  end if;

  -- 4. Calculate Prices
  if p_source = 'ota' then
    if p_ota_prices is null or cardinality(p_ota_prices) <> v_nights_count then
      raise exception 'OTA bookings require ota_prices length = %', v_nights_count;
    end if;

    select coalesce(array_agg(round(coalesce(ota.price, 0)::numeric, 2) order by ota.idx), array[]::numeric[])
    into v_prices
    from unnest(p_ota_prices) with ordinality as ota(price, idx);
  else
    select coalesce(array_agg(coalesce(rt.price, 0)::numeric(10, 2) order by d.stay_date), array[]::numeric[])
    into v_prices
    from unnest(v_night_dates) as d(stay_date)
    left join public.rate_templates rt
      on rt.room_id = v_pricing_room_id
     and rt.stay_date = d.stay_date;
  end if;

  select round(coalesce(sum(coalesce(price, 0)), 0)::numeric, 2)
  into v_total_price
  from unnest(v_prices) as p(price);

  -- 5. Insert Reservation
  v_booking_code := public.generate_booking_code();
  v_normalized_phone := nullif(btrim(coalesce(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(coalesce(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(coalesce(p_note, '')), '');

  insert into public.reservations (
    booking_code,
    guest_name,
    phone,
    source,
    status,
    checkin_date,
    checkout_date,
    checkin_time,
    note,
    total_price,
    created_by,
    updated_by
  )
  values (
    v_booking_code,
    btrim(p_guest_name),
    v_normalized_phone,
    p_source,
    'active',
    p_checkin_date,
    p_checkout_date,
    v_normalized_checkin_time,
    v_normalized_note,
    v_total_price,
    p_actor_user_id,
    p_actor_user_id
  )
  returning id into v_reservation_id;

  -- 6. Insert Reservation Nights
  insert into public.reservation_nights (
    reservation_id,
    room_id,
    room_type_id,
    stay_date,
    nightly_price,
    is_ota
  )
  select
    v_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(coalesce(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  from unnest(v_night_dates) with ordinality as d(stay_date, idx)
  join unnest(v_prices) with ordinality as pr(price, idx)
    on pr.idx = d.idx;

  -- 7. Audit Log
  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    p_actor_user_id,
    'booking_created',
    'reservation',
    v_reservation_id::text,
    jsonb_build_object(
      'booking_code', v_booking_code,
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price
    )
  );

  return jsonb_build_object(
    'id', v_reservation_id,
    'booking_code', v_booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
end;
$$;


-- Recreate booking_update_reservation to fix column error
create or replace function public.booking_update_reservation(
  p_reservation_id uuid,
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text default null,
  p_room_type_id bigint default null,
  p_source public.booking_source default 'walkin',
  p_phone text default null,
  p_checkin_time text default null,
  p_note text default null,
  p_ota_prices numeric[] default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_replaced_nights int;
  v_cancelled_at timestamptz;
  v_before jsonb;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
begin
  if p_guest_name is null or btrim(p_guest_name) = '' then
    raise exception 'guest_name is required';
  end if;

  if (p_room_number is null or btrim(p_room_number) = '') and p_room_type_id is null then
    raise exception 'Either room_number or room_type_id is required';
  end if;

  if p_checkout_date <= p_checkin_date then
    raise exception 'checkout_date must be after checkin_date';
  end if;

  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'active' then
    raise exception 'Reservation is not active';
  end if;

  -- 1. Resolve Room & Room Type
  if p_room_number is not null and btrim(p_room_number) <> '' then
    select * into v_room
    from public.rooms
    where room_number = btrim(p_room_number)
    for update;

    if not found then
      raise exception 'Room not found: %', p_room_number;
    end if;

    if not v_room.is_sellable then
      raise exception 'Room % is not sellable', v_room.room_number;
    end if;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  else
    v_room_id := null;
    v_effective_room_type_id := p_room_type_id;
    
    select id into v_pricing_room_id
    from public.rooms
    where room_type_id = p_room_type_id
    limit 1;
    
    if v_pricing_room_id is null then
      raise exception 'No rooms found for room_type_id: %', p_room_type_id;
    end if;
  end if;

  -- 2. Generate Dates
  select coalesce(array_agg(day::date order by day::date), array[]::date[])
  into v_night_dates
  from generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - interval '1 day')::timestamp,
    interval '1 day'
  ) as day;

  v_nights_count := cardinality(v_night_dates);
  if v_nights_count = 0 then
    raise exception 'No nights generated for selected date range';
  end if;

  -- 3. Check Conflicts (Only if assigning specific room)
  if v_room_id is not null then
    select rn.stay_date
    into v_conflict_date
    from public.reservation_nights rn
    where rn.room_id = v_room_id
      and rn.cancelled_at is null
      and rn.stay_date = any(v_night_dates)
      and rn.reservation_id <> p_reservation_id
    limit 1;

    if v_conflict_date is not null then
      raise exception 'Room % already booked on %', v_room.room_number, v_conflict_date;
    end if;
  end if;

  -- 4. Calculate Prices
  if p_source = 'ota' then
    if p_ota_prices is null or cardinality(p_ota_prices) <> v_nights_count then
      raise exception 'OTA bookings require ota_prices length = %', v_nights_count;
    end if;

    select coalesce(array_agg(round(coalesce(ota.price, 0)::numeric, 2) order by ota.idx), array[]::numeric[])
    into v_prices
    from unnest(p_ota_prices) with ordinality as ota(price, idx);
  else
    select coalesce(array_agg(coalesce(rt.price, 0)::numeric(10, 2) order by d.stay_date), array[]::numeric[])
    into v_prices
    from unnest(v_night_dates) as d(stay_date)
    left join public.rate_templates rt
      on rt.room_id = v_pricing_room_id
     and rt.stay_date = d.stay_date;
  end if;

  select round(coalesce(sum(coalesce(price, 0)), 0)::numeric, 2)
  into v_total_price
  from unnest(v_prices) as p(price);

  v_before := jsonb_build_object(
    'guest_name', v_reservation.guest_name,
    'source', v_reservation.source,
    'checkin_date', v_reservation.checkin_date,
    'checkout_date', v_reservation.checkout_date,
    'total_price', v_reservation.total_price
  );

  -- 5. Cancel old nights
  v_cancelled_at := timezone('utc', now());
  update public.reservation_nights
  set cancelled_at = v_cancelled_at
  where reservation_id = p_reservation_id
    and cancelled_at is null;
  get diagnostics v_replaced_nights = row_count;

  -- 6. Update Reservation
  v_normalized_phone := nullif(btrim(coalesce(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(coalesce(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(coalesce(p_note, '')), '');

  update public.reservations
  set
    guest_name = btrim(p_guest_name),
    phone = v_normalized_phone,
    source = p_source,
    checkin_date = p_checkin_date,
    checkout_date = p_checkout_date,
    checkin_time = v_normalized_checkin_time,
    note = v_normalized_note,
    total_price = v_total_price,
    updated_by = coalesce(p_actor_user_id, updated_by)
  where id = p_reservation_id;

  -- 7. Insert New Nights
  insert into public.reservation_nights (
    reservation_id,
    room_id,
    room_type_id,
    stay_date,
    nightly_price,
    is_ota
  )
  select
    p_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(coalesce(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  from unnest(v_night_dates) with ordinality as d(stay_date, idx)
  join unnest(v_prices) with ordinality as pr(price, idx)
    on pr.idx = d.idx;

  -- 8. Audit Log
  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  values (
    p_actor_user_id,
    'booking_updated',
    'reservation',
    p_reservation_id::text,
    v_before,
    jsonb_build_object(
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'source', p_source,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price,
      'replaced_nights', v_replaced_nights
    )
  );

  return jsonb_build_object(
    'id', p_reservation_id,
    'booking_code', v_reservation.booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
end;
$$;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240005_folio_payments.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Migration: Folio Payments
-- Date:      2026-02-24
-- Purpose:
--   Track actual money received (or refunded) per reservation.
--   Each row = 1 payment transaction.
--   Separate from Revenue (which is accrual/stay_date based).
-- ============================================================

-- PostgreSQL does not support CREATE TYPE IF NOT EXISTS
-- Use DO block to safely create enums only if they don't exist
DO $$ BEGIN
    CREATE TYPE public.payment_method_type AS ENUM (
        'cash', 'transfer', 'credit_card', 'other'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE public.payment_tx_type AS ENUM (
        'payment',
        'refund',
        'deposit'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


create table if not exists public.folio_payments (
  id              uuid primary key default gen_random_uuid(),
  reservation_id  uuid not null references public.reservations(id) on delete cascade,
  tx_type         public.payment_tx_type not null default 'payment',
  method          public.payment_method_type not null default 'cash',
  amount          numeric(10, 2) not null,         -- always positive; tx_type determines direction
  note            text,                             -- e.g. "Transfer ref 001", "Deposit refund"
  paid_at         timestamptz not null default timezone('utc', now()),
  paid_date       date not null,                   -- LOCAL date (for daily summary, set by server)
  recorded_by     uuid references public.profiles(user_id),
  created_at      timestamptz not null default timezone('utc', now())
);

create index if not exists idx_folio_payments_reservation
  on public.folio_payments (reservation_id);

create index if not exists idx_folio_payments_paid_date
  on public.folio_payments (paid_date);

-- ============================================================
-- VERIFY:
--   SELECT fp.paid_date, fp.method, fp.tx_type,
--          SUM(fp.amount) as total
--   FROM public.folio_payments fp
--   GROUP BY fp.paid_date, fp.method, fp.tx_type
--   ORDER BY fp.paid_date DESC;
-- ============================================================



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240006_ota_ref.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Migration: OTA Reference Number
-- Date:      2026-02-24
-- Purpose:
--   Add ota_ref to reservations — stores the OTA confirmation
--   code (e.g. Booking.com "1234567890") for reconciliation.
-- ============================================================

alter table public.reservations
  add column if not exists ota_ref text;

-- Index for quick lookup by OTA reference number
create index if not exists idx_reservations_ota_ref
  on public.reservations (ota_ref)
  where ota_ref is not null;

-- ============================================================
-- VERIFY:
--   SELECT id, booking_code, source, ota_ref
--   FROM public.reservations
--   WHERE source = 'ota'
--   ORDER BY created_at DESC LIMIT 5;
-- ============================================================



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240007_rate_change_log.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Migration: Rate Change Log + Auto-Prune
-- Date:      2026-02-24
-- Purpose:
--   1. Create rate_change_log table (audit trail)
--   2. Create trigger: log every INSERT/UPDATE on rate_templates
--   3. Schedule nightly Cron job to prune rate_templates > 30 days old
-- ============================================================

-- ─── PRE-REQUISITE ──────────────────────────────────────────
-- Before running this migration, enable pg_cron in:
--   Supabase Dashboard → Database → Extensions → pg_cron → Enable
-- If pg_cron is NOT enabled, skip section 3 below.
-- ─────────────────────────────────────────────────────────────


-- ─── 1. RATE CHANGE LOG TABLE ────────────────────────────────
create table if not exists public.rate_change_log (
  id            uuid primary key default gen_random_uuid(),
  room_id       uuid not null references public.rooms(id) on delete cascade,
  stay_date     date not null,
  old_price     numeric(10, 2),           -- null on first INSERT
  new_price     numeric(10, 2) not null,
  changed_by    uuid references public.profiles(user_id),
  operation     text not null check (operation in ('INSERT', 'UPDATE')),
  changed_at    timestamptz not null default timezone('utc', now())
);

-- Index for quick lookup: "what changed for room X on date Y?"
create index if not exists rate_change_log_room_date
  on public.rate_change_log (room_id, stay_date, changed_at desc);

-- Index for timeline view: "show me all changes in last 7 days"
create index if not exists rate_change_log_changed_at
  on public.rate_change_log (changed_at desc);

-- ─── 2. TRIGGER FUNCTION ─────────────────────────────────────
-- Fires AFTER INSERT OR UPDATE on rate_templates
-- Records old price (null on first insert) and new price

create or replace function public.fn_log_rate_change()
returns trigger
language plpgsql
security definer
as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.rate_change_log (
      room_id, stay_date, old_price, new_price, changed_by, operation
    ) values (
      NEW.room_id,
      NEW.stay_date,
      null,           -- no old price on first insert
      NEW.price,
      NEW.updated_by,
      'INSERT'
    );
  elsif TG_OP = 'UPDATE' then
    -- Only log if price actually changed
    if OLD.price is distinct from NEW.price then
      insert into public.rate_change_log (
        room_id, stay_date, old_price, new_price, changed_by, operation
      ) values (
        NEW.room_id,
        NEW.stay_date,
        OLD.price,
        NEW.price,
        NEW.updated_by,
        'UPDATE'
      );
    end if;
  end if;
  return NEW;
end;
$$;

-- Attach trigger to rate_templates
drop trigger if exists trg_rate_change_log on public.rate_templates;
create trigger trg_rate_change_log
  after insert or update
  on public.rate_templates
  for each row
  execute function public.fn_log_rate_change();


-- ─── 3. RLS POLICIES ─────────────────────────────────────────
alter table public.rate_change_log enable row level security;

-- Authenticated users can read the log
create policy "rate_change_log: auth read"
  on public.rate_change_log
  for select
  to authenticated
  using (true);

-- No direct insert/update/delete from client — only via trigger
create policy "rate_change_log: deny direct write"
  on public.rate_change_log
  for insert
  to authenticated
  with check (false);


-- ─── 4. CRON JOB — PRUNE OLD RATE TEMPLATES ──────────────────
-- ⚠️  REQUIRES pg_cron extension to be ENABLED first!
--     Supabase Dashboard → Database → Extensions → pg_cron
--
-- Runs every night at 03:00 UTC (10:00 Thailand time)
-- Deletes rate_templates rows where stay_date < 30 days ago
-- rate_change_log is NOT deleted — it is the permanent audit trail
--
-- Uncomment the lines below after enabling pg_cron:

-- select cron.schedule(
--   'rate-prune-old',                       -- job name (unique)
--   '0 3 * * *',                            -- every day at 03:00 UTC
--   $$
--     delete from public.rate_templates
--     where stay_date < current_date - interval '30 days';
--   $$
-- );


-- ─── VERIFY ───────────────────────────────────────────────────
-- After running, test with:
--
-- 1. Check table exists:
--    SELECT * FROM public.rate_change_log LIMIT 5;
--
-- 2. Manually trigger a rate update via the app's Bulk Update
--    then check:
--    SELECT * FROM public.rate_change_log ORDER BY changed_at DESC LIMIT 10;
--
-- 3. (After enabling pg_cron) list scheduled jobs:
--    SELECT * FROM cron.job;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240008_room_assignment.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Migration: Room Assignment, Room Features, and Room Blocks
-- Created: 2026-02-24
-- =============================================================

-- ── 1. Enums ──────────────────────────────────────────────────

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'room_block_type') THEN
    CREATE TYPE public.room_block_type AS ENUM ('OOO', 'OOS');
  END IF;
END $$;

-- ── 2. Room Features (Characteristics) ────────────────────────

CREATE TABLE IF NOT EXISTS public.room_features (
    code text PRIMARY KEY,        
    name text NOT NULL,
    category text NOT NULL,       -- e.g., 'View', 'Bedding', 'Location', 'Smoking', 'Misc'
    created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.room_features ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role full access" ON public.room_features FOR ALL USING (true);

-- Seed basic features
INSERT INTO public.room_features (code, name, category) VALUES
  ('BALC', 'Balcony', 'View'),
  ('SEA', 'Sea View', 'View'),
  ('POOL', 'Pool Access', 'View'),
  ('HIGH', 'High Floor', 'Location'),
  ('LOW', 'Low Floor', 'Location'),
  ('CORNER', 'Corner Room', 'Location'),
  ('NS', 'Non-Smoking', 'Smoking'),
  ('SMOKE', 'Smoking Allowed', 'Smoking'),
  ('KING', 'King Bed', 'Bedding'),
  ('TWIN', 'Twin Beds', 'Bedding'),
  ('QUIET', 'Quiet Room', 'Location'),
  ('ACC', 'Accessible', 'Misc'),
  ('CONN', 'Connecting Room', 'Misc')
ON CONFLICT (code) DO UPDATE 
  SET name = EXCLUDED.name, category = EXCLUDED.category;

-- ── 3. Map Features to Physical Rooms ─────────────────────────

CREATE TABLE IF NOT EXISTS public.room_feature_mapping (
    room_number text NOT NULL REFERENCES public.rooms(room_number) ON DELETE CASCADE,
    feature_code text NOT NULL REFERENCES public.room_features(code) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (room_number, feature_code)
);

ALTER TABLE public.room_feature_mapping ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role full access" ON public.room_feature_mapping FOR ALL USING (true);

-- ── 4. Guest Preferences for a specific reservation ───────────

CREATE TABLE IF NOT EXISTS public.reservation_preferences (
    reservation_id uuid NOT NULL REFERENCES public.reservations(id) ON DELETE CASCADE,
    feature_code text NOT NULL REFERENCES public.room_features(code) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (reservation_id, feature_code)
);

ALTER TABLE public.reservation_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role full access" ON public.reservation_preferences FOR ALL USING (true);

-- ── 5. Room Blocks (Out of Order / Out of Service) ────────────

CREATE TABLE IF NOT EXISTS public.room_blocks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    room_number text REFERENCES public.rooms(room_number) ON DELETE CASCADE,
    block_type public.room_block_type NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    reason text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid REFERENCES public.profiles(user_id)
);

CREATE INDEX IF NOT EXISTS idx_room_blocks_dates 
  ON public.room_blocks (start_date, end_date);

ALTER TABLE public.room_blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role full access" ON public.room_blocks FOR ALL USING (true);

-- ── 6. Modify reservation_nights for Floating Assignment ──────

-- Add room_type_id so we know what type they booked, even if room_id is NULL
ALTER TABLE public.reservation_nights
  ADD COLUMN IF NOT EXISTS room_type_id bigint REFERENCES public.room_types(id);

-- Backfill room_type_id from the assigned room
UPDATE public.reservation_nights rn
SET room_type_id = r.room_type_id
FROM public.rooms r
WHERE rn.room_id = r.id AND rn.room_type_id IS NULL;

-- Now make room_id optional (unassigned/floating reservations)
ALTER TABLE public.reservation_nights
  ALTER COLUMN room_id DROP NOT NULL;

-- ── Done ─────────────────────────────────────────────────────



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240009_room_blocks_conflicts.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Migration: Add Room Block conflict checking to Booking RPCs
-- Created: 2026-02-24
-- =============================================================

begin;

-- 1. Update booking_create_reservation to check room_blocks
create or replace function public.booking_create_reservation(
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text default null,
  p_room_type_id bigint default null,
  p_source public.booking_source default 'walkin',
  p_phone text default null,
  p_checkin_time text default null,
  p_note text default null,
  p_ota_prices numeric[] default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_reservation_id uuid;
  v_booking_code text;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_block_reason text;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
begin
  if p_guest_name is null or btrim(p_guest_name) = '' then
    raise exception 'guest_name is required';
  end if;

  if (p_room_number is null or btrim(p_room_number) = '') and p_room_type_id is null then
    raise exception 'Either room_number or room_type_id is required';
  end if;

  if p_checkout_date <= p_checkin_date then
    raise exception 'checkout_date must be after checkin_date';
  end if;

  -- 1. Resolve Room & Room Type
  if p_room_number is not null and btrim(p_room_number) <> '' then
    select * into v_room
    from public.rooms
    where room_number = btrim(p_room_number)
    for update;

    if not found then
      raise exception 'Room not found: %', p_room_number;
    end if;

    if not v_room.is_sellable then
      raise exception 'Room % is not sellable', v_room.room_number;
    end if;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  else
    v_room_id := null;
    v_effective_room_type_id := p_room_type_id;
    
    select id into v_pricing_room_id
    from public.rooms
    where room_type_id = p_room_type_id
    limit 1;
    
    if v_pricing_room_id is null then
      raise exception 'No rooms found for room_type_id: %', p_room_type_id;
    end if;
  end if;

  -- 2. Generate Dates
  select coalesce(array_agg(day::date order by day::date), array[]::date[])
  into v_night_dates
  from generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - interval '1 day')::timestamp,
    interval '1 day'
  ) as day;

  v_nights_count := cardinality(v_night_dates);
  if v_nights_count = 0 then
    raise exception 'No nights generated for selected date range';
  end if;

  -- 3. Check Conflicts (Only if assigning a specific room immediately)
  if v_room_id is not null then
    -- Check other reservations
    select rn.stay_date
    into v_conflict_date
    from public.reservation_nights rn
    where rn.room_id = v_room_id
      and rn.cancelled_at is null
      and rn.stay_date = any(v_night_dates)
    limit 1;

    if v_conflict_date is not null then
      raise exception 'Room % already booked on %', v_room.room_number, v_conflict_date;
    end if;

    -- NEW: Check Room Blocks (OOO only)
    select start_date, reason
    into v_conflict_date, v_block_reason
    from public.room_blocks
    where room_number = v_room.room_number
      and block_type = 'OOO'
      and (
          (start_date <= p_checkin_date and end_date > p_checkin_date) OR
          (start_date < p_checkout_date and end_date >= p_checkout_date) OR
          (start_date >= p_checkin_date and end_date <= p_checkout_date)
      )
    limit 1;

    if v_conflict_date is not null then
      raise exception 'Room % is Out of Order (OOO) during this period. Reason: %', v_room.room_number, v_block_reason;
    end if;
  end if;

  -- 4. Calculate Prices
  if p_source = 'ota' then
    if p_ota_prices is null or cardinality(p_ota_prices) <> v_nights_count then
      raise exception 'OTA bookings require ota_prices length = %', v_nights_count;
    end if;

    select coalesce(array_agg(round(coalesce(ota.price, 0)::numeric, 2) order by ota.idx), array[]::numeric[])
    into v_prices
    from unnest(p_ota_prices) with ordinality as ota(price, idx);
  else
    select coalesce(array_agg(coalesce(rt.price, 0)::numeric(10, 2) order by d.stay_date), array[]::numeric[])
    into v_prices
    from unnest(v_night_dates) as d(stay_date)
    left join public.rate_templates rt
      on rt.room_id = v_pricing_room_id
     and rt.stay_date = d.stay_date;
  end if;

  select round(coalesce(sum(coalesce(price, 0)), 0)::numeric, 2)
  into v_total_price
  from unnest(v_prices) as p(price);

  -- 5. Insert Reservation
  v_booking_code := public.generate_booking_code();
  v_normalized_phone := nullif(btrim(coalesce(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(coalesce(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(coalesce(p_note, '')), '');

  insert into public.reservations (
    booking_code,
    guest_name,
    phone,
    source,
    status,
    checkin_date,
    checkout_date,
    checkin_time,
    note,
    total_price,
    created_by,
    updated_by
  )
  values (
    v_booking_code,
    btrim(p_guest_name),
    v_normalized_phone,
    p_source,
    'active',
    p_checkin_date,
    p_checkout_date,
    v_normalized_checkin_time,
    v_normalized_note,
    v_total_price,
    p_actor_user_id,
    p_actor_user_id
  )
  returning id into v_reservation_id;

  -- 6. Insert Reservation Nights
  insert into public.reservation_nights (
    reservation_id,
    room_id,
    room_type_id,
    stay_date,
    nightly_price,
    is_ota
  )
  select
    v_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(coalesce(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  from unnest(v_night_dates) with ordinality as d(stay_date, idx)
  join unnest(v_prices) with ordinality as pr(price, idx)
    on pr.idx = d.idx;

  -- 7. Audit Log
  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    p_actor_user_id,
    'booking_created',
    'reservation',
    v_reservation_id::text,
    jsonb_build_object(
      'booking_code', v_booking_code,
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price
    )
  );

  return jsonb_build_object(
    'id', v_reservation_id,
    'booking_code', v_booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
end;
$$;


-- 2. Update booking_update_reservation to check room_blocks
create or replace function public.booking_update_reservation(
  p_reservation_id uuid,
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text default null,
  p_room_type_id bigint default null,
  p_source public.booking_source default 'walkin',
  p_phone text default null,
  p_checkin_time text default null,
  p_note text default null,
  p_ota_prices numeric[] default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_block_reason text;
  v_replaced_nights int;
  v_cancelled_at timestamptz;
  v_before jsonb;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
begin
  if p_guest_name is null or btrim(p_guest_name) = '' then
    raise exception 'guest_name is required';
  end if;

  if (p_room_number is null or btrim(p_room_number) = '') and p_room_type_id is null then
    raise exception 'Either room_number or room_type_id is required';
  end if;

  if p_checkout_date <= p_checkin_date then
    raise exception 'checkout_date must be after checkin_date';
  end if;

  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if not found then
    raise exception 'Reservation not found';
  end if;

  if v_reservation.status <> 'active' then
    raise exception 'Reservation is not active';
  end if;

  -- 1. Resolve Room & Room Type
  if p_room_number is not null and btrim(p_room_number) <> '' then
    select * into v_room
    from public.rooms
    where room_number = btrim(p_room_number)
    for update;

    if not found then
      raise exception 'Room not found: %', p_room_number;
    end if;

    if not v_room.is_sellable then
      raise exception 'Room % is not sellable', v_room.room_number;
    end if;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  else
    v_room_id := null;
    v_effective_room_type_id := p_room_type_id;
    
    select id into v_pricing_room_id
    from public.rooms
    where room_type_id = p_room_type_id
    limit 1;
    
    if v_pricing_room_id is null then
      raise exception 'No rooms found for room_type_id: %', p_room_type_id;
    end if;
  end if;

  -- 2. Generate Dates
  select coalesce(array_agg(day::date order by day::date), array[]::date[])
  into v_night_dates
  from generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - interval '1 day')::timestamp,
    interval '1 day'
  ) as day;

  v_nights_count := cardinality(v_night_dates);
  if v_nights_count = 0 then
    raise exception 'No nights generated for selected date range';
  end if;

  -- 3. Check Conflicts
  if v_room_id is not null then
    -- Check other reservations
    select rn.stay_date
    into v_conflict_date
    from public.reservation_nights rn
    where rn.room_id = v_room_id
      and rn.cancelled_at is null
      and rn.stay_date = any(v_night_dates)
      and rn.reservation_id <> p_reservation_id
    limit 1;

    if v_conflict_date is not null then
      raise exception 'Room % already booked on %', v_room.room_number, v_conflict_date;
    end if;

    -- NEW: Check Room Blocks (OOO only)
    select start_date, reason
    into v_conflict_date, v_block_reason
    from public.room_blocks
    where room_number = v_room.room_number
      and block_type = 'OOO'
      and (
          (start_date <= p_checkin_date and end_date > p_checkin_date) OR
          (start_date < p_checkout_date and end_date >= p_checkout_date) OR
          (start_date >= p_checkin_date and end_date <= p_checkout_date)
      )
    limit 1;

    if v_conflict_date is not null then
      raise exception 'Room % is Out of Order (OOO) during this period. Reason: %', v_room.room_number, v_block_reason;
    end if;
  end if;

  -- 4. Calculate Prices
  if p_source = 'ota' then
    if p_ota_prices is null or cardinality(p_ota_prices) <> v_nights_count then
      raise exception 'OTA bookings require ota_prices length = %', v_nights_count;
    end if;

    select coalesce(array_agg(round(coalesce(ota.price, 0)::numeric, 2) order by ota.idx), array[]::numeric[])
    into v_prices
    from unnest(p_ota_prices) with ordinality as ota(price, idx);
  else
    select coalesce(array_agg(coalesce(rt.price, 0)::numeric(10, 2) order by d.stay_date), array[]::numeric[])
    into v_prices
    from unnest(v_night_dates) as d(stay_date)
    left join public.rate_templates rt
      on rt.room_id = v_pricing_room_id
     and rt.stay_date = d.stay_date;
  end if;

  select round(coalesce(sum(coalesce(price, 0)), 0)::numeric, 2)
  into v_total_price
  from unnest(v_prices) as p(price);

  v_before := jsonb_build_object(
    'guest_name', v_reservation.guest_name,
    'source', v_reservation.source,
    'checkin_date', v_reservation.checkin_date,
    'checkout_date', v_reservation.checkout_date,
    'total_price', v_reservation.total_price
  );

  -- 5. Cancel old nights
  v_cancelled_at := timezone('utc', now());
  update public.reservation_nights
  set cancelled_at = v_cancelled_at
  where reservation_id = p_reservation_id
    and cancelled_at is null;
  get diagnostics v_replaced_nights = row_count;

  -- 6. Update Reservation
  v_normalized_phone := nullif(btrim(coalesce(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(coalesce(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(coalesce(p_note, '')), '');

  update public.reservations
  set
    guest_name = btrim(p_guest_name),
    phone = v_normalized_phone,
    source = p_source,
    checkin_date = p_checkin_date,
    checkout_date = p_checkout_date,
    checkin_time = v_normalized_checkin_time,
    note = v_normalized_note,
    total_price = v_total_price,
    updated_by = coalesce(p_actor_user_id, updated_by)
  where id = p_reservation_id;

  -- 7. Insert New Nights
  insert into public.reservation_nights (
    reservation_id,
    room_id,
    room_type_id,
    stay_date,
    nightly_price,
    is_ota
  )
  select
    p_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(coalesce(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  from unnest(v_night_dates) with ordinality as d(stay_date, idx)
  join unnest(v_prices) with ordinality as pr(price, idx)
    on pr.idx = d.idx;

  -- 8. Audit Log
  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json
  )
  values (
    p_actor_user_id,
    'booking_updated',
    'reservation',
    p_reservation_id::text,
    v_before,
    jsonb_build_object(
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'source', p_source,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price,
      'replaced_nights', v_replaced_nights
    )
  );

  return jsonb_build_object(
    'id', p_reservation_id,
    'booking_code', v_reservation.booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
end;
$$;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240010_traces_and_guests.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Migration: Traces System + Guest Profiles
-- Created: 2026-02-24
-- =============================================================

-- ── 1. Enums ──────────────────────────────────────────────────

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trace_dept') THEN
    CREATE TYPE public.trace_dept AS ENUM ('FD', 'HK', 'MAINT', 'MGMT', 'OTHER');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trace_status') THEN
    CREATE TYPE public.trace_status AS ENUM ('open', 'done', 'cancelled');
  END IF;
END $$;

-- ── 2. Guest Profiles ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.guest_profiles (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  -- Identity
  first_name    text,
  last_name     text NOT NULL,
  nationality   text,
  passport_no   text,
  dob           date,

  -- Contact
  phone         text,
  email         text,

  -- Hotel fields (inspired by Opera "Preferences" + "VIP" + "Specials")
  vip_tier      text,         -- 'regular' | 'loyal' | 'vip' | 'longest'
  preferences   text,         -- e.g. "Prefers floor 3, extra pillow"
  notes         text,         -- internal staff-only notes
  blacklisted   boolean NOT NULL DEFAULT false,

  -- OCR passport raw data (from Google Vision)
  passport_raw  jsonb
);

ALTER TABLE public.guest_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role full access" ON public.guest_profiles FOR ALL USING (true);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_guest_profiles_updated_at ON public.guest_profiles;
CREATE TRIGGER trg_guest_profiles_updated_at
  BEFORE UPDATE ON public.guest_profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 3. Extend reservations table ──────────────────────────────

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS guest_profile_id  uuid REFERENCES public.guest_profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS adults            smallint NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS children          smallint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS arrival_time      text,    -- "14:00"
  ADD COLUMN IF NOT EXISTS departure_time    text,    -- "12:00"
  ADD COLUMN IF NOT EXISTS specials          text;    -- free-text: "Anniversary, quiet room"

-- ── 4. Alert Codes (predefined list) ──────────────────────────

CREATE TABLE IF NOT EXISTS public.alert_codes (
  code        text PRIMARY KEY,
  description text NOT NULL,
  dept        public.trace_dept,
  auto_on_co  boolean NOT NULL DEFAULT false,  -- auto-show at checkout
  icon        text                             -- emoji hint for UI
);

ALTER TABLE public.alert_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role full access" ON public.alert_codes FOR ALL USING (true);

-- Seed alert codes (idempotent)
INSERT INTO public.alert_codes (code, description, dept, auto_on_co, icon) VALUES
  ('ADA',   'Guest has EU/UK/US adaptor — collect on checkout', 'FD',    true,  '🔌'),
  ('HAIR',  'Guest has hair dryer — collect on checkout',        'FD',    true,  '💇'),
  ('IRON',  'Guest has iron & board — collect on checkout',      'FD',    true,  '👔'),
  ('BED',   'Extra bed/mattress requested',                      'HK',   false,  '🛏️'),
  ('PIL',   'Extra pillow/blanket requested',                    'HK',   false,  '🛏️'),
  ('DND',   'Do Not Disturb — guest requested privacy',          'HK',   false,  '🚫'),
  ('DEP',   'Take deposit on arrival',                           'FD',   false,  '💰'),
  ('GRT',   'Manager to greet guest on arrival',                 'MGMT', false,  '🤝'),
  ('ANN',   'Anniversary — arrange celebration',                 'FD',   false,  '🎉'),
  ('BIR',   'Birthday — arrange celebration',                    'FD',   false,  '🎂'),
  ('PCP',   'Previous complaint — handle with extra care',       'MGMT', false,  '⚠️'),
  ('BOAT',  'Guest has boat transfer booked — confirm time',     'FD',   false,  '⛵'),
  ('CAR',   'Guest has car transfer booked — confirm time',      'FD',   false,  '🚗'),
  ('VIP',   'VIP Guest — priority service',                      'MGMT', false,  '⭐'),
  ('OTH',   'Other — see trace notes',                           'FD',   false,  '📋')
ON CONFLICT (code) DO UPDATE
  SET description = EXCLUDED.description,
      dept        = EXCLUDED.dept,
      auto_on_co  = EXCLUDED.auto_on_co,
      icon        = EXCLUDED.icon;

-- ── 5. Reservation Alerts (many-to-many) ──────────────────────

CREATE TABLE IF NOT EXISTS public.reservation_alerts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id  uuid NOT NULL REFERENCES public.reservations(id) ON DELETE CASCADE,
  alert_code      text NOT NULL REFERENCES public.alert_codes(code) ON DELETE CASCADE,
  note            text,         -- optional custom note for this instance
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reservation_id, alert_code)
);

ALTER TABLE public.reservation_alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role full access" ON public.reservation_alerts FOR ALL USING (true);

-- ── 6. Loan Items (stock management) ──────────────────────────

CREATE TABLE IF NOT EXISTS public.loan_items (
  code        text PRIMARY KEY,
  name        text NOT NULL,
  total_qty   smallint NOT NULL DEFAULT 0,
  available   smallint NOT NULL DEFAULT 0,
  icon        text
);

ALTER TABLE public.loan_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role full access" ON public.loan_items FOR ALL USING (true);

-- Seed loan items (idempotent)
INSERT INTO public.loan_items (code, name, total_qty, available, icon) VALUES
  ('ADAPTER_EU',   'EU Adapter',          10, 10, '🔌'),
  ('ADAPTER_UK',   'UK Adapter',          10, 10, '🔌'),
  ('ADAPTER_US',   'US Adapter',           5,  5, '🔌'),
  ('HAIR_DRYER',   'Hair Dryer',           5,  5, '💇'),
  ('IRON',         'Iron & Board',         3,  3, '👔'),
  ('EXTRA_BED',    'Extra Bed/Mattress',   4,  4, '🛏️'),
  ('EXTRA_PILLOW', 'Extra Pillow',        20, 20, '🛏️'),
  ('EXTRA_TOWEL',  'Extra Towel',         30, 30, '🪥'),
  ('KETTLE',       'Electric Kettle',      5,  5, '☕'),
  ('UMBRELLA',     'Umbrella',             8,  8, '☂️'),
  ('YOGA_MAT',     'Yoga Mat',             4,  4, '🧘')
ON CONFLICT (code) DO UPDATE
  SET name      = EXCLUDED.name,
      total_qty = EXCLUDED.total_qty,
      icon      = EXCLUDED.icon;
  -- Note: available stock is NOT reset on re-run to avoid wiping live data

-- ── 7. Reservation Traces ────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.reservation_traces (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id  uuid NOT NULL REFERENCES public.reservations(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  created_by      text,                  -- staff name

  -- Oracle-inspired fields
  dept            public.trace_dept NOT NULL DEFAULT 'FD',
  trace_text      text NOT NULL,
  from_date       date NOT NULL,
  to_date         date NOT NULL,

  -- Loan item link (optional — ties into loan_items stock)
  loan_item_code  text REFERENCES public.loan_items(code) ON DELETE SET NULL,
  loan_qty        smallint NOT NULL DEFAULT 0,

  -- Resolution
  status          public.trace_status NOT NULL DEFAULT 'open',
  resolved_at     timestamptz,
  resolved_by     text
);

CREATE INDEX IF NOT EXISTS idx_reservation_traces_reservation_id
  ON public.reservation_traces (reservation_id);
CREATE INDEX IF NOT EXISTS idx_reservation_traces_from_date
  ON public.reservation_traces (from_date);
CREATE INDEX IF NOT EXISTS idx_reservation_traces_status
  ON public.reservation_traces (status);

ALTER TABLE public.reservation_traces ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service role full access" ON public.reservation_traces FOR ALL USING (true);

-- ── Done ─────────────────────────────────────────────────────



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602240011_traces_and_guests_extras.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Migration: Add extra fields to Guest Profiles
-- Created: 2026-02-24
-- =============================================================

-- Add the sequence for the auto-generated member number
CREATE SEQUENCE IF NOT EXISTS public.guest_member_seq START 10001;

-- Add the new columns to the guest_profiles table
ALTER TABLE public.guest_profiles
ADD COLUMN IF NOT EXISTS gender             text,
ADD COLUMN IF NOT EXISTS car_registration   text,
ADD COLUMN IF NOT EXISTS line_id            text,
ADD COLUMN IF NOT EXISTS member_no          text UNIQUE;

-- We can set a default value for new records directly using the sequence,
-- but since some records might already exist without a member_no,
-- let's backfill existing records and set a default.

-- 1. Set the default for future inserts
ALTER TABLE public.guest_profiles
ALTER COLUMN member_no SET DEFAULT 'MEM-' || nextval('public.guest_member_seq')::text;

-- 2. Backfill existing records that don't have a member_no
UPDATE public.guest_profiles
SET member_no = 'MEM-' || nextval('public.guest_member_seq')::text
WHERE member_no IS NULL;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602250001_capacity_check.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Capacity Check for Floating Bookings
-- Adds per-night room type capacity enforcement to booking_create_reservation
-- and booking_update_reservation RPCs.
-- Created: 2026-02-25
-- =============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.booking_create_reservation(
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text DEFAULT NULL,
  p_room_type_id bigint DEFAULT NULL,
  p_source public.booking_source DEFAULT 'walkin',
  p_phone text DEFAULT NULL,
  p_checkin_time text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_ota_prices numeric[] DEFAULT NULL,
  p_actor_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_reservation_id uuid;
  v_booking_code text;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_capacity_date date;
  v_room_capacity int;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
BEGIN
  IF p_guest_name IS NULL OR btrim(p_guest_name) = '' THEN
    RAISE EXCEPTION 'guest_name is required';
  END IF;

  IF (p_room_number IS NULL OR btrim(p_room_number) = '') AND p_room_type_id IS NULL THEN
    RAISE EXCEPTION 'Either room_number or room_type_id is required';
  END IF;

  IF p_checkout_date <= p_checkin_date THEN
    RAISE EXCEPTION 'checkout_date must be after checkin_date';
  END IF;

  -- 1. Resolve Room & Room Type
  IF p_room_number IS NOT NULL AND btrim(p_room_number) <> '' THEN
    SELECT * INTO v_room
    FROM public.rooms
    WHERE room_number = btrim(p_room_number)
    FOR UPDATE;

    IF NOT found THEN
      RAISE EXCEPTION 'Room not found: %', p_room_number;
    END IF;

    IF NOT v_room.is_sellable THEN
      RAISE EXCEPTION 'Room % is not sellable', v_room.room_number;
    END IF;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  ELSE
    v_room_id := NULL;
    v_effective_room_type_id := p_room_type_id;

    -- Pick any room of this type to use for pricing templates
    SELECT id INTO v_pricing_room_id
    FROM public.rooms
    WHERE room_type_id = p_room_type_id
      AND is_sellable = true
    LIMIT 1;

    IF v_pricing_room_id IS NULL THEN
      RAISE EXCEPTION 'No rooms found for room_type_id: %', p_room_type_id;
    END IF;
  END IF;

  -- 2. Generate Dates
  SELECT COALESCE(array_agg(day::date ORDER BY day::date), ARRAY[]::date[])
  INTO v_night_dates
  FROM generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - INTERVAL '1 day')::timestamp,
    INTERVAL '1 day'
  ) AS day;

  v_nights_count := cardinality(v_night_dates);
  IF v_nights_count = 0 THEN
    RAISE EXCEPTION 'No nights generated for selected date range';
  END IF;

  -- 3. Check Conflicts (specific room) OR Capacity (floating booking)
  IF v_room_id IS NOT NULL THEN
    -- Specific room: check for date conflicts
    SELECT rn.stay_date INTO v_conflict_date
    FROM public.reservation_nights rn
    WHERE rn.room_id = v_room_id
      AND rn.cancelled_at IS NULL
      AND rn.stay_date = ANY(v_night_dates)
    LIMIT 1;

    IF v_conflict_date IS NOT NULL THEN
      RAISE EXCEPTION 'Room % already booked on %', v_room.room_number, v_conflict_date;
    END IF;
  ELSE
    -- Floating booking: check per-night capacity (booked count vs sellable rooms)
    SELECT COUNT(*) INTO v_room_capacity
    FROM public.rooms
    WHERE room_type_id = v_effective_room_type_id
      AND is_sellable = true;

    SELECT d INTO v_capacity_date
    FROM unnest(v_night_dates) AS d
    WHERE (
      SELECT COUNT(DISTINCT rn.reservation_id)
      FROM public.reservation_nights rn
      WHERE rn.room_type_id = v_effective_room_type_id
        AND rn.stay_date = d
        AND rn.cancelled_at IS NULL
    ) >= v_room_capacity
    LIMIT 1;

    IF v_capacity_date IS NOT NULL THEN
      RAISE EXCEPTION 'No availability: all % rooms of this type are fully booked on %', v_room_capacity, v_capacity_date;
    END IF;
  END IF;

  -- 4. Calculate Prices
  IF p_source = 'ota' THEN
    IF p_ota_prices IS NULL OR cardinality(p_ota_prices) <> v_nights_count THEN
      RAISE EXCEPTION 'OTA bookings require ota_prices length = %', v_nights_count;
    END IF;

    SELECT COALESCE(array_agg(round(COALESCE(ota.price, 0)::numeric, 2) ORDER BY ota.idx), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(p_ota_prices) WITH ORDINALITY AS ota(price, idx);
  ELSE
    SELECT COALESCE(array_agg(COALESCE(rt.price, 0)::numeric(10, 2) ORDER BY d.stay_date), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(v_night_dates) AS d(stay_date)
    LEFT JOIN public.rate_templates rt
      ON rt.room_id = v_pricing_room_id
     AND rt.stay_date = d.stay_date;
  END IF;

  SELECT round(COALESCE(sum(COALESCE(price, 0)), 0)::numeric, 2)
  INTO v_total_price
  FROM unnest(v_prices) AS p(price);

  -- 5. Insert Reservation
  v_booking_code := public.generate_booking_code();
  v_normalized_phone := nullif(btrim(COALESCE(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(COALESCE(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(COALESCE(p_note, '')), '');

  INSERT INTO public.reservations (
    booking_code, guest_name, phone, source, status,
    checkin_date, checkout_date, checkin_time, note,
    total_price, created_by, updated_by, room_number
  ) VALUES (
    v_booking_code,
    btrim(p_guest_name),
    v_normalized_phone,
    p_source,
    'active',
    p_checkin_date,
    p_checkout_date,
    v_normalized_checkin_time,
    v_normalized_note,
    v_total_price,
    p_actor_user_id,
    p_actor_user_id,
    nullif(btrim(p_room_number), '')
  )
  RETURNING id INTO v_reservation_id;

  -- 6. Insert Reservation Nights
  INSERT INTO public.reservation_nights (
    reservation_id, room_id, room_type_id, stay_date, nightly_price, is_ota
  )
  SELECT
    v_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(COALESCE(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  FROM unnest(v_night_dates) WITH ORDINALITY AS d(stay_date, idx)
  JOIN unnest(v_prices) WITH ORDINALITY AS pr(price, idx)
    ON pr.idx = d.idx;

  -- 7. Audit Log
  INSERT INTO public.audit_logs (actor_user_id, action, entity_type, entity_id, after_json)
  VALUES (
    p_actor_user_id,
    'booking_created',
    'reservation',
    v_reservation_id::text,
    jsonb_build_object(
      'booking_code', v_booking_code,
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price
    )
  );

  RETURN jsonb_build_object(
    'id', v_reservation_id,
    'booking_code', v_booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
END;
$$;

-- ── Same capacity check for booking_update_reservation ────────────────────

CREATE OR REPLACE FUNCTION public.booking_update_reservation(
  p_reservation_id uuid,
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text DEFAULT NULL,
  p_room_type_id bigint DEFAULT NULL,
  p_source public.booking_source DEFAULT 'walkin',
  p_phone text DEFAULT NULL,
  p_checkin_time text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_ota_prices numeric[] DEFAULT NULL,
  p_actor_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_reservation public.reservations%rowtype;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_capacity_date date;
  v_room_capacity int;
  v_replaced_nights int;
  v_cancelled_at timestamptz;
  v_before jsonb;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
BEGIN
  IF p_guest_name IS NULL OR btrim(p_guest_name) = '' THEN
    RAISE EXCEPTION 'guest_name is required';
  END IF;

  IF (p_room_number IS NULL OR btrim(p_room_number) = '') AND p_room_type_id IS NULL THEN
    RAISE EXCEPTION 'Either room_number or room_type_id is required';
  END IF;

  IF p_checkout_date <= p_checkin_date THEN
    RAISE EXCEPTION 'checkout_date must be after checkin_date';
  END IF;

  SELECT * INTO v_reservation
  FROM public.reservations
  WHERE id = p_reservation_id
  FOR UPDATE;

  IF NOT found THEN
    RAISE EXCEPTION 'Reservation not found';
  END IF;

  IF v_reservation.status <> 'active' THEN
    RAISE EXCEPTION 'Reservation is not active';
  END IF;

  -- 1. Resolve Room & Room Type
  IF p_room_number IS NOT NULL AND btrim(p_room_number) <> '' THEN
    SELECT * INTO v_room
    FROM public.rooms
    WHERE room_number = btrim(p_room_number)
    FOR UPDATE;

    IF NOT found THEN
      RAISE EXCEPTION 'Room not found: %', p_room_number;
    END IF;

    IF NOT v_room.is_sellable THEN
      RAISE EXCEPTION 'Room % is not sellable', v_room.room_number;
    END IF;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  ELSE
    v_room_id := NULL;
    v_effective_room_type_id := p_room_type_id;

    SELECT id INTO v_pricing_room_id
    FROM public.rooms
    WHERE room_type_id = p_room_type_id
      AND is_sellable = true
    LIMIT 1;

    IF v_pricing_room_id IS NULL THEN
      RAISE EXCEPTION 'No rooms found for room_type_id: %', p_room_type_id;
    END IF;
  END IF;

  -- 2. Generate Dates
  SELECT COALESCE(array_agg(day::date ORDER BY day::date), ARRAY[]::date[])
  INTO v_night_dates
  FROM generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - INTERVAL '1 day')::timestamp,
    INTERVAL '1 day'
  ) AS day;

  v_nights_count := cardinality(v_night_dates);
  IF v_nights_count = 0 THEN
    RAISE EXCEPTION 'No nights generated for selected date range';
  END IF;

  -- 3. Conflict or Capacity check
  IF v_room_id IS NOT NULL THEN
    SELECT rn.stay_date INTO v_conflict_date
    FROM public.reservation_nights rn
    WHERE rn.room_id = v_room_id
      AND rn.cancelled_at IS NULL
      AND rn.stay_date = ANY(v_night_dates)
      AND rn.reservation_id <> p_reservation_id
    LIMIT 1;

    IF v_conflict_date IS NOT NULL THEN
      RAISE EXCEPTION 'Room % already booked on %', v_room.room_number, v_conflict_date;
    END IF;
  ELSE
    -- Capacity check: exclude THIS reservation's existing nights from count
    SELECT COUNT(*) INTO v_room_capacity
    FROM public.rooms
    WHERE room_type_id = v_effective_room_type_id
      AND is_sellable = true;

    SELECT d INTO v_capacity_date
    FROM unnest(v_night_dates) AS d
    WHERE (
      SELECT COUNT(DISTINCT rn.reservation_id)
      FROM public.reservation_nights rn
      WHERE rn.room_type_id = v_effective_room_type_id
        AND rn.stay_date = d
        AND rn.cancelled_at IS NULL
        AND rn.reservation_id <> p_reservation_id  -- exclude self
    ) >= v_room_capacity
    LIMIT 1;

    IF v_capacity_date IS NOT NULL THEN
      RAISE EXCEPTION 'No availability: all % rooms of this type are fully booked on %', v_room_capacity, v_capacity_date;
    END IF;
  END IF;

  -- 4. Calculate Prices
  IF p_source = 'ota' THEN
    IF p_ota_prices IS NULL OR cardinality(p_ota_prices) <> v_nights_count THEN
      RAISE EXCEPTION 'OTA bookings require ota_prices length = %', v_nights_count;
    END IF;

    SELECT COALESCE(array_agg(round(COALESCE(ota.price, 0)::numeric, 2) ORDER BY ota.idx), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(p_ota_prices) WITH ORDINALITY AS ota(price, idx);
  ELSE
    SELECT COALESCE(array_agg(COALESCE(rt.price, 0)::numeric(10, 2) ORDER BY d.stay_date), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(v_night_dates) AS d(stay_date)
    LEFT JOIN public.rate_templates rt
      ON rt.room_id = v_pricing_room_id
     AND rt.stay_date = d.stay_date;
  END IF;

  SELECT round(COALESCE(sum(COALESCE(price, 0)), 0)::numeric, 2)
  INTO v_total_price
  FROM unnest(v_prices) AS p(price);

  v_before := jsonb_build_object(
    'guest_name', v_reservation.guest_name,
    'source', v_reservation.source,
    'checkin_date', v_reservation.checkin_date,
    'checkout_date', v_reservation.checkout_date,
    'total_price', v_reservation.total_price
  );

  -- 5. Cancel old nights
  v_cancelled_at := timezone('utc', now());
  UPDATE public.reservation_nights
  SET cancelled_at = v_cancelled_at
  WHERE reservation_id = p_reservation_id
    AND cancelled_at IS NULL;
  GET DIAGNOSTICS v_replaced_nights = ROW_COUNT;

  -- 6. Update Reservation
  v_normalized_phone := nullif(btrim(COALESCE(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(COALESCE(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(COALESCE(p_note, '')), '');

  UPDATE public.reservations SET
    guest_name = btrim(p_guest_name),
    phone = v_normalized_phone,
    source = p_source,
    checkin_date = p_checkin_date,
    checkout_date = p_checkout_date,
    checkin_time = v_normalized_checkin_time,
    note = v_normalized_note,
    total_price = v_total_price,
    room_number = nullif(btrim(p_room_number), ''),
    updated_by = COALESCE(p_actor_user_id, updated_by)
  WHERE id = p_reservation_id;

  -- 7. Insert New Nights
  INSERT INTO public.reservation_nights (
    reservation_id, room_id, room_type_id, stay_date, nightly_price, is_ota
  )
  SELECT
    p_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(COALESCE(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  FROM unnest(v_night_dates) WITH ORDINALITY AS d(stay_date, idx)
  JOIN unnest(v_prices) WITH ORDINALITY AS pr(price, idx)
    ON pr.idx = d.idx;

  -- 8. Audit Log
  INSERT INTO public.audit_logs (actor_user_id, action, entity_type, entity_id, before_json, after_json)
  VALUES (
    p_actor_user_id,
    'booking_updated',
    'reservation',
    p_reservation_id::text,
    v_before,
    jsonb_build_object(
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'source', p_source,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price,
      'replaced_nights', v_replaced_nights
    )
  );

  RETURN jsonb_build_object(
    'id', p_reservation_id,
    'booking_code', v_reservation.booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
END;
$$;

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602250002_fix_stored_procs_room_number.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Fix booking_create_reservation & booking_update_reservation
-- Remove references to reservations.room_number (column was dropped)
-- The room assignment is stored in reservation_nights.room_id instead.
-- Created: 2026-02-25
-- =============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.booking_create_reservation(
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text DEFAULT NULL,
  p_room_type_id bigint DEFAULT NULL,
  p_source public.booking_source DEFAULT 'walkin',
  p_phone text DEFAULT NULL,
  p_checkin_time text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_ota_prices numeric[] DEFAULT NULL,
  p_actor_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_reservation_id uuid;
  v_booking_code text;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_capacity_date date;
  v_room_capacity int;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
BEGIN
  IF p_guest_name IS NULL OR btrim(p_guest_name) = '' THEN
    RAISE EXCEPTION 'guest_name is required';
  END IF;

  IF (p_room_number IS NULL OR btrim(p_room_number) = '') AND p_room_type_id IS NULL THEN
    RAISE EXCEPTION 'Either room_number or room_type_id is required';
  END IF;

  IF p_checkout_date <= p_checkin_date THEN
    RAISE EXCEPTION 'checkout_date must be after checkin_date';
  END IF;

  -- 1. Resolve Room & Room Type
  IF p_room_number IS NOT NULL AND btrim(p_room_number) <> '' THEN
    SELECT * INTO v_room
    FROM public.rooms
    WHERE room_number = btrim(p_room_number)
    FOR UPDATE;

    IF NOT found THEN
      RAISE EXCEPTION 'Room not found: %', p_room_number;
    END IF;

    IF NOT v_room.is_sellable THEN
      RAISE EXCEPTION 'Room % is not sellable', v_room.room_number;
    END IF;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  ELSE
    v_room_id := NULL;
    v_effective_room_type_id := p_room_type_id;

    -- Pick any room of this type to use for pricing templates
    SELECT id INTO v_pricing_room_id
    FROM public.rooms
    WHERE room_type_id = p_room_type_id
      AND is_sellable = true
    LIMIT 1;

    IF v_pricing_room_id IS NULL THEN
      RAISE EXCEPTION 'No rooms found for room_type_id: %', p_room_type_id;
    END IF;
  END IF;

  -- 2. Generate Dates
  SELECT COALESCE(array_agg(day::date ORDER BY day::date), ARRAY[]::date[])
  INTO v_night_dates
  FROM generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - INTERVAL '1 day')::timestamp,
    INTERVAL '1 day'
  ) AS day;

  v_nights_count := cardinality(v_night_dates);
  IF v_nights_count = 0 THEN
    RAISE EXCEPTION 'No nights generated for selected date range';
  END IF;

  -- 3. Check Conflicts (specific room) OR Capacity (floating booking)
  IF v_room_id IS NOT NULL THEN
    SELECT rn.stay_date INTO v_conflict_date
    FROM public.reservation_nights rn
    WHERE rn.room_id = v_room_id
      AND rn.cancelled_at IS NULL
      AND rn.stay_date = ANY(v_night_dates)
    LIMIT 1;

    IF v_conflict_date IS NOT NULL THEN
      RAISE EXCEPTION 'Room % already booked on %', v_room.room_number, v_conflict_date;
    END IF;
  ELSE
    -- Floating booking: check per-night capacity
    SELECT COUNT(*) INTO v_room_capacity
    FROM public.rooms
    WHERE room_type_id = v_effective_room_type_id
      AND is_sellable = true;

    SELECT d INTO v_capacity_date
    FROM unnest(v_night_dates) AS d
    WHERE (
      SELECT COUNT(DISTINCT rn.reservation_id)
      FROM public.reservation_nights rn
      WHERE rn.room_type_id = v_effective_room_type_id
        AND rn.stay_date = d
        AND rn.cancelled_at IS NULL
    ) >= v_room_capacity
    LIMIT 1;

    IF v_capacity_date IS NOT NULL THEN
      RAISE EXCEPTION 'No availability: all % rooms of this type are fully booked on %', v_room_capacity, v_capacity_date;
    END IF;
  END IF;

  -- 4. Calculate Prices
  IF p_source = 'ota' THEN
    IF p_ota_prices IS NULL OR cardinality(p_ota_prices) <> v_nights_count THEN
      RAISE EXCEPTION 'OTA bookings require ota_prices length = %', v_nights_count;
    END IF;

    SELECT COALESCE(array_agg(round(COALESCE(ota.price, 0)::numeric, 2) ORDER BY ota.idx), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(p_ota_prices) WITH ORDINALITY AS ota(price, idx);
  ELSE
    SELECT COALESCE(array_agg(COALESCE(rt.price, 0)::numeric(10, 2) ORDER BY d.stay_date), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(v_night_dates) AS d(stay_date)
    LEFT JOIN public.rate_templates rt
      ON rt.room_id = v_pricing_room_id
     AND rt.stay_date = d.stay_date;
  END IF;

  SELECT round(COALESCE(sum(COALESCE(price, 0)), 0)::numeric, 2)
  INTO v_total_price
  FROM unnest(v_prices) AS p(price);

  -- 5. Insert Reservation (no room_number column — room tracked via reservation_nights.room_id)
  v_booking_code := public.generate_booking_code();
  v_normalized_phone := nullif(btrim(COALESCE(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(COALESCE(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(COALESCE(p_note, '')), '');

  INSERT INTO public.reservations (
    booking_code, guest_name, phone, source, status,
    checkin_date, checkout_date, checkin_time, note,
    total_price, created_by, updated_by
  ) VALUES (
    v_booking_code,
    btrim(p_guest_name),
    v_normalized_phone,
    p_source,
    'active',
    p_checkin_date,
    p_checkout_date,
    v_normalized_checkin_time,
    v_normalized_note,
    v_total_price,
    p_actor_user_id,
    p_actor_user_id
  )
  RETURNING id INTO v_reservation_id;

  -- 6. Insert Reservation Nights
  INSERT INTO public.reservation_nights (
    reservation_id, room_id, room_type_id, stay_date, nightly_price, is_ota
  )
  SELECT
    v_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(COALESCE(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  FROM unnest(v_night_dates) WITH ORDINALITY AS d(stay_date, idx)
  JOIN unnest(v_prices) WITH ORDINALITY AS pr(price, idx)
    ON pr.idx = d.idx;

  -- 7. Audit Log
  INSERT INTO public.audit_logs (actor_user_id, action, entity_type, entity_id, after_json)
  VALUES (
    p_actor_user_id,
    'booking_created',
    'reservation',
    v_reservation_id::text,
    jsonb_build_object(
      'booking_code', v_booking_code,
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price
    )
  );

  RETURN jsonb_build_object(
    'id', v_reservation_id,
    'booking_code', v_booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
END;
$$;

-- ── Fix booking_update_reservation: remove room_number from UPDATE ──────────

CREATE OR REPLACE FUNCTION public.booking_update_reservation(
  p_reservation_id uuid,
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_number text DEFAULT NULL,
  p_room_type_id bigint DEFAULT NULL,
  p_source public.booking_source DEFAULT 'walkin',
  p_phone text DEFAULT NULL,
  p_checkin_time text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_ota_prices numeric[] DEFAULT NULL,
  p_actor_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_reservation public.reservations%rowtype;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_capacity_date date;
  v_room_capacity int;
  v_replaced_nights int;
  v_cancelled_at timestamptz;
  v_before jsonb;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
BEGIN
  IF p_guest_name IS NULL OR btrim(p_guest_name) = '' THEN
    RAISE EXCEPTION 'guest_name is required';
  END IF;

  IF (p_room_number IS NULL OR btrim(p_room_number) = '') AND p_room_type_id IS NULL THEN
    RAISE EXCEPTION 'Either room_number or room_type_id is required';
  END IF;

  IF p_checkout_date <= p_checkin_date THEN
    RAISE EXCEPTION 'checkout_date must be after checkin_date';
  END IF;

  SELECT * INTO v_reservation
  FROM public.reservations
  WHERE id = p_reservation_id
  FOR UPDATE;

  IF NOT found THEN
    RAISE EXCEPTION 'Reservation not found';
  END IF;

  IF v_reservation.status <> 'active' THEN
    RAISE EXCEPTION 'Reservation is not active';
  END IF;

  -- 1. Resolve Room & Room Type
  IF p_room_number IS NOT NULL AND btrim(p_room_number) <> '' THEN
    SELECT * INTO v_room
    FROM public.rooms
    WHERE room_number = btrim(p_room_number)
    FOR UPDATE;

    IF NOT found THEN
      RAISE EXCEPTION 'Room not found: %', p_room_number;
    END IF;

    IF NOT v_room.is_sellable THEN
      RAISE EXCEPTION 'Room % is not sellable', v_room.room_number;
    END IF;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  ELSE
    v_room_id := NULL;
    v_effective_room_type_id := p_room_type_id;

    SELECT id INTO v_pricing_room_id
    FROM public.rooms
    WHERE room_type_id = p_room_type_id
      AND is_sellable = true
    LIMIT 1;

    IF v_pricing_room_id IS NULL THEN
      RAISE EXCEPTION 'No rooms found for room_type_id: %', p_room_type_id;
    END IF;
  END IF;

  -- 2. Generate Dates
  SELECT COALESCE(array_agg(day::date ORDER BY day::date), ARRAY[]::date[])
  INTO v_night_dates
  FROM generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - INTERVAL '1 day')::timestamp,
    INTERVAL '1 day'
  ) AS day;

  v_nights_count := cardinality(v_night_dates);
  IF v_nights_count = 0 THEN
    RAISE EXCEPTION 'No nights generated for selected date range';
  END IF;

  -- 3. Conflict or Capacity check
  IF v_room_id IS NOT NULL THEN
    SELECT rn.stay_date INTO v_conflict_date
    FROM public.reservation_nights rn
    WHERE rn.room_id = v_room_id
      AND rn.cancelled_at IS NULL
      AND rn.stay_date = ANY(v_night_dates)
      AND rn.reservation_id <> p_reservation_id
    LIMIT 1;

    IF v_conflict_date IS NOT NULL THEN
      RAISE EXCEPTION 'Room % already booked on %', v_room.room_number, v_conflict_date;
    END IF;
  ELSE
    -- Capacity check: exclude THIS reservation's existing nights from count
    SELECT COUNT(*) INTO v_room_capacity
    FROM public.rooms
    WHERE room_type_id = v_effective_room_type_id
      AND is_sellable = true;

    SELECT d INTO v_capacity_date
    FROM unnest(v_night_dates) AS d
    WHERE (
      SELECT COUNT(DISTINCT rn.reservation_id)
      FROM public.reservation_nights rn
      WHERE rn.room_type_id = v_effective_room_type_id
        AND rn.stay_date = d
        AND rn.cancelled_at IS NULL
        AND rn.reservation_id <> p_reservation_id  -- exclude self
    ) >= v_room_capacity
    LIMIT 1;

    IF v_capacity_date IS NOT NULL THEN
      RAISE EXCEPTION 'No availability: all % rooms of this type are fully booked on %', v_room_capacity, v_capacity_date;
    END IF;
  END IF;

  -- 4. Calculate Prices
  IF p_source = 'ota' THEN
    IF p_ota_prices IS NULL OR cardinality(p_ota_prices) <> v_nights_count THEN
      RAISE EXCEPTION 'OTA bookings require ota_prices length = %', v_nights_count;
    END IF;

    SELECT COALESCE(array_agg(round(COALESCE(ota.price, 0)::numeric, 2) ORDER BY ota.idx), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(p_ota_prices) WITH ORDINALITY AS ota(price, idx);
  ELSE
    SELECT COALESCE(array_agg(COALESCE(rt.price, 0)::numeric(10, 2) ORDER BY d.stay_date), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(v_night_dates) AS d(stay_date)
    LEFT JOIN public.rate_templates rt
      ON rt.room_id = v_pricing_room_id
     AND rt.stay_date = d.stay_date;
  END IF;

  SELECT round(COALESCE(sum(COALESCE(price, 0)), 0)::numeric, 2)
  INTO v_total_price
  FROM unnest(v_prices) AS p(price);

  v_before := jsonb_build_object(
    'guest_name', v_reservation.guest_name,
    'source', v_reservation.source,
    'checkin_date', v_reservation.checkin_date,
    'checkout_date', v_reservation.checkout_date,
    'total_price', v_reservation.total_price
  );

  -- 5. Cancel old nights
  v_cancelled_at := timezone('utc', now());
  UPDATE public.reservation_nights
  SET cancelled_at = v_cancelled_at
  WHERE reservation_id = p_reservation_id
    AND cancelled_at IS NULL;
  GET DIAGNOSTICS v_replaced_nights = ROW_COUNT;

  -- 6. Update Reservation (no room_number column — room tracked via reservation_nights.room_id)
  v_normalized_phone := nullif(btrim(COALESCE(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(COALESCE(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(COALESCE(p_note, '')), '');

  UPDATE public.reservations SET
    guest_name = btrim(p_guest_name),
    phone = v_normalized_phone,
    source = p_source,
    checkin_date = p_checkin_date,
    checkout_date = p_checkout_date,
    checkin_time = v_normalized_checkin_time,
    note = v_normalized_note,
    total_price = v_total_price,
    updated_by = COALESCE(p_actor_user_id, updated_by)
  WHERE id = p_reservation_id;

  -- 7. Insert New Nights
  INSERT INTO public.reservation_nights (
    reservation_id, room_id, room_type_id, stay_date, nightly_price, is_ota
  )
  SELECT
    p_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(COALESCE(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  FROM unnest(v_night_dates) WITH ORDINALITY AS d(stay_date, idx)
  JOIN unnest(v_prices) WITH ORDINALITY AS pr(price, idx)
    ON pr.idx = d.idx;

  -- 8. Audit Log
  INSERT INTO public.audit_logs (actor_user_id, action, entity_type, entity_id, before_json, after_json)
  VALUES (
    p_actor_user_id,
    'booking_updated',
    'reservation',
    p_reservation_id::text,
    v_before,
    jsonb_build_object(
      'room_number', p_room_number,
      'room_type_id', v_effective_room_type_id,
      'source', p_source,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price,
      'replaced_nights', v_replaced_nights
    )
  );

  RETURN jsonb_build_object(
    'id', p_reservation_id,
    'booking_code', v_reservation.booking_code,
    'guest_name', btrim(p_guest_name),
    'room_number', p_room_number,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
END;
$$;

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602250003_room_detail.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Phase B: Room Detail System
-- bed_types, room_beds, room_detail, deduction system, scoring_config
-- Created: 2026-02-25
-- Fixed: removed unsupported IF NOT EXISTS from CREATE POLICY
-- =============================================================

BEGIN;

-- ── 1. Occupancy fields on room_types ────────────────────────

ALTER TABLE public.room_types
  ADD COLUMN IF NOT EXISTS max_guests            int  NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS extra_guest_charge    numeric(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS child_free_under_cm   int NOT NULL DEFAULT 110,
  ADD COLUMN IF NOT EXISTS child_extra_charge    numeric(10,2) NOT NULL DEFAULT 100;

-- ── 2. Bed Types (lookup) ────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bed_types (
  code      text PRIMARY KEY,     -- 'KING', 'QUEEN', 'SINGLE'
  name      text NOT NULL,        -- 'King Bed 6ft'
  width_ft  numeric(3,1) NOT NULL -- 6.0 / 5.0 / 3.5
);

INSERT INTO public.bed_types (code, name, width_ft) VALUES
  ('KING',   'King Bed 6ft',      6.0),
  ('QUEEN',  'Queen Bed 5ft',     5.0),
  ('SINGLE', 'Single Bed 3.5ft',  3.5)
ON CONFLICT (code) DO UPDATE
  SET name = EXCLUDED.name, width_ft = EXCLUDED.width_ft;

ALTER TABLE public.bed_types ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "bed_types_read"  ON public.bed_types;
DROP POLICY IF EXISTS "bed_types_write" ON public.bed_types;
CREATE POLICY "bed_types_read" ON public.bed_types FOR SELECT TO authenticated USING (true);
CREATE POLICY "bed_types_write" ON public.bed_types FOR ALL TO authenticated
  USING (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]))
  WITH CHECK (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]));

-- ── 3. Room Bed Configuration (per physical room) ────────────

CREATE TABLE IF NOT EXISTS public.room_beds (
  room_id       uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  bed_type_code text NOT NULL REFERENCES public.bed_types(code) ON DELETE CASCADE,
  quantity      int  NOT NULL DEFAULT 1 CHECK (quantity >= 1),
  PRIMARY KEY (room_id, bed_type_code)
);

ALTER TABLE public.room_beds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "room_beds_read"  ON public.room_beds;
DROP POLICY IF EXISTS "room_beds_write" ON public.room_beds;
CREATE POLICY "room_beds_read" ON public.room_beds FOR SELECT TO authenticated USING (true);
CREATE POLICY "room_beds_write" ON public.room_beds FOR ALL TO authenticated
  USING (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]))
  WITH CHECK (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]));

-- ── 4. Room Detail (Condition + Quality Score) ───────────────

CREATE TABLE IF NOT EXISTS public.room_detail (
  room_id         uuid PRIMARY KEY REFERENCES public.rooms(id) ON DELETE CASCADE,

  -- Base ratings 1-5 (default 5 = perfect before any deduction)
  ac_base         int NOT NULL DEFAULT 5 CHECK (ac_base BETWEEN 1 AND 5),
  furniture_base  int NOT NULL DEFAULT 5 CHECK (furniture_base BETWEEN 1 AND 5),
  bathroom_base   int NOT NULL DEFAULT 5 CHECK (bathroom_base BETWEEN 1 AND 5),
  wifi_base       int NOT NULL DEFAULT 5 CHECK (wifi_base BETWEEN 1 AND 5),

  -- Cumulative deductions per category (sum of room_condition_deductions)
  ac_deduct       numeric(4,1) NOT NULL DEFAULT 0,
  furniture_deduct numeric(4,1) NOT NULL DEFAULT 0,
  bathroom_deduct numeric(4,1) NOT NULL DEFAULT 0,
  wifi_deduct     numeric(4,1) NOT NULL DEFAULT 0,

  -- Equipment / info fields
  ac_model        text,
  last_renovated  date,
  tv_size_inch    int,
  floor_number    int,
  extra_notes     text,

  -- Auto-computed quality score (2.0–10.0)
  -- Each category net = GREATEST(1, base - deduct), then avg × 2
  quality_score   numeric(4,2) GENERATED ALWAYS AS (
    (
      (GREATEST(1.0, ac_base::numeric - ac_deduct) +
       GREATEST(1.0, furniture_base::numeric - furniture_deduct) +
       GREATEST(1.0, bathroom_base::numeric - bathroom_deduct) +
       GREATEST(1.0, wifi_base::numeric - wifi_deduct)) / 4.0
    ) * 2.0
  ) STORED,

  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.room_detail ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "room_detail_read"  ON public.room_detail;
DROP POLICY IF EXISTS "room_detail_write" ON public.room_detail;
CREATE POLICY "room_detail_read" ON public.room_detail FOR SELECT TO authenticated USING (true);
CREATE POLICY "room_detail_write" ON public.room_detail FOR ALL TO authenticated
  USING (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]))
  WITH CHECK (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]));

-- ── 5. Condition Deduction Templates (Admin-managed presets) ─

CREATE TABLE IF NOT EXISTS public.condition_deduction_templates (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category      text NOT NULL CHECK (category IN ('ac','furniture','bathroom','wifi')),
  label         text NOT NULL,              -- 'โต๊ะมีรอย > 30%', 'ก๊อกรั่ว'
  deduct_points numeric(3,1) NOT NULL CHECK (deduct_points > 0 AND deduct_points <= 5),
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (category, label)
);

-- Seed common deductions
INSERT INTO public.condition_deduction_templates (category, label, deduct_points) VALUES
  ('ac',        'แอร์เย็นน้อยกว่าปกติ',          1.0),
  ('ac',        'แอร์มีเสียงดัง',                 0.5),
  ('ac',        'รอยสนิมที่ตัวแอร์',              1.0),
  ('furniture', 'โต๊ะมีรอยขีดข่วน > 30%',        1.0),
  ('furniture', 'เก้าอี้ขาหัก/โยก',               2.0),
  ('furniture', 'ผ้าม่านซีดหรือขาด',              0.5),
  ('furniture', 'เฟอร์นิเจอร์เก่ามากกว่า 10 ปี', 1.5),
  ('bathroom',  'ก๊อกน้ำรั่ว',                    1.0),
  ('bathroom',  'กระเบื้องแตก',                   1.5),
  ('bathroom',  'ฝักบัวอุดตัน',                   0.5),
  ('wifi',      'สัญญาณอ่อน (< 1 Mbps)',          2.0),
  ('wifi',      'สัญญาณกลาง (1-5 Mbps)',          1.0)
ON CONFLICT (category, label) DO NOTHING;

ALTER TABLE public.condition_deduction_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "deduct_templates_read"  ON public.condition_deduction_templates;
DROP POLICY IF EXISTS "deduct_templates_write" ON public.condition_deduction_templates;
CREATE POLICY "deduct_templates_read" ON public.condition_deduction_templates FOR SELECT TO authenticated USING (true);
CREATE POLICY "deduct_templates_write" ON public.condition_deduction_templates FOR ALL TO authenticated
  USING (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]))
  WITH CHECK (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]));

-- ── 6. Room Condition Deductions (applied to each room) ──────

CREATE TABLE IF NOT EXISTS public.room_condition_deductions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id       uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  template_id   uuid REFERENCES public.condition_deduction_templates(id) ON DELETE SET NULL,
  category      text NOT NULL CHECK (category IN ('ac','furniture','bathroom','wifi')),
  label         text NOT NULL,
  deduct_points numeric(3,1) NOT NULL CHECK (deduct_points > 0),
  noted_at      timestamptz NOT NULL DEFAULT now(),
  noted_by      uuid REFERENCES public.profiles(user_id)
);

CREATE INDEX IF NOT EXISTS idx_room_cond_deductions_room ON public.room_condition_deductions(room_id);

ALTER TABLE public.room_condition_deductions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "room_deductions_read"  ON public.room_condition_deductions;
DROP POLICY IF EXISTS "room_deductions_write" ON public.room_condition_deductions;
CREATE POLICY "room_deductions_read" ON public.room_condition_deductions FOR SELECT TO authenticated USING (true);
CREATE POLICY "room_deductions_write" ON public.room_condition_deductions FOR ALL TO authenticated
  USING (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]))
  WITH CHECK (public.has_any_role(ARRAY['admin','supervisor']::public.user_role[]));

-- ── 7. Trigger: Update room_detail.xx_deduct when deductions change ─

CREATE OR REPLACE FUNCTION public.sync_room_deduct_totals()
RETURNS TRIGGER AS $$
DECLARE
  v_room_id uuid;
BEGIN
  v_room_id := COALESCE(NEW.room_id, OLD.room_id);

  INSERT INTO public.room_detail (room_id, ac_deduct, furniture_deduct, bathroom_deduct, wifi_deduct)
  SELECT
    v_room_id,
    COALESCE(SUM(CASE WHEN category = 'ac'        THEN deduct_points ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN category = 'furniture' THEN deduct_points ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN category = 'bathroom'  THEN deduct_points ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN category = 'wifi'      THEN deduct_points ELSE 0 END), 0)
  FROM public.room_condition_deductions
  WHERE room_id = v_room_id
  ON CONFLICT (room_id) DO UPDATE SET
    ac_deduct        = EXCLUDED.ac_deduct,
    furniture_deduct = EXCLUDED.furniture_deduct,
    bathroom_deduct  = EXCLUDED.bathroom_deduct,
    wifi_deduct      = EXCLUDED.wifi_deduct,
    updated_at       = now();

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_deduct_on_insert ON public.room_condition_deductions;
CREATE TRIGGER trg_sync_deduct_on_insert
  AFTER INSERT OR DELETE ON public.room_condition_deductions
  FOR EACH ROW EXECUTE FUNCTION public.sync_room_deduct_totals();

-- ── 8. Room Stay History (HK bridge for Usage Balance) ────────

CREATE TABLE IF NOT EXISTS public.room_stay_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id     uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  stayed_at   date NOT NULL,
  source      text NOT NULL DEFAULT 'pms' CHECK (source IN ('pms', 'maintenance_app')),
  imported_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (room_id, stayed_at, source)
);

CREATE INDEX IF NOT EXISTS idx_stay_history_room ON public.room_stay_history(room_id);

ALTER TABLE public.room_stay_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "stay_history_read"  ON public.room_stay_history;
DROP POLICY IF EXISTS "stay_history_write" ON public.room_stay_history;
CREATE POLICY "stay_history_read" ON public.room_stay_history FOR SELECT TO authenticated USING (true);
CREATE POLICY "stay_history_write" ON public.room_stay_history FOR ALL TO authenticated
  USING (public.has_any_role(ARRAY['admin','frontdesk','supervisor']::public.user_role[]))
  WITH CHECK (public.has_any_role(ARRAY['admin','frontdesk','supervisor']::public.user_role[]));

-- ── 9. Scoring Config ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.scoring_config (
  key   text PRIMARY KEY,
  value numeric NOT NULL DEFAULT 0,
  label text
);

INSERT INTO public.scoring_config (key, value, label) VALUES
  ('w_preference', 40, 'Preference Match %'),
  ('w_bed',        25, 'Bed Match %'),
  ('w_quality',    20, 'Room Quality %'),
  ('w_balance',    10, 'Usage Balance %'),
  ('w_hk',          5, 'HK Status %')
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.scoring_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "scoring_config_read"  ON public.scoring_config;
DROP POLICY IF EXISTS "scoring_config_write" ON public.scoring_config;
CREATE POLICY "scoring_config_read" ON public.scoring_config FOR SELECT TO authenticated USING (true);
CREATE POLICY "scoring_config_write" ON public.scoring_config FOR ALL TO authenticated
  USING (public.has_any_role(ARRAY['admin']::public.user_role[]))
  WITH CHECK (public.has_any_role(ARRAY['admin']::public.user_role[]));

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602250004_room_layout.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Room Layout: floor_number, sort_order, wing
-- Phase F1: Add physical location data for proximity scoring
-- Created: 2026-02-25
-- =============================================================
-- sort_order = bay number from stair end (1 = closest to stair, ascending away)
-- wing: 'L' = left corridor, 'R' = right corridor, 'C' = single/no pair
-- Large rooms (Triple/Junior Suite) occupy 2 bays → sort_order uses the first bay number
-- Across-corridor pairs share the same sort_order
-- =============================================================

BEGIN;

-- ── Add columns to rooms ─────────────────────────────────────

ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS floor_number int,
  ADD COLUMN IF NOT EXISTS sort_order   int,
  ADD COLUMN IF NOT EXISTS wing         text CHECK (wing IN ('L', 'R', 'C'));

-- ── Floor 1 — Family Rooms (Building Annex) ──────────────────
-- 3 large Family rooms with angled/chevron walls
-- 110 = OOC normally, not for sale unless fully booked

UPDATE public.rooms SET floor_number=1, wing='L', sort_order=1 WHERE room_number='106';
UPDATE public.rooms SET floor_number=1, wing='C', sort_order=2 WHERE room_number='108';
UPDATE public.rooms SET floor_number=1, wing='R', sort_order=3 WHERE room_number='110';

-- ── Floor 2 — Main Building ───────────────────────────────────
-- LEFT wing: 202–226, ascending sort_order away from stair
-- RIGHT wing: 250–228, ascending sort_order away from stair (mirrors left)
-- Large rooms 206 (Triple) + 246 (Junior Suite) occupy sort_order 3 (2 bays wide)
-- 226 is at sort_order 13, single room (no pair across), wing='C'

-- Left wing (L)
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=1  WHERE room_number='202';
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=2  WHERE room_number='204';
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=3  WHERE room_number='206'; -- Triple Beds (2-bay room)
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=5  WHERE room_number='210';
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=6  WHERE room_number='212';
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=7  WHERE room_number='214';
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=8  WHERE room_number='216';
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=9  WHERE room_number='218';
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=10 WHERE room_number='220';
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=11 WHERE room_number='222';
UPDATE public.rooms SET floor_number=2, wing='L', sort_order=12 WHERE room_number='224';
UPDATE public.rooms SET floor_number=2, wing='C', sort_order=13 WHERE room_number='226'; -- single at end

-- Right wing (R) — mirrors left, same sort_order as across-corridor partner
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=1  WHERE room_number='250';
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=2  WHERE room_number='248';
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=3  WHERE room_number='246'; -- Junior Suite King (2-bay room)
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=5  WHERE room_number='242';
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=6  WHERE room_number='240';
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=7  WHERE room_number='238';
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=8  WHERE room_number='236';
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=9  WHERE room_number='234';
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=10 WHERE room_number='232';
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=11 WHERE room_number='230';
UPDATE public.rooms SET floor_number=2, wing='R', sort_order=12 WHERE room_number='228';

-- ── Floor 3 — Main Building (same layout as Floor 2) ─────────
-- 306 = Junior Suite King (L, sort=3), 346 = Triple Beds (R, sort=3)
-- 326 = single at end (C, sort=13)

-- Left wing (L)
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=1  WHERE room_number='302';
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=2  WHERE room_number='304';
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=3  WHERE room_number='306'; -- Junior Suite King (2-bay room)
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=5  WHERE room_number='310';
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=6  WHERE room_number='312';
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=7  WHERE room_number='314';
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=8  WHERE room_number='316';
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=9  WHERE room_number='318';
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=10 WHERE room_number='320';
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=11 WHERE room_number='322';
UPDATE public.rooms SET floor_number=3, wing='L', sort_order=12 WHERE room_number='324';
UPDATE public.rooms SET floor_number=3, wing='C', sort_order=13 WHERE room_number='326'; -- single at end

-- Right wing (R)
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=1  WHERE room_number='350';
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=2  WHERE room_number='348';
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=3  WHERE room_number='346'; -- Triple Beds (2-bay room)
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=5  WHERE room_number='342';
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=6  WHERE room_number='340';
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=7  WHERE room_number='338';
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=8  WHERE room_number='336';
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=9  WHERE room_number='334';
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=10 WHERE room_number='332';
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=11 WHERE room_number='330';
UPDATE public.rooms SET floor_number=3, wing='R', sort_order=12 WHERE room_number='328';

-- ── Indexes ───────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_rooms_floor_sort ON public.rooms(floor_number, sort_order);
CREATE INDEX IF NOT EXISTS idx_rooms_floor_wing  ON public.rooms(floor_number, wing);

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602250005_room_layout_fix.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Fix 1: 226 and 326 are end of left corridor (not solo/center)
-- Fix 2: F1 rooms 106/108 sort_order correction
BEGIN;
UPDATE public.rooms SET wing = 'L' WHERE room_number IN ('226', '326');
-- Correct sort_order for F1: 106 closest to entrance
UPDATE public.rooms SET wing = 'L' WHERE room_number IN ('106', '108', '110');
UPDATE public.rooms SET sort_order = 1 WHERE room_number = '106';
UPDATE public.rooms SET sort_order = 2 WHERE room_number = '108';
UPDATE public.rooms SET sort_order = 3 WHERE room_number = '110';
COMMIT;




-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602250006_uuid_standardize.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Phase A: UUID Standardization (Idempotent version)
-- Migrate room_feature_mapping + room_blocks from room_number text FK → room_id UUID
-- Safe to run even if columns already exist or were never created
-- Created: 2026-02-25  Fixed: 2026-02-25
-- =============================================================

BEGIN;

-- ── 1. room_feature_mapping ──────────────────────────────────

-- Step 1a: Add room_id column if not present
ALTER TABLE public.room_feature_mapping
  ADD COLUMN IF NOT EXISTS room_id uuid REFERENCES public.rooms(id) ON DELETE CASCADE;

-- Step 1b–1f: Only backfill from room_number if that column still exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'room_feature_mapping'
      AND column_name  = 'room_number'
  ) THEN
    -- Backfill room_id from rooms.room_number
    UPDATE public.room_feature_mapping rfm
    SET room_id = r.id
    FROM public.rooms r
    WHERE r.room_number = rfm.room_number
      AND rfm.room_id IS NULL;

    -- Drop orphan rows
    DELETE FROM public.room_feature_mapping WHERE room_id IS NULL;

    -- Drop old PK and replace
    ALTER TABLE public.room_feature_mapping DROP CONSTRAINT IF EXISTS room_feature_mapping_pkey;
    ALTER TABLE public.room_feature_mapping ADD PRIMARY KEY (room_id, feature_code);

    -- Drop old column
    ALTER TABLE public.room_feature_mapping DROP COLUMN room_number;
  END IF;
END $$;

-- Ensure room_id is NOT NULL (in case backfill wasn't needed but col was just added)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'room_feature_mapping'
      AND column_name  = 'room_id'
      AND is_nullable  = 'YES'
  ) THEN
    -- Only set NOT NULL if all rows have room_id
    IF NOT EXISTS (SELECT 1 FROM public.room_feature_mapping WHERE room_id IS NULL) THEN
      ALTER TABLE public.room_feature_mapping ALTER COLUMN room_id SET NOT NULL;
    END IF;
  END IF;
END $$;

-- Ensure PK exists
ALTER TABLE public.room_feature_mapping DROP CONSTRAINT IF EXISTS room_feature_mapping_pkey;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.room_feature_mapping'::regclass
      AND contype = 'p'
  ) THEN
    ALTER TABLE public.room_feature_mapping ADD PRIMARY KEY (room_id, feature_code);
  END IF;
END $$;

-- ── 2. room_blocks ───────────────────────────────────────────

-- Step 2a: Add room_id column if not present
ALTER TABLE public.room_blocks
  ADD COLUMN IF NOT EXISTS room_id uuid REFERENCES public.rooms(id) ON DELETE CASCADE;

-- Step 2b–2c: Only backfill from room_number if that column still exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'room_blocks'
      AND column_name  = 'room_number'
  ) THEN
    -- Backfill room_id from rooms.room_number
    UPDATE public.room_blocks rb
    SET room_id = r.id
    FROM public.rooms r
    WHERE r.room_number = rb.room_number
      AND rb.room_id IS NULL;

    -- Drop old column
    ALTER TABLE public.room_blocks DROP COLUMN room_number;
  END IF;
END $$;

-- ── 3. reservation_preferences — already uses reservation_id (UUID), no change needed

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602260001_complete_uuid_standardize.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Phase A Final: Complete UUID Standardization
-- Drops functions with p_room_number and recreates them with p_room_id UUID
-- Created: 2026-02-26
-- =============================================================

BEGIN;

-- Drop old functions
DROP FUNCTION IF EXISTS public.booking_create_reservation(text, date, date, text, bigint, public.booking_source, text, text, text, numeric[], uuid);
DROP FUNCTION IF EXISTS public.booking_update_reservation(uuid, text, date, date, text, bigint, public.booking_source, text, text, text, numeric[], uuid);

-- 1. Create booking_create_reservation with p_room_id
CREATE OR REPLACE FUNCTION public.booking_create_reservation(
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_id uuid DEFAULT NULL,
  p_room_type_id bigint DEFAULT NULL,
  p_source public.booking_source DEFAULT 'walkin',
  p_phone text DEFAULT NULL,
  p_checkin_time text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_ota_prices numeric[] DEFAULT NULL,
  p_actor_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_reservation_id uuid;
  v_booking_code text;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_capacity_date date;
  v_room_capacity int;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
  v_block_reason text;
BEGIN
  IF p_guest_name IS NULL OR btrim(p_guest_name) = '' THEN
    RAISE EXCEPTION 'guest_name is required';
  END IF;

  IF p_room_id IS NULL AND p_room_type_id IS NULL THEN
    RAISE EXCEPTION 'Either room_id or room_type_id is required';
  END IF;

  IF p_checkout_date <= p_checkin_date THEN
    RAISE EXCEPTION 'checkout_date must be after checkin_date';
  END IF;

  -- 1. Resolve Room & Room Type
  IF p_room_id IS NOT NULL THEN
    SELECT * INTO v_room
    FROM public.rooms
    WHERE id = p_room_id
    FOR UPDATE;

    IF NOT found THEN
      RAISE EXCEPTION 'Room not found';
    END IF;

    IF NOT v_room.is_sellable THEN
      RAISE EXCEPTION 'Room % is not sellable', v_room.room_number;
    END IF;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  ELSE
    v_room_id := NULL;
    v_effective_room_type_id := p_room_type_id;

    -- Pick any room of this type to use for pricing templates
    SELECT id INTO v_pricing_room_id
    FROM public.rooms
    WHERE room_type_id = p_room_type_id
      AND is_sellable = true
    LIMIT 1;

    IF v_pricing_room_id IS NULL THEN
      RAISE EXCEPTION 'No rooms found for room_type_id: %', p_room_type_id;
    END IF;
  END IF;

  -- 2. Generate Dates
  SELECT COALESCE(array_agg(day::date ORDER BY day::date), ARRAY[]::date[])
  INTO v_night_dates
  FROM generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - INTERVAL '1 day')::timestamp,
    INTERVAL '1 day'
  ) AS day;

  v_nights_count := cardinality(v_night_dates);
  IF v_nights_count = 0 THEN
    RAISE EXCEPTION 'No nights generated for selected date range';
  END IF;

  -- 3. Check Conflicts (specific room) OR Capacity (floating booking)
  IF v_room_id IS NOT NULL THEN
    SELECT rn.stay_date INTO v_conflict_date
    FROM public.reservation_nights rn
    WHERE rn.room_id = v_room_id
      AND rn.cancelled_at IS NULL
      AND rn.stay_date = ANY(v_night_dates)
    LIMIT 1;

    IF v_conflict_date IS NOT NULL THEN
      RAISE EXCEPTION 'Room % already booked on %', v_room.room_number, v_conflict_date;
    END IF;

    -- Check Room Blocks (OOO only)
    SELECT start_date, reason
    INTO v_conflict_date, v_block_reason
    FROM public.room_blocks
    WHERE room_id = v_room_id
      AND block_type = 'OOO'
      AND (
          (start_date <= p_checkin_date AND end_date > p_checkin_date) OR
          (start_date < p_checkout_date AND end_date >= p_checkout_date) OR
          (start_date >= p_checkin_date AND end_date <= p_checkout_date)
      )
    LIMIT 1;

    IF v_conflict_date IS NOT NULL THEN
      RAISE EXCEPTION 'Room % is Out of Order (OOO) during this period. Reason: %', v_room.room_number, v_block_reason;
    END IF;
  ELSE
    -- Floating booking: check per-night capacity
    SELECT COUNT(*) INTO v_room_capacity
    FROM public.rooms
    WHERE room_type_id = v_effective_room_type_id
      AND is_sellable = true;

    SELECT d INTO v_capacity_date
    FROM unnest(v_night_dates) AS d
    WHERE (
      SELECT COUNT(DISTINCT rn.reservation_id)
      FROM public.reservation_nights rn
      WHERE rn.room_type_id = v_effective_room_type_id
        AND rn.stay_date = d
        AND rn.cancelled_at IS NULL
    ) >= v_room_capacity
    LIMIT 1;

    IF v_capacity_date IS NOT NULL THEN
      RAISE EXCEPTION 'No availability: all % rooms of this type are fully booked on %', v_room_capacity, v_capacity_date;
    END IF;
  END IF;

  -- 4. Calculate Prices
  IF p_source = 'ota' THEN
    IF p_ota_prices IS NULL OR cardinality(p_ota_prices) <> v_nights_count THEN
      RAISE EXCEPTION 'OTA bookings require ota_prices length = %', v_nights_count;
    END IF;

    SELECT COALESCE(array_agg(round(COALESCE(ota.price, 0)::numeric, 2) ORDER BY ota.idx), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(p_ota_prices) WITH ORDINALITY AS ota(price, idx);
  ELSE
    SELECT COALESCE(array_agg(COALESCE(rt.price, 0)::numeric(10, 2) ORDER BY d.stay_date), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(v_night_dates) AS d(stay_date)
    LEFT JOIN public.rate_templates rt
      ON rt.room_id = v_pricing_room_id
     AND rt.stay_date = d.stay_date;
  END IF;

  SELECT round(COALESCE(sum(COALESCE(price, 0)), 0)::numeric, 2)
  INTO v_total_price
  FROM unnest(v_prices) AS p(price);

  -- 5. Insert Reservation
  v_booking_code := public.generate_booking_code();
  v_normalized_phone := nullif(btrim(COALESCE(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(COALESCE(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(COALESCE(p_note, '')), '');

  INSERT INTO public.reservations (
    booking_code, guest_name, phone, source, status,
    checkin_date, checkout_date, checkin_time, note,
    total_price, created_by, updated_by
  ) VALUES (
    v_booking_code,
    btrim(p_guest_name),
    v_normalized_phone,
    p_source,
    'active',
    p_checkin_date,
    p_checkout_date,
    v_normalized_checkin_time,
    v_normalized_note,
    v_total_price,
    p_actor_user_id,
    p_actor_user_id
  )
  RETURNING id INTO v_reservation_id;

  -- 6. Insert Reservation Nights
  INSERT INTO public.reservation_nights (
    reservation_id, room_id, room_type_id, stay_date, nightly_price, is_ota
  )
  SELECT
    v_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(COALESCE(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  FROM unnest(v_night_dates) WITH ORDINALITY AS d(stay_date, idx)
  JOIN unnest(v_prices) WITH ORDINALITY AS pr(price, idx)
    ON pr.idx = d.idx;

  -- 7. Audit Log
  INSERT INTO public.audit_logs (actor_user_id, action, entity_type, entity_id, after_json)
  VALUES (
    p_actor_user_id,
    'booking_created',
    'reservation',
    v_reservation_id::text,
    jsonb_build_object(
      'booking_code', v_booking_code,
      'room_id', p_room_id,
      'room_type_id', v_effective_room_type_id,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price
    )
  );

  RETURN jsonb_build_object(
    'id', v_reservation_id,
    'booking_code', v_booking_code,
    'guest_name', btrim(p_guest_name),
    'room_id', p_room_id,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
END;
$$;


-- 2. Create booking_update_reservation with p_room_id
CREATE OR REPLACE FUNCTION public.booking_update_reservation(
  p_reservation_id uuid,
  p_guest_name text,
  p_checkin_date date,
  p_checkout_date date,
  p_room_id uuid DEFAULT NULL,
  p_room_type_id bigint DEFAULT NULL,
  p_source public.booking_source DEFAULT 'walkin',
  p_phone text DEFAULT NULL,
  p_checkin_time text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_ota_prices numeric[] DEFAULT NULL,
  p_actor_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_reservation public.reservations%rowtype;
  v_room public.rooms%rowtype;
  v_room_id uuid;
  v_effective_room_type_id bigint;
  v_pricing_room_id uuid;
  v_night_dates date[];
  v_nights_count int;
  v_prices numeric[];
  v_total_price numeric(10, 2);
  v_conflict_date date;
  v_capacity_date date;
  v_room_capacity int;
  v_replaced_nights int;
  v_cancelled_at timestamptz;
  v_before jsonb;
  v_normalized_phone text;
  v_normalized_checkin_time text;
  v_normalized_note text;
  v_block_reason text;
BEGIN
  IF p_guest_name IS NULL OR btrim(p_guest_name) = '' THEN
    RAISE EXCEPTION 'guest_name is required';
  END IF;

  IF p_room_id IS NULL AND p_room_type_id IS NULL THEN
    RAISE EXCEPTION 'Either room_id or room_type_id is required';
  END IF;

  IF p_checkout_date <= p_checkin_date THEN
    RAISE EXCEPTION 'checkout_date must be after checkin_date';
  END IF;

  SELECT * INTO v_reservation
  FROM public.reservations
  WHERE id = p_reservation_id
  FOR UPDATE;

  IF NOT found THEN
    RAISE EXCEPTION 'Reservation not found';
  END IF;

  IF v_reservation.status <> 'active' THEN
    RAISE EXCEPTION 'Reservation is not active';
  END IF;

  -- 1. Resolve Room & Room Type
  IF p_room_id IS NOT NULL THEN
    SELECT * INTO v_room
    FROM public.rooms
    WHERE id = p_room_id
    FOR UPDATE;

    IF NOT found THEN
      RAISE EXCEPTION 'Room not found';
    END IF;

    IF NOT v_room.is_sellable THEN
      RAISE EXCEPTION 'Room % is not sellable', v_room.room_number;
    END IF;

    v_room_id := v_room.id;
    v_effective_room_type_id := v_room.room_type_id;
    v_pricing_room_id := v_room.id;
  ELSE
    v_room_id := NULL;
    v_effective_room_type_id := p_room_type_id;

    SELECT id INTO v_pricing_room_id
    FROM public.rooms
    WHERE room_type_id = p_room_type_id
      AND is_sellable = true
    LIMIT 1;

    IF v_pricing_room_id IS NULL THEN
      RAISE EXCEPTION 'No rooms found for room_type_id: %', p_room_type_id;
    END IF;
  END IF;

  -- 2. Generate Dates
  SELECT COALESCE(array_agg(day::date ORDER BY day::date), ARRAY[]::date[])
  INTO v_night_dates
  FROM generate_series(
    p_checkin_date::timestamp,
    (p_checkout_date - INTERVAL '1 day')::timestamp,
    INTERVAL '1 day'
  ) AS day;

  v_nights_count := cardinality(v_night_dates);
  IF v_nights_count = 0 THEN
    RAISE EXCEPTION 'No nights generated for selected date range';
  END IF;

  -- 3. Conflict or Capacity check
  IF v_room_id IS NOT NULL THEN
    SELECT rn.stay_date INTO v_conflict_date
    FROM public.reservation_nights rn
    WHERE rn.room_id = v_room_id
      AND rn.cancelled_at IS NULL
      AND rn.stay_date = ANY(v_night_dates)
      AND rn.reservation_id <> p_reservation_id
    LIMIT 1;

    IF v_conflict_date IS NOT NULL THEN
      RAISE EXCEPTION 'Room % already booked on %', v_room.room_number, v_conflict_date;
    END IF;

    -- Check Room Blocks (OOO only)
    SELECT start_date, reason
    INTO v_conflict_date, v_block_reason
    FROM public.room_blocks
    WHERE room_id = v_room_id
      AND block_type = 'OOO'
      AND (
          (start_date <= p_checkin_date AND end_date > p_checkin_date) OR
          (start_date < p_checkout_date AND end_date >= p_checkout_date) OR
          (start_date >= p_checkin_date AND end_date <= p_checkout_date)
      )
    LIMIT 1;

    IF v_conflict_date IS NOT NULL THEN
      RAISE EXCEPTION 'Room % is Out of Order (OOO) during this period. Reason: %', v_room.room_number, v_block_reason;
    END IF;
  ELSE
    -- Capacity check: exclude THIS reservation's existing nights from count
    SELECT COUNT(*) INTO v_room_capacity
    FROM public.rooms
    WHERE room_type_id = v_effective_room_type_id
      AND is_sellable = true;

    SELECT d INTO v_capacity_date
    FROM unnest(v_night_dates) AS d
    WHERE (
      SELECT COUNT(DISTINCT rn.reservation_id)
      FROM public.reservation_nights rn
      WHERE rn.room_type_id = v_effective_room_type_id
        AND rn.stay_date = d
        AND rn.cancelled_at IS NULL
        AND rn.reservation_id <> p_reservation_id  -- exclude self
    ) >= v_room_capacity
    LIMIT 1;

    IF v_capacity_date IS NOT NULL THEN
      RAISE EXCEPTION 'No availability: all % rooms of this type are fully booked on %', v_room_capacity, v_capacity_date;
    END IF;
  END IF;

  -- 4. Calculate Prices
  IF p_source = 'ota' THEN
    IF p_ota_prices IS NULL OR cardinality(p_ota_prices) <> v_nights_count THEN
      RAISE EXCEPTION 'OTA bookings require ota_prices length = %', v_nights_count;
    END IF;

    SELECT COALESCE(array_agg(round(COALESCE(ota.price, 0)::numeric, 2) ORDER BY ota.idx), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(p_ota_prices) WITH ORDINALITY AS ota(price, idx);
  ELSE
    SELECT COALESCE(array_agg(COALESCE(rt.price, 0)::numeric(10, 2) ORDER BY d.stay_date), ARRAY[]::numeric[])
    INTO v_prices
    FROM unnest(v_night_dates) AS d(stay_date)
    LEFT JOIN public.rate_templates rt
      ON rt.room_id = v_pricing_room_id
     AND rt.stay_date = d.stay_date;
  END IF;

  SELECT round(COALESCE(sum(COALESCE(price, 0)), 0)::numeric, 2)
  INTO v_total_price
  FROM unnest(v_prices) AS p(price);

  v_before := jsonb_build_object(
    'guest_name', v_reservation.guest_name,
    'source', v_reservation.source,
    'checkin_date', v_reservation.checkin_date,
    'checkout_date', v_reservation.checkout_date,
    'total_price', v_reservation.total_price
  );

  -- 5. Cancel old nights
  v_cancelled_at := timezone('utc', now());
  UPDATE public.reservation_nights
  SET cancelled_at = v_cancelled_at
  WHERE reservation_id = p_reservation_id
    AND cancelled_at IS NULL;
  GET DIAGNOSTICS v_replaced_nights = ROW_COUNT;

  -- 6. Update Reservation
  v_normalized_phone := nullif(btrim(COALESCE(p_phone, '')), '');
  v_normalized_checkin_time := nullif(btrim(COALESCE(p_checkin_time, '')), '');
  v_normalized_note := nullif(btrim(COALESCE(p_note, '')), '');

  UPDATE public.reservations SET
    guest_name = btrim(p_guest_name),
    phone = v_normalized_phone,
    source = p_source,
    checkin_date = p_checkin_date,
    checkout_date = p_checkout_date,
    checkin_time = v_normalized_checkin_time,
    note = v_normalized_note,
    total_price = v_total_price,
    updated_by = COALESCE(p_actor_user_id, updated_by)
  WHERE id = p_reservation_id;

  -- 7. Insert New Nights
  INSERT INTO public.reservation_nights (
    reservation_id, room_id, room_type_id, stay_date, nightly_price, is_ota
  )
  SELECT
    p_reservation_id,
    v_room_id,
    v_effective_room_type_id,
    d.stay_date,
    round(COALESCE(pr.price, 0)::numeric, 2),
    p_source = 'ota'
  FROM unnest(v_night_dates) WITH ORDINALITY AS d(stay_date, idx)
  JOIN unnest(v_prices) WITH ORDINALITY AS pr(price, idx)
    ON pr.idx = d.idx;

  -- 8. Audit Log
  INSERT INTO public.audit_logs (actor_user_id, action, entity_type, entity_id, before_json, after_json)
  VALUES (
    p_actor_user_id,
    'booking_updated',
    'reservation',
    p_reservation_id::text,
    v_before,
    jsonb_build_object(
      'room_id', p_room_id,
      'room_type_id', v_effective_room_type_id,
      'source', p_source,
      'checkin_date', p_checkin_date,
      'checkout_date', p_checkout_date,
      'total_price', v_total_price,
      'replaced_nights', v_replaced_nights
    )
  );

  RETURN jsonb_build_object(
    'id', p_reservation_id,
    'booking_code', v_reservation.booking_code,
    'guest_name', btrim(p_guest_name),
    'room_id', p_room_id,
    'room_type_id', v_effective_room_type_id,
    'source', p_source,
    'checkin_date', p_checkin_date,
    'checkout_date', p_checkout_date,
    'total_nights', v_nights_count,
    'nightly_prices', to_jsonb(v_prices),
    'total_price', v_total_price
  );
END;
$$;

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602260002_group_booking.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Group Booking table
CREATE TABLE IF NOT EXISTS booking_groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_code  TEXT NOT NULL UNIQUE,
  group_name  TEXT NOT NULL,            -- e.g. "Wang Family Reunion"
  contact_name TEXT,
  contact_phone TEXT,
  contact_email TEXT,
  source      booking_source NOT NULL DEFAULT 'direct',
  note        TEXT,
  total_rooms INT NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','cancelled','completed')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Link reservations to group
ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS booking_group_id UUID REFERENCES booking_groups(id);

CREATE INDEX IF NOT EXISTS idx_reservations_group
  ON reservations(booking_group_id) WHERE booking_group_id IS NOT NULL;

-- Auto-generate group code
CREATE OR REPLACE FUNCTION generate_group_code()
RETURNS TRIGGER AS $$
BEGIN
  NEW.group_code := 'GRP-' || TO_CHAR(NOW(), 'YYMMDD') || '-' ||
    LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_group_code
  BEFORE INSERT ON booking_groups
  FOR EACH ROW
  WHEN (NEW.group_code IS NULL OR NEW.group_code = '')
  EXECUTE FUNCTION generate_group_code();



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602260003_phase1_enhancements.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Migration: Phase 1 Enhancements
-- Date:      2026-02-26
-- Purpose:
--   1. Add discount fields to reservations
--   2. Add checked_in_at timestamp
--   3. Add guest identity fields (address, ID card)
--   4. RLS policies for new tables
-- =============================================================

-- 1. Discount fields on reservations
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS discount_percent numeric(5,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_reason  text;

-- 2. Check-in timestamp
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS checked_in_at timestamptz;

-- Index for quickly finding checked-in reservations
CREATE INDEX IF NOT EXISTS idx_reservations_checked_in
  ON public.reservations (checked_in_at)
  WHERE checked_in_at IS NOT NULL;

-- 3. Guest identity fields (for check-in ID/passport flow)
ALTER TABLE public.guest_profiles
  ADD COLUMN IF NOT EXISTS id_card_number text,
  ADD COLUMN IF NOT EXISTS address_line1  text,
  ADD COLUMN IF NOT EXISTS address_line2  text,
  ADD COLUMN IF NOT EXISTS city           text,
  ADD COLUMN IF NOT EXISTS province       text,
  ADD COLUMN IF NOT EXISTS postal_code    text,
  ADD COLUMN IF NOT EXISTS country        text;

-- 4. Stay count on guest profiles (for loyalty tracking)
ALTER TABLE public.guest_profiles
  ADD COLUMN IF NOT EXISTS stay_count integer NOT NULL DEFAULT 0;

-- =============================================================
-- VERIFY:
--   SELECT column_name, data_type, column_default
--   FROM information_schema.columns
--   WHERE table_name = 'reservations'
--     AND column_name IN ('discount_percent', 'discount_reason', 'checked_in_at');
--
--   SELECT column_name, data_type
--   FROM information_schema.columns
--   WHERE table_name = 'guest_profiles'
--     AND column_name IN ('id_card_number', 'address_line1', 'country', 'stay_count');
-- =============================================================



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602260004_rate_plans.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Migration: Rate Plans / Special Rates
-- Date:      2026-02-26
-- Purpose:
--   1) Add configurable rate plan table
--   2) Link reservations to selected rate plan
--   3) Seed default plans (RACK, DIRECT, LONGSTAY, VIP, PROMO)
--
-- Note:
--   room_types.id is BIGINT in current schema, so apply_to_room_types
--   uses BIGINT[] instead of UUID[].
-- =============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.rate_plans (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                 text NOT NULL UNIQUE,
  name_en              text NOT NULL,
  name_th              text,
  description          text,
  discount_type        text NOT NULL DEFAULT 'percent'
    CHECK (discount_type IN ('percent', 'fixed', 'override')),
  discount_value       numeric(10,2) NOT NULL DEFAULT 0,
  min_nights           int NOT NULL DEFAULT 1,
  max_nights           int,
  valid_from           date,
  valid_until          date,
  is_active            boolean NOT NULL DEFAULT true,
  apply_to_room_types  bigint[],
  sort_order           int NOT NULL DEFAULT 0,
  created_at           timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at           timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT chk_rate_plans_min_nights CHECK (min_nights >= 1),
  CONSTRAINT chk_rate_plans_max_nights CHECK (max_nights IS NULL OR max_nights >= min_nights),
  CONSTRAINT chk_rate_plans_valid_range CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from),
  CONSTRAINT chk_rate_plans_discount_value_non_negative CHECK (discount_value >= 0)
);

CREATE INDEX IF NOT EXISTS idx_rate_plans_active
  ON public.rate_plans (is_active, sort_order, code);

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS rate_plan_id uuid REFERENCES public.rate_plans(id);

CREATE INDEX IF NOT EXISTS idx_reservations_rate_plan
  ON public.reservations (rate_plan_id)
  WHERE rate_plan_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_rate_plans_updated_at ON public.rate_plans;
CREATE TRIGGER trg_rate_plans_updated_at
BEFORE UPDATE ON public.rate_plans
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

INSERT INTO public.rate_plans (
  code, name_en, name_th, discount_type, discount_value, min_nights, sort_order
)
VALUES
  ('RACK',     'Rack Rate',   'ราคาปกติ',      'percent', 0,  1, 0),
  ('DIRECT',   'Direct Rate', 'ราคาจองตรง',    'percent', 10, 1, 1),
  ('LONGSTAY', 'Long Stay',   'ราคาพักยาว',    'percent', 20, 7, 2),
  ('VIP',      'VIP Rate',    'ราคา VIP',      'percent', 25, 1, 3),
  ('PROMO',    'Promotion',   'ราคาโปรโมชั่น', 'percent', 15, 1, 4)
ON CONFLICT (code) DO NOTHING;

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602280001_daily_plan_atomic_rpc.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Ensure daily plan save is atomic (single transaction)

CREATE OR REPLACE FUNCTION public.hk_save_daily_plan(
  p_date date,
  p_assignments jsonb DEFAULT '[]'::jsonb
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'p_date is required';
  END IF;

  IF p_assignments IS NULL THEN
    p_assignments := '[]'::jsonb;
  END IF;

  IF jsonb_typeof(p_assignments) <> 'array' THEN
    RAISE EXCEPTION 'p_assignments must be a JSON array';
  END IF;

  CREATE TEMP TABLE tmp_daily_plan_assignments (
    room_id uuid PRIMARY KEY,
    assigned_maid text NOT NULL,
    priority integer NOT NULL
  ) ON COMMIT DROP;

  INSERT INTO tmp_daily_plan_assignments (room_id, assigned_maid, priority)
  SELECT
    (item ->> 'room_id')::uuid AS room_id,
    trim(item ->> 'assigned_maid') AS assigned_maid,
    (item ->> 'priority')::integer AS priority
  FROM jsonb_array_elements(p_assignments) AS item;

  IF EXISTS (
    SELECT 1
    FROM tmp_daily_plan_assignments
    WHERE assigned_maid = ''
  ) THEN
    RAISE EXCEPTION 'assigned_maid is required for all assignments';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_daily_plan_assignments
    WHERE priority < 1 OR priority > 15
  ) THEN
    RAISE EXCEPTION 'priority must be between 1 and 15';
  END IF;

  DELETE FROM public.daily_plans dp
  WHERE dp.plan_date = p_date
    AND NOT EXISTS (
      SELECT 1
      FROM tmp_daily_plan_assignments t
      WHERE t.room_id = dp.room_id
    );

  INSERT INTO public.daily_plans (plan_date, room_id, assigned_maid, priority)
  SELECT p_date, room_id, assigned_maid, priority
  FROM tmp_daily_plan_assignments
  ON CONFLICT (plan_date, room_id) DO UPDATE
  SET
    assigned_maid = EXCLUDED.assigned_maid,
    priority = EXCLUDED.priority;

  SELECT count(*) INTO v_count FROM tmp_daily_plan_assignments;
  RETURN v_count;
END;
$$;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202602280002_housekeeping_phase6.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 6: Housekeeping System Foundation
-- Adds timer/NS/checklist support to housekeeping_tasks
-- Creates 7 new tables for daily plans, extra tasks, stock, checklists
begin;

-- ============================================================
-- 1. ALTER existing tables
-- ============================================================

-- housekeeping_tasks: timer tracking, no-service flag, checklist snapshot, maid name (text)
-- NOTE: assigned_maid (uuid) already exists for future auth; we add assigned_maid_name (text) for current use
ALTER TABLE public.housekeeping_tasks
  ADD COLUMN IF NOT EXISTS accumulated_ms bigint NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_no_service boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS checklist_snapshot jsonb,
  ADD COLUMN IF NOT EXISTS assigned_maid_name text;

-- room_types: cleaning duration per room type
ALTER TABLE public.room_types
  ADD COLUMN IF NOT EXISTS cleaning_duration_min int NOT NULL DEFAULT 60;

-- Seed cleaning durations based on REAL room type codes (from seed.sql)
-- TS=Twin Standard, DS=Double Standard, DQ=Deluxe Queen, DT=Deluxe Twin
-- JS=Junior Suite, TB=Triple Beds, FR=Family Room
UPDATE public.room_types SET cleaning_duration_min = 60  WHERE code IN ('TS', 'DS');
UPDATE public.room_types SET cleaning_duration_min = 60  WHERE code IN ('DQ', 'DT');
UPDATE public.room_types SET cleaning_duration_min = 90  WHERE code IN ('JS', 'TB');
UPDATE public.room_types SET cleaning_duration_min = 100 WHERE code = 'FR';

-- ============================================================
-- 2. CREATE new tables
-- ============================================================

-- checklist_templates: Room amenity checklist items per room type
CREATE TABLE IF NOT EXISTS public.checklist_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_type_code text NOT NULL,
  item_name text NOT NULL,
  default_quantity int NOT NULL DEFAULT 1,
  category text NOT NULL DEFAULT 'General',
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (room_type_code, item_name)
);

-- daily_plans: Maid-to-room assignment per day (priority 1-15)
CREATE TABLE IF NOT EXISTS public.daily_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_date date NOT NULL,
  room_id uuid NOT NULL REFERENCES public.rooms(id),
  assigned_maid text NOT NULL,
  priority int NOT NULL DEFAULT 1 CHECK (priority >= 1 AND priority <= 15),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (plan_date, room_id)
);

-- extra_task_templates: Reusable extra task definitions
CREATE TABLE IF NOT EXISTS public.extra_task_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  duration_min int NOT NULL DEFAULT 60,
  category text NOT NULL DEFAULT 'General',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- extra_task_assignments: Daily task assignment to maid
CREATE TABLE IF NOT EXISTS public.extra_task_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_date date NOT NULL,
  template_id uuid REFERENCES public.extra_task_templates(id),
  task_name text NOT NULL,
  assigned_maid text NOT NULL DEFAULT 'Others',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','paused','done','cancelled')),
  priority int NOT NULL DEFAULT 999,
  duration_min int NOT NULL DEFAULT 60,
  started_at timestamptz,
  finished_at timestamptz,
  accumulated_ms bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (assignment_date, task_name)
);

-- stock_items: Inventory levels
CREATE TABLE IF NOT EXISTS public.stock_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_name text NOT NULL UNIQUE,
  current_quantity int NOT NULL DEFAULT 0,
  unit text NOT NULL DEFAULT 'pieces',
  reorder_level int NOT NULL DEFAULT 10,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- maid_cart_items: Per-maid cart inventory
CREATE TABLE IF NOT EXISTS public.maid_cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  maid_name text NOT NULL,
  item_name text NOT NULL,
  quantity int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (maid_name, item_name)
);

-- stock_transactions: Audit trail for all stock changes
CREATE TABLE IF NOT EXISTS public.stock_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_date date NOT NULL DEFAULT current_date,
  action text NOT NULL CHECK (action IN ('refill','use','extra_request','adjust')),
  maid_name text,
  item_name text NOT NULL,
  quantity_change int NOT NULL,
  room_number text,
  note text,
  actor text NOT NULL DEFAULT 'system',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

-- ============================================================
-- 3. Triggers (updated_at) using existing set_updated_at()
-- ============================================================

DROP TRIGGER IF EXISTS trg_daily_plans_updated_at ON public.daily_plans;
CREATE TRIGGER trg_daily_plans_updated_at
BEFORE UPDATE ON public.daily_plans
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_extra_task_assignments_updated_at ON public.extra_task_assignments;
CREATE TRIGGER trg_extra_task_assignments_updated_at
BEFORE UPDATE ON public.extra_task_assignments
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- 4. Seed checklist_templates (Standard room — expand per type)
-- ============================================================

-- Real room type codes: TS, DS, DQ, DT, JS, TB, FR (from seed.sql)
INSERT INTO public.checklist_templates (room_type_code, item_name, default_quantity, category, sort_order) VALUES
  -- TS (Twin Standard — 2 beds, 2 guests)
  ('TS', 'Make Bed', 1, 'Bed', 1),
  ('TS', 'Change Sheets', 1, 'Bed', 2),
  ('TS', 'Pillow Case', 2, 'Bed', 3),
  ('TS', 'Bath Towel', 2, 'Bathroom', 10),
  ('TS', 'Hand Towel', 2, 'Bathroom', 11),
  ('TS', 'Floor Mat', 1, 'Bathroom', 12),
  ('TS', 'Tissue Box', 1, 'Bathroom', 13),
  ('TS', 'Toilet Paper', 1, 'Bathroom', 14),
  ('TS', 'Soap', 2, 'Amenity', 20),
  ('TS', 'Shampoo', 2, 'Amenity', 21),
  ('TS', 'Water Bottle', 2, 'Amenity', 22),
  ('TS', 'Trash Bin', 1, 'Room', 30),
  ('TS', 'Vacuum', 1, 'Room', 31),
  ('TS', 'Mop Floor', 1, 'Room', 32),
  -- DS (Double Standard — 1 bed, 2 guests)
  ('DS', 'Make Bed', 1, 'Bed', 1),
  ('DS', 'Change Sheets', 1, 'Bed', 2),
  ('DS', 'Pillow Case', 2, 'Bed', 3),
  ('DS', 'Bath Towel', 2, 'Bathroom', 10),
  ('DS', 'Hand Towel', 2, 'Bathroom', 11),
  ('DS', 'Floor Mat', 1, 'Bathroom', 12),
  ('DS', 'Tissue Box', 1, 'Bathroom', 13),
  ('DS', 'Toilet Paper', 1, 'Bathroom', 14),
  ('DS', 'Soap', 2, 'Amenity', 20),
  ('DS', 'Shampoo', 2, 'Amenity', 21),
  ('DS', 'Water Bottle', 2, 'Amenity', 22),
  ('DS', 'Trash Bin', 1, 'Room', 30),
  ('DS', 'Vacuum', 1, 'Room', 31),
  ('DS', 'Mop Floor', 1, 'Room', 32),
  -- DQ (Deluxe Queen)
  ('DQ', 'Make Bed', 1, 'Bed', 1),
  ('DQ', 'Change Sheets', 1, 'Bed', 2),
  ('DQ', 'Pillow Case', 2, 'Bed', 3),
  ('DQ', 'Bath Towel', 2, 'Bathroom', 10),
  ('DQ', 'Hand Towel', 2, 'Bathroom', 11),
  ('DQ', 'Floor Mat', 1, 'Bathroom', 12),
  ('DQ', 'Tissue Box', 1, 'Bathroom', 13),
  ('DQ', 'Toilet Paper', 1, 'Bathroom', 14),
  ('DQ', 'Soap', 2, 'Amenity', 20),
  ('DQ', 'Shampoo', 2, 'Amenity', 21),
  ('DQ', 'Water Bottle', 2, 'Amenity', 22),
  ('DQ', 'Trash Bin', 1, 'Room', 30),
  ('DQ', 'Vacuum', 1, 'Room', 31),
  ('DQ', 'Mop Floor', 1, 'Room', 32),
  -- DT (Deluxe Twin)
  ('DT', 'Make Bed', 1, 'Bed', 1),
  ('DT', 'Change Sheets', 1, 'Bed', 2),
  ('DT', 'Pillow Case', 2, 'Bed', 3),
  ('DT', 'Bath Towel', 2, 'Bathroom', 10),
  ('DT', 'Hand Towel', 2, 'Bathroom', 11),
  ('DT', 'Floor Mat', 1, 'Bathroom', 12),
  ('DT', 'Tissue Box', 1, 'Bathroom', 13),
  ('DT', 'Toilet Paper', 1, 'Bathroom', 14),
  ('DT', 'Soap', 2, 'Amenity', 20),
  ('DT', 'Shampoo', 2, 'Amenity', 21),
  ('DT', 'Water Bottle', 2, 'Amenity', 22),
  ('DT', 'Trash Bin', 1, 'Room', 30),
  ('DT', 'Vacuum', 1, 'Room', 31),
  ('DT', 'Mop Floor', 1, 'Room', 32),
  -- JS (Junior Suite — larger, 90min)
  ('JS', 'Make Bed', 1, 'Bed', 1),
  ('JS', 'Change Sheets', 1, 'Bed', 2),
  ('JS', 'Pillow Case', 2, 'Bed', 3),
  ('JS', 'Bath Towel', 2, 'Bathroom', 10),
  ('JS', 'Hand Towel', 2, 'Bathroom', 11),
  ('JS', 'Floor Mat', 1, 'Bathroom', 12),
  ('JS', 'Tissue Box', 1, 'Bathroom', 13),
  ('JS', 'Toilet Paper', 1, 'Bathroom', 14),
  ('JS', 'Soap', 2, 'Amenity', 20),
  ('JS', 'Shampoo', 2, 'Amenity', 21),
  ('JS', 'Water Bottle', 2, 'Amenity', 22),
  ('JS', 'Trash Bin', 1, 'Room', 30),
  ('JS', 'Vacuum', 1, 'Room', 31),
  ('JS', 'Mop Floor', 1, 'Room', 32),
  -- TB (Triple Beds — 3 guests, extra amenities, 90min)
  ('TB', 'Make Bed', 1, 'Bed', 1),
  ('TB', 'Change Sheets', 1, 'Bed', 2),
  ('TB', 'Pillow Case', 3, 'Bed', 3),
  ('TB', 'Bath Towel', 3, 'Bathroom', 10),
  ('TB', 'Hand Towel', 3, 'Bathroom', 11),
  ('TB', 'Floor Mat', 1, 'Bathroom', 12),
  ('TB', 'Tissue Box', 1, 'Bathroom', 13),
  ('TB', 'Toilet Paper', 1, 'Bathroom', 14),
  ('TB', 'Soap', 3, 'Amenity', 20),
  ('TB', 'Shampoo', 3, 'Amenity', 21),
  ('TB', 'Water Bottle', 3, 'Amenity', 22),
  ('TB', 'Trash Bin', 1, 'Room', 30),
  ('TB', 'Vacuum', 1, 'Room', 31),
  ('TB', 'Mop Floor', 1, 'Room', 32),
  -- FR (Family Room — 4+ guests, extra everything, 100min)
  ('FR', 'Make Bed', 1, 'Bed', 1),
  ('FR', 'Change Sheets', 2, 'Bed', 2),
  ('FR', 'Pillow Case', 4, 'Bed', 3),
  ('FR', 'Bath Towel', 4, 'Bathroom', 10),
  ('FR', 'Hand Towel', 4, 'Bathroom', 11),
  ('FR', 'Floor Mat', 1, 'Bathroom', 12),
  ('FR', 'Tissue Box', 2, 'Bathroom', 13),
  ('FR', 'Toilet Paper', 2, 'Bathroom', 14),
  ('FR', 'Soap', 4, 'Amenity', 20),
  ('FR', 'Shampoo', 4, 'Amenity', 21),
  ('FR', 'Water Bottle', 4, 'Amenity', 22),
  ('FR', 'Trash Bin', 1, 'Room', 30),
  ('FR', 'Vacuum', 1, 'Room', 31),
  ('FR', 'Mop Floor', 1, 'Room', 32)
ON CONFLICT (room_type_code, item_name) DO NOTHING;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603010001_phase9_housekeeping_finish_atomic.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

drop function if exists public.hk_finish_task_with_maintenance(
  uuid,
  text,
  text,
  jsonb,
  boolean,
  text,
  uuid[],
  text
);

create or replace function public.hk_finish_task_with_maintenance(
  p_task_id uuid,
  p_maid_name text default null,
  p_note text default null,
  p_checklist jsonb default null,
  p_auto_approve boolean default false,
  p_approved_by text default null,
  p_maintenance_assignment_ids uuid[] default null,
  p_maintenance_note text default null
)
returns table (
  task_id uuid,
  duration_ms bigint,
  final_status text,
  auto_approved boolean,
  maintenance_completed_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.housekeeping_tasks%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_final_ms bigint := 0;
  v_final_min integer := 0;
  v_should_auto_approve boolean := false;
  v_final_status text := 'cleaned';
  v_normalized_maid text := nullif(trim(coalesce(p_maid_name, '')), '');
  v_normalized_approve_by text := nullif(trim(coalesce(p_approved_by, '')), '');
  v_normalized_maintenance_note text := nullif(trim(coalesce(p_maintenance_note, '')), '');
  v_target_assignment_ids uuid[] := '{}'::uuid[];
  v_completed_count integer := 0;
begin
  if p_task_id is null then
    raise exception 'p_task_id is required';
  end if;

  select *
  into v_task
  from public.housekeeping_tasks
  where id = p_task_id
  for update;

  if not found then
    raise exception 'Task not found';
  end if;

  if v_task.status not in ('in_progress', 'paused') then
    raise exception 'Task must be in_progress or paused to finish (current: %)', v_task.status;
  end if;

  if v_task.status = 'in_progress' then
    if v_task.started_at is null then
      raise exception 'Data inconsistency: in_progress task has no started_at';
    end if;

    v_final_ms := coalesce(v_task.accumulated_ms, 0)
      + greatest(extract(epoch from (v_now - v_task.started_at)) * 1000, 0)::bigint;
  else
    v_final_ms := coalesce(v_task.accumulated_ms, 0);
  end if;

  v_final_min := greatest(1, round(v_final_ms::numeric / 60000)::integer);

  update public.housekeeping_tasks
  set
    status = 'cleaned',
    finished_at = v_now,
    accumulated_ms = v_final_ms,
    started_at = null,
    checklist_snapshot = p_checklist
  where id = p_task_id;

  insert into public.housekeeping_logs (task_id, status, note, checklist)
  values (
    p_task_id,
    'cleaned',
    coalesce(
      nullif(trim(coalesce(p_note, '')), ''),
      format('finished by %s, duration: %s min', coalesce(v_normalized_maid, 'unknown'), v_final_min)
    ),
    p_checklist
  );

  if p_maintenance_assignment_ids is null or coalesce(array_length(p_maintenance_assignment_ids, 1), 0) = 0 then
    select coalesce(array_agg(ma.id), '{}'::uuid[])
    into v_target_assignment_ids
    from public.maintenance_assignments ma
    where ma.room_id = v_task.room_id
      and ma.assigned_date = v_task.stay_date
      and ma.status = 'pending';
  else
    select coalesce(array_agg(ma.id), '{}'::uuid[])
    into v_target_assignment_ids
    from public.maintenance_assignments ma
    where ma.id = any(p_maintenance_assignment_ids)
      and ma.room_id = v_task.room_id
      and ma.assigned_date = v_task.stay_date
      and ma.status = 'pending';
  end if;

  if coalesce(array_length(v_target_assignment_ids, 1), 0) > 0 then
    with completed as (
      update public.maintenance_assignments ma
      set
        status = 'completed',
        completed_at = v_now,
        notes = coalesce(v_normalized_maintenance_note, ma.notes)
      where ma.id = any(v_target_assignment_ids)
        and ma.status = 'pending'
      returning ma.task_id
    )
    insert into public.maintenance_logs (room_id, task_id, performed_at, performed_by, notes)
    select
      v_task.room_id,
      c.task_id,
      v_now,
      v_normalized_maid,
      coalesce(v_normalized_maintenance_note, format('Completed with housekeeping task %s', p_task_id::text))
    from completed c;

    get diagnostics v_completed_count = row_count;
  end if;

  v_should_auto_approve := coalesce(p_auto_approve, false) or coalesce(v_task.is_no_service, false);
  if v_should_auto_approve then
    update public.housekeeping_tasks
    set
      status = 'approved',
      approved_at = v_now
    where id = p_task_id;

    insert into public.housekeeping_logs (task_id, status, note)
    values (
      p_task_id,
      'approved',
      format(
        'approved by %s%s',
        coalesce(v_normalized_approve_by, coalesce(v_normalized_maid, 'system')),
        case when coalesce(v_task.is_no_service, false) then ' (no service auto-approve)' else '' end
      )
    );

    v_final_status := 'approved';
  end if;

  return query
  select
    p_task_id,
    v_final_ms,
    v_final_status,
    v_should_auto_approve,
    v_completed_count;
end;
$$;

grant execute on function public.hk_finish_task_with_maintenance(
  uuid,
  text,
  text,
  jsonb,
  boolean,
  text,
  uuid[],
  text
) to anon, authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603010002_phase9_maintenance.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create extension if not exists "pgcrypto";

-- ============================================================
-- Phase 9: Maintenance Hub schema
-- ============================================================

create table if not exists public.maintenance_tasks (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  threshold_count int not null check (threshold_count > 0),
  warning_count int check (warning_count is null or warning_count > 0),
  applicable_room_types text[] check (
    applicable_room_types is null
    or array_length(applicable_room_types, 1) is null
    or applicable_room_types <@ array['TS','DS','DQ','DT','JS','TB','FR']::text[]
  ),
  sync_to_housekeeper boolean not null default false,
  checklist_items text[],
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.maintenance_logs (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  task_id uuid not null references public.maintenance_tasks(id) on delete cascade,
  performed_at timestamptz not null default timezone('utc', now()),
  performed_by text,
  stay_count_at_time int not null default 0,
  notes text
);

create table if not exists public.maintenance_notes (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  task_id uuid not null references public.maintenance_tasks(id) on delete cascade,
  note text not null,
  created_at timestamptz not null default timezone('utc', now()),
  is_resolved boolean not null default false,
  resolved_at timestamptz
);

create table if not exists public.maintenance_task_times (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.maintenance_tasks(id) on delete cascade,
  room_type_code text not null check (room_type_code in ('TS','DS','DQ','DT','JS','TB','FR')),
  estimated_minutes int not null default 30 check (estimated_minutes > 0),
  created_at timestamptz not null default timezone('utc', now()),
  unique (task_id, room_type_code)
);

create table if not exists public.maintenance_assignments (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  task_id uuid not null references public.maintenance_tasks(id) on delete cascade,
  assigned_at timestamptz not null default timezone('utc', now()),
  assigned_by text,
  assigned_date date not null default current_date,
  status text not null default 'pending' check (status in ('pending', 'completed', 'cancelled')),
  completed_at timestamptz,
  notes text
);

-- ============================================================
-- Indexes
-- ============================================================

create index if not exists idx_maintenance_logs_room_task_performed_at
  on public.maintenance_logs (room_id, task_id, performed_at desc);

create index if not exists idx_maintenance_notes_active_by_room
  on public.maintenance_notes (room_id)
  where is_resolved = false;

create index if not exists idx_maintenance_assignments_room_date_status
  on public.maintenance_assignments (room_id, assigned_date, status);

-- ============================================================
-- RLS + allow-all policies (project currently no auth restrictions)
-- ============================================================

alter table public.maintenance_tasks enable row level security;
alter table public.maintenance_logs enable row level security;
alter table public.maintenance_notes enable row level security;
alter table public.maintenance_task_times enable row level security;
alter table public.maintenance_assignments enable row level security;

drop policy if exists maintenance_tasks_allow_all on public.maintenance_tasks;
create policy maintenance_tasks_allow_all
  on public.maintenance_tasks
  for all to anon, authenticated
  using (true)
  with check (true);

drop policy if exists maintenance_logs_allow_all on public.maintenance_logs;
create policy maintenance_logs_allow_all
  on public.maintenance_logs
  for all to anon, authenticated
  using (true)
  with check (true);

drop policy if exists maintenance_notes_allow_all on public.maintenance_notes;
create policy maintenance_notes_allow_all
  on public.maintenance_notes
  for all to anon, authenticated
  using (true)
  with check (true);

drop policy if exists maintenance_task_times_allow_all on public.maintenance_task_times;
create policy maintenance_task_times_allow_all
  on public.maintenance_task_times
  for all to anon, authenticated
  using (true)
  with check (true);

drop policy if exists maintenance_assignments_allow_all on public.maintenance_assignments;
create policy maintenance_assignments_allow_all
  on public.maintenance_assignments
  for all to anon, authenticated
  using (true)
  with check (true);

-- ============================================================
-- Trigger: auto-calculate stay_count_at_time from housekeeping_tasks approved
-- ============================================================

create or replace function public.calculate_stay_count_on_insert()
returns trigger
language plpgsql
as $$
begin
  select coalesce(count(*), 0)
  into new.stay_count_at_time
  from public.housekeeping_tasks ht
  where ht.room_id = new.room_id
    and ht.status = 'approved';

  return new;
end;
$$;

drop trigger if exists trigger_calculate_stay_count on public.maintenance_logs;
create trigger trigger_calculate_stay_count
before insert on public.maintenance_logs
for each row execute function public.calculate_stay_count_on_insert();

-- ============================================================
-- RPC 1: get_room_maintenance_status()
-- ============================================================

drop function if exists public.get_room_maintenance_status();

create or replace function public.get_room_maintenance_status()
returns table (
  room_id uuid,
  room_number text,
  room_type_code text,
  task_id uuid,
  task_name text,
  threshold_count int,
  warning_count int,
  applicable_room_types text[],
  total_stays bigint,
  last_stay_at timestamptz,
  last_done_at timestamptz,
  last_done_at_stay int,
  stays_since_last bigint,
  status text
)
language sql
stable
as $$
  with room_stays as (
    select
      ht.room_id,
      count(*)::bigint as stay_count,
      max(ht.approved_at) as last_stay_at
    from public.housekeeping_tasks ht
    where ht.status = 'approved'
    group by ht.room_id
  ),
  last_maintenance as (
    select distinct on (ml.room_id, ml.task_id)
      ml.room_id,
      ml.task_id,
      ml.performed_at,
      ml.stay_count_at_time
    from public.maintenance_logs ml
    order by ml.room_id, ml.task_id, ml.performed_at desc
  )
  select
    r.id as room_id,
    r.room_number,
    rt.code as room_type_code,
    t.id as task_id,
    t.name as task_name,
    t.threshold_count,
    t.warning_count,
    t.applicable_room_types,
    coalesce(rs.stay_count, 0) as total_stays,
    rs.last_stay_at,
    lm.performed_at as last_done_at,
    coalesce(lm.stay_count_at_time, 0) as last_done_at_stay,
    greatest(coalesce(rs.stay_count, 0) - coalesce(lm.stay_count_at_time, 0), 0) as stays_since_last,
    case
      when greatest(coalesce(rs.stay_count, 0) - coalesce(lm.stay_count_at_time, 0), 0) >= t.threshold_count then 'OVERDUE'
      when t.warning_count is not null
        and greatest(coalesce(rs.stay_count, 0) - coalesce(lm.stay_count_at_time, 0), 0) >= t.warning_count then 'WARNING'
      else 'OK'
    end as status
  from public.rooms r
  join public.room_types rt on rt.id = r.room_type_id
  cross join public.maintenance_tasks t
  left join room_stays rs on rs.room_id = r.id
  left join last_maintenance lm on lm.room_id = r.id and lm.task_id = t.id
  where r.is_visible_on_board = true
    and t.is_active = true
    and (
      t.applicable_room_types is null
      or array_length(t.applicable_room_types, 1) is null
      or rt.code = any(t.applicable_room_types)
    )
  order by r.room_number, t.name;
$$;

-- ============================================================
-- RPC 2: get_maintenance_for_rooms(p_room_ids UUID[])
-- ============================================================

drop function if exists public.get_maintenance_for_rooms(uuid[]);

create or replace function public.get_maintenance_for_rooms(p_room_ids uuid[])
returns table (
  room_id uuid,
  task_id uuid,
  task_name text,
  checklist_items text[],
  estimated_minutes int,
  stays_since_last bigint,
  threshold_count int,
  status text
)
language sql
stable
as $$
  select
    rms.room_id,
    rms.task_id,
    rms.task_name,
    mt.checklist_items,
    coalesce(mtt.estimated_minutes, 30) as estimated_minutes,
    rms.stays_since_last,
    rms.threshold_count,
    rms.status
  from public.get_room_maintenance_status() rms
  join public.maintenance_tasks mt on mt.id = rms.task_id
  left join public.maintenance_task_times mtt
    on mtt.task_id = rms.task_id
   and mtt.room_type_code = rms.room_type_code
  where rms.room_id = any(p_room_ids)
    and rms.status = 'OVERDUE'
    and mt.sync_to_housekeeper = true;
$$;

-- ============================================================
-- RPC 3: get_todays_maintenance_assignments(p_target_date DATE)
-- ============================================================

drop function if exists public.get_todays_maintenance_assignments(date);

create or replace function public.get_todays_maintenance_assignments(p_target_date date default current_date)
returns table (
  assignment_id uuid,
  room_id uuid,
  room_number text,
  room_type_code text,
  task_id uuid,
  task_name text,
  checklist_items text[],
  estimated_minutes int,
  status text,
  assigned_by text,
  assigned_at timestamptz,
  notes text
)
language sql
stable
as $$
  select
    ma.id as assignment_id,
    ma.room_id,
    r.room_number,
    rt.code as room_type_code,
    ma.task_id,
    mt.name as task_name,
    mt.checklist_items,
    coalesce(mtt.estimated_minutes, 30) as estimated_minutes,
    ma.status,
    ma.assigned_by,
    ma.assigned_at,
    ma.notes
  from public.maintenance_assignments ma
  join public.rooms r on r.id = ma.room_id
  join public.room_types rt on rt.id = r.room_type_id
  join public.maintenance_tasks mt on mt.id = ma.task_id
  left join public.maintenance_task_times mtt
    on mtt.task_id = ma.task_id
   and mtt.room_type_code = rt.code
  where ma.assigned_date = coalesce(p_target_date, current_date)
    and ma.status = 'pending'
  order by ma.assigned_at asc;
$$;

grant execute on function public.get_room_maintenance_status() to anon, authenticated;
grant execute on function public.get_maintenance_for_rooms(uuid[]) to anon, authenticated;
grant execute on function public.get_todays_maintenance_assignments(date) to anon, authenticated;

-- ============================================================
-- Seed default maintenance tasks
-- ============================================================

insert into public.maintenance_tasks (
  name,
  description,
  threshold_count,
  warning_count,
  applicable_room_types,
  sync_to_housekeeper,
  checklist_items,
  is_active
)
values
  ('ล้างแอร์', 'ล้างแอร์ทำความสะอาด', 200, 150, null, false, null, true),
  ('ราดน้ำยาท่อน้ำ', 'ราดน้ำยาป้องกันท่อตัน', 5, null, null, false, null, true),
  ('Deep Clean เบื้องต้น', 'ทำความสะอาดขั้นพื้นฐาน', 10, null, null, false, null, true),
  ('Deep Clean แบบละเอียด', 'ทำความสะอาดอย่างละเอียด', 30, 25, null, false, null, true),
  ('ซักผ้าม่าน', 'ซักผ้าม่านประจำ', 50, 40, null, false, null, true)
on conflict (name) do update set
  description = excluded.description,
  threshold_count = excluded.threshold_count,
  warning_count = excluded.warning_count,
  applicable_room_types = excluded.applicable_room_types,
  sync_to_housekeeper = excluded.sync_to_housekeeper,
  checklist_items = excluded.checklist_items,
  is_active = excluded.is_active;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603010003_phase9_maintenance_checklist_results.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create extension if not exists "pgcrypto";

-- ============================================================
-- Phase 9.1: Maintenance checklist result audit (per assignment)
-- ============================================================

create table if not exists public.maintenance_assignment_checklist_results (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.maintenance_assignments(id) on delete cascade,
  item_index int not null check (item_index > 0),
  item_name text not null,
  is_checked boolean not null default false,
  checked_at timestamptz,
  checked_by text,
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (assignment_id, item_index)
);

create index if not exists idx_maintenance_assignment_checklists_assignment
  on public.maintenance_assignment_checklist_results (assignment_id);

alter table public.maintenance_assignment_checklist_results enable row level security;

drop policy if exists maintenance_assignment_checklists_allow_all on public.maintenance_assignment_checklist_results;
create policy maintenance_assignment_checklists_allow_all
  on public.maintenance_assignment_checklist_results
  for all to anon, authenticated
  using (true)
  with check (true);

-- ============================================================
-- Extend RPC get_todays_maintenance_assignments with sync flag
-- ============================================================

drop function if exists public.get_todays_maintenance_assignments(date);

create or replace function public.get_todays_maintenance_assignments(p_target_date date default current_date)
returns table (
  assignment_id uuid,
  room_id uuid,
  room_number text,
  room_type_code text,
  task_id uuid,
  task_name text,
  sync_to_housekeeper boolean,
  checklist_items text[],
  estimated_minutes int,
  status text,
  assigned_by text,
  assigned_at timestamptz,
  notes text
)
language sql
stable
as $$
  select
    ma.id as assignment_id,
    ma.room_id,
    r.room_number,
    rt.code as room_type_code,
    ma.task_id,
    mt.name as task_name,
    mt.sync_to_housekeeper,
    mt.checklist_items,
    coalesce(mtt.estimated_minutes, 30) as estimated_minutes,
    ma.status,
    ma.assigned_by,
    ma.assigned_at,
    ma.notes
  from public.maintenance_assignments ma
  join public.rooms r on r.id = ma.room_id
  join public.room_types rt on rt.id = r.room_type_id
  join public.maintenance_tasks mt on mt.id = ma.task_id
  left join public.maintenance_task_times mtt
    on mtt.task_id = ma.task_id
   and mtt.room_type_code = rt.code
  where ma.assigned_date = coalesce(p_target_date, current_date)
    and ma.status = 'pending'
  order by ma.assigned_at asc;
$$;

grant execute on function public.get_todays_maintenance_assignments(date) to anon, authenticated;

-- ============================================================
-- Atomic finish: validate + persist maintenance checklists
-- ============================================================

drop function if exists public.hk_finish_task_with_maintenance(
  uuid,
  text,
  text,
  jsonb,
  boolean,
  text,
  uuid[],
  text
);

drop function if exists public.hk_finish_task_with_maintenance(
  uuid,
  text,
  text,
  jsonb,
  boolean,
  text,
  uuid[],
  text,
  jsonb
);

create or replace function public.hk_finish_task_with_maintenance(
  p_task_id uuid,
  p_maid_name text default null,
  p_note text default null,
  p_checklist jsonb default null,
  p_auto_approve boolean default false,
  p_approved_by text default null,
  p_maintenance_assignment_ids uuid[] default null,
  p_maintenance_note text default null,
  p_maintenance_checklist jsonb default null
)
returns table (
  task_id uuid,
  duration_ms bigint,
  final_status text,
  auto_approved boolean,
  maintenance_completed_count integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.housekeeping_tasks%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_final_ms bigint := 0;
  v_final_min integer := 0;
  v_should_auto_approve boolean := false;
  v_final_status text := 'cleaned';
  v_normalized_maid text := nullif(trim(coalesce(p_maid_name, '')), '');
  v_normalized_approve_by text := nullif(trim(coalesce(p_approved_by, '')), '');
  v_normalized_maintenance_note text := nullif(trim(coalesce(p_maintenance_note, '')), '');
  v_target_assignment_ids uuid[] := '{}'::uuid[];
  v_completed_count integer := 0;
  v_assignment record;
  v_required_item text;
  v_payload_entry jsonb;
  v_item_checked boolean;
begin
  if p_task_id is null then
    raise exception 'p_task_id is required';
  end if;

  select *
  into v_task
  from public.housekeeping_tasks
  where id = p_task_id
  for update;

  if not found then
    raise exception 'Task not found';
  end if;

  if v_task.status not in ('in_progress', 'paused') then
    raise exception 'Task must be in_progress or paused to finish (current: %)', v_task.status;
  end if;

  if v_task.status = 'in_progress' then
    if v_task.started_at is null then
      raise exception 'Data inconsistency: in_progress task has no started_at';
    end if;

    v_final_ms := coalesce(v_task.accumulated_ms, 0)
      + greatest(extract(epoch from (v_now - v_task.started_at)) * 1000, 0)::bigint;
  else
    v_final_ms := coalesce(v_task.accumulated_ms, 0);
  end if;

  v_final_min := greatest(1, round(v_final_ms::numeric / 60000)::integer);

  update public.housekeeping_tasks
  set
    status = 'cleaned',
    finished_at = v_now,
    accumulated_ms = v_final_ms,
    started_at = null,
    checklist_snapshot = p_checklist
  where id = p_task_id;

  insert into public.housekeeping_logs (task_id, status, note, checklist)
  values (
    p_task_id,
    'cleaned',
    coalesce(
      nullif(trim(coalesce(p_note, '')), ''),
      format('finished by %s, duration: %s min', coalesce(v_normalized_maid, 'unknown'), v_final_min)
    ),
    p_checklist
  );

  if p_maintenance_assignment_ids is null or coalesce(array_length(p_maintenance_assignment_ids, 1), 0) = 0 then
    select coalesce(array_agg(ma.id), '{}'::uuid[])
    into v_target_assignment_ids
    from public.maintenance_assignments ma
    where ma.room_id = v_task.room_id
      and ma.assigned_date = v_task.stay_date
      and ma.status = 'pending';
  else
    select coalesce(array_agg(ma.id), '{}'::uuid[])
    into v_target_assignment_ids
    from public.maintenance_assignments ma
    where ma.id = any(p_maintenance_assignment_ids)
      and ma.room_id = v_task.room_id
      and ma.assigned_date = v_task.stay_date
      and ma.status = 'pending';
  end if;

  if coalesce(array_length(v_target_assignment_ids, 1), 0) > 0 then
    -- Validate and persist per-assignment checklist results before closing assignments.
    for v_assignment in
      select
        ma.id as assignment_id,
        ma.task_id,
        mt.sync_to_housekeeper,
        mt.checklist_items
      from public.maintenance_assignments ma
      join public.maintenance_tasks mt on mt.id = ma.task_id
      where ma.id = any(v_target_assignment_ids)
    loop
      v_payload_entry := null;

      if p_maintenance_checklist is not null then
        select entry
        into v_payload_entry
        from jsonb_array_elements(p_maintenance_checklist) as entry
        where nullif(entry->>'assignment_id', '') is not null
          and (entry->>'assignment_id')::uuid = v_assignment.assignment_id
        limit 1;
      end if;

      if coalesce(v_assignment.sync_to_housekeeper, false)
         and coalesce(array_length(v_assignment.checklist_items, 1), 0) > 0 then
        if v_payload_entry is null then
          raise exception 'Missing maintenance checklist for assignment %', v_assignment.assignment_id;
        end if;

        foreach v_required_item in array v_assignment.checklist_items
        loop
          select exists (
            select 1
            from jsonb_array_elements(coalesce(v_payload_entry->'items', '[]'::jsonb)) as it
            where lower(trim(coalesce(it->>'item', ''))) = lower(trim(v_required_item))
              and lower(coalesce(it->>'checked', 'false')) in ('true', 't', '1', 'yes', 'y')
          )
          into v_item_checked;

          if not coalesce(v_item_checked, false) then
            raise exception
              'Maintenance checklist incomplete for assignment % item %',
              v_assignment.assignment_id,
              v_required_item;
          end if;
        end loop;
      end if;

      if v_payload_entry is not null then
        insert into public.maintenance_assignment_checklist_results (
          assignment_id,
          item_index,
          item_name,
          is_checked,
          checked_at,
          checked_by,
          note
        )
        select
          v_assignment.assignment_id,
          item_ordinality::int,
          trim(coalesce(item_value->>'item', '')) as item_name,
          case
            when lower(coalesce(item_value->>'checked', 'false')) in ('true', 't', '1', 'yes', 'y') then true
            else false
          end as is_checked,
          case
            when lower(coalesce(item_value->>'checked', 'false')) in ('true', 't', '1', 'yes', 'y') then v_now
            else null
          end as checked_at,
          case
            when lower(coalesce(item_value->>'checked', 'false')) in ('true', 't', '1', 'yes', 'y') then v_normalized_maid
            else null
          end as checked_by,
          nullif(trim(coalesce(item_value->>'note', '')), '') as note
        from jsonb_array_elements(coalesce(v_payload_entry->'items', '[]'::jsonb)) with ordinality as i(item_value, item_ordinality)
        where nullif(trim(coalesce(item_value->>'item', '')), '') is not null
        on conflict (assignment_id, item_index)
        do update set
          item_name = excluded.item_name,
          is_checked = excluded.is_checked,
          checked_at = excluded.checked_at,
          checked_by = excluded.checked_by,
          note = excluded.note;
      end if;
    end loop;

    with completed as (
      update public.maintenance_assignments ma
      set
        status = 'completed',
        completed_at = v_now,
        notes = coalesce(v_normalized_maintenance_note, ma.notes)
      where ma.id = any(v_target_assignment_ids)
        and ma.status = 'pending'
      returning ma.task_id
    )
    insert into public.maintenance_logs (room_id, task_id, performed_at, performed_by, notes)
    select
      v_task.room_id,
      c.task_id,
      v_now,
      v_normalized_maid,
      coalesce(v_normalized_maintenance_note, format('Completed with housekeeping task %s', p_task_id::text))
    from completed c;

    get diagnostics v_completed_count = row_count;
  end if;

  v_should_auto_approve := coalesce(p_auto_approve, false) or coalesce(v_task.is_no_service, false);
  if v_should_auto_approve then
    update public.housekeeping_tasks
    set
      status = 'approved',
      approved_at = v_now
    where id = p_task_id;

    insert into public.housekeeping_logs (task_id, status, note)
    values (
      p_task_id,
      'approved',
      format(
        'approved by %s%s',
        coalesce(v_normalized_approve_by, coalesce(v_normalized_maid, 'system')),
        case when coalesce(v_task.is_no_service, false) then ' (no service auto-approve)' else '' end
      )
    );

    v_final_status := 'approved';
  end if;

  return query
  select
    p_task_id,
    v_final_ms,
    v_final_status,
    v_should_auto_approve,
    v_completed_count;
end;
$$;

grant execute on function public.hk_finish_task_with_maintenance(
  uuid,
  text,
  text,
  jsonb,
  boolean,
  text,
  uuid[],
  text,
  jsonb
) to anon, authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603020001_phase10_pos_inventory.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create extension if not exists "pgcrypto";

-- ============================================================
-- Phase 10: POS + Inventory + Stock v2
-- ============================================================

create sequence if not exists public.pos_order_seq start with 1;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sku text unique,
  category text not null default 'amenity'
    check (category in ('amenity', 'pos', 'both')),
  unit text not null default 'pieces',
  sale_price numeric(10,2),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.main_stock (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  quantity int not null default 0 check (quantity >= 0),
  reorder_level int not null default 10,
  updated_at timestamptz not null default timezone('utc', now()),
  unique (product_id)
);

create table if not exists public.floor_stock (
  id uuid primary key default gen_random_uuid(),
  floor_number int not null,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity int not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (floor_number, product_id)
);

create table if not exists public.stock_transactions_v2 (
  id uuid primary key default gen_random_uuid(),
  transaction_date date not null default current_date,
  product_id uuid not null references public.products(id),
  action text not null check (action in ('use','transfer_out','transfer_in','sale','receive','adjust','return')),
  quantity_change int not null,
  from_location text,
  to_location text,
  reference_type text,
  reference_id uuid,
  room_number text,
  floor_number int,
  performed_by text,
  note text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_stock_tx_v2_date on public.stock_transactions_v2 (transaction_date);
create index if not exists idx_stock_tx_v2_product on public.stock_transactions_v2 (product_id);
create index if not exists idx_stock_tx_v2_floor on public.stock_transactions_v2 (floor_number);
create index if not exists idx_stock_tx_v2_ref on public.stock_transactions_v2 (reference_type, reference_id);

create table if not exists public.pos_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  order_type text not null check (order_type in ('walkin', 'guest_charge')),
  reservation_id uuid references public.reservations(id),
  guest_name text,
  status text not null default 'completed' check (status in ('pending', 'completed', 'voided')),
  subtotal numeric(10,2) not null default 0,
  total numeric(10,2) not null default 0,
  payment_method text,
  note text,
  created_by text,
  order_date date not null default current_date,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_pos_orders_date on public.pos_orders(order_date);
create index if not exists idx_pos_orders_status on public.pos_orders(status);
create index if not exists idx_pos_orders_type on public.pos_orders(order_type);
create index if not exists idx_pos_orders_reservation on public.pos_orders(reservation_id);

create table if not exists public.pos_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.pos_orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  product_name text not null,
  quantity int not null default 1 check (quantity > 0),
  unit_price numeric(10,2) not null,
  line_total numeric(10,2) not null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_pos_order_items_order on public.pos_order_items(order_id);
create index if not exists idx_pos_order_items_product on public.pos_order_items(product_id);

alter table public.checklist_templates
  add column if not exists product_id uuid references public.products(id);

alter table public.folio_payments
  add column if not exists pos_order_id uuid references public.pos_orders(id);

create index if not exists idx_checklist_templates_product on public.checklist_templates(product_id);
create index if not exists idx_folio_payments_pos_order on public.folio_payments(pos_order_id);

create or replace function public.generate_pos_order_number()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seq bigint;
  v_today text;
begin
  v_today := to_char(current_date, 'YYYYMMDD');
  v_seq := nextval('public.pos_order_seq');
  return 'POS-' || v_today || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

create or replace function public.stock_transfer(
  p_product_id uuid,
  p_floor_number int,
  p_quantity int,
  p_note text default null,
  p_performed_by text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_main_qty int;
  v_main_after int;
  v_floor_after int;
  v_now timestamptz := timezone('utc', now());
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_actor text := nullif(trim(coalesce(p_performed_by, '')), '');
begin
  if p_product_id is null then
    raise exception 'p_product_id is required';
  end if;

  if p_floor_number is null or p_floor_number <= 0 then
    raise exception 'p_floor_number must be > 0';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'p_quantity must be > 0';
  end if;

  insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
  values (p_product_id, 0, 10, v_now)
  on conflict (product_id) do nothing;

  select quantity
  into v_main_qty
  from public.main_stock
  where product_id = p_product_id
  for update;

  if v_main_qty < p_quantity then
    raise exception 'insufficient main stock for product % (have %, need %)', p_product_id, v_main_qty, p_quantity;
  end if;

  v_main_after := v_main_qty - p_quantity;

  update public.main_stock
  set quantity = v_main_after,
      updated_at = v_now
  where product_id = p_product_id;

  insert into public.floor_stock (floor_number, product_id, quantity, updated_at)
  values (p_floor_number, p_product_id, p_quantity, v_now)
  on conflict (floor_number, product_id)
  do update set
    quantity = public.floor_stock.quantity + excluded.quantity,
    updated_at = v_now;

  select quantity
  into v_floor_after
  from public.floor_stock
  where floor_number = p_floor_number
    and product_id = p_product_id;

  insert into public.stock_transactions_v2 (
    transaction_date,
    product_id,
    action,
    quantity_change,
    from_location,
    to_location,
    reference_type,
    floor_number,
    performed_by,
    note,
    created_at
  )
  values
  (
    (v_now at time zone 'Asia/Bangkok')::date,
    p_product_id,
    'transfer_out',
    -p_quantity,
    'main',
    'floor_' || p_floor_number::text,
    'transfer',
    p_floor_number,
    v_actor,
    coalesce(v_note, 'main to floor transfer'),
    v_now
  ),
  (
    (v_now at time zone 'Asia/Bangkok')::date,
    p_product_id,
    'transfer_in',
    p_quantity,
    'main',
    'floor_' || p_floor_number::text,
    'transfer',
    p_floor_number,
    v_actor,
    coalesce(v_note, 'main to floor transfer'),
    v_now
  );

  return jsonb_build_object(
    'main_remaining', v_main_after,
    'floor_new_quantity', v_floor_after,
    'moved_quantity', p_quantity,
    'floor_number', p_floor_number
  );
end;
$$;

create or replace function public.hk_deduct_floor_stock(
  p_task_id uuid,
  p_room_number text,
  p_floor_number int,
  p_maid_name text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_item jsonb;
  v_product_id uuid;
  v_used int;
  v_current int;
  v_deduct int;
  v_after int;
  v_note text;
  v_processed int := 0;
  v_skipped int := 0;
  v_oversell int := 0;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    return jsonb_build_object('processed', 0, 'skipped', 0, 'oversell', 0);
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := null;
    begin
      v_product_id := (v_item ->> 'product_id')::uuid;
    exception when others then
      v_product_id := null;
    end;

    v_used := greatest(coalesce((v_item ->> 'used')::int, 0), 0);

    if v_product_id is null or v_used <= 0 then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    select quantity
    into v_current
    from public.floor_stock
    where floor_number = p_floor_number
      and product_id = v_product_id
    for update;

    if not found then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_deduct := least(v_current, v_used);
    v_after := greatest(v_current - v_used, 0);

    update public.floor_stock
    set quantity = v_after,
        updated_at = v_now
    where floor_number = p_floor_number
      and product_id = v_product_id;

    if v_used > v_current then
      v_oversell := v_oversell + (v_used - v_current);
      v_note := format(
        'HK used %s, deducted %s (oversell %s)',
        v_used,
        v_deduct,
        (v_used - v_current)
      );
    else
      v_note := format('HK used %s, deducted %s', v_used, v_deduct);
    end if;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      room_number,
      floor_number,
      performed_by,
      note,
      created_at
    )
    values (
      (v_now at time zone 'Asia/Bangkok')::date,
      v_product_id,
      'use',
      -v_deduct,
      'floor_' || p_floor_number::text,
      null,
      'housekeeping_task',
      p_task_id,
      p_room_number,
      p_floor_number,
      nullif(trim(coalesce(p_maid_name, '')), ''),
      v_note,
      v_now
    );

    v_processed := v_processed + 1;
  end loop;

  return jsonb_build_object('processed', v_processed, 'skipped', v_skipped, 'oversell', v_oversell);
end;
$$;

create or replace function public.pos_create_order(
  p_order_type text,
  p_items jsonb,
  p_payment_method text,
  p_reservation_id uuid,
  p_created_by text,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_type text := coalesce(trim(p_order_type), '');
  v_payment_method text := nullif(trim(coalesce(p_payment_method, '')), '');
  v_created_by text := nullif(trim(coalesce(p_created_by, '')), '');
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_now timestamptz := timezone('utc', now());
  v_order_id uuid;
  v_order_number text;
  v_guest_name text;
  v_subtotal numeric(10,2) := 0;
  v_total numeric(10,2) := 0;
  v_folio_payment_id uuid;
  v_item jsonb;
  v_product record;
  v_product_id uuid;
  v_qty int;
  v_line_total numeric(10,2);
  v_main_current int;
  v_deduct int;
  v_oversell int;
  v_order_date date := (v_now at time zone 'Asia/Bangkok')::date;
begin
  if v_order_type not in ('walkin', 'guest_charge') then
    raise exception 'invalid p_order_type: %', p_order_type;
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'p_items must be non-empty array';
  end if;

  if v_order_type = 'walkin' then
    if v_payment_method not in ('cash', 'transfer', 'credit_card') then
      raise exception 'walkin payment method must be cash|transfer|credit_card';
    end if;
  else
    v_payment_method := null;
    if p_reservation_id is null then
      raise exception 'p_reservation_id is required for guest_charge';
    end if;

    select r.guest_name
    into v_guest_name
    from public.reservations r
    where r.id = p_reservation_id
      and r.status = 'active'
      and exists (
        select 1
        from public.reservation_nights rn
        where rn.reservation_id = r.id
          and rn.stay_date = v_order_date
          and rn.cancelled_at is null
      )
    limit 1;

    if v_guest_name is null then
      raise exception 'reservation is not eligible for guest_charge';
    end if;
  end if;

  v_order_number := public.generate_pos_order_number();

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_product_id := (v_item ->> 'product_id')::uuid;
    exception when others then
      v_product_id := null;
    end;

    v_qty := greatest(coalesce((v_item ->> 'quantity')::int, 0), 0);
    if v_product_id is null or v_qty <= 0 then
      raise exception 'invalid item payload, each row must include product_id + quantity > 0';
    end if;

    select p.id, p.name, p.category, p.sale_price, p.is_active
    into v_product
    from public.products p
    where p.id = v_product_id
    limit 1;

    if not found then
      raise exception 'product not found: %', v_product_id;
    end if;

    if not coalesce(v_product.is_active, false) then
      raise exception 'product inactive: %', v_product.name;
    end if;

    if v_product.category not in ('pos', 'both') then
      raise exception 'product is not POS sale item: %', v_product.name;
    end if;

    if v_product.sale_price is null then
      raise exception 'product sale_price is required for POS item: %', v_product.name;
    end if;

    v_line_total := round((v_product.sale_price * v_qty)::numeric, 2);
    v_subtotal := round((v_subtotal + v_line_total)::numeric, 2);
  end loop;

  v_total := v_subtotal;

  insert into public.pos_orders (
    order_number,
    order_type,
    reservation_id,
    guest_name,
    status,
    subtotal,
    total,
    payment_method,
    note,
    created_by,
    order_date,
    created_at,
    updated_at
  )
  values (
    v_order_number,
    v_order_type,
    case when v_order_type = 'guest_charge' then p_reservation_id else null end,
    case when v_order_type = 'guest_charge' then v_guest_name else null end,
    'completed',
    v_subtotal,
    v_total,
    v_payment_method,
    v_note,
    v_created_by,
    v_order_date,
    v_now,
    v_now
  )
  returning id into v_order_id;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_qty := greatest(coalesce((v_item ->> 'quantity')::int, 0), 0);

    select p.id, p.name, p.category, p.sale_price, p.is_active
    into v_product
    from public.products p
    where p.id = v_product_id
    limit 1;

    v_line_total := round((v_product.sale_price * v_qty)::numeric, 2);

    insert into public.pos_order_items (
      order_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      line_total,
      created_at
    )
    values (
      v_order_id,
      v_product_id,
      v_product.name,
      v_qty,
      v_product.sale_price,
      v_line_total,
      v_now
    );

    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    select quantity
    into v_main_current
    from public.main_stock
    where product_id = v_product_id
    for update;

    v_deduct := least(v_main_current, v_qty);
    v_oversell := greatest(v_qty - v_main_current, 0);

    update public.main_stock
    set quantity = greatest(v_main_current - v_qty, 0),
        updated_at = v_now
    where product_id = v_product_id;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      performed_by,
      note,
      created_at
    )
    values (
      v_order_date,
      v_product_id,
      'sale',
      -v_deduct,
      'main',
      null,
      'pos_order',
      v_order_id,
      v_created_by,
      case
        when v_oversell > 0 then format('oversell warning: sold %s, deducted %s, missing %s', v_qty, v_deduct, v_oversell)
        else format('sold %s', v_qty)
      end,
      v_now
    );
  end loop;

  if v_order_type = 'guest_charge' then
    insert into public.folio_payments (
      reservation_id,
      tx_type,
      method,
      amount,
      note,
      paid_at,
      paid_date,
      pos_order_id
    )
    values (
      p_reservation_id,
      'payment',
      'other',
      v_total,
      coalesce(v_note, 'POS guest charge ' || v_order_number),
      v_now,
      v_order_date,
      v_order_id
    )
    returning id into v_folio_payment_id;
  end if;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'folio_payment_id', v_folio_payment_id,
    'subtotal', v_subtotal,
    'total', v_total
  );
end;
$$;

create or replace function public.pos_void_order(
  p_order_id uuid,
  p_note text default null,
  p_voided_by text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.pos_orders%rowtype;
  v_item record;
  v_now timestamptz := timezone('utc', now());
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_voided_by text := nullif(trim(coalesce(p_voided_by, '')), '');
  v_order_date date;
  v_refund_payment_id uuid;
begin
  if p_order_id is null then
    raise exception 'p_order_id is required';
  end if;

  select *
  into v_order
  from public.pos_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.status = 'voided' then
    raise exception 'order already voided';
  end if;

  if v_order.status <> 'completed' then
    raise exception 'only completed order can be voided';
  end if;

  v_order_date := (v_now at time zone 'Asia/Bangkok')::date;

  update public.pos_orders
  set status = 'voided',
      note = coalesce(v_order.note, '') || case when v_note is null then '' else ('\nVOID: ' || v_note) end,
      updated_at = v_now
  where id = p_order_id;

  for v_item in
    select poi.product_id, poi.quantity
    from public.pos_order_items poi
    where poi.order_id = p_order_id
  loop
    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_item.product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    update public.main_stock
    set quantity = quantity + v_item.quantity,
        updated_at = v_now
    where product_id = v_item.product_id;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      performed_by,
      note,
      created_at
    )
    values (
      v_order_date,
      v_item.product_id,
      'return',
      v_item.quantity,
      null,
      'main',
      'pos_order',
      p_order_id,
      v_voided_by,
      coalesce(v_note, 'pos order void return'),
      v_now
    );
  end loop;

  if v_order.order_type = 'guest_charge' and v_order.reservation_id is not null and v_order.total > 0 then
    insert into public.folio_payments (
      reservation_id,
      tx_type,
      method,
      amount,
      note,
      paid_at,
      paid_date,
      pos_order_id
    )
    values (
      v_order.reservation_id,
      'refund',
      'other',
      v_order.total,
      coalesce(v_note, 'POS void refund ' || v_order.order_number),
      v_now,
      v_order_date,
      p_order_id
    )
    returning id into v_refund_payment_id;
  end if;

  return jsonb_build_object(
    'order_id', p_order_id,
    'order_number', v_order.order_number,
    'status', 'voided',
    'refund_payment_id', v_refund_payment_id
  );
end;
$$;

-- updated_at triggers (safe)
drop trigger if exists trg_products_updated_at on public.products;
create trigger trg_products_updated_at
before update on public.products
for each row execute function public.set_updated_at();

drop trigger if exists trg_pos_orders_updated_at on public.pos_orders;
create trigger trg_pos_orders_updated_at
before update on public.pos_orders
for each row execute function public.set_updated_at();

alter table public.products enable row level security;
alter table public.main_stock enable row level security;
alter table public.floor_stock enable row level security;
alter table public.stock_transactions_v2 enable row level security;
alter table public.pos_orders enable row level security;
alter table public.pos_order_items enable row level security;

drop policy if exists products_allow_all on public.products;
create policy products_allow_all on public.products
for all to anon, authenticated
using (true)
with check (true);

drop policy if exists main_stock_allow_all on public.main_stock;
create policy main_stock_allow_all on public.main_stock
for all to anon, authenticated
using (true)
with check (true);

drop policy if exists floor_stock_allow_all on public.floor_stock;
create policy floor_stock_allow_all on public.floor_stock
for all to anon, authenticated
using (true)
with check (true);

drop policy if exists stock_transactions_v2_allow_all on public.stock_transactions_v2;
create policy stock_transactions_v2_allow_all on public.stock_transactions_v2
for all to anon, authenticated
using (true)
with check (true);

drop policy if exists pos_orders_allow_all on public.pos_orders;
create policy pos_orders_allow_all on public.pos_orders
for all to anon, authenticated
using (true)
with check (true);

drop policy if exists pos_order_items_allow_all on public.pos_order_items;
create policy pos_order_items_allow_all on public.pos_order_items
for all to anon, authenticated
using (true)
with check (true);

grant execute on function public.generate_pos_order_number() to anon, authenticated;
grant execute on function public.stock_transfer(uuid, int, int, text, text) to anon, authenticated;
grant execute on function public.hk_deduct_floor_stock(uuid, text, int, text, jsonb) to anon, authenticated;
grant execute on function public.pos_create_order(text, jsonb, text, uuid, text, text) to anon, authenticated;
grant execute on function public.pos_void_order(uuid, text, text) to anon, authenticated;

insert into public.products (name, category, unit, sale_price)
values
  ('Water Bottle', 'both', 'bottles', 20.00),
  ('Coffee', 'amenity', 'sachets', null),
  ('Soap', 'amenity', 'bars', null),
  ('Shampoo', 'amenity', 'bottles', null),
  ('Toothbrush Set', 'amenity', 'sets', null),
  ('Sewing Kit', 'amenity', 'sets', null),
  ('Shower Cap', 'amenity', 'pieces', null),
  ('Razor', 'amenity', 'pieces', null)
on conflict (name) do nothing;

update public.checklist_templates ct
set product_id = p.id
from public.products p
where lower(ct.item_name) = lower(p.name)
  and ct.product_id is null;

insert into public.main_stock (product_id, quantity, reorder_level)
select p.id, 0, 10
from public.products p
where p.category in ('amenity','both')
on conflict (product_id) do nothing;

insert into public.floor_stock (floor_number, product_id, quantity)
select floors.floor_no, p.id, 0
from generate_series(1, 3) as floors(floor_no)
cross join public.products p
where p.category in ('amenity','both')
on conflict (floor_number, product_id) do nothing;

comment on table public.stock_items is 'DEPRECATED Phase 10 -> use products + main_stock + floor_stock';
comment on table public.maid_cart_items is 'DEPRECATED Phase 10 -> use floor_stock';
comment on table public.stock_transactions is 'DEPRECATED Phase 10 -> use stock_transactions_v2';

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603020002_phase10_fo_prepare_flow.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- ============================================================
-- Phase 10.x: FO Daily Prepare Flow (Water/Coffee style)
-- ============================================================

alter table public.products
  add column if not exists fulfillment_mode text not null default 'standard'
    check (fulfillment_mode in ('standard', 'daily_prepare'));

create index if not exists idx_products_fulfillment_mode
  on public.products (fulfillment_mode);

create table if not exists public.fo_prepare_batches (
  id uuid primary key default gen_random_uuid(),
  business_date date not null unique,
  status text not null default 'prepared'
    check (status in ('prepared', 'returned', 'cancelled')),
  prepared_at timestamptz not null default timezone('utc', now()),
  prepared_by text,
  prepare_note text,
  insufficient_warning boolean not null default false,
  returned_at timestamptz,
  returned_by text,
  return_note text,
  return_override_note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_fo_prepare_batches_date
  on public.fo_prepare_batches (business_date desc);

create index if not exists idx_fo_prepare_batches_status
  on public.fo_prepare_batches (status);

create table if not exists public.fo_prepare_batch_items (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.fo_prepare_batches(id) on delete cascade,
  floor_number int not null check (floor_number > 0),
  product_id uuid not null references public.products(id) on delete restrict,
  suggested_qty int not null default 0 check (suggested_qty >= 0),
  requested_qty int not null default 0 check (requested_qty >= 0),
  prepared_qty int not null default 0 check (prepared_qty >= 0),
  shortage_qty int not null default 0 check (shortage_qty >= 0),
  used_qty int not null default 0 check (used_qty >= 0),
  remaining_qty int not null default 0 check (remaining_qty >= 0),
  returned_qty int not null default 0 check (returned_qty >= 0),
  return_note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (batch_id, floor_number, product_id)
);

create index if not exists idx_fo_prepare_items_batch
  on public.fo_prepare_batch_items (batch_id);

create index if not exists idx_fo_prepare_items_floor
  on public.fo_prepare_batch_items (floor_number);

create index if not exists idx_fo_prepare_items_product
  on public.fo_prepare_batch_items (product_id);

create or replace function public.fo_prepare_daily_stock(
  p_business_date date,
  p_prepared_by text default null,
  p_prepare_note text default null,
  p_items jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_actor text := nullif(trim(coalesce(p_prepared_by, '')), '');
  v_note text := nullif(trim(coalesce(p_prepare_note, '')), '');
  v_batch_id uuid;
  v_existing_id uuid;
  v_existing_status text;
  v_item jsonb;
  v_floor_number int;
  v_product_id uuid;
  v_suggested int;
  v_requested int;
  v_main_current int;
  v_moved int;
  v_shortage int;
  v_floor_after int;
  v_item_count int := 0;
  v_total_requested int := 0;
  v_total_prepared int := 0;
  v_total_shortage int := 0;
  v_has_shortage boolean := false;
begin
  if p_business_date is null then
    raise exception 'p_business_date is required';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'p_items must be non-empty array';
  end if;

  select b.id, b.status
  into v_existing_id, v_existing_status
  from public.fo_prepare_batches b
  where b.business_date = p_business_date
  limit 1
  for update;

  if found then
    raise exception 'FO prepare batch already exists for % (status: %)', p_business_date, v_existing_status;
  end if;

  insert into public.fo_prepare_batches (
    business_date,
    status,
    prepared_at,
    prepared_by,
    prepare_note,
    insufficient_warning,
    created_at,
    updated_at
  )
  values (
    p_business_date,
    'prepared',
    v_now,
    v_actor,
    v_note,
    false,
    v_now,
    v_now
  )
  returning id into v_batch_id;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_floor_number := null;
    v_product_id := null;
    v_suggested := 0;
    v_requested := 0;

    begin
      v_floor_number := (v_item ->> 'floor_number')::int;
    exception when others then
      v_floor_number := null;
    end;

    begin
      v_product_id := (v_item ->> 'product_id')::uuid;
    exception when others then
      v_product_id := null;
    end;

    begin
      v_suggested := greatest(coalesce((v_item ->> 'suggested_qty')::int, 0), 0);
    exception when others then
      v_suggested := 0;
    end;

    begin
      v_requested := greatest(coalesce((v_item ->> 'requested_qty')::int, 0), 0);
    exception when others then
      v_requested := 0;
    end;

    if v_floor_number is null or v_floor_number <= 0 or v_product_id is null or v_requested <= 0 then
      continue;
    end if;

    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    select quantity
    into v_main_current
    from public.main_stock
    where product_id = v_product_id
    for update;

    v_moved := least(coalesce(v_main_current, 0), v_requested);
    v_shortage := greatest(v_requested - v_moved, 0);

    if v_moved > 0 then
      update public.main_stock
      set quantity = greatest(coalesce(v_main_current, 0) - v_moved, 0),
          updated_at = v_now
      where product_id = v_product_id;

      insert into public.floor_stock (floor_number, product_id, quantity, updated_at)
      values (v_floor_number, v_product_id, v_moved, v_now)
      on conflict (floor_number, product_id)
      do update set
        quantity = public.floor_stock.quantity + excluded.quantity,
        updated_at = v_now;

      select quantity
      into v_floor_after
      from public.floor_stock
      where floor_number = v_floor_number
        and product_id = v_product_id;

      insert into public.stock_transactions_v2 (
        transaction_date,
        product_id,
        action,
        quantity_change,
        from_location,
        to_location,
        reference_type,
        reference_id,
        floor_number,
        performed_by,
        note,
        created_at
      )
      values
      (
        p_business_date,
        v_product_id,
        'transfer_out',
        -v_moved,
        'main',
        'floor_' || v_floor_number::text,
        'fo_prepare',
        v_batch_id,
        v_floor_number,
        v_actor,
        coalesce(v_note, 'FO prepare daily stock'),
        v_now
      ),
      (
        p_business_date,
        v_product_id,
        'transfer_in',
        v_moved,
        'main',
        'floor_' || v_floor_number::text,
        'fo_prepare',
        v_batch_id,
        v_floor_number,
        v_actor,
        coalesce(v_note, 'FO prepare daily stock'),
        v_now
      );
    else
      v_floor_after := coalesce((
        select fs.quantity
        from public.floor_stock fs
        where fs.floor_number = v_floor_number
          and fs.product_id = v_product_id
        limit 1
      ), 0);
    end if;

    insert into public.fo_prepare_batch_items (
      batch_id,
      floor_number,
      product_id,
      suggested_qty,
      requested_qty,
      prepared_qty,
      shortage_qty,
      used_qty,
      remaining_qty,
      returned_qty,
      created_at,
      updated_at
    )
    values (
      v_batch_id,
      v_floor_number,
      v_product_id,
      v_suggested,
      v_requested,
      v_moved,
      v_shortage,
      0,
      v_moved,
      0,
      v_now,
      v_now
    );

    v_item_count := v_item_count + 1;
    v_total_requested := v_total_requested + v_requested;
    v_total_prepared := v_total_prepared + v_moved;
    v_total_shortage := v_total_shortage + v_shortage;
    if v_shortage > 0 then
      v_has_shortage := true;
    end if;
  end loop;

  if v_item_count = 0 then
    raise exception 'No valid items for FO prepare';
  end if;

  update public.fo_prepare_batches
  set
    insufficient_warning = v_has_shortage,
    updated_at = v_now
  where id = v_batch_id;

  return jsonb_build_object(
    'batch_id', v_batch_id,
    'item_count', v_item_count,
    'total_requested', v_total_requested,
    'total_prepared', v_total_prepared,
    'total_shortage', v_total_shortage,
    'has_shortage', v_has_shortage
  );
end;
$$;

create or replace function public.fo_return_daily_stock(
  p_batch_id uuid,
  p_returned_by text default null,
  p_return_note text default null,
  p_items jsonb default '[]'::jsonb,
  p_force boolean default false,
  p_override_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_actor text := nullif(trim(coalesce(p_returned_by, '')), '');
  v_note text := nullif(trim(coalesce(p_return_note, '')), '');
  v_override_note text := nullif(trim(coalesce(p_override_note, '')), '');
  v_batch public.fo_prepare_batches%rowtype;
  v_item jsonb;
  v_item_id uuid;
  v_return_qty int;
  v_item_note text;
  v_line public.fo_prepare_batch_items%rowtype;
  v_used_qty int;
  v_system_remaining int;
  v_floor_current int;
  v_main_current int;
  v_processed_count int := 0;
  v_expected_count int := 0;
  v_total_returned int := 0;
  v_seen_ids uuid[] := '{}'::uuid[];
begin
  if p_batch_id is null then
    raise exception 'p_batch_id is required';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'p_items must be non-empty array';
  end if;

  select *
  into v_batch
  from public.fo_prepare_batches
  where id = p_batch_id
  for update;

  if not found then
    raise exception 'FO prepare batch not found';
  end if;

  if v_batch.status <> 'prepared' then
    raise exception 'Batch status must be prepared (current: %)', v_batch.status;
  end if;

  select count(*)
  into v_expected_count
  from public.fo_prepare_batch_items
  where batch_id = p_batch_id
    and prepared_qty > 0;

  if v_expected_count = 0 then
    raise exception 'No prepared items found in batch';
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_item_id := null;
    v_return_qty := 0;
    v_item_note := null;

    begin
      v_item_id := (v_item ->> 'item_id')::uuid;
    exception when others then
      v_item_id := null;
    end;

    begin
      v_return_qty := greatest(coalesce((v_item ->> 'return_qty')::int, 0), 0);
    exception when others then
      v_return_qty := 0;
    end;

    v_item_note := nullif(trim(coalesce(v_item ->> 'note', '')), '');

    if v_item_id is null then
      raise exception 'Each return item must include valid item_id';
    end if;

    if v_item_id = any(v_seen_ids) then
      raise exception 'Duplicate return item_id in payload: %', v_item_id;
    end if;
    v_seen_ids := array_append(v_seen_ids, v_item_id);

    select *
    into v_line
    from public.fo_prepare_batch_items
    where id = v_item_id
      and batch_id = p_batch_id
    for update;

    if not found then
      raise exception 'Batch item not found: %', v_item_id;
    end if;

    if v_return_qty > v_line.prepared_qty then
      raise exception 'return_qty exceeds prepared_qty for item % (prepared %, return %)',
        v_item_id, v_line.prepared_qty, v_return_qty;
    end if;

    select coalesce(sum(abs(st.quantity_change)), 0)::int
    into v_used_qty
    from public.stock_transactions_v2 st
    where st.transaction_date = v_batch.business_date
      and st.action = 'use'
      and st.reference_type = 'housekeeping_task'
      and st.product_id = v_line.product_id
      and st.floor_number = v_line.floor_number;

    v_system_remaining := greatest(v_line.prepared_qty - v_used_qty, 0);

    if v_return_qty <> v_system_remaining and v_item_note is null then
      raise exception
        'Return note is required when return_qty differs from system remaining (item %: return %, system %)',
        v_item_id, v_return_qty, v_system_remaining;
    end if;

    select quantity
    into v_floor_current
    from public.floor_stock
    where floor_number = v_line.floor_number
      and product_id = v_line.product_id
    for update;

    if not found then
      v_floor_current := 0;
    end if;

    if v_return_qty > v_floor_current then
      raise exception
        'insufficient floor stock for return (item %, floor %, have %, return %)',
        v_item_id, v_line.floor_number, v_floor_current, v_return_qty;
    end if;

    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_line.product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    select quantity
    into v_main_current
    from public.main_stock
    where product_id = v_line.product_id
    for update;

    if v_return_qty > 0 then
      update public.floor_stock
      set quantity = greatest(v_floor_current - v_return_qty, 0),
          updated_at = v_now
      where floor_number = v_line.floor_number
        and product_id = v_line.product_id;

      update public.main_stock
      set quantity = coalesce(v_main_current, 0) + v_return_qty,
          updated_at = v_now
      where product_id = v_line.product_id;

      insert into public.stock_transactions_v2 (
        transaction_date,
        product_id,
        action,
        quantity_change,
        from_location,
        to_location,
        reference_type,
        reference_id,
        floor_number,
        performed_by,
        note,
        created_at
      )
      values (
        v_batch.business_date,
        v_line.product_id,
        'return',
        v_return_qty,
        'floor_' || v_line.floor_number::text,
        'main',
        'fo_return',
        p_batch_id,
        v_line.floor_number,
        v_actor,
        coalesce(v_item_note, v_note, 'FO return remaining stock'),
        v_now
      );
    end if;

    update public.fo_prepare_batch_items
    set
      used_qty = v_used_qty,
      remaining_qty = greatest(v_system_remaining - v_return_qty, 0),
      returned_qty = v_return_qty,
      return_note = coalesce(v_item_note, return_note),
      updated_at = v_now
    where id = v_item_id;

    v_total_returned := v_total_returned + v_return_qty;
    v_processed_count := v_processed_count + 1;
  end loop;

  if v_processed_count <> v_expected_count then
    raise exception
      'Return payload incomplete. Expected % items, received %',
      v_expected_count, v_processed_count;
  end if;

  if coalesce(p_force, false) and v_override_note is null then
    raise exception 'override note is required when force return is true';
  end if;

  update public.fo_prepare_batches
  set
    status = 'returned',
    returned_at = v_now,
    returned_by = v_actor,
    return_note = v_note,
    return_override_note = case when coalesce(p_force, false) then v_override_note else null end,
    updated_at = v_now
  where id = p_batch_id;

  return jsonb_build_object(
    'batch_id', p_batch_id,
    'processed_items', v_processed_count,
    'total_returned', v_total_returned,
    'force_return', coalesce(p_force, false)
  );
end;
$$;

alter table public.fo_prepare_batches enable row level security;
alter table public.fo_prepare_batch_items enable row level security;

drop policy if exists fo_prepare_batches_allow_all on public.fo_prepare_batches;
create policy fo_prepare_batches_allow_all
  on public.fo_prepare_batches
  for all
  using (true)
  with check (true);

drop policy if exists fo_prepare_batch_items_allow_all on public.fo_prepare_batch_items;
create policy fo_prepare_batch_items_allow_all
  on public.fo_prepare_batch_items
  for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.fo_prepare_batches to anon, authenticated;
grant select, insert, update, delete on table public.fo_prepare_batch_items to anon, authenticated;
grant execute on function public.fo_prepare_daily_stock(date, text, text, jsonb) to anon, authenticated;
grant execute on function public.fo_return_daily_stock(uuid, text, text, jsonb, boolean, text) to anon, authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603020003_phase9_allow_duplicate_extra_tasks.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 9 hotfix: allow creating multiple extra task cards with same task_name on same date.
-- Old schema had UNIQUE (assignment_date, task_name) which blocks duplicate cards.

ALTER TABLE IF EXISTS public.extra_task_assignments
  DROP CONSTRAINT IF EXISTS extra_task_assignments_assignment_date_task_name_key;

CREATE INDEX IF NOT EXISTS idx_extra_task_assignments_date_maid_priority
  ON public.extra_task_assignments (assignment_date, assigned_maid, priority);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603030001_phase11_hk_no_service_note.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.housekeeping_tasks
  add column if not exists no_service_note text,
  add column if not exists no_service_marked_at timestamptz,
  add column if not exists no_service_marked_by text;

comment on column public.housekeeping_tasks.no_service_note is
  'Optional operational note for no-service requests set by Front Desk or housekeeper';

comment on column public.housekeeping_tasks.no_service_marked_at is
  'Timestamp when no-service flag was set from Room Diary or maid flow';

comment on column public.housekeeping_tasks.no_service_marked_by is
  'Actor label who marked no-service (e.g., Front Desk)';

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603030002_phase11_inventory_dashboard_visibility.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.products
  add column if not exists show_on_inventory_dashboard boolean not null default true;

create index if not exists idx_products_show_on_inventory_dashboard
  on public.products (show_on_inventory_dashboard);

comment on column public.products.show_on_inventory_dashboard is
  'When true, product is shown in Inventory Dashboard Floor Stock detail section.';

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603040001_phase11_transportation.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- ═══════════════════════════════════════════════════
-- Phase 11: Transportation & Transfer Management
-- ═══════════════════════════════════════════════════

-- 1. boat_companies — บริษัทเรือ
create table if not exists public.boat_companies (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  contact_phone text,
  contact_line text,
  contact_whatsapp text,
  website text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. boat_piers — ท่าเรือ (1 company → many piers)
create table if not exists public.boat_piers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.boat_companies(id) on delete cascade,
  name text not null,
  location_note text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (company_id, name)
);

create index if not exists idx_boat_piers_company on public.boat_piers (company_id);

-- 3. boat_routes — เส้นทาง + ตารางเวลา + ราคา + commission
create table if not exists public.boat_routes (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.boat_companies(id) on delete cascade,
  departure_pier_id uuid references public.boat_piers(id) on delete set null,
  origin text not null,
  destination text not null,
  boat_type text default 'speedboat',
  departure_times text[],
  duration_minutes int,
  ticket_price numeric(10,2),
  cost_price numeric(10,2),
  includes_pickup boolean not null default false,
  pickup_fee numeric(10,2),
  season_label text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_boat_routes_company on public.boat_routes (company_id);
create index if not exists idx_boat_routes_active on public.boat_routes (is_active);

-- 4. drivers — คนขับ
create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  license_type text,
  company text,
  photo_url text,
  rating_avg numeric(3,2) not null default 0,
  total_trips int not null default 0,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_drivers_active on public.drivers (is_active);
create index if not exists idx_drivers_rating on public.drivers (rating_avg desc, total_trips desc);

-- 5. vehicles — รถ
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  plate_number text not null unique,
  vehicle_type text not null default 'sedan',
  capacity int not null default 4,
  color text,
  default_driver_id uuid references public.drivers(id) on delete set null,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_vehicles_driver on public.vehicles (default_driver_id);
create index if not exists idx_vehicles_active on public.vehicles (is_active);

-- 6. transfers — การจอง Transfer (หัวใจระบบ)
create table if not exists public.transfers (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  guest_name text not null,
  guest_phone text,
  transfer_type text not null check (transfer_type in (
    'airport_pickup', 'airport_dropoff',
    'hotel_to_anywhere', 'bus_ferry_pickup', 'ticket_only'
  )),
  service_mode text not null default 'driver_only' check (service_mode in (
    'company_pickup', 'hotel_arrange', 'ticket_only', 'driver_only'
  )),
  pickup_datetime timestamptz not null,
  pickup_location text not null,
  dropoff_location text not null,
  pax int not null default 1,
  luggage_count int default 0,
  driver_id uuid references public.drivers(id) on delete set null,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  boat_company_id uuid references public.boat_companies(id) on delete set null,
  boat_route_id uuid references public.boat_routes(id) on delete set null,
  selling_price numeric(10,2),
  cost_price numeric(10,2),
  driver_fee numeric(10,2),
  driver_commission numeric(10,2) default 0,
  net_commission numeric(10,2),
  actual_price numeric(10,2),
  payment_status text not null default 'unpaid' check (payment_status in (
    'unpaid', 'paid_to_hotel', 'paid_to_driver', 'settled'
  )),
  payment_method text,
  status text not null default 'pending' check (status in (
    'pending', 'confirmed', 'driver_assigned', 'in_progress', 'completed', 'cancelled', 'no_show'
  )),
  staff_note text,
  guest_note text,
  voucher_note text,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_transfers_pickup on public.transfers (pickup_datetime);
create index if not exists idx_transfers_reservation on public.transfers (reservation_id);
create index if not exists idx_transfers_driver on public.transfers (driver_id);
create index if not exists idx_transfers_status on public.transfers (status);
-- NOTE: do not create expression index on timestamptz::date (not immutable in Postgres).
-- Daily filters should use pickup_datetime range predicates and idx_transfers_pickup.

-- 7. driver_ratings — คะแนน per-trip (staff-only Phase 11)
create table if not exists public.driver_ratings (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.transfers(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  score_punctuality int not null check (score_punctuality between 1 and 5),
  score_value int not null check (score_value between 1 and 5),
  score_service int not null check (score_service between 1 and 5),
  comment text,
  rated_by text,
  created_at timestamptz not null default now(),
  unique (transfer_id)
);

create index if not exists idx_driver_ratings_driver on public.driver_ratings (driver_id);
create index if not exists idx_driver_ratings_created_at on public.driver_ratings (created_at desc);

-- 8. transfer_notifications — log แจ้งเตือน (in-app only Phase 11)
create table if not exists public.transfer_notifications (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.transfers(id) on delete cascade,
  notification_type text not null,
  channel text not null default 'in_app',
  message text,
  sent_at timestamptz,
  status text not null default 'pending' check (status in ('pending', 'sent', 'failed', 'acknowledged')),
  created_at timestamptz not null default now()
);

create index if not exists idx_transfer_notifications_transfer on public.transfer_notifications (transfer_id);
create index if not exists idx_transfer_notifications_status on public.transfer_notifications (status);

-- 9. transfer_vouchers — voucher data (for browser print)
create table if not exists public.transfer_vouchers (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null unique references public.transfers(id) on delete cascade,
  voucher_number text not null unique,
  guest_name text not null,
  route_description text,
  departure_time text,
  pier_name text,
  boat_company_name text,
  pickup_time text,
  pickup_location text,
  driver_name text,
  driver_phone text,
  vehicle_info text,
  special_instructions text,
  printed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_transfer_vouchers_number on public.transfer_vouchers (voucher_number);

-- Voucher number sequence (global running, no daily reset)
create sequence if not exists public.transfer_voucher_seq start with 1;

create or replace function public.generate_transfer_voucher_number()
returns text
language plpgsql
as $$
declare
  v_seq bigint;
  v_today text;
begin
  v_today := to_char(current_date, 'YYYYMMDD');
  v_seq := nextval('public.transfer_voucher_seq');
  return 'TRF-' || v_today || '-' || lpad(v_seq::text, 4, '0');
end;
$$;

-- Create transfer booking in one atomic DB transaction.
create or replace function public.transfer_create_booking(
  p_reservation_id uuid,
  p_transfer_type text,
  p_service_mode text,
  p_pickup_datetime timestamptz,
  p_pickup_location text,
  p_dropoff_location text,
  p_pax int default 1,
  p_luggage_count int default 0,
  p_driver_id uuid default null,
  p_vehicle_id uuid default null,
  p_boat_company_id uuid default null,
  p_boat_route_id uuid default null,
  p_selling_price numeric default null,
  p_cost_price numeric default null,
  p_driver_fee numeric default null,
  p_driver_commission numeric default 0,
  p_payment_method text default null,
  p_staff_note text default null,
  p_created_by text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation_status text;
  v_guest_name text;
  v_guest_phone text;
  v_transfer_id uuid;
  v_voucher_number text;
  v_payment_method text;
  v_payment_status text;
  v_transfer_status text;
  v_alert_code text;
  v_alert_line text;
  v_alert_note text;
  v_alert_id uuid;
  v_trace_text text;
  v_pickup_date date;
  v_pickup_time text;
  v_driver_name text;
  v_driver_phone text;
  v_vehicle_info text;
  v_boat_company_name text;
  v_pier_name text;
  v_route_description text;
  v_departure_time text;
  v_operator_label text;
  v_net_commission numeric(10,2);
  v_selling_price numeric(10,2);
  v_cost_price numeric(10,2);
  v_driver_fee numeric(10,2);
  v_driver_commission numeric(10,2);
  v_alert_created boolean := false;
  v_trace_created boolean := false;
  v_folio_posted boolean := false;
begin
  if p_reservation_id is null then
    raise exception 'reservation_id is required';
  end if;
  if p_pickup_datetime is null then
    raise exception 'pickup_datetime is required';
  end if;
  if p_pickup_datetime <= now() then
    raise exception 'pickup_datetime must be future';
  end if;
  if coalesce(trim(p_pickup_location), '') = '' then
    raise exception 'pickup_location is required';
  end if;
  if coalesce(trim(p_dropoff_location), '') = '' then
    raise exception 'dropoff_location is required';
  end if;
  if coalesce(p_pax, 0) <= 0 then
    raise exception 'pax must be greater than 0';
  end if;
  if coalesce(p_driver_commission, 0) < 0 then
    raise exception 'driver_commission must be >= 0';
  end if;
  if p_selling_price is not null and p_selling_price < 0 then
    raise exception 'selling_price must be >= 0';
  end if;
  if p_cost_price is not null and p_cost_price < 0 then
    raise exception 'cost_price must be >= 0';
  end if;
  if p_driver_fee is not null and p_driver_fee < 0 then
    raise exception 'driver_fee must be >= 0';
  end if;

  select
    r.status::text,
    r.guest_name,
    coalesce(nullif(trim(r.phone), ''), nullif(trim(gp.phone), ''))
  into
    v_reservation_status,
    v_guest_name,
    v_guest_phone
  from public.reservations r
  left join public.guest_profiles gp on gp.id = r.guest_profile_id
  where r.id = p_reservation_id;

  if not found then
    raise exception 'Reservation not found';
  end if;
  if v_reservation_status <> 'active' then
    raise exception 'Reservation must be active to create transfer';
  end if;

  v_payment_method := nullif(trim(coalesce(p_payment_method, '')), '');
  if v_payment_method is not null and v_payment_method not in ('cash', 'transfer', 'credit_card', 'other') then
    raise exception 'payment_method must be cash|transfer|credit_card|other';
  end if;

  v_selling_price := case when p_selling_price is null then null else round(p_selling_price::numeric, 2) end;
  v_cost_price := case when p_cost_price is null then null else round(p_cost_price::numeric, 2) end;
  v_driver_fee := case when p_driver_fee is null then null else round(p_driver_fee::numeric, 2) end;
  v_driver_commission := round(coalesce(p_driver_commission, 0)::numeric, 2);

  v_net_commission := round(
    coalesce(v_selling_price, 0)
    - coalesce(v_cost_price, 0)
    - coalesce(v_driver_fee, 0)
    + coalesce(v_driver_commission, 0),
    2
  );

  if v_payment_method is not null then
    v_payment_status := 'paid_to_hotel';
    if v_selling_price is null or v_selling_price <= 0 then
      raise exception 'selling_price must be > 0 when payment_method is provided';
    end if;
  else
    v_payment_status := 'unpaid';
  end if;

  if p_driver_id is not null then
    v_transfer_status := 'driver_assigned';
  else
    v_transfer_status := 'pending';
  end if;

  v_pickup_date := (p_pickup_datetime at time zone 'Asia/Bangkok')::date;
  v_pickup_time := to_char((p_pickup_datetime at time zone 'Asia/Bangkok'), 'HH24:MI');

  if p_driver_id is not null then
    select d.name, d.phone into v_driver_name, v_driver_phone
    from public.drivers d
    where d.id = p_driver_id;
  end if;

  if p_vehicle_id is not null then
    select concat_ws(' ', v.vehicle_type, '-', v.plate_number, coalesce('(' || v.color || ')', ''))
    into v_vehicle_info
    from public.vehicles v
    where v.id = p_vehicle_id;
  end if;

  if p_boat_route_id is not null then
    select
      br.origin || ' -> ' || br.destination,
      br.departure_times[1],
      bp.name,
      bc.name
    into
      v_route_description,
      v_departure_time,
      v_pier_name,
      v_boat_company_name
    from public.boat_routes br
    left join public.boat_piers bp on bp.id = br.departure_pier_id
    left join public.boat_companies bc on bc.id = br.company_id
    where br.id = p_boat_route_id;
  elsif p_boat_company_id is not null then
    select bc.name into v_boat_company_name
    from public.boat_companies bc
    where bc.id = p_boat_company_id;
  end if;

  if v_route_description is null then
    v_route_description := p_pickup_location || ' -> ' || p_dropoff_location;
  end if;

  insert into public.transfers (
    reservation_id,
    guest_name,
    guest_phone,
    transfer_type,
    service_mode,
    pickup_datetime,
    pickup_location,
    dropoff_location,
    pax,
    luggage_count,
    driver_id,
    vehicle_id,
    boat_company_id,
    boat_route_id,
    selling_price,
    cost_price,
    driver_fee,
    driver_commission,
    net_commission,
    payment_status,
    payment_method,
    status,
    staff_note,
    created_by
  )
  values (
    p_reservation_id,
    v_guest_name,
    v_guest_phone,
    p_transfer_type,
    p_service_mode,
    p_pickup_datetime,
    p_pickup_location,
    p_dropoff_location,
    coalesce(p_pax, 1),
    coalesce(p_luggage_count, 0),
    p_driver_id,
    p_vehicle_id,
    p_boat_company_id,
    p_boat_route_id,
    v_selling_price,
    v_cost_price,
    v_driver_fee,
    v_driver_commission,
    v_net_commission,
    v_payment_status,
    v_payment_method,
    v_transfer_status,
    nullif(trim(coalesce(p_staff_note, '')), ''),
    nullif(trim(coalesce(p_created_by, '')), '')
  )
  returning id into v_transfer_id;

  v_voucher_number := public.generate_transfer_voucher_number();
  v_operator_label := coalesce(nullif(v_boat_company_name, ''), nullif(v_driver_name, ''), 'Transfer');

  insert into public.transfer_vouchers (
    transfer_id,
    voucher_number,
    guest_name,
    route_description,
    departure_time,
    pier_name,
    boat_company_name,
    pickup_time,
    pickup_location,
    driver_name,
    driver_phone,
    vehicle_info,
    special_instructions
  )
  values (
    v_transfer_id,
    v_voucher_number,
    v_guest_name,
    v_route_description,
    v_departure_time,
    v_pier_name,
    v_boat_company_name,
    v_pickup_time,
    p_pickup_location,
    v_driver_name,
    v_driver_phone,
    v_vehicle_info,
    nullif(trim(coalesce(p_staff_note, '')), '')
  );

  v_alert_code := case
    when p_transfer_type in ('bus_ferry_pickup', 'ticket_only') then 'BOAT'
    else 'CAR'
  end;
  v_alert_line := '[' || v_voucher_number || '] ' || v_pickup_time || ' ' || v_operator_label;

  select ra.id, ra.note
  into v_alert_id, v_alert_note
  from public.reservation_alerts ra
  where ra.reservation_id = p_reservation_id
    and ra.alert_code = v_alert_code
  for update;

  if not found then
    insert into public.reservation_alerts (reservation_id, alert_code, note)
    values (p_reservation_id, v_alert_code, v_alert_line);
  else
    if coalesce(trim(v_alert_note), '') = '' then
      v_alert_note := v_alert_line;
    elsif strpos(v_alert_note, v_alert_line) > 0 then
      v_alert_note := v_alert_note;
    else
      v_alert_note := v_alert_note || E'\n' || v_alert_line;
    end if;

    update public.reservation_alerts
    set note = v_alert_note
    where id = v_alert_id;
  end if;
  v_alert_created := true;

  v_trace_text := '[TRANSFER][' || v_voucher_number || '] '
    || p_transfer_type
    || ' pickup '
    || v_pickup_time
    || ' - '
    || v_operator_label;

  insert into public.reservation_traces (
    reservation_id,
    created_by,
    dept,
    trace_text,
    from_date,
    to_date,
    status
  )
  values (
    p_reservation_id,
    nullif(trim(coalesce(p_created_by, '')), ''),
    'FD',
    v_trace_text,
    v_pickup_date,
    v_pickup_date,
    'open'
  );
  v_trace_created := true;

  if v_payment_status = 'paid_to_hotel' and v_selling_price is not null and v_selling_price > 0 then
    insert into public.folio_payments (
      reservation_id,
      tx_type,
      method,
      amount,
      note,
      paid_date,
      paid_at
    )
    values (
      p_reservation_id,
      'payment',
      v_payment_method::public.payment_method_type,
      v_selling_price,
      'Transfer: ' || p_transfer_type || ' - ' || v_voucher_number,
      current_date,
      now()
    );
    v_folio_posted := true;
  end if;

  return jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'voucher_number', v_voucher_number,
    'alert_created', v_alert_created,
    'trace_created', v_trace_created,
    'folio_posted', v_folio_posted
  );
end;
$$;

-- RLS Policies (service role only)
alter table public.boat_companies enable row level security;
drop policy if exists boat_companies_service_role_full_access on public.boat_companies;
create policy boat_companies_service_role_full_access on public.boat_companies
for all to service_role
using (true)
with check (true);

alter table public.boat_piers enable row level security;
drop policy if exists boat_piers_service_role_full_access on public.boat_piers;
create policy boat_piers_service_role_full_access on public.boat_piers
for all to service_role
using (true)
with check (true);

alter table public.boat_routes enable row level security;
drop policy if exists boat_routes_service_role_full_access on public.boat_routes;
create policy boat_routes_service_role_full_access on public.boat_routes
for all to service_role
using (true)
with check (true);

alter table public.drivers enable row level security;
drop policy if exists drivers_service_role_full_access on public.drivers;
create policy drivers_service_role_full_access on public.drivers
for all to service_role
using (true)
with check (true);

alter table public.vehicles enable row level security;
drop policy if exists vehicles_service_role_full_access on public.vehicles;
create policy vehicles_service_role_full_access on public.vehicles
for all to service_role
using (true)
with check (true);

alter table public.transfers enable row level security;
drop policy if exists transfers_service_role_full_access on public.transfers;
create policy transfers_service_role_full_access on public.transfers
for all to service_role
using (true)
with check (true);

alter table public.driver_ratings enable row level security;
drop policy if exists driver_ratings_service_role_full_access on public.driver_ratings;
create policy driver_ratings_service_role_full_access on public.driver_ratings
for all to service_role
using (true)
with check (true);

alter table public.transfer_notifications enable row level security;
drop policy if exists transfer_notifications_service_role_full_access on public.transfer_notifications;
create policy transfer_notifications_service_role_full_access on public.transfer_notifications
for all to service_role
using (true)
with check (true);

alter table public.transfer_vouchers enable row level security;
drop policy if exists transfer_vouchers_service_role_full_access on public.transfer_vouchers;
create policy transfer_vouchers_service_role_full_access on public.transfer_vouchers
for all to service_role
using (true)
with check (true);

-- Updated_at triggers
drop trigger if exists trg_boat_companies_updated_at on public.boat_companies;
create trigger trg_boat_companies_updated_at
before update on public.boat_companies
for each row execute function public.set_updated_at();

drop trigger if exists trg_boat_routes_updated_at on public.boat_routes;
create trigger trg_boat_routes_updated_at
before update on public.boat_routes
for each row execute function public.set_updated_at();

drop trigger if exists trg_drivers_updated_at on public.drivers;
create trigger trg_drivers_updated_at
before update on public.drivers
for each row execute function public.set_updated_at();

drop trigger if exists trg_vehicles_updated_at on public.vehicles;
create trigger trg_vehicles_updated_at
before update on public.vehicles
for each row execute function public.set_updated_at();

drop trigger if exists trg_transfers_updated_at on public.transfers;
create trigger trg_transfers_updated_at
before update on public.transfers
for each row execute function public.set_updated_at();

-- Seed Data
insert into public.boat_companies (name, contact_phone, website)
values ('Lomprayah High-Speed Ferry', null, 'https://www.lomprayah.com/')
on conflict (name) do nothing;

insert into public.boat_piers (company_id, name, location_note)
values
  (
    (select id from public.boat_companies where name = 'Lomprayah High-Speed Ferry'),
    'Example Pier',
    'ถนนตัวอย่าง'
  ),
  (
    (select id from public.boat_companies where name = 'Lomprayah High-Speed Ferry'),
    'Example Pier',
    'อ.ตัวอย่าง'
  )
on conflict (company_id, name) do nothing;

insert into public.boat_companies (name, website)
values ('Raja Ferry Port', 'https://www.rajaferryport.com/')
on conflict (name) do nothing;

insert into public.boat_routes (
  company_id,
  departure_pier_id,
  origin,
  destination,
  boat_type,
  departure_times,
  duration_minutes,
  ticket_price,
  cost_price
)
values
  (
    (select id from public.boat_companies where name = 'Lomprayah High-Speed Ferry'),
    (
      select bp.id
      from public.boat_piers bp
      join public.boat_companies bc on bc.id = bp.company_id
      where bc.name = 'Lomprayah High-Speed Ferry'
        and bp.name = 'Example Pier'
      limit 1
    ),
    'Example Pier', 'Island A', 'speedboat',
    array['08:00', '12:00'], 90, null, null
  ),
  (
    (select id from public.boat_companies where name = 'Lomprayah High-Speed Ferry'),
    (
      select bp.id
      from public.boat_piers bp
      join public.boat_companies bc on bc.id = bp.company_id
      where bc.name = 'Lomprayah High-Speed Ferry'
        and bp.name = 'Example Pier'
      limit 1
    ),
    'Example Pier', 'Island B', 'speedboat',
    array['08:00', '12:00'], 120, null, null
  ),
  (
    (select id from public.boat_companies where name = 'Lomprayah High-Speed Ferry'),
    (
      select bp.id
      from public.boat_piers bp
      join public.boat_companies bc on bc.id = bp.company_id
      where bc.name = 'Lomprayah High-Speed Ferry'
        and bp.name = 'Example Pier'
      limit 1
    ),
    'Example Pier', 'Island C', 'speedboat',
    array['08:00'], 150, null, null
  )
on conflict do nothing;

grant execute on function public.generate_transfer_voucher_number() to anon, authenticated;
grant execute on function public.transfer_create_booking(
  uuid,
  text,
  text,
  timestamptz,
  text,
  text,
  int,
  int,
  uuid,
  uuid,
  uuid,
  uuid,
  numeric,
  numeric,
  numeric,
  numeric,
  text,
  text,
  text
) to anon, authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050001_phase11_raja_pickup_timetable.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Raja Ferry pickup timetable from OpenHotel
-- Source: provided schedule photo (Pickup from Hotel)

insert into public.boat_companies (name, website)
values ('Raja Ferry Port', 'https://www.rajaferryport.com/')
on conflict (name) do nothing;

insert into public.boat_piers (company_id, name, location_note)
values
  (
    (select id from public.boat_companies where name = 'Raja Ferry Port' limit 1),
    'Pier A',
    'Island A'
  ),
  (
    (select id from public.boat_companies where name = 'Raja Ferry Port' limit 1),
    'Pier B',
    'Island B'
  )
on conflict (company_id, name) do nothing;

do $$
declare
  v_company_id uuid;
  v_route_id uuid;
begin
  select id into v_company_id
  from public.boat_companies
  where name = 'Raja Ferry Port'
  limit 1;

  -- Route 1: OpenHotel -> Island A (Pier A)
  select id into v_route_id
  from public.boat_routes
  where company_id = v_company_id
    and lower(origin) = lower('OpenHotel')
    and lower(destination) = lower('Island A (Pier A)')
  order by created_at desc
  limit 1;

  if v_route_id is null then
    insert into public.boat_routes (
      company_id,
      departure_pier_id,
      origin,
      destination,
      boat_type,
      departure_times,
      duration_minutes,
      ticket_price,
      cost_price,
      includes_pickup,
      pickup_fee,
      season_label,
      notes,
      is_active
    ) values (
      v_company_id,
      null,
      'OpenHotel',
      'Island A (Pier A)',
      'car_ferry',
      array['06:30','09:00','11:00','12:00','14:00','16:00','17:00'],
      null,
      null,
      null,
      true,
      null,
      'Raja Pickup from Hotel',
      'Pickup->Arrive: 06:30->09:30, 09:00->12:30, 11:00->14:30, 12:00->15:30, 14:00->17:30, 16:00->19:30, 17:00->20:30',
      true
    );
  else
    update public.boat_routes
    set boat_type = 'car_ferry',
        departure_times = array['06:30','09:00','11:00','12:00','14:00','16:00','17:00'],
        includes_pickup = true,
        season_label = 'Raja Pickup from Hotel',
        notes = 'Pickup->Arrive: 06:30->09:30, 09:00->12:30, 11:00->14:30, 12:00->15:30, 14:00->17:30, 16:00->19:30, 17:00->20:30',
        is_active = true,
        updated_at = now()
    where id = v_route_id;
  end if;

  -- Route 2: OpenHotel -> Island B (Pier B)
  v_route_id := null;
  select id into v_route_id
  from public.boat_routes
  where company_id = v_company_id
    and lower(origin) = lower('OpenHotel')
    and lower(destination) = lower('Island B (Pier B)')
  order by created_at desc
  limit 1;

  if v_route_id is null then
    insert into public.boat_routes (
      company_id,
      departure_pier_id,
      origin,
      destination,
      boat_type,
      departure_times,
      duration_minutes,
      ticket_price,
      cost_price,
      includes_pickup,
      pickup_fee,
      season_label,
      notes,
      is_active
    ) values (
      v_company_id,
      null,
      'OpenHotel',
      'Island B (Pier B)',
      'car_ferry',
      array['06:30','08:00','09:00','11:00','12:00','14:00','16:00'],
      null,
      null,
      null,
      true,
      null,
      'Raja Pickup from Hotel',
      'Pickup->Arrive: 06:30->10:30, 08:00->13:30, 09:00->13:30, 11:00->16:30, 12:00->16:30, 14:00->20:30, 16:00->20:30',
      true
    );
  else
    update public.boat_routes
    set boat_type = 'car_ferry',
        departure_times = array['06:30','08:00','09:00','11:00','12:00','14:00','16:00'],
        includes_pickup = true,
        season_label = 'Raja Pickup from Hotel',
        notes = 'Pickup->Arrive: 06:30->10:30, 08:00->13:30, 09:00->13:30, 11:00->16:30, 12:00->16:30, 14:00->20:30, 16:00->20:30',
        is_active = true,
        updated_at = now()
    where id = v_route_id;
  end if;
end $$;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050002_phase11_transfer_alert_switch.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 11 hotfix: board transfer alert switch (ON/OFF)
-- Default behavior: every transfer starts with alert enabled.

alter table if exists public.transfers
  add column if not exists alert_enabled boolean;

update public.transfers
set alert_enabled = true
where alert_enabled is null;

alter table if exists public.transfers
  alter column alert_enabled set default true,
  alter column alert_enabled set not null;

create index if not exists idx_transfers_alert_enabled
  on public.transfers (alert_enabled);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050003_phase11_transfer_increment_driver.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create or replace function public.increment_driver_total_trips(p_driver_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_driver_id is null then
    raise exception 'driver_id is required';
  end if;

  update public.drivers
  set total_trips = coalesce(total_trips, 0) + 1
  where id = p_driver_id;

  if not found then
    raise exception 'Driver not found';
  end if;
end;
$$;

grant execute on function public.increment_driver_total_trips(uuid) to anon, authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050004_phase11a_accounting_backbone.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- ============================================================
-- Phase 11A: Accounting Backbone (Agent B scope)
-- ============================================================

create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────────
-- transfer_transactions (separate from folio_payments)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.transfer_transactions (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.transfers(id) on delete cascade,
  reservation_id uuid references public.reservations(id) on delete set null,
  guest_profile_id uuid references public.guest_profiles(id) on delete set null,
  tx_type text not null check (tx_type in ('charge', 'refund', 'adjustment')),
  amount numeric(10,2) not null check (amount >= 0),
  selling_price numeric(10,2),
  cost_price numeric(10,2),
  margin numeric(10,2),
  payment_method public.payment_method_type,
  cashier_name text,
  note text,
  transaction_date date not null default current_date,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_transfer_transactions_date
  on public.transfer_transactions (transaction_date desc);

create index if not exists idx_transfer_transactions_transfer
  on public.transfer_transactions (transfer_id);

create index if not exists idx_transfer_transactions_reservation
  on public.transfer_transactions (reservation_id);

create index if not exists idx_transfer_transactions_guest
  on public.transfer_transactions (guest_profile_id);

-- ─────────────────────────────────────────────────────────────
-- commission_ledger (1 transfer = 1 commission, idempotent)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.commission_ledger (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null unique references public.transfers(id) on delete cascade,
  reservation_id uuid references public.reservations(id) on delete set null,
  guest_profile_id uuid references public.guest_profiles(id) on delete set null,
  staff_name text not null,
  rule_type text not null default 'fixed' check (rule_type in ('pct_sell', 'pct_margin', 'fixed')),
  rule_value numeric(10,2) not null default 0,
  base_amount numeric(10,2) not null default 0,
  commission_amount numeric(10,2) not null default 0 check (commission_amount >= 0),
  status text not null default 'pending' check (status in ('pending', 'approved', 'paid', 'reversed')),
  payout_cycle text not null default 'monthly' check (payout_cycle in ('monthly', 'bimonthly')),
  approved_by text,
  approved_at timestamptz,
  paid_at timestamptz,
  reversal_reason text,
  reversed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint commission_reversal_reason_required
    check (status <> 'reversed' or (reversal_reason is not null and btrim(reversal_reason) <> ''))
);

create index if not exists idx_commission_ledger_status
  on public.commission_ledger (status);

create index if not exists idx_commission_ledger_created_at
  on public.commission_ledger (created_at desc);

create index if not exists idx_commission_ledger_staff
  on public.commission_ledger (staff_name);

drop trigger if exists trg_commission_ledger_updated_at on public.commission_ledger;
create trigger trg_commission_ledger_updated_at
before update on public.commission_ledger
for each row execute function public.set_updated_at();

-- ─────────────────────────────────────────────────────────────
-- tip_ledger
-- ─────────────────────────────────────────────────────────────
create table if not exists public.tip_ledger (
  id uuid primary key default gen_random_uuid(),
  tip_type text not null check (tip_type in ('unassigned', 'manual_staff')),
  reservation_id uuid references public.reservations(id) on delete set null,
  guest_profile_id uuid references public.guest_profiles(id) on delete set null,
  transfer_id uuid references public.transfers(id) on delete set null,
  amount numeric(10,2) not null check (amount > 0),
  payment_method public.payment_method_type not null default 'cash',
  assigned_to text,
  recorded_by text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'paid', 'reversed')),
  approved_at timestamptz,
  paid_at timestamptz,
  reversal_reason text,
  reversed_at timestamptz,
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint tip_manual_staff_link_required
    check (
      tip_type <> 'manual_staff'
      or (reservation_id is not null and guest_profile_id is not null)
    ),
  constraint tip_reversal_reason_required
    check (status <> 'reversed' or (reversal_reason is not null and btrim(reversal_reason) <> ''))
);

create index if not exists idx_tip_ledger_status
  on public.tip_ledger (status);

create index if not exists idx_tip_ledger_created_at
  on public.tip_ledger (created_at desc);

create index if not exists idx_tip_ledger_reservation
  on public.tip_ledger (reservation_id);

create index if not exists idx_tip_ledger_guest
  on public.tip_ledger (guest_profile_id);

drop trigger if exists trg_tip_ledger_updated_at on public.tip_ledger;
create trigger trg_tip_ledger_updated_at
before update on public.tip_ledger
for each row execute function public.set_updated_at();

-- ─────────────────────────────────────────────────────────────
-- folio_payments enhancement (hotel revenue only)
-- ─────────────────────────────────────────────────────────────
alter table public.folio_payments
  add column if not exists revenue_category text,
  add column if not exists cashier_name text;

update public.folio_payments
set revenue_category = case
  when revenue_category is not null then revenue_category
  when tx_type = 'deposit' then 'deposit'
  when pos_order_id is not null then 'pos_revenue'
  else 'room_revenue'
end;

alter table public.folio_payments
  alter column revenue_category set default 'room_revenue';

update public.folio_payments
set revenue_category = 'room_revenue'
where revenue_category is null;

alter table public.folio_payments
  alter column revenue_category set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'folio_payments_revenue_category_check'
  ) then
    alter table public.folio_payments
      add constraint folio_payments_revenue_category_check
      check (revenue_category in ('room_revenue', 'pos_revenue', 'extra_charge', 'deposit'));
  end if;
end $$;

create index if not exists idx_folio_payments_revenue_category
  on public.folio_payments (revenue_category);

create index if not exists idx_folio_payments_cashier_name
  on public.folio_payments (cashier_name);

-- ─────────────────────────────────────────────────────────────
-- audit_logs enhancement
-- ─────────────────────────────────────────────────────────────
alter table public.audit_logs
  add column if not exists change_reason text,
  add column if not exists ip_address text;

create index if not exists idx_audit_logs_entity_created
  on public.audit_logs (entity_type, entity_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- daily_snapshots enhancement
-- ─────────────────────────────────────────────────────────────
alter table public.daily_snapshots
  add column if not exists transfer_revenue numeric(12,2) not null default 0,
  add column if not exists transfer_cost numeric(12,2) not null default 0,
  add column if not exists transfer_margin numeric(12,2) not null default 0,
  add column if not exists pos_revenue numeric(12,2) not null default 0,
  add column if not exists tip_total numeric(12,2) not null default 0,
  add column if not exists commission_liability numeric(12,2) not null default 0,
  add column if not exists deposit_received numeric(12,2) not null default 0,
  add column if not exists deposit_refunded numeric(12,2) not null default 0;

-- ─────────────────────────────────────────────────────────────
-- RLS (service role full access)
-- ─────────────────────────────────────────────────────────────
alter table public.transfer_transactions enable row level security;
drop policy if exists transfer_transactions_service_role_full_access on public.transfer_transactions;
create policy transfer_transactions_service_role_full_access on public.transfer_transactions
for all to service_role
using (true)
with check (true);

alter table public.commission_ledger enable row level security;
drop policy if exists commission_ledger_service_role_full_access on public.commission_ledger;
create policy commission_ledger_service_role_full_access on public.commission_ledger
for all to service_role
using (true)
with check (true);

alter table public.tip_ledger enable row level security;
drop policy if exists tip_ledger_service_role_full_access on public.tip_ledger;
create policy tip_ledger_service_role_full_access on public.tip_ledger
for all to service_role
using (true)
with check (true);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050005_phase11a_rpc_patch.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Phase 11A: Accounting Backbone — RPC Patch
-- Patches transfer_create_booking to:
--   1. Insert into transfer_transactions instead of folio_payments
--   2. Auto-create commission_ledger entry (1:1 with transfer)
-- Depends on: 20260305_phase11a_accounting_backbone.sql (new tables)
-- =============================================================

-- ★ Replace the folio_payments insert section in transfer_create_booking
-- Original: lines 546-566 inserted into folio_payments
-- New: insert into transfer_transactions + commission_ledger

CREATE OR REPLACE FUNCTION public.transfer_create_booking(
  p_reservation_id uuid,
  p_transfer_type text,
  p_service_mode text,
  p_pickup_datetime timestamptz,
  p_pickup_location text,
  p_dropoff_location text,
  p_pax int default 1,
  p_luggage_count int default 0,
  p_driver_id uuid default null,
  p_vehicle_id uuid default null,
  p_boat_company_id uuid default null,
  p_boat_route_id uuid default null,
  p_selling_price numeric default null,
  p_cost_price numeric default null,
  p_driver_fee numeric default null,
  p_driver_commission numeric default 0,
  p_payment_method text default null,
  p_staff_note text default null,
  p_created_by text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation_status text;
  v_reservation_checkout_date date;
  v_guest_name text;
  v_guest_phone text;
  v_guest_profile_id uuid;
  v_transfer_id uuid;
  v_voucher_number text;
  v_payment_method text;
  v_payment_status text;
  v_transfer_status text;
  v_alert_code text;
  v_alert_line text;
  v_alert_note text;
  v_alert_id uuid;
  v_trace_text text;
  v_pickup_date date;
  v_pickup_time text;
  v_driver_name text;
  v_driver_phone text;
  v_vehicle_info text;
  v_boat_company_name text;
  v_pier_name text;
  v_route_description text;
  v_departure_time text;
  v_operator_label text;
  v_net_commission numeric(10,2);
  v_selling_price numeric(10,2);
  v_cost_price numeric(10,2);
  v_driver_fee numeric(10,2);
  v_driver_commission numeric(10,2);
  v_margin numeric(10,2);
  v_alert_created boolean := false;
  v_trace_created boolean := false;
  v_transfer_tx_posted boolean := false;
  v_commission_created boolean := false;
begin
  -- ── Validation (unchanged from Phase 11) ──
  if p_reservation_id is null then
    raise exception 'reservation_id is required';
  end if;
  if p_pickup_datetime is null then
    raise exception 'pickup_datetime is required';
  end if;
  if p_pickup_datetime <= now() then
    raise exception 'pickup_datetime must be future';
  end if;
  if coalesce(trim(p_pickup_location), '') = '' then
    raise exception 'pickup_location is required';
  end if;
  if coalesce(trim(p_dropoff_location), '') = '' then
    raise exception 'dropoff_location is required';
  end if;
  if coalesce(p_pax, 0) <= 0 then
    raise exception 'pax must be greater than 0';
  end if;
  if coalesce(p_driver_commission, 0) < 0 then
    raise exception 'driver_commission must be >= 0';
  end if;
  if p_selling_price is not null and p_selling_price < 0 then
    raise exception 'selling_price must be >= 0';
  end if;
  if p_cost_price is not null and p_cost_price < 0 then
    raise exception 'cost_price must be >= 0';
  end if;
  if p_driver_fee is not null and p_driver_fee < 0 then
    raise exception 'driver_fee must be >= 0';
  end if;

  -- ── Lookup reservation + guest_profile_id (★ NEW: also fetch guest_profile_id) ──
  select
    r.status::text,
    r.checkout_date,
    r.guest_name,
    coalesce(nullif(trim(r.phone), ''), nullif(trim(gp.phone), '')),
    r.guest_profile_id
  into
    v_reservation_status,
    v_reservation_checkout_date,
    v_guest_name,
    v_guest_phone,
    v_guest_profile_id
  from public.reservations r
  left join public.guest_profiles gp on gp.id = r.guest_profile_id
  where r.id = p_reservation_id;

  if not found then
    raise exception 'Reservation not found';
  end if;
  if v_reservation_status <> 'active'
     and not (
       v_reservation_status = 'checked_out'
       and v_reservation_checkout_date = (now() at time zone 'Asia/Bangkok')::date
     ) then
    raise exception 'Reservation must be active or checked out today to create transfer';
  end if;

  -- ── Payment method validation ──
  v_payment_method := nullif(trim(coalesce(p_payment_method, '')), '');
  if v_payment_method is not null and v_payment_method not in ('cash', 'transfer', 'credit_card', 'other') then
    raise exception 'payment_method must be cash|transfer|credit_card|other';
  end if;

  -- ── Price rounding ──
  v_selling_price := case when p_selling_price is null then null else round(p_selling_price::numeric, 2) end;
  v_cost_price := case when p_cost_price is null then null else round(p_cost_price::numeric, 2) end;
  v_driver_fee := case when p_driver_fee is null then null else round(p_driver_fee::numeric, 2) end;
  v_driver_commission := round(coalesce(p_driver_commission, 0)::numeric, 2);

  v_net_commission := round(
    coalesce(v_selling_price, 0)
    - coalesce(v_cost_price, 0)
    - coalesce(v_driver_fee, 0)
    + coalesce(v_driver_commission, 0),
    2
  );

  v_margin := round(coalesce(v_selling_price, 0) - coalesce(v_cost_price, 0), 2);

  if v_payment_method is not null then
    v_payment_status := 'paid_to_hotel';
    if v_selling_price is null or v_selling_price <= 0 then
      raise exception 'selling_price must be > 0 when payment_method is provided';
    end if;
  else
    v_payment_status := 'unpaid';
  end if;

  if p_driver_id is not null then
    v_transfer_status := 'driver_assigned';
  else
    v_transfer_status := 'pending';
  end if;

  v_pickup_date := (p_pickup_datetime at time zone 'Asia/Bangkok')::date;
  v_pickup_time := to_char((p_pickup_datetime at time zone 'Asia/Bangkok'), 'HH24:MI');

  -- ── Lookup driver/vehicle/boat (unchanged) ──
  if p_driver_id is not null then
    select d.name, d.phone into v_driver_name, v_driver_phone
    from public.drivers d
    where d.id = p_driver_id;
  end if;

  if p_vehicle_id is not null then
    select concat_ws(' ', v.vehicle_type, '-', v.plate_number, coalesce('(' || v.color || ')', ''))
    into v_vehicle_info
    from public.vehicles v
    where v.id = p_vehicle_id;
  end if;

  if p_boat_route_id is not null then
    select
      br.origin || ' -> ' || br.destination,
      br.departure_times[1],
      bp.name,
      bc.name
    into
      v_route_description,
      v_departure_time,
      v_pier_name,
      v_boat_company_name
    from public.boat_routes br
    left join public.boat_piers bp on bp.id = br.departure_pier_id
    left join public.boat_companies bc on bc.id = br.company_id
    where br.id = p_boat_route_id;
  elsif p_boat_company_id is not null then
    select bc.name into v_boat_company_name
    from public.boat_companies bc
    where bc.id = p_boat_company_id;
  end if;

  if v_route_description is null then
    v_route_description := p_pickup_location || ' -> ' || p_dropoff_location;
  end if;

  -- ── Insert transfer (unchanged) ──
  insert into public.transfers (
    reservation_id,
    guest_name,
    guest_phone,
    transfer_type,
    service_mode,
    pickup_datetime,
    pickup_location,
    dropoff_location,
    pax,
    luggage_count,
    driver_id,
    vehicle_id,
    boat_company_id,
    boat_route_id,
    selling_price,
    cost_price,
    driver_fee,
    driver_commission,
    net_commission,
    payment_status,
    payment_method,
    status,
    staff_note,
    created_by
  )
  values (
    p_reservation_id,
    v_guest_name,
    v_guest_phone,
    p_transfer_type,
    p_service_mode,
    p_pickup_datetime,
    p_pickup_location,
    p_dropoff_location,
    coalesce(p_pax, 1),
    coalesce(p_luggage_count, 0),
    p_driver_id,
    p_vehicle_id,
    p_boat_company_id,
    p_boat_route_id,
    v_selling_price,
    v_cost_price,
    v_driver_fee,
    v_driver_commission,
    v_net_commission,
    v_payment_status,
    v_payment_method,
    v_transfer_status,
    nullif(trim(coalesce(p_staff_note, '')), ''),
    nullif(trim(coalesce(p_created_by, '')), '')
  )
  returning id into v_transfer_id;

  -- ── Voucher (unchanged) ──
  v_voucher_number := public.generate_transfer_voucher_number();
  v_operator_label := coalesce(nullif(v_boat_company_name, ''), nullif(v_driver_name, ''), 'Transfer');

  insert into public.transfer_vouchers (
    transfer_id,
    voucher_number,
    guest_name,
    route_description,
    departure_time,
    pier_name,
    boat_company_name,
    pickup_time,
    pickup_location,
    driver_name,
    driver_phone,
    vehicle_info,
    special_instructions
  )
  values (
    v_transfer_id,
    v_voucher_number,
    v_guest_name,
    v_route_description,
    v_departure_time,
    v_pier_name,
    v_boat_company_name,
    v_pickup_time,
    p_pickup_location,
    v_driver_name,
    v_driver_phone,
    v_vehicle_info,
    nullif(trim(coalesce(p_staff_note, '')), '')
  );

  -- ── Alert (unchanged) ──
  v_alert_code := case
    when p_transfer_type in ('bus_ferry_pickup', 'ticket_only') then 'BOAT'
    else 'CAR'
  end;
  v_alert_line := '[' || v_voucher_number || '] ' || v_pickup_time || ' ' || v_operator_label;

  select ra.id, ra.note
  into v_alert_id, v_alert_note
  from public.reservation_alerts ra
  where ra.reservation_id = p_reservation_id
    and ra.alert_code = v_alert_code
  for update;

  if not found then
    insert into public.reservation_alerts (reservation_id, alert_code, note)
    values (p_reservation_id, v_alert_code, v_alert_line);
  else
    if coalesce(trim(v_alert_note), '') = '' then
      v_alert_note := v_alert_line;
    elsif strpos(v_alert_note, v_alert_line) > 0 then
      v_alert_note := v_alert_note;
    else
      v_alert_note := v_alert_note || E'\n' || v_alert_line;
    end if;

    update public.reservation_alerts
    set note = v_alert_note
    where id = v_alert_id;
  end if;
  v_alert_created := true;

  -- ── Trace (unchanged) ──
  v_trace_text := '[TRANSFER][' || v_voucher_number || '] '
    || p_transfer_type
    || ' pickup '
    || v_pickup_time
    || ' - '
    || v_operator_label;

  insert into public.reservation_traces (
    reservation_id,
    created_by,
    dept,
    trace_text,
    from_date,
    to_date,
    status
  )
  values (
    p_reservation_id,
    nullif(trim(coalesce(p_created_by, '')), ''),
    'FD',
    v_trace_text,
    v_pickup_date,
    v_pickup_date,
    'open'
  );
  v_trace_created := true;

  -- ══════════════════════════════════════════════════════
  -- ★ PHASE 11A CHANGE: Insert transfer_transactions instead of folio_payments
  -- ══════════════════════════════════════════════════════
  if v_payment_status = 'paid_to_hotel' and v_selling_price is not null and v_selling_price > 0 then
    insert into public.transfer_transactions (
      transfer_id,
      reservation_id,
      guest_profile_id,
      tx_type,
      amount,
      selling_price,
      cost_price,
      margin,
      payment_method,
      cashier_name,
      note
    )
    values (
      v_transfer_id,
      p_reservation_id,
      v_guest_profile_id,
      'charge',
      v_selling_price,
      v_selling_price,
      v_cost_price,
      v_margin,
      v_payment_method::public.payment_method_type,
      nullif(trim(coalesce(p_created_by, '')), ''),
      'Transfer: ' || p_transfer_type || ' - ' || v_voucher_number
    );
    v_transfer_tx_posted := true;
  end if;

  -- ══════════════════════════════════════════════════════
  -- ★ PHASE 11A: Auto-create commission_ledger (1:1 with transfer)
  -- Only when selling_price > 0 (has financial data)
  -- ══════════════════════════════════════════════════════
  if v_selling_price is not null and v_selling_price > 0 then
    insert into public.commission_ledger (
      transfer_id,
      reservation_id,
      guest_profile_id,
      staff_name,
      rule_type,
      rule_value,
      base_amount,
      commission_amount,
      status,
      payout_cycle
    )
    values (
      v_transfer_id,
      p_reservation_id,
      v_guest_profile_id,
      coalesce(v_driver_name, nullif(trim(coalesce(p_created_by, '')), ''), 'N/A'),
      'pct_sell',
      case when v_selling_price > 0 then round((v_driver_commission / v_selling_price) * 100, 2) else 0 end,
      v_selling_price,
      v_driver_commission,
      'pending',
      'monthly'
    );
    v_commission_created := true;
  end if;

  return jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'voucher_number', v_voucher_number,
    'alert_created', v_alert_created,
    'trace_created', v_trace_created,
    'transfer_tx_posted', v_transfer_tx_posted,
    'commission_created', v_commission_created
  );
end;
$$;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050006_phase11b_merge_rpc_column_guard_hotfix.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Hotfix: Merge profile RPC should not fail when optional modules
--         do not yet have guest_profile_id columns.
-- Date: 2026-03-05
-- =============================================================

create or replace function public.merge_guest_profiles(
  p_master_id uuid,
  p_source_id uuid,
  p_reason text default 'manual_merge'
) returns jsonb
language plpgsql
as $$
declare
  v_master public.guest_profiles%rowtype;
  v_source public.guest_profiles%rowtype;

  v_has_transfers_guest_profile boolean;
  v_has_transfer_tx_guest_profile boolean;
  v_has_commission_guest_profile boolean;
  v_has_tip_guest_profile boolean;
  v_has_reservation_guests boolean;
begin
  select * into v_master
  from public.guest_profiles
  where id = p_master_id
  for update;

  select * into v_source
  from public.guest_profiles
  where id = p_source_id
  for update;

  if v_master.id is null then
    raise exception 'Master profile not found';
  end if;
  if v_source.id is null then
    raise exception 'Source profile not found';
  end if;
  if p_master_id = p_source_id then
    raise exception 'Cannot merge profile with itself';
  end if;
  if v_master.do_not_merge or v_source.do_not_merge then
    raise exception 'Profile has do_not_merge flag';
  end if;
  if v_source.profile_status = 'merged' then
    raise exception 'Source already merged';
  end if;

  -- Core link: reservations must always repoint.
  update public.reservations
  set guest_profile_id = p_master_id
  where guest_profile_id = p_source_id;

  -- Optional modules: guard by real column existence before updating.
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'transfers'
      and column_name = 'guest_profile_id'
  ) into v_has_transfers_guest_profile;

  if v_has_transfers_guest_profile then
    execute 'update public.transfers set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'transfer_transactions'
      and column_name = 'guest_profile_id'
  ) into v_has_transfer_tx_guest_profile;

  if v_has_transfer_tx_guest_profile then
    execute 'update public.transfer_transactions set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'commission_ledger'
      and column_name = 'guest_profile_id'
  ) into v_has_commission_guest_profile;

  if v_has_commission_guest_profile then
    execute 'update public.commission_ledger set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tip_ledger'
      and column_name = 'guest_profile_id'
  ) into v_has_tip_guest_profile;

  if v_has_tip_guest_profile then
    execute 'update public.tip_ledger set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  select exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'reservation_guests'
  ) into v_has_reservation_guests;

  if v_has_reservation_guests then
    -- Remove rows that would break unique constraints after repoint.
    execute $q$
      delete from public.reservation_guests src
      using public.reservation_guests other_row
      where src.guest_profile_id = $1
        and src.reservation_id = other_row.reservation_id
        and other_row.guest_profile_id <> $1
        and (
          other_row.guest_profile_id = $2
          or (
            src.role = 'accompanying'
            and other_row.role = 'accompanying'
            and src.display_order = other_row.display_order
          )
          or (src.role = 'primary' and other_row.role = 'primary')
        )
    $q$ using p_source_id, p_master_id;

    execute 'update public.reservation_guests set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  update public.guest_profiles
  set
    profile_status = 'merged',
    merged_into = p_master_id,
    updated_at = now()
  where id = p_source_id;

  update public.guest_profiles
  set
    stay_count = (
      select count(*)
      from public.reservations
      where guest_profile_id = p_master_id
        and status <> 'cancelled'
    ),
    updated_at = now()
  where id = p_master_id;

  update public.profile_match_scores
  set status = 'merged'
  where (profile_a = p_source_id or profile_b = p_source_id)
    and status = 'pending';

  insert into public.audit_logs (action, entity_type, entity_id, before_json, after_json, change_reason)
  values (
    'profile_merged',
    'guest_profiles',
    p_master_id::text,
    jsonb_build_object('source_id', p_source_id, 'source_name', concat(v_source.first_name, ' ', v_source.last_name)),
    jsonb_build_object('master_id', p_master_id, 'master_name', concat(v_master.first_name, ' ', v_master.last_name)),
    p_reason
  );

  return jsonb_build_object(
    'success', true,
    'master_id', p_master_id,
    'source_id', p_source_id
  );
end;
$$;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050007_phase11b_profile_lifecycle.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Migration: Phase 11B - Profile Lifecycle + Duplicate Control
-- Date: 2026-03-05
-- =============================================================

-- 1A) guest_profiles expansion
ALTER TABLE public.guest_profiles
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS id_type text,
  ADD COLUMN IF NOT EXISTS id_number text,
  ADD COLUMN IF NOT EXISTS nationality_code text,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS whatsapp text,
  ADD COLUMN IF NOT EXISTS profile_status text NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS merged_into uuid REFERENCES public.guest_profiles(id),
  ADD COLUMN IF NOT EXISTS do_not_merge boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_stay_date date;

-- Keep existing semantics in codebase: gender = M/F/Other
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_gender') THEN
    ALTER TABLE public.guest_profiles
      ADD CONSTRAINT chk_gender
      CHECK (gender IS NULL OR gender IN ('M', 'F', 'Other'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_id_type') THEN
    ALTER TABLE public.guest_profiles
      ADD CONSTRAINT chk_id_type
      CHECK (id_type IS NULL OR id_type IN ('thai_id', 'passport', 'other'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_profile_status') THEN
    ALTER TABLE public.guest_profiles
      ADD CONSTRAINT chk_profile_status
      CHECK (profile_status IN ('draft', 'verified', 'merged', 'blacklisted'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_id_number_requires_type') THEN
    ALTER TABLE public.guest_profiles
      ADD CONSTRAINT chk_id_number_requires_type
      CHECK (id_number IS NULL OR id_type IS NOT NULL);
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_guest_profiles_id_number_unique
  ON public.guest_profiles (id_type, id_number)
  WHERE id_number IS NOT NULL
    AND id_type IS NOT NULL
    AND profile_status <> 'merged';

-- 1B) profile_match_scores
CREATE TABLE IF NOT EXISTS public.profile_match_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_a uuid NOT NULL REFERENCES public.guest_profiles(id) ON DELETE CASCADE,
  profile_b uuid NOT NULL REFERENCES public.guest_profiles(id) ON DELETE CASCADE,
  score numeric(5,2) NOT NULL,
  match_fields jsonb NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'merged', 'dismissed', 'do_not_merge')),
  reviewed_by text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT no_self_match CHECK (profile_a <> profile_b),
  CONSTRAINT unique_match_pair UNIQUE (profile_a, profile_b)
);

-- 1C) reservation_guests (accompanying)
CREATE TABLE IF NOT EXISTS public.reservation_guests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid NOT NULL REFERENCES public.reservations(id) ON DELETE CASCADE,
  guest_profile_id uuid NOT NULL REFERENCES public.guest_profiles(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'accompanying'
    CHECK (role IN ('primary', 'accompanying')),
  display_order smallint NOT NULL DEFAULT 1
    CHECK (display_order BETWEEN 1 AND 4),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT unique_guest_per_reservation UNIQUE (reservation_id, guest_profile_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_primary_guest
  ON public.reservation_guests (reservation_id)
  WHERE role = 'primary';

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_accompanying_order
  ON public.reservation_guests (reservation_id, display_order)
  WHERE role = 'accompanying';

-- 1D) Backfill nationality_code + country from legacy nationality
UPDATE public.guest_profiles
SET
  nationality_code = CASE UPPER(TRIM(nationality))
    WHEN 'THA' THEN 'THA' WHEN 'THAI' THEN 'THA' WHEN 'THAILAND' THEN 'THA'
    WHEN 'GBR' THEN 'GBR' WHEN 'BRITISH' THEN 'GBR' WHEN 'UK' THEN 'GBR'
    WHEN 'USA' THEN 'USA' WHEN 'AMERICAN' THEN 'USA' WHEN 'US' THEN 'USA'
    WHEN 'JPN' THEN 'JPN' WHEN 'JAPANESE' THEN 'JPN' WHEN 'JAPAN' THEN 'JPN'
    WHEN 'KOR' THEN 'KOR' WHEN 'KOREAN' THEN 'KOR'
    WHEN 'CHN' THEN 'CHN' WHEN 'CHINESE' THEN 'CHN' WHEN 'CHINA' THEN 'CHN'
    WHEN 'AUS' THEN 'AUS' WHEN 'AUSTRALIAN' THEN 'AUS'
    WHEN 'DEU' THEN 'DEU' WHEN 'GERMAN' THEN 'DEU' WHEN 'GERMANY' THEN 'DEU'
    WHEN 'FRA' THEN 'FRA' WHEN 'FRENCH' THEN 'FRA' WHEN 'FRANCE' THEN 'FRA'
    WHEN 'RUS' THEN 'RUS' WHEN 'RUSSIAN' THEN 'RUS'
    WHEN 'IND' THEN 'IND' WHEN 'INDIAN' THEN 'IND'
    ELSE UPPER(TRIM(nationality))
  END,
  country = CASE UPPER(TRIM(nationality))
    WHEN 'THA' THEN 'Thailand' WHEN 'THAI' THEN 'Thailand' WHEN 'THAILAND' THEN 'Thailand'
    WHEN 'GBR' THEN 'United Kingdom' WHEN 'BRITISH' THEN 'United Kingdom' WHEN 'UK' THEN 'United Kingdom'
    WHEN 'USA' THEN 'United States' WHEN 'AMERICAN' THEN 'United States' WHEN 'US' THEN 'United States'
    WHEN 'JPN' THEN 'Japan' WHEN 'JAPANESE' THEN 'Japan' WHEN 'JAPAN' THEN 'Japan'
    WHEN 'KOR' THEN 'South Korea' WHEN 'KOREAN' THEN 'South Korea'
    WHEN 'CHN' THEN 'China' WHEN 'CHINESE' THEN 'China' WHEN 'CHINA' THEN 'China'
    WHEN 'AUS' THEN 'Australia' WHEN 'AUSTRALIAN' THEN 'Australia'
    WHEN 'DEU' THEN 'Germany' WHEN 'GERMAN' THEN 'Germany' WHEN 'GERMANY' THEN 'Germany'
    WHEN 'FRA' THEN 'France' WHEN 'FRENCH' THEN 'France' WHEN 'FRANCE' THEN 'France'
    WHEN 'RUS' THEN 'Russia' WHEN 'RUSSIAN' THEN 'Russia'
    WHEN 'IND' THEN 'India' WHEN 'INDIAN' THEN 'India'
    ELSE nationality
  END
WHERE nationality IS NOT NULL
  AND nationality_code IS NULL;

-- 1E) Atomic merge RPC
CREATE OR REPLACE FUNCTION public.merge_guest_profiles(
  p_master_id uuid,
  p_source_id uuid,
  p_reason text DEFAULT 'manual_merge'
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_master public.guest_profiles%ROWTYPE;
  v_source public.guest_profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_master
  FROM public.guest_profiles
  WHERE id = p_master_id
  FOR UPDATE;

  SELECT * INTO v_source
  FROM public.guest_profiles
  WHERE id = p_source_id
  FOR UPDATE;

  IF v_master.id IS NULL THEN
    RAISE EXCEPTION 'Master profile not found';
  END IF;
  IF v_source.id IS NULL THEN
    RAISE EXCEPTION 'Source profile not found';
  END IF;
  IF p_master_id = p_source_id THEN
    RAISE EXCEPTION 'Cannot merge profile with itself';
  END IF;
  IF v_master.do_not_merge OR v_source.do_not_merge THEN
    RAISE EXCEPTION 'Profile has do_not_merge flag';
  END IF;
  IF v_source.profile_status = 'merged' THEN
    RAISE EXCEPTION 'Source already merged';
  END IF;

  UPDATE public.reservations
  SET guest_profile_id = p_master_id
  WHERE guest_profile_id = p_source_id;

  UPDATE public.transfers
  SET guest_profile_id = p_master_id
  WHERE guest_profile_id = p_source_id;

  UPDATE public.transfer_transactions
  SET guest_profile_id = p_master_id
  WHERE guest_profile_id = p_source_id;

  UPDATE public.commission_ledger
  SET guest_profile_id = p_master_id
  WHERE guest_profile_id = p_source_id;

  UPDATE public.tip_ledger
  SET guest_profile_id = p_master_id
  WHERE guest_profile_id = p_source_id;

  -- reservation_guests: remove source rows that would violate unique constraints
  DELETE FROM public.reservation_guests src
  USING public.reservation_guests other_row
  WHERE src.guest_profile_id = p_source_id
    AND src.reservation_id = other_row.reservation_id
    AND other_row.guest_profile_id <> p_source_id
    AND (
      other_row.guest_profile_id = p_master_id
      OR (
        src.role = 'accompanying'
        AND other_row.role = 'accompanying'
        AND src.display_order = other_row.display_order
      )
      OR (src.role = 'primary' AND other_row.role = 'primary')
    );

  UPDATE public.reservation_guests
  SET guest_profile_id = p_master_id
  WHERE guest_profile_id = p_source_id;

  UPDATE public.guest_profiles
  SET
    profile_status = 'merged',
    merged_into = p_master_id,
    updated_at = now()
  WHERE id = p_source_id;

  UPDATE public.guest_profiles
  SET
    stay_count = (
      SELECT count(*)
      FROM public.reservations
      WHERE guest_profile_id = p_master_id
        AND status <> 'cancelled'
    ),
    updated_at = now()
  WHERE id = p_master_id;

  UPDATE public.profile_match_scores
  SET status = 'merged'
  WHERE (profile_a = p_source_id OR profile_b = p_source_id)
    AND status = 'pending';

  INSERT INTO public.audit_logs (action, entity_type, entity_id, before_json, after_json, change_reason)
  VALUES (
    'profile_merged',
    'guest_profiles',
    p_master_id::text,
    jsonb_build_object('source_id', p_source_id, 'source_name', concat(v_source.first_name, ' ', v_source.last_name)),
    jsonb_build_object('master_id', p_master_id, 'master_name', concat(v_master.first_name, ' ', v_master.last_name)),
    p_reason
  );

  RETURN jsonb_build_object(
    'success', true,
    'master_id', p_master_id,
    'source_id', p_source_id
  );
END;
$$;

-- 1F) RLS + service role policy
ALTER TABLE public.profile_match_scores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS service_full ON public.profile_match_scores;
CREATE POLICY service_full
  ON public.profile_match_scores
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

ALTER TABLE public.reservation_guests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS service_full ON public.reservation_guests;
CREATE POLICY service_full
  ON public.reservation_guests
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050008_phase11b_thai_card_fastpath.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- =============================================================
-- Migration: Phase 11B Thai Card Fast Path
-- Date: 2026-03-04
-- Purpose:
--   1) Backfill legacy Thai ID rows into unified (id_type, id_number)
--   2) Add fast lookup index for Thai card check-in flow
-- =============================================================

-- Backfill from legacy id_card_number when id_number is empty.
UPDATE public.guest_profiles
SET
  id_type = COALESCE(NULLIF(id_type, ''), 'thai_id'),
  id_number = regexp_replace(COALESCE(id_card_number, ''), '\D', '', 'g')
WHERE COALESCE(NULLIF(id_card_number, ''), '') <> ''
  AND COALESCE(NULLIF(id_number, ''), '') = '';

-- Fast exact-lookup path for card reader flow.
CREATE INDEX IF NOT EXISTS idx_guest_profiles_thai_id_lookup
  ON public.guest_profiles (id_number)
  WHERE id_type = 'thai_id'
    AND profile_status <> 'merged';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050009_phase12a_staff_directory_foundation.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create extension if not exists "pgcrypto";

-- ============================================================
-- Phase 12A: Staff Directory Foundation (Layer 1)
-- Scope:
--   1) departments (+ seed)
--   2) staff (1:1 extension of profiles.user_id)
--   3) line_binding_tokens
--   4) idempotent backfill profiles -> staff
--   5) baseline RLS
-- ============================================================

-- ------------------------------------------------------------
-- 1) departments
-- ------------------------------------------------------------
create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  line_group_id text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_departments_is_active
  on public.departments (is_active);

drop trigger if exists trg_departments_updated_at on public.departments;
create trigger trg_departments_updated_at
before update on public.departments
for each row execute function public.set_updated_at();

insert into public.departments (code, name)
values
  ('FO', 'Front Office'),
  ('HK', 'Housekeeping'),
  ('MNT', 'Maintenance'),
  ('FB', 'Food & Beverage'),
  ('SEC', 'Security')
on conflict (code) do nothing;

-- ------------------------------------------------------------
-- 2) staff (profiles extension)
-- ------------------------------------------------------------
create table if not exists public.staff (
  id uuid primary key references public.profiles(user_id) on delete cascade,
  employee_code text unique not null,
  display_name text not null,
  nickname text,
  department_id uuid references public.departments(id) on delete set null,
  is_active boolean not null default true,
  line_user_id text unique,
  line_display_name text,
  line_picture_url text,
  line_bound_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_staff_department
  on public.staff (department_id);

create index if not exists idx_staff_is_active
  on public.staff (is_active);

create index if not exists idx_staff_display_name
  on public.staff (display_name);

drop trigger if exists trg_staff_updated_at on public.staff;
create trigger trg_staff_updated_at
before update on public.staff
for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 3) line_binding_tokens
-- ------------------------------------------------------------
create table if not exists public.line_binding_tokens (
  token text primary key,
  staff_id uuid not null references public.staff(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_line_binding_tokens_staff_expires
  on public.line_binding_tokens (staff_id, expires_at desc);

create index if not exists idx_line_binding_tokens_open
  on public.line_binding_tokens (staff_id, used_at, expires_at);

-- ------------------------------------------------------------
-- 4) idempotent backfill (profiles -> staff)
-- Role lock in Phase 12A: admin | frontdesk | maid | supervisor
-- ------------------------------------------------------------
insert into public.staff (
  id,
  display_name,
  employee_code,
  department_id,
  is_active,
  created_at,
  updated_at
)
select
  p.user_id,
  coalesce(nullif(trim(p.full_name), ''), 'Unknown'),
  'TMP-' || upper(substr(p.user_id::text, 1, 8)),
  d.id,
  true,
  timezone('utc', now()),
  timezone('utc', now())
from public.profiles p
left join public.departments d
  on d.code = case
    when p.role = 'frontdesk' then 'FO'
    when p.role = 'maid' then 'HK'
    when p.role = 'supervisor' then 'FO'
    when p.role = 'admin' then 'FO'
    else 'FO'
  end
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 5) baseline RLS
-- Intentionally no DELETE policies in Phase 12A:
--   - staff uses soft-delete via is_active=false
--   - line_binding_tokens uses used_at lifecycle instead of hard delete
-- ------------------------------------------------------------
alter table public.departments enable row level security;
alter table public.staff enable row level security;
alter table public.line_binding_tokens enable row level security;

drop policy if exists departments_select_authenticated on public.departments;
create policy departments_select_authenticated on public.departments
for select to authenticated
using (is_active = true);

drop policy if exists departments_write_admin_supervisor on public.departments;
create policy departments_write_admin_supervisor on public.departments
for all to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

drop policy if exists staff_select_self_or_admin_supervisor on public.staff;
create policy staff_select_self_or_admin_supervisor on public.staff
for select to authenticated
using (
  id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

drop policy if exists staff_write_admin_supervisor on public.staff;
create policy staff_write_admin_supervisor on public.staff
for all to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

drop policy if exists line_binding_tokens_select_self_or_admin_supervisor on public.line_binding_tokens;
create policy line_binding_tokens_select_self_or_admin_supervisor on public.line_binding_tokens
for select to authenticated
using (
  staff_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

drop policy if exists line_binding_tokens_insert_self_or_admin_supervisor on public.line_binding_tokens;
create policy line_binding_tokens_insert_self_or_admin_supervisor on public.line_binding_tokens
for insert to authenticated
with check (
  staff_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

drop policy if exists line_binding_tokens_update_self_or_admin_supervisor on public.line_binding_tokens;
create policy line_binding_tokens_update_self_or_admin_supervisor on public.line_binding_tokens
for update to authenticated
using (
  staff_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
)
with check (
  staff_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050010_phase12b_hk_staff_lanes.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 12B hotfix: operational staff lanes independent from auth-linked staff

create table if not exists public.hk_staff_lanes (
  id uuid primary key default gen_random_uuid(),
  display_name text not null unique,
  nickname text,
  department_code text not null default 'HK'
    check (department_code in ('FO', 'HK', 'MNT', 'FB', 'SEC')),
  is_active boolean not null default true,
  hk_lane_enabled boolean not null default true,
  hk_lane_order integer not null default 100
    check (hk_lane_order between 1 and 999),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_hk_staff_lanes_active_order
  on public.hk_staff_lanes (is_active, hk_lane_enabled, hk_lane_order, display_name);

drop trigger if exists trg_hk_staff_lanes_updated_at on public.hk_staff_lanes;
create trigger trg_hk_staff_lanes_updated_at
before update on public.hk_staff_lanes
for each row execute function public.set_updated_at();

-- seed baseline names used by HK workflow
insert into public.hk_staff_lanes (display_name, department_code, hk_lane_enabled, hk_lane_order, is_active)
values
  ('Jan', 'HK', true, 1, true),
  ('Tan', 'HK', true, 2, true),
  ('Others', 'HK', true, 999, true)
on conflict (display_name) do nothing;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050011_phase12b_shifts_webhook.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- ============================================================
-- Phase 12B: Staff Shifts foundation for roster + LINE bind flow
-- ============================================================

create table if not exists public.staff_shifts (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id) on delete cascade,
  shift_date date not null,
  shift_type text not null
    check (shift_type in ('morning', 'afternoon', 'night', 'off')),
  started_at timestamptz,
  ended_at timestamptz,
  is_on_duty boolean generated always as (
    started_at is not null and ended_at is null
  ) stored,
  created_at timestamptz not null default timezone('utc', now()),
  unique (staff_id, shift_date, shift_type),
  constraint chk_staff_shifts_clock_order
    check (ended_at is null or started_at is null or ended_at >= started_at)
);

create index if not exists idx_staff_shifts_date
  on public.staff_shifts (shift_date, staff_id);

create index if not exists idx_staff_shifts_on_duty
  on public.staff_shifts (is_on_duty)
  where is_on_duty = true;

alter table public.staff_shifts enable row level security;

drop policy if exists shifts_select_authenticated on public.staff_shifts;
create policy shifts_select_authenticated on public.staff_shifts
for select to authenticated
using (true);

drop policy if exists shifts_insert_admin_supervisor on public.staff_shifts;
create policy shifts_insert_admin_supervisor on public.staff_shifts
for insert to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

drop policy if exists shifts_update_admin_supervisor on public.staff_shifts;
create policy shifts_update_admin_supervisor on public.staff_shifts
for update to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

-- Intentionally no DELETE policy (history should be preserved).

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050012_phase12b_staff_hk_lane.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 12B Hotfix: make HK lanes dynamic from staff directory

alter table public.staff
  add column if not exists hk_lane_enabled boolean not null default false,
  add column if not exists hk_lane_order integer not null default 100;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_staff_hk_lane_order'
      and conrelid = 'public.staff'::regclass
  ) then
    alter table public.staff
      add constraint chk_staff_hk_lane_order check (hk_lane_order between 1 and 999);
  end if;
end
$$;

create index if not exists idx_staff_hk_lane_enabled_order
  on public.staff (hk_lane_enabled, hk_lane_order, display_name);

-- Backfill: current HK staff are lane-enabled by default
update public.staff s
set hk_lane_enabled = true
from public.departments d
where s.department_id = d.id
  and d.code = 'HK'
  and s.hk_lane_enabled is distinct from true;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603050013_phase12c_logbook_freeform_revised.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- ============================================================
-- Phase 12C Revised: Freeform Logbook Board
-- - logbook_notes
-- - logbook_note_links
-- - logbook_note_mentions
-- ============================================================

create table if not exists public.logbook_notes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  note_type text not null default 'general'
    check (note_type in ('general', 'task', 'urgent', 'stock', 'vip')),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved')),
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high', 'urgent')),
  x int not null default 40,
  y int not null default 40,
  width int not null default 320,
  height int not null default 220,
  z_index int not null default 1,
  is_minimized boolean not null default false,
  remind_at timestamptz,
  created_by uuid not null references public.staff(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.logbook_note_links (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.logbook_notes(id) on delete cascade,
  link_type text not null
    check (link_type in ('room', 'guest', 'stock', 'staff')),
  ref_id uuid,
  ref_code text,
  label text not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint chk_logbook_link_ref_not_null
    check (ref_id is not null or ref_code is not null)
);

-- Convention: stock links use ref_code='stock' and ref_id=null.
create table if not exists public.logbook_note_mentions (
  id uuid primary key default gen_random_uuid(),
  note_id uuid not null references public.logbook_notes(id) on delete cascade,
  mention_type text not null
    check (mention_type in ('staff', 'group_all', 'group_frontdesk')),
  staff_id uuid references public.staff(id) on delete cascade,
  is_acknowledged boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  constraint chk_logbook_mention_staff
    check (
      (mention_type = 'staff' and staff_id is not null)
      or (mention_type in ('group_all', 'group_frontdesk') and staff_id is null)
    )
);

drop trigger if exists trg_logbook_notes_updated_at on public.logbook_notes;
drop trigger if exists set_logbook_notes_updated_at on public.logbook_notes;
create trigger trg_logbook_notes_updated_at
before update on public.logbook_notes
for each row execute function public.set_updated_at();

create index if not exists idx_logbook_notes_updated_at
  on public.logbook_notes (updated_at desc);
create index if not exists idx_logbook_notes_created_by
  on public.logbook_notes (created_by);
create index if not exists idx_logbook_notes_status
  on public.logbook_notes (status);
create index if not exists idx_logbook_notes_type
  on public.logbook_notes (note_type);
create index if not exists idx_logbook_notes_zindex
  on public.logbook_notes (z_index);

create index if not exists idx_logbook_links_note_type
  on public.logbook_note_links (note_id, link_type);
create index if not exists idx_logbook_links_ref_id
  on public.logbook_note_links (ref_id);
create index if not exists idx_logbook_links_ref_code
  on public.logbook_note_links (ref_code);

create index if not exists idx_logbook_mentions_note
  on public.logbook_note_mentions (note_id);
create index if not exists idx_logbook_mentions_staff
  on public.logbook_note_mentions (staff_id);

create unique index if not exists idx_logbook_mentions_unique_staff
  on public.logbook_note_mentions (note_id, staff_id)
  where mention_type = 'staff';
create unique index if not exists idx_logbook_mentions_unique_group
  on public.logbook_note_mentions (note_id, mention_type)
  where mention_type in ('group_all', 'group_frontdesk');

alter table public.logbook_notes enable row level security;
alter table public.logbook_note_links enable row level security;
alter table public.logbook_note_mentions enable row level security;

drop policy if exists logbook_notes_select_authenticated on public.logbook_notes;
create policy logbook_notes_select_authenticated
on public.logbook_notes
for select
to authenticated
using (true);

drop policy if exists logbook_notes_insert_self on public.logbook_notes;
create policy logbook_notes_insert_self
on public.logbook_notes
for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists logbook_notes_update_owner_or_admin on public.logbook_notes;
create policy logbook_notes_update_owner_or_admin
on public.logbook_notes
for update
to authenticated
using (
  created_by = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
)
with check (
  created_by = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

drop policy if exists logbook_notes_delete_owner_or_admin on public.logbook_notes;
create policy logbook_notes_delete_owner_or_admin
on public.logbook_notes
for delete
to authenticated
using (
  created_by = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  )
);

drop policy if exists logbook_note_links_select_authenticated on public.logbook_note_links;
create policy logbook_note_links_select_authenticated
on public.logbook_note_links
for select
to authenticated
using (true);

drop policy if exists logbook_note_links_insert_manage_note on public.logbook_note_links;
create policy logbook_note_links_insert_manage_note
on public.logbook_note_links
for insert
to authenticated
with check (
  exists (
    select 1
    from public.logbook_notes n
    where n.id = note_id
      and (
        n.created_by = auth.uid()
        or exists (
          select 1
          from public.profiles p
          where p.user_id = auth.uid()
            and p.role in ('admin', 'supervisor')
        )
      )
  )
);

drop policy if exists logbook_note_links_delete_manage_note on public.logbook_note_links;
create policy logbook_note_links_delete_manage_note
on public.logbook_note_links
for delete
to authenticated
using (
  exists (
    select 1
    from public.logbook_notes n
    where n.id = note_id
      and (
        n.created_by = auth.uid()
        or exists (
          select 1
          from public.profiles p
          where p.user_id = auth.uid()
            and p.role in ('admin', 'supervisor')
        )
      )
  )
);

drop policy if exists logbook_note_mentions_select_authenticated on public.logbook_note_mentions;
create policy logbook_note_mentions_select_authenticated
on public.logbook_note_mentions
for select
to authenticated
using (true);

drop policy if exists logbook_note_mentions_insert_manage_note on public.logbook_note_mentions;
create policy logbook_note_mentions_insert_manage_note
on public.logbook_note_mentions
for insert
to authenticated
with check (
  exists (
    select 1
    from public.logbook_notes n
    where n.id = note_id
      and (
        n.created_by = auth.uid()
        or exists (
          select 1
          from public.profiles p
          where p.user_id = auth.uid()
            and p.role in ('admin', 'supervisor')
        )
      )
  )
);

drop policy if exists logbook_note_mentions_update_manage_note on public.logbook_note_mentions;
create policy logbook_note_mentions_update_manage_note
on public.logbook_note_mentions
for update
to authenticated
using (
  exists (
    select 1
    from public.logbook_notes n
    where n.id = note_id
      and (
        n.created_by = auth.uid()
        or exists (
          select 1
          from public.profiles p
          where p.user_id = auth.uid()
            and p.role in ('admin', 'supervisor')
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.logbook_notes n
    where n.id = note_id
      and (
        n.created_by = auth.uid()
        or exists (
          select 1
          from public.profiles p
          where p.user_id = auth.uid()
            and p.role in ('admin', 'supervisor')
        )
      )
  )
);

drop policy if exists logbook_note_mentions_delete_manage_note on public.logbook_note_mentions;
create policy logbook_note_mentions_delete_manage_note
on public.logbook_note_mentions
for delete
to authenticated
using (
  exists (
    select 1
    from public.logbook_notes n
    where n.id = note_id
      and (
        n.created_by = auth.uid()
        or exists (
          select 1
          from public.profiles p
          where p.user_id = auth.uid()
            and p.role in ('admin', 'supervisor')
        )
      )
  )
);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603060001_phase12d_logbook_archive_rich_editor.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.logbook_notes
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by uuid references public.staff(id) on delete set null,
  add column if not exists body_rich jsonb,
  add column if not exists board_mode text;

update public.logbook_notes
set board_mode = case when is_minimized then 'minimized' else 'middle' end
where board_mode is null;

alter table public.logbook_notes
  alter column board_mode set default 'middle';

alter table public.logbook_notes
  alter column board_mode set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_logbook_notes_board_mode'
      and conrelid = 'public.logbook_notes'::regclass
  ) then
    alter table public.logbook_notes
      add constraint chk_logbook_notes_board_mode
      check (board_mode in ('minimized', 'middle'));
  end if;
end $$;

create index if not exists idx_logbook_notes_archived_at
  on public.logbook_notes (archived_at desc);

create index if not exists idx_logbook_notes_board_mode
  on public.logbook_notes (board_mode);

create index if not exists idx_logbook_notes_remind_at
  on public.logbook_notes (remind_at);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603060002_phase12d_room_link_mode.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.logbook_note_links
  add column if not exists room_link_mode text not null default 'static';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_logbook_note_links_room_link_mode'
  ) then
    alter table public.logbook_note_links
      add constraint chk_logbook_note_links_room_link_mode
      check (room_link_mode in ('static', 'dynamic'));
  end if;
end $$;

update public.logbook_note_links
set room_link_mode = 'static'
where room_link_mode is null
   or trim(room_link_mode) = '';

create index if not exists idx_logbook_note_links_room_link_mode
  on public.logbook_note_links (room_link_mode);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603070001_phase14_dayuse_rooms.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Phase 14: Day Use Rooms
-- ============================================================

-- 1) Rooms day-use flag
alter table public.rooms
  add column if not exists is_dayuse boolean not null default false;

-- 2) Reservations day-use fields
alter table public.reservations
  add column if not exists is_dayuse boolean not null default false,
  add column if not exists dayuse_expires_at timestamptz;

-- 3) reservation_nights dayuse_session
alter table public.reservation_nights
  add column if not exists dayuse_session smallint not null default 0;

-- 4) Replace unique index to allow multi-use same room/day
drop index if exists public.uq_reservation_nights_active_room_day;

create unique index if not exists uq_reservation_nights_room_date_session
  on public.reservation_nights (room_id, stay_date, dayuse_session)
  where cancelled_at is null;

-- 5) Relax reservation date range for same-day day use
alter table public.reservations
  drop constraint if exists reservation_date_range;

alter table public.reservations
  add constraint reservation_date_range
  check (checkout_date >= checkin_date);

-- 6) Extend folio revenue category constraint
alter table public.folio_payments
  drop constraint if exists folio_payments_revenue_category_check;

alter table public.folio_payments
  add constraint folio_payments_revenue_category_check
  check (
    revenue_category in (
      'room_revenue',
      'pos_revenue',
      'extra_charge',
      'deposit',
      'no_show_fee',
      'dayuse_revenue'
    )
  );

-- 7) Day-use config in hotel_settings
alter table public.hotel_settings
  add column if not exists dayuse_rate numeric(10,2) default 200.00,
  add column if not exists dayuse_duration_min int default 120,
  add column if not exists dayuse_extend_rate numeric(10,2) default 100.00,
  add column if not exists dayuse_extend_min int default 60;

-- 8) Daily snapshots day-use metrics
alter table public.daily_snapshots
  add column if not exists dayuse_revenue numeric(12,2) default 0,
  add column if not exists dayuse_sessions int default 0;

-- 9) Seed day-use rooms (silent skip if not found)
update public.rooms
set is_dayuse = true
where room_number in ('118', '120', '122');

-- 10) Helpful index
create index if not exists idx_reservations_dayuse_active
  on public.reservations (checkin_date, status)
  where is_dayuse = true and status = 'active';




-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603070002_phase14_dayuse_rooms_hotfix.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Phase 14 Hotfix: ensure canonical day-use rooms are visible
-- ============================================================

update public.rooms
set
  is_dayuse = true,
  is_visible_on_board = true
where room_number in ('118', '120', '122');

update public.hotel_settings
set
  dayuse_rate = coalesce(dayuse_rate, 200.00),
  dayuse_duration_min = coalesce(dayuse_duration_min, 120),
  dayuse_extend_rate = coalesce(dayuse_extend_rate, 100.00),
  dayuse_extend_min = coalesce(dayuse_extend_min, 60)
where id = 1;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603070003_phase14_dayuse_rooms_seed_missing.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 14 hotfix: some environments do not have rooms 118/120/122 yet.
-- Ensure canonical Day Use rooms exist and are visible on board/diary.

BEGIN;

WITH target_rooms AS (
  SELECT *
  FROM (
    VALUES
      ('118'::text, 4::int),
      ('120'::text, 5::int),
      ('122'::text, 6::int)
  ) AS v(room_number, sort_order)
),
preferred_type AS (
  SELECT room_type_id AS id
  FROM public.rooms
  WHERE room_number IN ('106', '108')
  ORDER BY room_number
  LIMIT 1
),
fallback_type AS (
  SELECT id
  FROM public.room_types
  WHERE code <> 'CLOSED'
  ORDER BY sort_order ASC, id ASC
  LIMIT 1
),
resolved_type AS (
  SELECT id FROM preferred_type
  UNION ALL
  SELECT id FROM fallback_type
  LIMIT 1
)
INSERT INTO public.rooms (
  room_number,
  room_type_id,
  is_sellable,
  is_visible_on_board,
  closure_reason,
  sort_order,
  floor_number,
  wing,
  is_dayuse
)
SELECT
  tr.room_number,
  rt.id,
  true,
  true,
  null,
  tr.sort_order,
  1,
  'R',
  true
FROM target_rooms tr
CROSS JOIN resolved_type rt
ON CONFLICT (room_number) DO UPDATE
SET
  floor_number = EXCLUDED.floor_number,
  wing = EXCLUDED.wing,
  sort_order = EXCLUDED.sort_order,
  is_dayuse = true,
  is_visible_on_board = true,
  is_sellable = true,
  closure_reason = null,
  room_type_id = COALESCE(public.rooms.room_type_id, EXCLUDED.room_type_id),
  updated_at = timezone('utc', now());

UPDATE public.rooms
SET
  is_dayuse = true,
  is_visible_on_board = true,
  is_sellable = true,
  closure_reason = null,
  floor_number = 1,
  wing = 'R',
  sort_order = CASE room_number
    WHEN '118' THEN 4
    WHEN '120' THEN 5
    WHEN '122' THEN 6
    ELSE sort_order
  END,
  updated_at = timezone('utc', now())
WHERE room_number IN ('118', '120', '122');

INSERT INTO public.room_layouts (room_id, view_type, grid_x, grid_y, zone, sort_order)
SELECT
  r.id,
  vt.view_type,
  null,
  null,
  'building',
  r.sort_order
FROM public.rooms r
CROSS JOIN (
  VALUES
    ('month'::text),
    ('week'::text),
    ('day'::text)
) AS vt(view_type)
WHERE r.room_number IN ('118', '120', '122')
ON CONFLICT (room_id, view_type) DO UPDATE
SET
  zone = EXCLUDED.zone,
  sort_order = EXCLUDED.sort_order;

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603080001_phase15_night_audit_popup_snooze.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

alter table public.hotel_settings
  add column if not exists night_audit_popup_snooze_min integer not null default 30;

alter table public.hotel_settings
  drop constraint if exists hotel_settings_night_audit_popup_snooze_min_check;

alter table public.hotel_settings
  add constraint hotel_settings_night_audit_popup_snooze_min_check
  check (night_audit_popup_snooze_min between 1 and 1440);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603080002_phase16_accompanying_guest_invariant.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

comment on table public.reservation_guests is
  'Reservation party members. Primary guest is persisted with role=primary, display_order=1. Accompanying guest slots use display_order 2..4.';

comment on column public.reservation_guests.display_order is
  'Slot convention: 1=primary, 2..4=accompanying. Max occupancy is enforced in API/business layer.';

insert into public.reservation_guests (reservation_id, guest_profile_id, role, display_order)
select r.id, r.guest_profile_id, 'primary', 1
from public.reservations r
where r.guest_profile_id is not null
  and not exists (
    select 1
    from public.reservation_guests rg
    where rg.reservation_id = r.id
      and rg.role = 'primary'
  );

create or replace function public.link_primary_guest(
  p_reservation_id uuid,
  p_guest_profile_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_profile public.guest_profiles%rowtype;
  v_existing_role text;
begin
  if p_reservation_id is null then
    raise exception 'reservation_id is required';
  end if;
  if p_guest_profile_id is null then
    raise exception 'guest_profile_id is required';
  end if;

  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_reservation.id is null then
    raise exception 'Reservation not found';
  end if;

  select *
  into v_profile
  from public.guest_profiles
  where id = p_guest_profile_id
  for update;

  if v_profile.id is null then
    raise exception 'Guest profile not found';
  end if;

  if v_profile.profile_status = 'merged' then
    raise exception 'Cannot link merged guest profile';
  end if;

  update public.reservations
  set guest_profile_id = p_guest_profile_id
  where id = p_reservation_id;

  delete from public.reservation_guests
  where reservation_id = p_reservation_id
    and role = 'primary'
    and guest_profile_id <> p_guest_profile_id;

  select role
  into v_existing_role
  from public.reservation_guests
  where reservation_id = p_reservation_id
    and guest_profile_id = p_guest_profile_id
  limit 1;

  if v_existing_role is null then
    insert into public.reservation_guests (reservation_id, guest_profile_id, role, display_order)
    values (p_reservation_id, p_guest_profile_id, 'primary', 1);
  else
    update public.reservation_guests
    set role = 'primary',
        display_order = 1
    where reservation_id = p_reservation_id
      and guest_profile_id = p_guest_profile_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'reservation_id', p_reservation_id,
    'guest_profile_id', p_guest_profile_id,
    'role', 'primary',
    'display_order', 1
  );
end;
$$;

create or replace function public.unlink_primary_guest(
  p_reservation_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
begin
  if p_reservation_id is null then
    raise exception 'reservation_id is required';
  end if;

  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_reservation.id is null then
    raise exception 'Reservation not found';
  end if;

  update public.reservations
  set guest_profile_id = null
  where id = p_reservation_id;

  delete from public.reservation_guests
  where reservation_id = p_reservation_id
    and role = 'primary';

  return jsonb_build_object(
    'success', true,
    'reservation_id', p_reservation_id,
    'guest_profile_id', null
  );
end;
$$;

grant execute on function public.link_primary_guest(uuid, uuid) to authenticated, service_role;
grant execute on function public.unlink_primary_guest(uuid) to authenticated, service_role;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603080003_phase17_planned_room_move.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.reservations
  add column if not exists parent_reservation_id uuid references public.reservations(id) on delete set null;

create table if not exists public.reservation_room_plans (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  from_room_id_snapshot uuid references public.rooms(id) on delete set null,
  to_room_type_id bigint not null references public.room_types(id),
  to_room_id uuid not null references public.rooms(id),
  move_reason text not null,
  pricing_policy text not null default 'keep_rtc',
  discount_type text,
  discount_value numeric(10,2),
  discount_reason text,
  do_not_move boolean not null default false,
  do_not_move_note text,
  status text not null default 'planned',
  executed_at timestamptz,
  cancelled_at timestamptz,
  created_by uuid references public.profiles(user_id),
  updated_by uuid references public.profiles(user_id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint reservation_room_plans_date_range_check check (end_date >= start_date),
  constraint reservation_room_plans_pricing_policy_check check (pricing_policy in ('keep_rtc', 'reprice_grid', 'reprice_grid_discount')),
  constraint reservation_room_plans_discount_type_check check (discount_type is null or discount_type in ('percent', 'fixed')),
  constraint reservation_room_plans_status_check check (status in ('planned', 'executed', 'cancelled')),
  constraint reservation_room_plans_do_not_move_note_check check ((not do_not_move) or (do_not_move_note is not null and btrim(do_not_move_note) <> ''))
);

create index if not exists idx_reservation_room_plans_reservation_status_start
  on public.reservation_room_plans (reservation_id, status, start_date);

create index if not exists idx_reservation_room_plans_room_status_dates
  on public.reservation_room_plans (to_room_id, status, start_date, end_date);

create index if not exists idx_reservations_parent_reservation_id
  on public.reservations (parent_reservation_id)
  where parent_reservation_id is not null;

create or replace function public.set_reservation_room_plans_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_reservation_room_plans_updated_at on public.reservation_room_plans;
create trigger trg_reservation_room_plans_updated_at
before update on public.reservation_room_plans
for each row
execute function public.set_reservation_room_plans_updated_at();

alter table public.reservation_room_plans enable row level security;
drop policy if exists service_full_access on public.reservation_room_plans;
create policy service_full_access
  on public.reservation_room_plans
  for all
  using (true)
  with check (true);

comment on table public.reservation_room_plans is
  'Future planned room move segments. to_room_id blocks inventory for the nightly date range while status=planned.';

comment on column public.reservation_room_plans.from_room_id_snapshot is
  'Reference-only snapshot of the source room at planning time. Execute must not require it to match current room.';

comment on column public.reservation_room_plans.do_not_move is
  'Hard lock for this planned segment. Override or cancel requires operator note in API workflow.';

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603080004_phase17b_planned_move_dependencies.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.reservation_nights
  add column if not exists assignment_source text;

alter table public.reservation_nights
  add column if not exists dependency_plan_id uuid references public.reservation_room_plans(id) on delete set null;

alter table public.reservation_nights
  add column if not exists dependency_reason text;

alter table public.reservation_nights
  drop constraint if exists reservation_nights_assignment_source_check;

alter table public.reservation_nights
  add constraint reservation_nights_assignment_source_check
  check (
    assignment_source is null
    or assignment_source in ('manual', 'auto_assign', 'planned_move_release')
  );

create index if not exists idx_reservation_nights_dependency_plan_id
  on public.reservation_nights (dependency_plan_id)
  where dependency_plan_id is not null and cancelled_at is null;

create index if not exists idx_reservation_nights_room_date_dependency
  on public.reservation_nights (room_id, stay_date, dependency_plan_id)
  where cancelled_at is null;

comment on column public.reservation_nights.assignment_source is
  'How this room assignment was produced: manual, auto_assign, or planned_move_release.';

comment on column public.reservation_nights.dependency_plan_id is
  'If assignment_source=planned_move_release, this links the room assignment to the reservation_room_plans row that released the source room.';

comment on column public.reservation_nights.dependency_reason is
  'Human-readable explanation for plan-dependent room assignment.';

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603100001_phase20_extra_fees_policy_loans.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create table if not exists public.extra_fee_templates (
  code text primary key,
  name text not null,
  default_price numeric(10,2) not null default 0,
  category text not null default 'service',
  icon text,
  is_active boolean not null default true,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  constraint extra_fee_templates_category_check
    check (category in ('service', 'penalty', 'damage', 'policy'))
);

create index if not exists idx_extra_fee_templates_sort
  on public.extra_fee_templates (sort_order, code);

alter table public.extra_fee_templates enable row level security;
drop policy if exists extra_fee_templates_service_role_full_access on public.extra_fee_templates;
create policy extra_fee_templates_service_role_full_access on public.extra_fee_templates
for all to service_role
using (true)
with check (true);

insert into public.extra_fee_templates (code, name, default_price, category, icon, is_active, sort_order)
values
  ('EXTRA_PERSON', 'Extra Person', 300, 'service', '👤', true, 10),
  ('EXTRA_PILLOW', 'Extra Pillow', 50, 'service', '🛏️', true, 20),
  ('EXTRA_TOWEL', 'Extra Towel', 50, 'service', '🪥', true, 30),
  ('EXTRA_BED_CHARGE', 'Extra Bed Charge', 500, 'service', '🛏️', true, 40),
  ('EXTRA_CLEANING', 'Extra Cleaning Fee', 500, 'damage', '🧹', true, 50),
  ('DAMAGE_FEE', 'Damage Fee', 0, 'damage', '⚠️', true, 60),
  ('SHORTEN_FEE', 'Early Departure Fee', 0, 'penalty', '📅', true, 70),
  ('CANCEL_FEE', 'Cancellation Fee', 0, 'penalty', '❌', true, 80),
  ('EARLY_CHECKIN_FEE', 'Early Check-in Fee', 0, 'policy', '🌅', true, 90),
  ('LATE_CHECKOUT_FEE', 'Late Check-out Fee', 0, 'policy', '🕓', true, 100)
on conflict (code) do update
set
  name = excluded.name,
  default_price = excluded.default_price,
  category = excluded.category,
  icon = excluded.icon,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

alter table public.folio_payments
  add column if not exists fee_template_code text references public.extra_fee_templates(code) on delete set null;

create index if not exists idx_folio_payments_fee_template_code
  on public.folio_payments (fee_template_code);

alter table public.reservation_traces
  add column if not exists due_date date;

create index if not exists idx_reservation_traces_due_date
  on public.reservation_traces (due_date)
  where due_date is not null;

alter table public.loan_items
  add column if not exists requires_hk_collection boolean not null default false;

update public.loan_items
set requires_hk_collection = true
where code in ('EXTRA_BED', 'EXTRA_PILLOW', 'EXTRA_TOWEL');

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603100002_phase20b_hk_collect_defaults.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Hotfix defaults for maid collection scope:
-- keep only Pillow, Towel, Kettle as HK collect for now.
update public.loan_items
set requires_hk_collection = true
where code in ('EXTRA_PILLOW', 'EXTRA_TOWEL', 'KETTLE');

update public.loan_items
set requires_hk_collection = false
where code = 'EXTRA_BED';

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603120001_phase28_assigned_room_lock.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.reservations
  add column if not exists do_not_move_assigned_room boolean not null default false,
  add column if not exists do_not_move_reason text,
  add column if not exists do_not_move_room_id_snapshot uuid references public.rooms(id) on delete set null,
  add column if not exists do_not_move_set_at timestamptz,
  add column if not exists do_not_move_set_by text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reservations_do_not_move_assigned_room_check'
  ) then
    alter table public.reservations
      add constraint reservations_do_not_move_assigned_room_check
      check (
        (not do_not_move_assigned_room)
        or (
          do_not_move_reason is not null
          and btrim(do_not_move_reason) <> ''
          and do_not_move_room_id_snapshot is not null
        )
      );
  end if;
end $$;

create index if not exists reservations_do_not_move_assigned_room_idx
  on public.reservations (do_not_move_assigned_room)
  where do_not_move_assigned_room = true;

create index if not exists reservations_do_not_move_room_snapshot_idx
  on public.reservations (do_not_move_room_id_snapshot)
  where do_not_move_assigned_room = true;

comment on column public.reservations.do_not_move_assigned_room
  is 'Pre-check-in assigned room lock. Auto-clears after successful check-in or successful override room change.';

comment on column public.reservations.do_not_move_room_id_snapshot
  is 'Room id that was assigned when the Do Not Move lock was created.';

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603120002_phase29_guest_stay_night_counters.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.guest_profiles
  add column if not exists night_count integer not null default 0,
  add column if not exists main_stay_count integer not null default 0,
  add column if not exists accompanying_stay_count integer not null default 0,
  add column if not exists main_night_count integer not null default 0,
  add column if not exists accompanying_night_count integer not null default 0;

comment on column public.guest_profiles.stay_count is
  'Legacy total stays counter. Phase 29+: incremented only on checkout and includes primary+accompanying roles.';
comment on column public.guest_profiles.night_count is
  'Total completed nights across all roles. Incremented only on checkout.';
comment on column public.guest_profiles.main_stay_count is
  'Completed stays where profile role was primary. Incremented only on checkout.';
comment on column public.guest_profiles.accompanying_stay_count is
  'Completed stays where profile role was accompanying. Incremented only on checkout.';
comment on column public.guest_profiles.main_night_count is
  'Completed nights where profile role was primary. Incremented only on checkout.';
comment on column public.guest_profiles.accompanying_night_count is
  'Completed nights where profile role was accompanying. Incremented only on checkout.';

create index if not exists idx_guest_profiles_main_stay_count
  on public.guest_profiles (main_stay_count desc);
create index if not exists idx_guest_profiles_accompanying_stay_count
  on public.guest_profiles (accompanying_stay_count desc);

with completed_from_party as (
  select
    rg.guest_profile_id,
    rg.role,
    greatest((r.checkout_date::date - r.checkin_date::date), 1)::int as nights,
    r.checkout_date::date as checkout_date
  from public.reservations r
  join public.reservation_guests rg
    on rg.reservation_id = r.id
  where r.status = 'checked_out'
    and rg.guest_profile_id is not null
    and rg.role in ('primary', 'accompanying')
),
completed_primary_fallback as (
  select
    r.guest_profile_id,
    'primary'::text as role,
    greatest((r.checkout_date::date - r.checkin_date::date), 1)::int as nights,
    r.checkout_date::date as checkout_date
  from public.reservations r
  where r.status = 'checked_out'
    and r.guest_profile_id is not null
    and not exists (
      select 1
      from public.reservation_guests rg
      where rg.reservation_id = r.id
        and rg.role = 'primary'
    )
),
completed_union as (
  select * from completed_from_party
  union all
  select * from completed_primary_fallback
),
stats as (
  select
    cu.guest_profile_id,
    sum(case when cu.role = 'primary' then 1 else 0 end)::int as main_stays,
    sum(case when cu.role = 'accompanying' then 1 else 0 end)::int as accompanying_stays,
    sum(case when cu.role = 'primary' then cu.nights else 0 end)::int as main_nights,
    sum(case when cu.role = 'accompanying' then cu.nights else 0 end)::int as accompanying_nights,
    max(cu.checkout_date)::date as last_stay_date
  from completed_union cu
  group by cu.guest_profile_id
)
update public.guest_profiles gp
set
  main_stay_count = coalesce(stats.main_stays, 0),
  accompanying_stay_count = coalesce(stats.accompanying_stays, 0),
  main_night_count = coalesce(stats.main_nights, 0),
  accompanying_night_count = coalesce(stats.accompanying_nights, 0),
  stay_count = coalesce(stats.main_stays, 0) + coalesce(stats.accompanying_stays, 0),
  night_count = coalesce(stats.main_nights, 0) + coalesce(stats.accompanying_nights, 0),
  last_stay_date = stats.last_stay_date
from (
  select
    gp2.id,
    st.main_stays,
    st.accompanying_stays,
    st.main_nights,
    st.accompanying_nights,
    st.last_stay_date
  from public.guest_profiles gp2
  left join stats st on st.guest_profile_id = gp2.id
) stats
where gp.id = stats.id;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603130001_booking_discount_modes.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

alter table public.reservations
  add column if not exists discount_type text not null default 'percent',
  add column if not exists discount_value numeric(10,2) not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reservations_discount_type_check'
  ) then
    alter table public.reservations
      add constraint reservations_discount_type_check
      check (discount_type in ('percent', 'fixed_total', 'fixed_per_night'));
  end if;
end $$;

update public.reservations
set
  discount_type = 'percent',
  discount_value = coalesce(discount_percent, 0)
where coalesce(discount_type, '') not in ('percent', 'fixed_total', 'fixed_per_night')
   or coalesce(discount_value, 0) = 0;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603130002_phase29_deposit_event_model.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.folio_payments
  add column if not exists is_record_only boolean not null default false;

comment on column public.folio_payments.is_record_only is
  'True = ledger trace only. Visible in folio but excluded from outstanding balance math.';

create index if not exists idx_folio_payments_reservation_record_only
  on public.folio_payments (reservation_id, is_record_only);

create or replace function public.normalize_deposit_method_text(p_raw text)
returns public.payment_method_type
language plpgsql
immutable
as $$
declare
  v_value text := lower(trim(coalesce(p_raw, '')));
begin
  if v_value = 'cash' then return 'cash'; end if;
  if v_value = 'transfer' then return 'transfer'; end if;
  if v_value = 'credit_card' then return 'credit_card'; end if;
  if v_value = 'other' then return 'other'; end if;
  if v_value like '%promptpay%' then return 'transfer'; end if;
  if v_value like '%bank transfer%' then return 'transfer'; end if;
  if v_value like '%transfer%' then return 'transfer'; end if;
  if v_value like '%credit%' then return 'credit_card'; end if;
  if v_value like '%card%' then return 'credit_card'; end if;
  if v_value like '%cash%' then return 'cash'; end if;
  return 'other';
end;
$$;

create or replace function public.parse_deposit_snapshot_lines(
  p_note text,
  p_amount numeric
)
returns table (
  method public.payment_method_type,
  amount numeric(10,2),
  note text
)
language plpgsql
immutable
as $$
declare
  v_total numeric(10,2) := round(coalesce(p_amount, 0)::numeric, 2);
  v_note_text text := nullif(trim(coalesce(p_note, '')), '');
  v_parsed jsonb;
  v_lines_total numeric(10,2);
begin
  if v_total <= 0 then
    return;
  end if;

  if v_note_text is null then
    return query
    select 'other'::public.payment_method_type, v_total, null::text;
    return;
  end if;

  begin
    v_parsed := v_note_text::jsonb;
  exception when others then
    v_parsed := null;
  end;

  if v_parsed is not null and jsonb_typeof(v_parsed) = 'object' and jsonb_typeof(v_parsed -> 'lines') = 'array' then
    select round(coalesce(sum((entry ->> 'amount')::numeric), 0), 2)
    into v_lines_total
    from jsonb_array_elements(v_parsed -> 'lines') entry
    where coalesce((entry ->> 'amount')::numeric, 0) > 0;

    if abs(coalesce(v_lines_total, 0) - v_total) <= 0.01 then
      return query
      select
        public.normalize_deposit_method_text(entry ->> 'method') as method,
        round((entry ->> 'amount')::numeric, 2) as amount,
        nullif(trim(coalesce(entry ->> 'note', '')), '') as note
      from jsonb_array_elements(v_parsed -> 'lines') entry
      where coalesce((entry ->> 'amount')::numeric, 0) > 0;
      return;
    end if;
  end if;

  return query
  select public.normalize_deposit_method_text(v_note_text), v_total, v_note_text;
end;
$$;

insert into public.folio_payments (
  reservation_id,
  tx_type,
  method,
  amount,
  note,
  paid_at,
  paid_date,
  revenue_category,
  cashier_name,
  is_record_only
)
select
  r.id,
  'deposit',
  line.method,
  line.amount,
  line.note,
  coalesce(r.deposit_paid_at, timezone('utc', now())),
  (coalesce(r.deposit_paid_at, timezone('utc', now())) at time zone 'Asia/Bangkok')::date,
  'deposit',
  'FO',
  false
from public.reservations r
cross join lateral public.parse_deposit_snapshot_lines(r.deposit_note, r.deposit_amount) as line
where coalesce(r.deposit_amount, 0) > 0
  and not exists (
    select 1
    from public.folio_payments fp
    where fp.reservation_id = r.id
      and fp.revenue_category = 'deposit'
      and coalesce(fp.is_record_only, false) = false
  );

create or replace function public.apply_deposit_snapshot_lines(
  p_reservation_id uuid,
  p_lines jsonb default '[]'::jsonb,
  p_general_note text default null,
  p_cashier_name text default 'FO'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_lines jsonb := coalesce(p_lines, '[]'::jsonb);
  v_general_note text := nullif(trim(coalesce(p_general_note, '')), '');
  v_cashier_name text := nullif(trim(coalesce(p_cashier_name, '')), '');
  v_now timestamptz := timezone('utc', now());
  v_paid_date date := (v_now at time zone 'Asia/Bangkok')::date;
  v_method public.payment_method_type;
  v_current_amount numeric(10,2);
  v_target_amount numeric(10,2);
  v_diff numeric(10,2);
  v_note text;
  v_total numeric(10,2);
  v_snapshot_note text;
  v_last_paid_at timestamptz;
begin
  if p_reservation_id is null then
    raise exception 'reservation_id is required';
  end if;

  if jsonb_typeof(v_lines) is distinct from 'array' then
    raise exception 'deposit lines must be a JSON array';
  end if;

  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_reservation.id is null then
    raise exception 'Reservation not found';
  end if;

  for v_method, v_target_amount, v_note in
    select
      public.normalize_deposit_method_text(item ->> 'method') as method,
      round(coalesce((item ->> 'amount')::numeric, 0), 2) as amount,
      nullif(trim(coalesce(item ->> 'note', '')), '') as note
    from jsonb_array_elements(v_lines) as item
  loop
    if v_target_amount <= 0 then
      raise exception 'deposit line amount must be greater than 0';
    end if;
  end loop;

  for v_method in
    select unnest(enum_range(null::public.payment_method_type))
  loop
    select round(
      coalesce(
        sum(
          case
            when fp.tx_type = 'deposit' then fp.amount
            when fp.tx_type = 'refund' then -fp.amount
            else 0
          end
        ),
        0
      ),
      2
    )
    into v_current_amount
    from public.folio_payments fp
    where fp.reservation_id = p_reservation_id
      and fp.revenue_category = 'deposit'
      and coalesce(fp.is_record_only, false) = false
      and fp.method = v_method;

    select round(
      coalesce(sum((item ->> 'amount')::numeric), 0),
      2
    )
    into v_target_amount
    from jsonb_array_elements(v_lines) item
    where public.normalize_deposit_method_text(item ->> 'method') = v_method;

    select nullif(trim(coalesce(item ->> 'note', '')), '')
    into v_note
    from jsonb_array_elements(v_lines) item
    where public.normalize_deposit_method_text(item ->> 'method') = v_method
    order by (item ->> 'amount')::numeric desc
    limit 1;

    v_current_amount := coalesce(v_current_amount, 0);
    v_target_amount := coalesce(v_target_amount, 0);
    v_diff := round(v_target_amount - v_current_amount, 2);

    if v_diff > 0 then
      insert into public.folio_payments (
        reservation_id,
        tx_type,
        method,
        amount,
        note,
        paid_at,
        paid_date,
        revenue_category,
        cashier_name,
        is_record_only
      )
      values (
        p_reservation_id,
        'deposit',
        v_method,
        v_diff,
        coalesce(v_note, 'Deposit collected'),
        v_now,
        v_paid_date,
        'deposit',
        coalesce(v_cashier_name, 'FO'),
        false
      );
    elsif v_diff < 0 then
      insert into public.folio_payments (
        reservation_id,
        tx_type,
        method,
        amount,
        note,
        paid_at,
        paid_date,
        revenue_category,
        cashier_name,
        is_record_only
      )
      values (
        p_reservation_id,
        'refund',
        v_method,
        abs(v_diff),
        coalesce(v_note, 'Deposit refund'),
        v_now,
        v_paid_date,
        'deposit',
        coalesce(v_cashier_name, 'FO'),
        false
      );
    end if;
  end loop;

  select round(
    coalesce(
      sum(
        case
          when fp.tx_type = 'deposit' then fp.amount
          when fp.tx_type = 'refund' then -fp.amount
          else 0
        end
      ),
      0
    ),
    2
  )
  into v_total
  from public.folio_payments fp
  where fp.reservation_id = p_reservation_id
    and fp.revenue_category = 'deposit'
    and coalesce(fp.is_record_only, false) = false;

  select max(fp.paid_at)
  into v_last_paid_at
  from public.folio_payments fp
  where fp.reservation_id = p_reservation_id
    and fp.revenue_category = 'deposit'
    and fp.tx_type = 'deposit'
    and coalesce(fp.is_record_only, false) = false;

  select case
      when jsonb_array_length(v_lines) = 0 and v_general_note is null then null
      else jsonb_strip_nulls(
        jsonb_build_object(
          'lines',
          coalesce(
            (
              select jsonb_agg(
                jsonb_strip_nulls(
                  jsonb_build_object(
                    'method', public.normalize_deposit_method_text(item ->> 'method'),
                    'amount', round((item ->> 'amount')::numeric, 2),
                    'note', nullif(trim(coalesce(item ->> 'note', '')), '')
                  )
                )
              )
              from jsonb_array_elements(v_lines) item
            ),
            '[]'::jsonb
          ),
          'note',
          v_general_note
        )
      )::text
    end
  into v_snapshot_note;

  update public.reservations
  set deposit_amount = coalesce(v_total, 0),
      deposit_paid_at = case when coalesce(v_total, 0) > 0 then coalesce(v_last_paid_at, v_now) else null end,
      deposit_note = v_snapshot_note,
      updated_at = v_now
  where id = p_reservation_id;

  return jsonb_build_object(
    'success', true,
    'reservation_id', p_reservation_id,
    'deposit_amount', coalesce(v_total, 0),
    'deposit_paid_at', case when coalesce(v_total, 0) > 0 then coalesce(v_last_paid_at, v_now) else null end,
    'deposit_note', v_snapshot_note
  );
end;
$$;

grant execute on function public.apply_deposit_snapshot_lines(uuid, jsonb, text, text) to authenticated, service_role;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603130003_phase29_extra_charge_deposit_settlement.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create or replace function public.post_extra_charge_with_deposit_v1(
  p_reservation_id uuid,
  p_fee_template_code text,
  p_amount numeric,
  p_note text default null,
  p_cashier_name text default 'FO',
  p_paid_at timestamptz default timezone('utc', now())
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_template public.extra_fee_templates%rowtype;
  v_amount numeric(10,2) := round(coalesce(p_amount, 0)::numeric, 2);
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_cashier text := nullif(trim(coalesce(p_cashier_name, '')), '');
  v_paid_at timestamptz := coalesce(p_paid_at, timezone('utc', now()));
  v_paid_date date := (v_paid_at at time zone 'Asia/Bangkok')::date;
  v_held_before numeric(10,2) := 0;
  v_deposit_applied numeric(10,2) := 0;
  v_remaining_outstanding numeric(10,2) := 0;
  v_held_after numeric(10,2) := 0;
  v_room_number text := null;
  v_charge_row_id uuid;
  v_apply_row_id uuid;
  v_deposit_row_id uuid;
begin
  if p_reservation_id is null then
    raise exception 'reservation_id is required';
  end if;

  if v_amount <= 0 then
    raise exception 'amount must be greater than 0';
  end if;

  select *
  into v_reservation
  from public.reservations r
  where r.id = p_reservation_id
  for update;

  if v_reservation.id is null then
    raise exception 'reservation not found';
  end if;

  if v_reservation.status <> 'active' then
    raise exception 'reservation is not active';
  end if;

  select *
  into v_template
  from public.extra_fee_templates eft
  where upper(trim(coalesce(eft.code, ''))) = upper(trim(coalesce(p_fee_template_code, '')))
  limit 1;

  if v_template.code is null then
    raise exception 'fee template not found';
  end if;

  if coalesce(v_template.is_active, false) = false then
    raise exception 'fee template is inactive';
  end if;

  select rooms.room_number
  into v_room_number
  from public.reservation_nights rn
  join public.rooms on rooms.id = rn.room_id
  where rn.reservation_id = p_reservation_id
    and rn.cancelled_at is null
    and rn.stay_date = v_paid_date
  order by rooms.room_number
  limit 1;

  if v_room_number is null then
    select rooms.room_number
    into v_room_number
    from public.reservation_nights rn
    join public.rooms on rooms.id = rn.room_id
    where rn.reservation_id = p_reservation_id
      and rn.cancelled_at is null
      and rn.room_id is not null
    order by rn.stay_date asc
    limit 1;
  end if;

  select round(
    coalesce(
      sum(
        case
          when fp.tx_type = 'deposit' then fp.amount
          when fp.tx_type = 'refund' and coalesce(fp.revenue_category, '') = 'deposit' then -fp.amount
          else 0
        end
      ),
      0
    )::numeric,
    2
  )
  into v_held_before
  from public.folio_payments fp
  where fp.reservation_id = p_reservation_id
    and coalesce(fp.revenue_category, '') = 'deposit'
    and coalesce(fp.is_record_only, false) = false;

  v_deposit_applied := round(least(v_amount, greatest(v_held_before, 0))::numeric, 2);
  v_remaining_outstanding := round(greatest(v_amount - v_deposit_applied, 0)::numeric, 2);

  if v_deposit_applied <= 0 then
    raise exception 'deposit held is required';
  end if;

  -- Charge row: visible as extra charge, excluded from credit math.
  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    paid_at,
    paid_date,
    revenue_category,
    fee_template_code,
    cashier_name,
    is_record_only
  )
  values (
    p_reservation_id,
    'payment',
    'cash'::public.payment_method_type,
    v_amount,
    coalesce(v_note, v_template.name),
    v_paid_at,
    v_paid_date,
    'extra_charge',
    v_template.code,
    coalesce(v_cashier, 'FO'),
    true
  )
  returning id into v_charge_row_id;

  -- Settlement trace row: counted in cash + credits and shown in folio/payment daily.
  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    paid_at,
    paid_date,
    revenue_category,
    fee_template_code,
    cashier_name,
    is_record_only
  )
  values (
    p_reservation_id,
    'payment',
    'cash'::public.payment_method_type,
    v_deposit_applied,
    format(
      'Paid by Deposit%s for %s',
      case when v_room_number is null then '' else format(' from room %s', v_room_number) end,
      coalesce(v_template.name, v_template.code)
    ),
    v_paid_at,
    v_paid_date,
    'room_revenue',
    v_template.code,
    coalesce(v_cashier, 'FO'),
    false
  )
  returning id into v_apply_row_id;

  -- Consume held deposit.
  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    paid_at,
    paid_date,
    revenue_category,
    fee_template_code,
    cashier_name,
    is_record_only
  )
  values (
    p_reservation_id,
    'refund',
    'cash'::public.payment_method_type,
    v_deposit_applied,
    format('Paid by Deposit for extra charge %s', coalesce(v_template.code, 'EXTRA')),
    v_paid_at,
    v_paid_date,
    'deposit',
    v_template.code,
    coalesce(v_cashier, 'FO'),
    false
  )
  returning id into v_deposit_row_id;

  select round(
    coalesce(
      sum(
        case
          when fp.tx_type = 'deposit' then fp.amount
          when fp.tx_type = 'refund' and coalesce(fp.revenue_category, '') = 'deposit' then -fp.amount
          else 0
        end
      ),
      0
    )::numeric,
    2
  )
  into v_held_after
  from public.folio_payments fp
  where fp.reservation_id = p_reservation_id
    and coalesce(fp.revenue_category, '') = 'deposit'
    and coalesce(fp.is_record_only, false) = false;

  update public.reservations
  set
    deposit_amount = greatest(v_held_after, 0),
    updated_at = timezone('utc', now())
  where id = p_reservation_id;

  return jsonb_build_object(
    'charge_row_id', v_charge_row_id,
    'deposit_apply_row_id', v_apply_row_id,
    'deposit_refund_row_id', v_deposit_row_id,
    'charge_amount', v_amount,
    'deposit_applied', v_deposit_applied,
    'remaining_outstanding', v_remaining_outstanding,
    'held_before', v_held_before,
    'held_after', v_held_after,
    'room_number', v_room_number
  );
end;
$$;

grant execute on function public.post_extra_charge_with_deposit_v1(
  uuid,
  text,
  numeric,
  text,
  text,
  timestamptz
) to authenticated, service_role;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603130004_phase29_pos_deposit_settlement.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create or replace function public.pos_create_order_v2(
  p_order_type text,
  p_items jsonb,
  p_payment_method text default null,
  p_reservation_id uuid default null,
  p_created_by text default null,
  p_note text default null,
  p_deposit_amount numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_type text := coalesce(trim(p_order_type), '');
  v_payment_method text := nullif(trim(coalesce(p_payment_method, '')), '');
  v_created_by text := nullif(trim(coalesce(p_created_by, '')), '');
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_now timestamptz := timezone('utc', now());
  v_order_id uuid;
  v_order_number text;
  v_guest_name text;
  v_room_number text;
  v_subtotal numeric(10,2) := 0;
  v_total numeric(10,2) := 0;
  v_item jsonb;
  v_product record;
  v_product_id uuid;
  v_qty int;
  v_line_total numeric(10,2);
  v_main_current int;
  v_deduct int;
  v_oversell int;
  v_order_date date := (v_now at time zone 'Asia/Bangkok')::date;
  v_held numeric(10,2) := 0;
  v_deposit_amount numeric(10,2) := greatest(coalesce(p_deposit_amount, 0), 0);
  v_deposit_apply numeric(10,2) := 0;
  v_remaining numeric(10,2) := 0;
begin
  if v_order_type not in ('walkin', 'guest_charge') then
    raise exception 'invalid p_order_type: %', p_order_type;
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'p_items must be non-empty array';
  end if;

  if v_order_type = 'walkin' then
    if v_payment_method not in ('cash', 'transfer', 'credit_card') then
      raise exception 'walkin payment method must be cash|transfer|credit_card';
    end if;
    v_deposit_amount := 0;
  else
    if p_reservation_id is null then
      raise exception 'p_reservation_id is required for guest_charge';
    end if;

    select
      r.guest_name,
      rm.room_number
    into
      v_guest_name,
      v_room_number
    from public.reservations r
    left join lateral (
      select rooms.room_number
      from public.reservation_nights rn
      join public.rooms on rooms.id = rn.room_id
      where rn.reservation_id = r.id
        and rn.stay_date = v_order_date
        and rn.cancelled_at is null
      order by rooms.room_number
      limit 1
    ) rm on true
    where r.id = p_reservation_id
      and r.status = 'active'
    for update of r;

    if v_guest_name is null then
      raise exception 'reservation is not eligible for room deposit settlement';
    end if;

    if v_room_number is null then
      raise exception 'reservation has no active room night today';
    end if;

    select coalesce(
      sum(
        case
          when fp.tx_type = 'deposit' then fp.amount
          when fp.tx_type = 'refund'
            and (
              coalesce(fp.revenue_category, '') = 'deposit'
              or lower(coalesce(fp.note, '')) like '%deposit refund%'
              or lower(coalesce(fp.note, '')) like '%paid by deposit%'
            )
          then -fp.amount
          else 0
        end
      ),
      0
    )
    into v_held
    from public.folio_payments fp
    where fp.reservation_id = p_reservation_id;

    v_held := round(v_held::numeric, 2);
    v_deposit_apply := round(least(v_deposit_amount, v_held)::numeric, 2);
    v_remaining := round(greatest(v_total - v_deposit_apply, 0)::numeric, 2);
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_product_id := (v_item ->> 'product_id')::uuid;
    exception when others then
      v_product_id := null;
    end;

    v_qty := greatest(coalesce((v_item ->> 'quantity')::int, 0), 0);
    if v_product_id is null or v_qty <= 0 then
      raise exception 'invalid item payload, each row must include product_id + quantity > 0';
    end if;

    select p.id, p.name, p.category, p.sale_price, p.is_active
    into v_product
    from public.products p
    where p.id = v_product_id
    limit 1;

    if not found then
      raise exception 'product not found: %', v_product_id;
    end if;

    if not coalesce(v_product.is_active, false) then
      raise exception 'product inactive: %', v_product.name;
    end if;

    if v_product.category not in ('pos', 'both') then
      raise exception 'product is not POS sale item: %', v_product.name;
    end if;

    if v_product.sale_price is null then
      raise exception 'product sale_price is required for POS item: %', v_product.name;
    end if;

    v_line_total := round((v_product.sale_price * v_qty)::numeric, 2);
    v_subtotal := round((v_subtotal + v_line_total)::numeric, 2);
  end loop;

  v_total := v_subtotal;

  if v_order_type = 'guest_charge' then
    v_deposit_apply := round(least(v_deposit_amount, v_held, v_total)::numeric, 2);
    v_remaining := round(greatest(v_total - v_deposit_apply, 0)::numeric, 2);

    if v_deposit_apply <= 0 then
      raise exception 'deposit held is required for room settlement';
    end if;

    if v_remaining > 0 and v_payment_method not in ('cash', 'transfer', 'credit_card') then
      raise exception 'remaining payment method must be cash|transfer|credit_card';
    end if;

    if v_remaining = 0 then
      v_payment_method := null;
    end if;
  end if;

  insert into public.pos_orders (
    order_number,
    order_type,
    reservation_id,
    guest_name,
    status,
    subtotal,
    total,
    payment_method,
    note,
    created_by,
    order_date,
    created_at,
    updated_at
  )
  values (
    public.generate_pos_order_number(),
    v_order_type,
    case when v_order_type = 'guest_charge' then p_reservation_id else null end,
    case when v_order_type = 'guest_charge' then v_guest_name else null end,
    'completed',
    v_subtotal,
    v_total,
    case when v_order_type = 'walkin' then v_payment_method else null end,
    v_note,
    v_created_by,
    v_order_date,
    v_now,
    v_now
  )
  returning id, order_number into v_order_id, v_order_number;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_qty := greatest(coalesce((v_item ->> 'quantity')::int, 0), 0);

    select p.id, p.name, p.category, p.sale_price, p.is_active
    into v_product
    from public.products p
    where p.id = v_product_id
    limit 1;

    v_line_total := round((v_product.sale_price * v_qty)::numeric, 2);

    insert into public.pos_order_items (
      order_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      line_total,
      created_at
    )
    values (
      v_order_id,
      v_product_id,
      v_product.name,
      v_qty,
      v_product.sale_price,
      v_line_total,
      v_now
    );

    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    select quantity
    into v_main_current
    from public.main_stock
    where product_id = v_product_id
    for update;

    v_deduct := least(v_main_current, v_qty);
    v_oversell := greatest(v_qty - v_main_current, 0);

    update public.main_stock
    set quantity = greatest(v_main_current - v_qty, 0),
        updated_at = v_now
    where product_id = v_product_id;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      performed_by,
      note,
      created_at
    )
    values (
      v_order_date,
      v_product_id,
      'sale',
      -v_deduct,
      'main',
      null,
      'pos_order',
      v_order_id,
      v_created_by,
      case
        when v_oversell > 0 then format('oversell warning: sold %s, deducted %s, missing %s', v_qty, v_deduct, v_oversell)
        else format('sold %s', v_qty)
      end,
      v_now
    );
  end loop;

  if v_order_type = 'walkin' then
    return jsonb_build_object(
      'order_id', v_order_id,
      'order_number', v_order_number,
      'subtotal', v_subtotal,
      'total', v_total,
      'deposit_used_amount', 0,
      'remaining_paid_amount', v_total,
      'payment_method', v_payment_method
    );
  end if;

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    paid_at,
    paid_date,
    revenue_category,
    cashier_name,
    pos_order_id
  )
  values (
    p_reservation_id,
    'refund',
    'cash',
    v_deposit_apply,
    format('Paid by Deposit for POS order %s (%s)', v_order_number, coalesce(v_room_number, 'no room')),
    v_now,
    v_order_date,
    'deposit',
    coalesce(v_created_by, 'FO'),
    v_order_id
  );

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    paid_at,
    paid_date,
    revenue_category,
    cashier_name,
    pos_order_id,
    is_record_only
  )
  values (
    p_reservation_id,
    'payment',
    'cash',
    v_deposit_apply,
    format('Paid by Deposit from room %s for POS order %s', coalesce(v_room_number, 'N/A'), v_order_number),
    v_now,
    v_order_date,
    'pos_revenue',
    coalesce(v_created_by, 'FO'),
    v_order_id,
    true
  );

  if v_remaining > 0 then
    insert into public.folio_payments (
      reservation_id,
      tx_type,
      method,
      amount,
      note,
      paid_at,
      paid_date,
      revenue_category,
      cashier_name,
      pos_order_id,
      is_record_only
    )
    values (
      p_reservation_id,
      'payment',
      v_payment_method::public.payment_method_type,
      v_remaining,
      format('POS remainder for room %s on order %s', coalesce(v_room_number, 'N/A'), v_order_number),
      v_now,
      v_order_date,
      'pos_revenue',
      coalesce(v_created_by, 'FO'),
      v_order_id,
      true
    );
  end if;

  update public.reservations
  set deposit_amount = greatest(
        0,
        coalesce((
          select round(sum(
            case
              when fp.tx_type = 'deposit' then fp.amount
              when fp.tx_type = 'refund'
                and (
                  coalesce(fp.revenue_category, '') = 'deposit'
                  or lower(coalesce(fp.note, '')) like '%deposit refund%'
                  or lower(coalesce(fp.note, '')) like '%paid by deposit%'
                )
              then -fp.amount
              else 0
            end
          )::numeric, 2)
          from public.folio_payments fp
          where fp.reservation_id = p_reservation_id
        ), 0)
      )
  where id = p_reservation_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'subtotal', v_subtotal,
    'total', v_total,
    'deposit_used_amount', v_deposit_apply,
    'remaining_paid_amount', v_remaining,
    'payment_method', case when v_remaining > 0 then v_payment_method else null end,
    'room_number', v_room_number
  );
end;
$$;

create or replace function public.pos_void_order_v2(
  p_order_id uuid,
  p_note text default null,
  p_voided_by text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.pos_orders%rowtype;
  v_item record;
  v_now timestamptz := timezone('utc', now());
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_voided_by text := nullif(trim(coalesce(p_voided_by, '')), '');
  v_order_date date;
  v_room_number text;
  v_record record;
begin
  if p_order_id is null then
    raise exception 'p_order_id is required';
  end if;

  select *
  into v_order
  from public.pos_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.status = 'voided' then
    raise exception 'order already voided';
  end if;

  if v_order.status <> 'completed' then
    raise exception 'only completed order can be voided';
  end if;

  v_order_date := (v_now at time zone 'Asia/Bangkok')::date;

  if v_order.reservation_id is not null then
    perform 1
    from public.reservations
    where id = v_order.reservation_id
      and status = 'active'
    for update;

    if not found then
      raise exception 'Cannot return to deposit: reservation already checked out. Use manual adjustment.';
    end if;

    select rooms.room_number
    into v_room_number
    from public.reservation_nights rn
    join public.rooms on rooms.id = rn.room_id
    where rn.reservation_id = v_order.reservation_id
      and rn.stay_date = v_order_date
      and rn.cancelled_at is null
    order by rooms.room_number
    limit 1;
  end if;

  update public.pos_orders
  set status = 'voided',
      note = coalesce(v_order.note, '') || case when v_note is null then '' else ('\nVOID: ' || v_note) end,
      updated_at = v_now
  where id = p_order_id;

  for v_item in
    select poi.product_id, poi.quantity
    from public.pos_order_items poi
    where poi.order_id = p_order_id
  loop
    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_item.product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    update public.main_stock
    set quantity = quantity + v_item.quantity,
        updated_at = v_now
    where product_id = v_item.product_id;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      performed_by,
      note,
      created_at
    )
    values (
      v_order_date,
      v_item.product_id,
      'return',
      v_item.quantity,
      null,
      'main',
      'pos_order',
      p_order_id,
      v_voided_by,
      coalesce(v_note, 'pos order void return'),
      v_now
    );
  end loop;

  if v_order.order_type = 'guest_charge' and v_order.reservation_id is not null then
    if exists (
      select 1
      from public.reservations r
      where r.id = v_order.reservation_id
        and r.status = 'checked_out'
    ) then
      raise exception 'Cannot return to deposit: reservation already checked out. Use manual adjustment.';
    end if;

    for v_record in
      select
        id,
        tx_type,
        method,
        amount,
        note,
        revenue_category,
        is_record_only
      from public.folio_payments
      where pos_order_id = p_order_id
      order by paid_at asc, created_at asc, id asc
    loop
      if v_record.tx_type = 'refund' and coalesce(v_record.revenue_category, '') = 'deposit' then
        insert into public.folio_payments (
          reservation_id,
          tx_type,
          method,
          amount,
          note,
          paid_at,
          paid_date,
          revenue_category,
          cashier_name,
          pos_order_id
        )
        values (
          v_order.reservation_id,
          'deposit',
          'cash',
          v_record.amount,
          coalesce(v_note, format('Void return to deposit for POS order %s', v_order.order_number)),
          v_now,
          v_order_date,
          'deposit',
          coalesce(v_voided_by, 'FO'),
          p_order_id
        );
      elsif coalesce(v_record.is_record_only, false) then
        insert into public.folio_payments (
          reservation_id,
          tx_type,
          method,
          amount,
          note,
          paid_at,
          paid_date,
          revenue_category,
          cashier_name,
          pos_order_id,
          is_record_only
        )
        values (
          v_order.reservation_id,
          'refund',
          coalesce(v_record.method::text, 'cash')::public.payment_method_type,
          v_record.amount,
          coalesce(v_note, format('Void return to deposit for POS order %s', v_order.order_number)),
          v_now,
          v_order_date,
          coalesce(v_record.revenue_category, 'pos_revenue'),
          coalesce(v_voided_by, 'FO'),
          p_order_id,
          true
        );
      end if;
    end loop;

    update public.reservations
    set deposit_amount = greatest(
          0,
          coalesce((
            select round(sum(
              case
                when fp.tx_type = 'deposit' then fp.amount
                when fp.tx_type = 'refund'
                  and (
                    coalesce(fp.revenue_category, '') = 'deposit'
                    or lower(coalesce(fp.note, '')) like '%deposit refund%'
                    or lower(coalesce(fp.note, '')) like '%paid by deposit%'
                  )
                then -fp.amount
                else 0
              end
            )::numeric, 2)
            from public.folio_payments fp
            where fp.reservation_id = v_order.reservation_id
          ), 0)
        )
    where id = v_order.reservation_id;
  end if;

  return jsonb_build_object(
    'order_id', p_order_id,
    'order_number', v_order.order_number,
    'status', 'voided'
  );
end;
$$;

grant execute on function public.pos_create_order_v2(text, jsonb, text, uuid, text, text, numeric) to anon, authenticated;
grant execute on function public.pos_void_order_v2(uuid, text, text) to anon, authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603130005_phase29_pos_deposit_settlement_hotfix_for_update.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Hotfix: fix FOR UPDATE on LEFT JOIN (lock only reservations row)
-- and enforce checked_out void guard for deposit return path.

create or replace function public.pos_create_order_v2(
  p_order_type text,
  p_items jsonb,
  p_payment_method text default null,
  p_reservation_id uuid default null,
  p_created_by text default null,
  p_note text default null,
  p_deposit_amount numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_type text := coalesce(trim(p_order_type), '');
  v_payment_method text := nullif(trim(coalesce(p_payment_method, '')), '');
  v_created_by text := nullif(trim(coalesce(p_created_by, '')), '');
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_now timestamptz := timezone('utc', now());
  v_order_id uuid;
  v_order_number text;
  v_guest_name text;
  v_room_number text;
  v_subtotal numeric(10,2) := 0;
  v_total numeric(10,2) := 0;
  v_item jsonb;
  v_product record;
  v_product_id uuid;
  v_qty int;
  v_line_total numeric(10,2);
  v_main_current int;
  v_deduct int;
  v_oversell int;
  v_order_date date := (v_now at time zone 'Asia/Bangkok')::date;
  v_held numeric(10,2) := 0;
  v_deposit_amount numeric(10,2) := greatest(coalesce(p_deposit_amount, 0), 0);
  v_deposit_apply numeric(10,2) := 0;
  v_remaining numeric(10,2) := 0;
begin
  if v_order_type not in ('walkin', 'guest_charge') then
    raise exception 'invalid p_order_type: %', p_order_type;
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'p_items must be non-empty array';
  end if;

  if v_order_type = 'walkin' then
    if v_payment_method not in ('cash', 'transfer', 'credit_card') then
      raise exception 'walkin payment method must be cash|transfer|credit_card';
    end if;
    v_deposit_amount := 0;
  else
    if p_reservation_id is null then
      raise exception 'p_reservation_id is required for guest_charge';
    end if;

    select
      r.guest_name,
      rm.room_number
    into
      v_guest_name,
      v_room_number
    from public.reservations r
    left join lateral (
      select rooms.room_number
      from public.reservation_nights rn
      join public.rooms on rooms.id = rn.room_id
      where rn.reservation_id = r.id
        and rn.stay_date = v_order_date
        and rn.cancelled_at is null
      order by rooms.room_number
      limit 1
    ) rm on true
    where r.id = p_reservation_id
      and r.status = 'active'
    for update of r;

    if v_guest_name is null then
      raise exception 'reservation is not eligible for room deposit settlement';
    end if;

    if v_room_number is null then
      raise exception 'reservation has no active room night today';
    end if;

    select coalesce(
      sum(
        case
          when fp.tx_type = 'deposit' then fp.amount
          when fp.tx_type = 'refund'
            and (
              coalesce(fp.revenue_category, '') = 'deposit'
              or lower(coalesce(fp.note, '')) like '%deposit refund%'
              or lower(coalesce(fp.note, '')) like '%paid by deposit%'
            )
          then -fp.amount
          else 0
        end
      ),
      0
    )
    into v_held
    from public.folio_payments fp
    where fp.reservation_id = p_reservation_id;

    v_held := round(v_held::numeric, 2);
    v_deposit_apply := round(least(v_deposit_amount, v_held)::numeric, 2);
    v_remaining := round(greatest(v_total - v_deposit_apply, 0)::numeric, 2);
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_product_id := (v_item ->> 'product_id')::uuid;
    exception when others then
      v_product_id := null;
    end;

    v_qty := greatest(coalesce((v_item ->> 'quantity')::int, 0), 0);
    if v_product_id is null or v_qty <= 0 then
      raise exception 'invalid item payload, each row must include product_id + quantity > 0';
    end if;

    select p.id, p.name, p.category, p.sale_price, p.is_active
    into v_product
    from public.products p
    where p.id = v_product_id
    limit 1;

    if not found then
      raise exception 'product not found: %', v_product_id;
    end if;

    if not coalesce(v_product.is_active, false) then
      raise exception 'product inactive: %', v_product.name;
    end if;

    if v_product.category not in ('pos', 'both') then
      raise exception 'product is not POS sale item: %', v_product.name;
    end if;

    if v_product.sale_price is null then
      raise exception 'product sale_price is required for POS item: %', v_product.name;
    end if;

    v_line_total := round((v_product.sale_price * v_qty)::numeric, 2);
    v_subtotal := round((v_subtotal + v_line_total)::numeric, 2);
  end loop;

  v_total := v_subtotal;

  if v_order_type = 'guest_charge' then
    v_deposit_apply := round(least(v_deposit_amount, v_held, v_total)::numeric, 2);
    v_remaining := round(greatest(v_total - v_deposit_apply, 0)::numeric, 2);

    if v_deposit_apply <= 0 then
      raise exception 'deposit held is required for room settlement';
    end if;

    if v_remaining > 0 and v_payment_method not in ('cash', 'transfer', 'credit_card') then
      raise exception 'remaining payment method must be cash|transfer|credit_card';
    end if;

    if v_remaining = 0 then
      v_payment_method := null;
    end if;
  end if;

  insert into public.pos_orders (
    order_number,
    order_type,
    reservation_id,
    guest_name,
    status,
    subtotal,
    total,
    payment_method,
    note,
    created_by,
    order_date,
    created_at,
    updated_at
  )
  values (
    public.generate_pos_order_number(),
    v_order_type,
    case when v_order_type = 'guest_charge' then p_reservation_id else null end,
    case when v_order_type = 'guest_charge' then v_guest_name else null end,
    'completed',
    v_subtotal,
    v_total,
    case when v_order_type = 'walkin' then v_payment_method else null end,
    v_note,
    v_created_by,
    v_order_date,
    v_now,
    v_now
  )
  returning id, order_number into v_order_id, v_order_number;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_qty := greatest(coalesce((v_item ->> 'quantity')::int, 0), 0);

    select p.id, p.name, p.category, p.sale_price, p.is_active
    into v_product
    from public.products p
    where p.id = v_product_id
    limit 1;

    v_line_total := round((v_product.sale_price * v_qty)::numeric, 2);

    insert into public.pos_order_items (
      order_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      line_total,
      created_at
    )
    values (
      v_order_id,
      v_product_id,
      v_product.name,
      v_qty,
      v_product.sale_price,
      v_line_total,
      v_now
    );

    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    select quantity
    into v_main_current
    from public.main_stock
    where product_id = v_product_id
    for update;

    v_deduct := least(v_main_current, v_qty);
    v_oversell := greatest(v_qty - v_main_current, 0);

    update public.main_stock
    set quantity = greatest(v_main_current - v_qty, 0),
        updated_at = v_now
    where product_id = v_product_id;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      performed_by,
      note,
      created_at
    )
    values (
      v_order_date,
      v_product_id,
      'sale',
      -v_deduct,
      'main',
      null,
      'pos_order',
      v_order_id,
      v_created_by,
      case
        when v_oversell > 0 then format('oversell warning: sold %s, deducted %s, missing %s', v_qty, v_deduct, v_oversell)
        else format('sold %s', v_qty)
      end,
      v_now
    );
  end loop;

  if v_order_type = 'walkin' then
    return jsonb_build_object(
      'order_id', v_order_id,
      'order_number', v_order_number,
      'subtotal', v_subtotal,
      'total', v_total,
      'deposit_used_amount', 0,
      'remaining_paid_amount', v_total,
      'payment_method', v_payment_method
    );
  end if;

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    paid_at,
    paid_date,
    revenue_category,
    cashier_name,
    pos_order_id
  )
  values (
    p_reservation_id,
    'refund',
    'cash',
    v_deposit_apply,
    format('Paid by Deposit for POS order %s (%s)', v_order_number, coalesce(v_room_number, 'no room')),
    v_now,
    v_order_date,
    'deposit',
    coalesce(v_created_by, 'FO'),
    v_order_id
  );

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    paid_at,
    paid_date,
    revenue_category,
    cashier_name,
    pos_order_id,
    is_record_only
  )
  values (
    p_reservation_id,
    'payment',
    'cash',
    v_deposit_apply,
    format('Paid by Deposit from room %s for POS order %s', coalesce(v_room_number, 'N/A'), v_order_number),
    v_now,
    v_order_date,
    'pos_revenue',
    coalesce(v_created_by, 'FO'),
    v_order_id,
    true
  );

  if v_remaining > 0 then
    insert into public.folio_payments (
      reservation_id,
      tx_type,
      method,
      amount,
      note,
      paid_at,
      paid_date,
      revenue_category,
      cashier_name,
      pos_order_id,
      is_record_only
    )
    values (
      p_reservation_id,
      'payment',
      v_payment_method::public.payment_method_type,
      v_remaining,
      format('POS remainder for room %s on order %s', coalesce(v_room_number, 'N/A'), v_order_number),
      v_now,
      v_order_date,
      'pos_revenue',
      coalesce(v_created_by, 'FO'),
      v_order_id,
      true
    );
  end if;

  update public.reservations
  set deposit_amount = greatest(
        0,
        coalesce((
          select round(sum(
            case
              when fp.tx_type = 'deposit' then fp.amount
              when fp.tx_type = 'refund'
                and (
                  coalesce(fp.revenue_category, '') = 'deposit'
                  or lower(coalesce(fp.note, '')) like '%deposit refund%'
                  or lower(coalesce(fp.note, '')) like '%paid by deposit%'
                )
              then -fp.amount
              else 0
            end
          )::numeric, 2)
          from public.folio_payments fp
          where fp.reservation_id = p_reservation_id
        ), 0)
      )
  where id = p_reservation_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'subtotal', v_subtotal,
    'total', v_total,
    'deposit_used_amount', v_deposit_apply,
    'remaining_paid_amount', v_remaining,
    'payment_method', case when v_remaining > 0 then v_payment_method else null end,
    'room_number', v_room_number
  );
end;
$$;

create or replace function public.pos_void_order_v2(
  p_order_id uuid,
  p_note text default null,
  p_voided_by text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.pos_orders%rowtype;
  v_item record;
  v_now timestamptz := timezone('utc', now());
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_voided_by text := nullif(trim(coalesce(p_voided_by, '')), '');
  v_order_date date;
  v_room_number text;
  v_record record;
begin
  if p_order_id is null then
    raise exception 'p_order_id is required';
  end if;

  select *
  into v_order
  from public.pos_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.status = 'voided' then
    raise exception 'order already voided';
  end if;

  if v_order.status <> 'completed' then
    raise exception 'only completed order can be voided';
  end if;

  v_order_date := (v_now at time zone 'Asia/Bangkok')::date;

  if v_order.reservation_id is not null then
    perform 1
    from public.reservations
    where id = v_order.reservation_id
      and status = 'active'
    for update;

    if not found then
      raise exception 'Cannot return to deposit: reservation already checked out. Use manual adjustment.';
    end if;

    select rooms.room_number
    into v_room_number
    from public.reservation_nights rn
    join public.rooms on rooms.id = rn.room_id
    where rn.reservation_id = v_order.reservation_id
      and rn.stay_date = v_order_date
      and rn.cancelled_at is null
    order by rooms.room_number
    limit 1;
  end if;

  update public.pos_orders
  set status = 'voided',
      note = coalesce(v_order.note, '') || case when v_note is null then '' else ('\nVOID: ' || v_note) end,
      updated_at = v_now
  where id = p_order_id;

  for v_item in
    select poi.product_id, poi.quantity
    from public.pos_order_items poi
    where poi.order_id = p_order_id
  loop
    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_item.product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    update public.main_stock
    set quantity = quantity + v_item.quantity,
        updated_at = v_now
    where product_id = v_item.product_id;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      performed_by,
      note,
      created_at
    )
    values (
      v_order_date,
      v_item.product_id,
      'return',
      v_item.quantity,
      null,
      'main',
      'pos_order',
      p_order_id,
      v_voided_by,
      coalesce(v_note, 'pos order void return'),
      v_now
    );
  end loop;

  if v_order.order_type = 'guest_charge' and v_order.reservation_id is not null then
    if exists (
      select 1
      from public.reservations r
      where r.id = v_order.reservation_id
        and r.status = 'checked_out'
    ) then
      raise exception 'Cannot return to deposit: reservation already checked out. Use manual adjustment.';
    end if;

    for v_record in
      select
        id,
        tx_type,
        method,
        amount,
        note,
        revenue_category,
        is_record_only
      from public.folio_payments
      where pos_order_id = p_order_id
      order by paid_at asc, created_at asc, id asc
    loop
      if v_record.tx_type = 'refund' and coalesce(v_record.revenue_category, '') = 'deposit' then
        insert into public.folio_payments (
          reservation_id,
          tx_type,
          method,
          amount,
          note,
          paid_at,
          paid_date,
          revenue_category,
          cashier_name,
          pos_order_id
        )
        values (
          v_order.reservation_id,
          'deposit',
          'cash',
          v_record.amount,
          coalesce(v_note, format('Void return to deposit for POS order %s', v_order.order_number)),
          v_now,
          v_order_date,
          'deposit',
          coalesce(v_voided_by, 'FO'),
          p_order_id
        );
      elsif coalesce(v_record.is_record_only, false) then
        insert into public.folio_payments (
          reservation_id,
          tx_type,
          method,
          amount,
          note,
          paid_at,
          paid_date,
          revenue_category,
          cashier_name,
          pos_order_id,
          is_record_only
        )
        values (
          v_order.reservation_id,
          'refund',
          coalesce(v_record.method::text, 'cash')::public.payment_method_type,
          v_record.amount,
          coalesce(v_note, format('Void return to deposit for POS order %s', v_order.order_number)),
          v_now,
          v_order_date,
          coalesce(v_record.revenue_category, 'pos_revenue'),
          coalesce(v_voided_by, 'FO'),
          p_order_id,
          true
        );
      end if;
    end loop;

    update public.reservations
    set deposit_amount = greatest(
          0,
          coalesce((
            select round(sum(
              case
                when fp.tx_type = 'deposit' then fp.amount
                when fp.tx_type = 'refund'
                  and (
                    coalesce(fp.revenue_category, '') = 'deposit'
                    or lower(coalesce(fp.note, '')) like '%deposit refund%'
                    or lower(coalesce(fp.note, '')) like '%paid by deposit%'
                  )
                then -fp.amount
                else 0
              end
            )::numeric, 2)
            from public.folio_payments fp
            where fp.reservation_id = v_order.reservation_id
          ), 0)
        )
    where id = v_order.reservation_id;
  end if;

  return jsonb_build_object(
    'order_id', p_order_id,
    'order_number', v_order.order_number,
    'status', 'voided'
  );
end;
$$;

grant execute on function public.pos_create_order_v2(text, jsonb, text, uuid, text, text, numeric) to anon, authenticated;
grant execute on function public.pos_void_order_v2(uuid, text, text) to anon, authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603140001_phase30_cancel_shorten_method_nullable.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 30 hotfix prerequisite
-- Fee rows settled from pre-paid are record-only traces and must not carry a payment method.

ALTER TABLE public.folio_payments
  ALTER COLUMN method DROP NOT NULL;

COMMENT ON COLUMN public.folio_payments.method IS
  'Payment method for real money movement rows. Can be NULL for record-only settlement traces (e.g., pre-paid fee deduction).';




-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603140002_phase31_rate_plan_access.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

CREATE TABLE IF NOT EXISTS public.rate_plan_tiers (
  rate_plan_id uuid NOT NULL REFERENCES public.rate_plans(id) ON DELETE CASCADE,
  tier_code text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (rate_plan_id, tier_code),
  CONSTRAINT chk_rate_plan_tiers_code CHECK (tier_code IN ('loyal', 'vip', 'longest'))
);

CREATE INDEX IF NOT EXISTS idx_rate_plan_tiers_tier_code
  ON public.rate_plan_tiers (tier_code, rate_plan_id);

CREATE TABLE IF NOT EXISTS public.rate_plan_profiles (
  rate_plan_id uuid NOT NULL REFERENCES public.rate_plans(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.guest_profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (rate_plan_id, profile_id)
);

CREATE INDEX IF NOT EXISTS idx_rate_plan_profiles_profile_id
  ON public.rate_plan_profiles (profile_id, rate_plan_id);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603140003_phase32_alert_trace_runtime.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

CREATE TABLE IF NOT EXISTS public.alert_templates (
  id serial PRIMARY KEY,
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  category text NOT NULL,
  display_surfaces text[] NOT NULL DEFAULT ARRAY['reservation']::text[],
  severity text NOT NULL DEFAULT 'info',
  is_system boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  icon text
);

ALTER TABLE public.alert_templates ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'alert_templates'
      AND policyname = 'service role full access'
  ) THEN
    CREATE POLICY "service role full access" ON public.alert_templates FOR ALL USING (true);
  END IF;
END $$;

ALTER TABLE public.reservation_alerts
  ADD COLUMN IF NOT EXISTS alert_template_id int REFERENCES public.alert_templates(id),
  ADD COLUMN IF NOT EXISTS custom_message text,
  ADD COLUMN IF NOT EXISTS display_surfaces text[],
  ADD COLUMN IF NOT EXISTS severity text DEFAULT 'info',
  ADD COLUMN IF NOT EXISTS is_dismissed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_by text;

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS expected_arrival_time time;

ALTER TABLE public.loan_items
  ADD COLUMN IF NOT EXISTS requires_extra_charge_reminder boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS linked_fee_template_code text;

INSERT INTO public.alert_templates (code, name, description, category, display_surfaces, severity, is_system, sort_order, icon)
SELECT
  ac.code,
  CASE ac.code
    WHEN 'ADA' THEN 'Adaptor / Device Return'
    WHEN 'HAIR' THEN 'Hair Dryer Return'
    WHEN 'IRON' THEN 'Iron Return'
    WHEN 'BED' THEN 'Extra Bed Request'
    WHEN 'PIL' THEN 'Extra Pillow Request'
    WHEN 'DND' THEN 'Do Not Disturb'
    WHEN 'DEP' THEN 'Take Deposit'
    WHEN 'GRT' THEN 'Manager Greeting'
    WHEN 'ANN' THEN 'Anniversary'
    WHEN 'BIR' THEN 'Birthday'
    WHEN 'PCP' THEN 'Previous Complaint'
    WHEN 'BOAT' THEN 'Boat Transfer'
    WHEN 'CAR' THEN 'Car Transfer'
    WHEN 'VIP' THEN 'VIP Guest'
    WHEN 'OTH' THEN 'Other Alert'
    ELSE ac.description
  END,
  ac.description,
  CASE
    WHEN ac.dept = 'HK' THEN 'housekeeping'
    WHEN ac.code IN ('BOAT', 'CAR') THEN 'arrival'
    ELSE 'policy'
  END,
  CASE
    WHEN ac.code IN ('BOAT', 'CAR') THEN ARRAY['arrivals','room_diary','calendar','reservation','room_drawer']::text[]
    WHEN ac.dept = 'HK' THEN ARRAY['reservation','room_drawer','inhouse','room_diary','calendar','hk_dashboard']::text[]
    WHEN ac.auto_on_co = true THEN ARRAY['reservation','room_drawer','inhouse']::text[]
    ELSE ARRAY['arrivals','reservation','room_drawer','inhouse']::text[]
  END,
  CASE
    WHEN ac.code IN ('PCP', 'VIP') THEN 'critical'
    WHEN ac.code IN ('BOAT', 'CAR', 'DEP', 'ANN', 'BIR') THEN 'warning'
    ELSE 'info'
  END,
  true,
  0,
  ac.icon
FROM public.alert_codes ac
ON CONFLICT (code) DO UPDATE
SET
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  display_surfaces = EXCLUDED.display_surfaces,
  severity = EXCLUDED.severity,
  icon = EXCLUDED.icon;

INSERT INTO public.alert_templates (code, name, description, category, display_surfaces, severity, is_system, sort_order, icon)
VALUES
  ('very_late_arrival', 'Very Late Arrival', 'Guest expects arrival after 22:00', 'arrival', ARRAY['arrivals','room_diary','calendar','reservation','room_drawer']::text[], 'warning', false, 10, '🌙'),
  ('clean_every_2_days', 'Clean Every 2 Days', 'Housekeeping frequency reminder', 'housekeeping', ARRAY['inhouse','room_diary','calendar','reservation','room_drawer','hk_dashboard']::text[], 'info', false, 20, '🧹')
ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  category = EXCLUDED.category,
  display_surfaces = EXCLUDED.display_surfaces,
  severity = EXCLUDED.severity,
  icon = EXCLUDED.icon;

UPDATE public.reservation_alerts ra
SET
  alert_template_id = at.id,
  severity = COALESCE(ra.severity, at.severity),
  display_surfaces = COALESCE(ra.display_surfaces, at.display_surfaces)
FROM public.alert_templates at
WHERE ra.alert_template_id IS NULL
  AND ra.alert_code = at.code;

CREATE INDEX IF NOT EXISTS idx_reservation_alerts_template_id
  ON public.reservation_alerts (alert_template_id);

CREATE INDEX IF NOT EXISTS idx_reservation_alerts_dismissed
  ON public.reservation_alerts (reservation_id, is_dismissed, created_at);

CREATE INDEX IF NOT EXISTS idx_alert_templates_active
  ON public.alert_templates (is_active, sort_order, code);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603140004_phase33_operations_setup.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

CREATE TABLE IF NOT EXISTS public.trace_templates (
  id serial PRIMARY KEY,
  name text NOT NULL,
  dept public.trace_dept NOT NULL DEFAULT 'FD',
  template_text text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.trace_templates ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'trace_templates'
      AND policyname = 'service role full access'
  ) THEN
    CREATE POLICY "service role full access" ON public.trace_templates FOR ALL USING (true);
  END IF;
END
$$;

INSERT INTO public.trace_templates (name, dept, template_text, is_active, sort_order)
VALUES
  ('Extra pillow before arrival', 'HK', 'Please place extra pillow in room before arrival.', true, 10),
  ('Extra bed setup', 'HK', 'Extra bed requested. Please set up before check-in.', true, 20),
  ('Do Not Disturb', 'HK', 'Do Not Disturb — guest requested privacy.', true, 30),
  ('EU adapter collect', 'FD', 'Guest has EU adapter — collect on checkout.', true, 40),
  ('Hair dryer collect', 'FD', 'Guest has hair dryer — collect on checkout.', true, 50),
  ('A/C issue check', 'MAINT', 'Please check A/C in room — guest reported issue.', true, 60),
  ('Anniversary amenity', 'FD', 'Anniversary — arrange cake / flowers.', true, 70),
  ('Transfer confirm', 'FD', 'Guest booked car transfer — confirm pick-up time.', true, 80)
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_trace_templates_active
  ON public.trace_templates (is_active, dept, sort_order, id);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603150001_phase32_fix_alert_display_surfaces.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 32 hotfix: Add room_diary and calendar to alert template display_surfaces
-- Root cause: seed data gave critical/warning templates surfaces without room_diary/calendar,
-- so filterAlertsForSurface("room_diary") filtered them out → only info (blue) dots showed.

-- 1) Fix alert_templates: add room_diary + calendar to all templates that don't already have them
--    Exception: auto_on_co templates (checkout-specific) keep restricted surfaces
UPDATE public.alert_templates
SET display_surfaces = array(
  SELECT DISTINCT unnest(
    display_surfaces || ARRAY['room_diary','calendar']::text[]
  )
)
WHERE NOT (display_surfaces @> ARRAY['room_diary']::text[])
  AND code NOT IN (
    SELECT code FROM public.alert_codes WHERE auto_on_co = true
  );

-- 2) Also fix reservation_alerts rows that inherited restricted surfaces from templates
--    For rows that have a template with room_diary/calendar, sync surfaces
UPDATE public.reservation_alerts ra
SET display_surfaces = at.display_surfaces
FROM public.alert_templates at
WHERE ra.alert_template_id = at.id
  AND ra.display_surfaces IS NOT NULL
  AND NOT (ra.display_surfaces @> ARRAY['room_diary']::text[])
  AND (at.display_surfaces @> ARRAY['room_diary']::text[]);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603150002_phase34_auth_and_bug_reports.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 34: Auth permissions + Bug Reports

-- 1) Add allowed_pages to profiles table
--    '*' = access all pages (admin default)
--    Array of route prefixes e.g. ARRAY['/pms/board','/pms/arrivals']
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS allowed_pages text[] DEFAULT ARRAY['*']::text[];

-- Default existing admin/supervisor rows to '*' (already the column default, but explicit)
UPDATE public.profiles
SET allowed_pages = ARRAY['*']::text[]
WHERE allowed_pages IS NULL
   OR allowed_pages = '{}';

-- 2) Bug Reports table
CREATE TABLE IF NOT EXISTS public.bug_reports (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reporter_email  text,
  page_url        text NOT NULL,
  description     text NOT NULL,
  screenshot_url  text,
  browser_info    jsonb,
  status          text NOT NULL DEFAULT 'open',
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'bug_reports' AND policyname = 'service role full access'
  ) THEN
    CREATE POLICY "service role full access" ON public.bug_reports FOR ALL USING (true);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON public.bug_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bug_reports_reporter ON public.bug_reports (reported_by);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603180001_phase36_fo_roster.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- ============================================================
-- Phase 36: FO Shift Roster — roster_config + staff_shifts extensions
-- ============================================================

-- 1A: roster_config — FO-specific scheduling configuration per staff
create table if not exists public.roster_config (
  id                      uuid primary key default gen_random_uuid(),
  staff_id                uuid not null unique references public.staff(id) on delete cascade,
  regular_day_off         smallint not null check (regular_day_off between 0 and 6), -- 0=Sun..6=Sat
  shift_preference        text not null default 'rotate'
                            check (shift_preference in ('morning_fixed', 'rotate')),
  night_rotation_order    smallint check (night_rotation_order between 1 and 10),
  extra_day_offs_per_month smallint not null default 0 check (extra_day_offs_per_month >= 0),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

drop trigger if exists trg_roster_config_updated_at on public.roster_config;
create trigger trg_roster_config_updated_at
before update on public.roster_config
for each row execute function public.set_updated_at();

-- 1B: Add is_generated column to staff_shifts
alter table public.staff_shifts
  add column if not exists is_generated boolean not null default false;

-- 1C: DELETE policy on staff_shifts (admin/supervisor only)
drop policy if exists shifts_delete_admin_supervisor on public.staff_shifts;
create policy shifts_delete_admin_supervisor on public.staff_shifts
  for delete to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'supervisor')
    )
  );

-- 1D: RLS on roster_config
alter table public.roster_config enable row level security;

drop policy if exists roster_config_select_authenticated on public.roster_config;
create policy roster_config_select_authenticated on public.roster_config
  for select to authenticated
  using (true);

drop policy if exists roster_config_insert_admin_supervisor on public.roster_config;
create policy roster_config_insert_admin_supervisor on public.roster_config
  for insert to authenticated
  with check (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'supervisor')
    )
  );

drop policy if exists roster_config_update_admin_supervisor on public.roster_config;
create policy roster_config_update_admin_supervisor on public.roster_config
  for update to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'supervisor')
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'supervisor')
    )
  );

drop policy if exists roster_config_delete_admin_supervisor on public.roster_config;
create policy roster_config_delete_admin_supervisor on public.roster_config
  for delete to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'supervisor')
    )
  );

-- 1E: Indexes
create index if not exists idx_staff_shifts_generated
  on public.staff_shifts (shift_date, is_generated)
  where is_generated = true;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603180002_phase37_identity_alert_settings.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

alter table public.hotel_settings
  add column if not exists identity_alert_under18_thai_id_enabled boolean not null default true,
  add column if not exists identity_alert_under18_passport_enabled boolean not null default true,
  add column if not exists identity_alert_over18_thai_id_enabled boolean not null default true,
  add column if not exists identity_alert_over18_passport_enabled boolean not null default true,
  add column if not exists identity_alert_birthday_enabled boolean not null default true;

update public.hotel_settings
set
  identity_alert_under18_thai_id_enabled = coalesce(identity_alert_under18_thai_id_enabled, true),
  identity_alert_under18_passport_enabled = coalesce(identity_alert_under18_passport_enabled, true),
  identity_alert_over18_thai_id_enabled = coalesce(identity_alert_over18_thai_id_enabled, true),
  identity_alert_over18_passport_enabled = coalesce(identity_alert_over18_passport_enabled, true),
  identity_alert_birthday_enabled = coalesce(identity_alert_birthday_enabled, true)
where id = 1;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603190001_phase38_ota_modification_original_checkout.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

alter table public.reservations
  add column if not exists original_checkout_date date;




-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603190002_phase38_dayuse_room_type_isolation.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================
-- Phase 38: Isolate Day Use room type from Family (hard split)
-- ============================================================
-- Goal:
-- 1) Create dedicated room_type code = 'DU' (Day Use)
-- 2) Move all day-use rooms to DU room type
-- 3) Enforce future writes so day-use rooms never drift back to Family/other types

BEGIN;

-- 1) Ensure dedicated Day Use room type exists
INSERT INTO public.room_types (code, name_en, name_local, sort_order, cleaning_duration_min)
VALUES ('DU', 'Day Use', 'Day Use', 65, 60)
ON CONFLICT (code) DO UPDATE
SET
  name_en = EXCLUDED.name_en,
  name_local = EXCLUDED.name_local,
  sort_order = EXCLUDED.sort_order,
  cleaning_duration_min = GREATEST(COALESCE(public.room_types.cleaning_duration_min, EXCLUDED.cleaning_duration_min), 1),
  updated_at = timezone('utc', now());

-- Ensure DU always has a housekeeping cleaning duration
UPDATE public.room_types
SET
  cleaning_duration_min = GREATEST(COALESCE(cleaning_duration_min, 60), 1),
  updated_at = timezone('utc', now())
WHERE code = 'DU';

-- 2) Canonical day-use room numbers should always be day-use
UPDATE public.rooms
SET
  is_dayuse = true,
  is_visible_on_board = true,
  is_sellable = true,
  closure_reason = null,
  updated_at = timezone('utc', now())
WHERE room_number IN ('118', '120', '122');

-- 3) Move all day-use rooms to DU room_type
WITH du_type AS (
  SELECT id
  FROM public.room_types
  WHERE code = 'DU'
  LIMIT 1
)
UPDATE public.rooms r
SET
  room_type_id = du.id,
  is_dayuse = true,
  updated_at = timezone('utc', now())
FROM du_type du
WHERE
  (COALESCE(r.is_dayuse, false) = true OR r.room_number IN ('118', '120', '122'))
  AND r.room_type_id IS DISTINCT FROM du.id;

-- 4) Keep reservation_nights.room_type_id aligned for day-use history rows
WITH du_type AS (
  SELECT id
  FROM public.room_types
  WHERE code = 'DU'
  LIMIT 1
),
dayuse_rooms AS (
  SELECT id
  FROM public.rooms
  WHERE COALESCE(is_dayuse, false) = true
)
UPDATE public.reservation_nights rn
SET room_type_id = du.id
FROM du_type du
WHERE
  rn.room_id IN (SELECT id FROM dayuse_rooms)
  AND rn.room_type_id IS DISTINCT FROM du.id;

-- 5) Enforce split at DB level for all future writes
CREATE OR REPLACE FUNCTION public.enforce_dayuse_room_type()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_dayuse_type_id bigint;
BEGIN
  SELECT id INTO v_dayuse_type_id
  FROM public.room_types
  WHERE code = 'DU'
  LIMIT 1;

  IF v_dayuse_type_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- If flagged day-use, always lock room_type to DU.
  IF COALESCE(NEW.is_dayuse, false) = true THEN
    NEW.room_type_id := v_dayuse_type_id;
    NEW.is_dayuse := true;
    RETURN NEW;
  END IF;

  -- If DU type is selected, force day-use flag on.
  IF NEW.room_type_id = v_dayuse_type_id THEN
    NEW.is_dayuse := true;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_rooms_enforce_dayuse_room_type ON public.rooms;
CREATE TRIGGER trg_rooms_enforce_dayuse_room_type
BEFORE INSERT OR UPDATE OF room_type_id, is_dayuse
ON public.rooms
FOR EACH ROW
EXECUTE FUNCTION public.enforce_dayuse_room_type();

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603210001_phase39a_audit_columns.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.audit_logs
  add column if not exists business_date date;

alter table public.audit_logs
  add column if not exists source text not null default 'manual'
    check (source in ('manual', 'system', 'api', 'night_audit'));

alter table public.audit_logs
  add column if not exists note text;

create index if not exists idx_audit_logs_business_date
  on public.audit_logs (business_date desc, created_at desc);

create index if not exists idx_audit_logs_entity_lookup
  on public.audit_logs (entity_type, entity_id, created_at desc);

create index if not exists idx_audit_logs_action
  on public.audit_logs (action);

update public.audit_logs
set business_date = (created_at at time zone 'Asia/Bangkok')::date
where business_date is null;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603210002_phase39b_monthly_audit.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 39B: Monthly Audit & Correction System
-- Snapshot + correction layer for end-of-month financial reconciliation

-- ============================================================
-- 1. Add tax_invoice_requested to reservations
-- ============================================================
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS tax_invoice_requested boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.reservations.tax_invoice_requested
  IS 'True when guest requests full tax invoice (ใบกำกับภาษีเต็มรูปแบบ)';

-- ============================================================
-- 2. monthly_audit_periods — tracks audit lifecycle per month
-- ============================================================
CREATE TABLE IF NOT EXISTS public.monthly_audit_periods (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  year          smallint NOT NULL,
  month         smallint NOT NULL CHECK (month BETWEEN 1 AND 12),
  status        text NOT NULL DEFAULT 'open'
                CHECK (status IN ('open','reviewing','audited','locked')),
  closed_at     timestamptz,
  closed_by     uuid,
  audited_at    timestamptz,
  audited_by    uuid,
  summary_json  jsonb,
  note          text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(year, month)
);

COMMENT ON TABLE public.monthly_audit_periods
  IS 'Monthly audit lifecycle: open → reviewing → audited → locked';

-- RLS
ALTER TABLE public.monthly_audit_periods ENABLE ROW LEVEL SECURITY;

CREATE POLICY map_select ON public.monthly_audit_periods
  FOR SELECT TO authenticated USING (true);

CREATE POLICY map_insert ON public.monthly_audit_periods
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));

CREATE POLICY map_update ON public.monthly_audit_periods
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));

-- ============================================================
-- 3. monthly_audit_entries — snapshot per reservation
-- ============================================================
CREATE TABLE IF NOT EXISTS public.monthly_audit_entries (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id             uuid NOT NULL REFERENCES public.monthly_audit_periods(id) ON DELETE CASCADE,
  reservation_id        uuid NOT NULL,
  booking_code          text,
  guest_name            text NOT NULL,
  source                text NOT NULL,
  checkin_date          date NOT NULL,
  checkout_date         date NOT NULL,
  room_number           text,
  room_type_name        text,
  total_nights          smallint NOT NULL DEFAULT 1,

  -- Revenue breakdown
  room_revenue          numeric(12,2) NOT NULL DEFAULT 0,
  extra_revenue         numeric(12,2) NOT NULL DEFAULT 0,
  pos_revenue           numeric(12,2) NOT NULL DEFAULT 0,
  total_revenue         numeric(12,2) NOT NULL DEFAULT 0,

  -- Payment breakdown by method
  paid_cash             numeric(12,2) NOT NULL DEFAULT 0,
  paid_transfer         numeric(12,2) NOT NULL DEFAULT 0,
  paid_credit_card      numeric(12,2) NOT NULL DEFAULT 0,
  paid_other            numeric(12,2) NOT NULL DEFAULT 0,
  total_paid            numeric(12,2) NOT NULL DEFAULT 0,

  -- Refund & balance
  refund_total          numeric(12,2) NOT NULL DEFAULT 0,
  outstanding           numeric(12,2) NOT NULL DEFAULT 0,

  -- Tax invoice
  tax_invoice_requested boolean NOT NULL DEFAULT false,
  tax_invoice_name      text,
  tax_id                text,

  -- Guest identity (for TM.30 / รร3 prep)
  nationality           text,
  passport_number       text,
  id_card_number        text,
  guest_count           smallint NOT NULL DEFAULT 1,

  -- Metadata
  raw_snapshot_json     jsonb,
  created_at            timestamptz NOT NULL DEFAULT now(),

  UNIQUE(period_id, reservation_id)
);

COMMENT ON TABLE public.monthly_audit_entries
  IS 'Frozen snapshot of each checked-out reservation for monthly audit';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_mae_period ON public.monthly_audit_entries(period_id);
CREATE INDEX IF NOT EXISTS idx_mae_reservation ON public.monthly_audit_entries(reservation_id);
CREATE INDEX IF NOT EXISTS idx_mae_source ON public.monthly_audit_entries(period_id, source);
CREATE INDEX IF NOT EXISTS idx_mae_checkout ON public.monthly_audit_entries(period_id, checkout_date);

-- RLS
ALTER TABLE public.monthly_audit_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY mae_select ON public.monthly_audit_entries
  FOR SELECT TO authenticated USING (true);

CREATE POLICY mae_insert ON public.monthly_audit_entries
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));

-- No direct UPDATE — corrections go through monthly_audit_corrections table

-- ============================================================
-- 4. monthly_audit_corrections — tracked edits by FO/Accountant
-- ============================================================
CREATE TABLE IF NOT EXISTS public.monthly_audit_corrections (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id        uuid NOT NULL REFERENCES public.monthly_audit_entries(id) ON DELETE CASCADE,
  field_name      text NOT NULL,
  old_value       text,
  new_value       text,
  reason          text,
  corrected_by    uuid,
  corrected_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.monthly_audit_corrections
  IS 'Tracked corrections to monthly audit entries. Each row = one field change.';

CREATE INDEX IF NOT EXISTS idx_mac_entry ON public.monthly_audit_corrections(entry_id);
CREATE INDEX IF NOT EXISTS idx_mac_corrected_at ON public.monthly_audit_corrections(corrected_at);

-- RLS
ALTER TABLE public.monthly_audit_corrections ENABLE ROW LEVEL SECURITY;

CREATE POLICY mac_select ON public.monthly_audit_corrections
  FOR SELECT TO authenticated USING (true);

CREATE POLICY mac_insert ON public.monthly_audit_corrections
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));

-- ============================================================
-- 5. Index on reservations for monthly audit scope query
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_reservations_checkout_status
  ON public.reservations(checkout_date, status)
  WHERE status = 'checked_out';

CREATE INDEX IF NOT EXISTS idx_reservations_tax_invoice
  ON public.reservations(tax_invoice_requested)
  WHERE tax_invoice_requested = true;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603210003_phase42_admin_corrections.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 42: Admin Corrections — Compensating Entry approach
-- Adds correction tracking to folio_payments + admin_corrections audit table
-- Design: NO soft-delete void — instead insert reversal rows (compensating entries)
-- This means ALL existing queries continue to work without modification

-- ─── 1. Correction columns on folio_payments ────────────────────────

-- Void tracking: reversal row points back to original
ALTER TABLE folio_payments
  ADD COLUMN IF NOT EXISTS is_void_reversal BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE folio_payments
  ADD COLUMN IF NOT EXISTS void_of UUID REFERENCES folio_payments(id);

-- Adjustment tracking: correction row points back to what it corrects
ALTER TABLE folio_payments
  ADD COLUMN IF NOT EXISTS is_correction BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE folio_payments
  ADD COLUMN IF NOT EXISTS correction_ref UUID REFERENCES folio_payments(id);
ALTER TABLE folio_payments
  ADD COLUMN IF NOT EXISTS correction_reason TEXT;

-- Index for finding void/correction chains
CREATE INDEX IF NOT EXISTS idx_folio_payments_void_of
  ON folio_payments(void_of) WHERE void_of IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_folio_payments_correction_ref
  ON folio_payments(correction_ref) WHERE correction_ref IS NOT NULL;

-- ─── 2. Folio reopen flag on reservations ───────────────────────────

ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS folio_reopened BOOLEAN NOT NULL DEFAULT false;

-- ─── 3. Admin corrections audit table ───────────────────────────────

CREATE TABLE IF NOT EXISTS admin_corrections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES reservations(id),
  action TEXT NOT NULL CHECK (action IN (
    'void', 'adjustment', 'reinstate',
    'reopen_folio', 'close_folio', 'transfer_payment'
  )),
  actor_user_id UUID NOT NULL REFERENCES profiles(user_id),
  before_snapshot JSONB NOT NULL DEFAULT '{}',
  after_snapshot JSONB NOT NULL DEFAULT '{}',
  reason TEXT NOT NULL,
  related_payment_ids UUID[] DEFAULT '{}',
  business_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_corrections_reservation
  ON admin_corrections(reservation_id);
CREATE INDEX IF NOT EXISTS idx_admin_corrections_created
  ON admin_corrections(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_corrections_action
  ON admin_corrections(action);

-- RLS
ALTER TABLE admin_corrections ENABLE ROW LEVEL SECURITY;
CREATE POLICY admin_corrections_service ON admin_corrections
  FOR ALL USING (true) WITH CHECK (true);

-- ─── 4. Guard: prevent double-void ──────────────────────────────────
-- A payment that already has a void reversal cannot be voided again
-- Enforced at application layer, but this partial unique index is a safety net
CREATE UNIQUE INDEX IF NOT EXISTS idx_folio_payments_void_of_unique
  ON folio_payments(void_of) WHERE void_of IS NOT NULL;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603280001_phase46_tax_invoice.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 46: Tax Invoice Foundation
-- Adds tax invoice schema inside PMS and invoice number generator.

-- 1) Seller profile columns on hotel_settings (snapshot source at issue time)
ALTER TABLE public.hotel_settings
  ADD COLUMN IF NOT EXISTS company_name text,
  ADD COLUMN IF NOT EXISTS company_name_en text,
  ADD COLUMN IF NOT EXISTS company_tax_id text,
  ADD COLUMN IF NOT EXISTS company_address text,
  ADD COLUMN IF NOT EXISTS company_address_en text,
  ADD COLUMN IF NOT EXISTS company_branch text,
  ADD COLUMN IF NOT EXISTS company_phone text;

-- Seed defaults for OpenHotel (safe: only fill empty fields)
UPDATE public.hotel_settings
SET
  company_name = COALESCE(NULLIF(company_name, ''), 'บริษัท ตัวอย่าง จำกัด'),
  company_name_en = COALESCE(NULLIF(company_name_en, ''), 'Example Co., Ltd.'),
  company_tax_id = COALESCE(NULLIF(company_tax_id, ''), '0000000000000'),
  company_address = COALESCE(NULLIF(company_address, ''), '000/00 ถนนตัวอย่าง13 ต.ตัวอย่าง อ.เมือง จ.ตัวอย่าง 00000'),
  company_address_en = COALESCE(NULLIF(company_address_en, ''), '000/00 Example 13 Road, Example, Mueang, Example Province 00000'),
  company_branch = COALESCE(NULLIF(company_branch, ''), 'สำนักงานใหญ่'),
  company_phone = COALESCE(NULLIF(company_phone, ''), '000-000-0000')
WHERE id = 1;

-- 2) Guest tax profiles
CREATE TABLE IF NOT EXISTS public.guest_tax_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guest_profile_id uuid REFERENCES public.guest_profiles(id),
  tax_id text NOT NULL,
  company_name text NOT NULL,
  address text,
  branch text NOT NULL DEFAULT 'สำนักงานใหญ่',
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  is_passport boolean NOT NULL DEFAULT false,
  CONSTRAINT guest_tax_profiles_tax_id_check CHECK (
    (is_passport = true AND length(tax_id) >= 1)
    OR (is_passport = false AND tax_id ~ '^[0-9]{13}$')
  )
);

CREATE INDEX IF NOT EXISTS idx_guest_tax_profiles_guest
  ON public.guest_tax_profiles(guest_profile_id);
CREATE INDEX IF NOT EXISTS idx_guest_tax_profiles_tax_id
  ON public.guest_tax_profiles(tax_id);
CREATE INDEX IF NOT EXISTS idx_guest_tax_profiles_company_name
  ON public.guest_tax_profiles(company_name);

-- 3) Invoices
CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no text,
  reservation_id uuid NOT NULL REFERENCES public.reservations(id),
  language text NOT NULL DEFAULT 'th' CHECK (language IN ('th', 'en')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'issued', 'cancelled')),
  issue_date date NOT NULL DEFAULT (timezone('Asia/Bangkok', now()))::date,

  -- Customer snapshot (frozen at issue time)
  customer_name text NOT NULL,
  customer_tax_id text,
  customer_address text,
  customer_branch text,
  guest_tax_profile_id uuid REFERENCES public.guest_tax_profiles(id),

  -- Booking snapshot
  booking_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,

  -- Financial (VAT inclusive model)
  line_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  subtotal numeric(12,2) NOT NULL DEFAULT 0,
  vat_rate numeric(5,4) NOT NULL DEFAULT 0.07,
  vat_amount numeric(12,2) NOT NULL DEFAULT 0,
  grand_total numeric(12,2) NOT NULL DEFAULT 0,
  discount numeric(12,2) NOT NULL DEFAULT 0,

  -- Seller snapshot
  seller_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,

  -- Audit
  issued_by text,
  cancelled_at timestamptz,
  cancelled_by text,
  cancel_reason text,
  updated_by text,
  update_reason text,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  is_passport boolean NOT NULL DEFAULT false,
  CONSTRAINT invoices_customer_tax_id_check CHECK (
    customer_tax_id IS NULL
    OR (is_passport = true AND length(customer_tax_id) >= 1)
    OR (is_passport = false AND customer_tax_id ~ '^[0-9]{13}$')
  )
);

-- Invoice number unique only when assigned (draft has NULL)
CREATE UNIQUE INDEX IF NOT EXISTS idx_invoices_invoice_no_unique
  ON public.invoices(invoice_no)
  WHERE invoice_no IS NOT NULL;

-- One issued invoice per reservation
CREATE UNIQUE INDEX IF NOT EXISTS idx_invoices_reservation_issued_unique
  ON public.invoices(reservation_id)
  WHERE status = 'issued';

CREATE INDEX IF NOT EXISTS idx_invoices_issue_date
  ON public.invoices(issue_date DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_status
  ON public.invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_customer_name
  ON public.invoices(customer_name);

-- updated_at triggers
DROP TRIGGER IF EXISTS trg_guest_tax_profiles_updated_at ON public.guest_tax_profiles;
CREATE TRIGGER trg_guest_tax_profiles_updated_at
BEFORE UPDATE ON public.guest_tax_profiles
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_invoices_updated_at ON public.invoices;
CREATE TRIGGER trg_invoices_updated_at
BEFORE UPDATE ON public.invoices
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 4) Invoice number generator (IVYY + variable-digit sequence, min 3)
CREATE OR REPLACE FUNCTION public.next_invoice_no(p_yy text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_yy text;
  v_prefix text;
  v_last_seq bigint;
  v_next_seq bigint;
  v_width int;
BEGIN
  v_yy := COALESCE(NULLIF(trim(p_yy), ''), to_char(timezone('Asia/Bangkok', now())::date, 'YY'));
  IF v_yy !~ '^\d{2}$' THEN
    RAISE EXCEPTION 'next_invoice_no(p_yy) expects 2 digits (YY), got: %', p_yy;
  END IF;

  v_prefix := 'IV' || v_yy;

  SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_no FROM 5) AS bigint)), 0)
    INTO v_last_seq
  FROM public.invoices
  WHERE invoice_no LIKE v_prefix || '%'
    AND invoice_no ~ ('^' || v_prefix || '[0-9]+$');

  v_next_seq := v_last_seq + 1;
  v_width := GREATEST(3, LENGTH(v_next_seq::text));

  RETURN v_prefix || LPAD(v_next_seq::text, v_width, '0');
END;
$$;

-- 5) RLS (service-role friendly; route-level auth remains source of truth)
ALTER TABLE public.guest_tax_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS guest_tax_profiles_service ON public.guest_tax_profiles;
CREATE POLICY guest_tax_profiles_service ON public.guest_tax_profiles
  FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS invoices_service ON public.invoices;
CREATE POLICY invoices_service ON public.invoices
  FOR ALL USING (true) WITH CHECK (true);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603280002_phase46_patch_columns.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 46 Patch: Add missing columns for existing installs
-- Adds is_passport to guest_tax_profiles + invoices
-- Adds company_name_en + company_address_en to hotel_settings

-- 1) hotel_settings: English seller columns
ALTER TABLE public.hotel_settings
  ADD COLUMN IF NOT EXISTS company_name_en text,
  ADD COLUMN IF NOT EXISTS company_address_en text;

-- Seed English values (only fill if empty)
UPDATE public.hotel_settings
SET
  company_name_en = COALESCE(NULLIF(company_name_en, ''), 'Example Co., Ltd.'),
  company_address_en = COALESCE(NULLIF(company_address_en, ''), '000/00 Example 13 Road, Example, Mueang, Example Province 00000')
WHERE id = 1;

-- 2) guest_tax_profiles: passport flag
ALTER TABLE public.guest_tax_profiles
  ADD COLUMN IF NOT EXISTS is_passport boolean NOT NULL DEFAULT false;

-- Drop old strict 13-digit constraint if it exists, replace with passport-aware one
ALTER TABLE public.guest_tax_profiles
  DROP CONSTRAINT IF EXISTS guest_tax_profiles_tax_id_digits,
  DROP CONSTRAINT IF EXISTS guest_tax_profiles_tax_id_check;

ALTER TABLE public.guest_tax_profiles
  ADD CONSTRAINT guest_tax_profiles_tax_id_check CHECK (
    (is_passport = true AND length(tax_id) >= 1)
    OR (is_passport = false AND tax_id ~ '^[0-9]{13}$')
  );

-- 3) invoices: passport flag
ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS is_passport boolean NOT NULL DEFAULT false;

-- Drop old strict constraint, replace with passport-aware one
ALTER TABLE public.invoices
  DROP CONSTRAINT IF EXISTS invoices_customer_tax_id_digits,
  DROP CONSTRAINT IF EXISTS invoices_customer_tax_id_check;

ALTER TABLE public.invoices
  ADD CONSTRAINT invoices_customer_tax_id_check CHECK (
    customer_tax_id IS NULL
    OR (is_passport = true AND length(customer_tax_id) >= 1)
    OR (is_passport = false AND customer_tax_id ~ '^[0-9]{13}$')
  );



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603280003_phase47_receipt.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 47: Simple Receipt
-- Lightweight receipt record for audit trail (no VAT breakdown needed)

-- 1) receipts table
CREATE TABLE IF NOT EXISTS public.receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_no text UNIQUE NOT NULL,
  reservation_id uuid NOT NULL REFERENCES public.reservations(id),
  guest_name text NOT NULL,
  room_numbers text[] NOT NULL DEFAULT '{}',
  grand_total numeric(12,2) NOT NULL DEFAULT 0,
  language text NOT NULL DEFAULT 'th' CHECK (language IN ('th', 'en')),
  printed_at timestamptz NOT NULL DEFAULT now(),
  printed_by text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_receipts_reservation
  ON public.receipts(reservation_id);
CREATE INDEX IF NOT EXISTS idx_receipts_printed_at
  ON public.receipts(printed_at DESC);
CREATE INDEX IF NOT EXISTS idx_receipts_guest_name
  ON public.receipts(guest_name);

-- updated_at trigger not needed (receipts are immutable records)

-- 2) Receipt number generator: RCYY + min 3 digits (e.g. RC26001)
CREATE OR REPLACE FUNCTION public.next_receipt_no(p_yy text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_yy text;
  v_prefix text;
  v_last_seq bigint;
  v_next_seq bigint;
  v_width int;
BEGIN
  v_yy := COALESCE(NULLIF(trim(p_yy), ''), to_char(timezone('Asia/Bangkok', now())::date, 'YY'));
  IF v_yy !~ '^\d{2}$' THEN
    RAISE EXCEPTION 'next_receipt_no(p_yy) expects 2 digits (YY), got: %', p_yy;
  END IF;

  v_prefix := 'RC' || v_yy;

  SELECT COALESCE(MAX(CAST(SUBSTRING(receipt_no FROM 5) AS bigint)), 0)
    INTO v_last_seq
  FROM public.receipts
  WHERE receipt_no LIKE v_prefix || '%'
    AND receipt_no ~ ('^' || v_prefix || '[0-9]+$');

  v_next_seq := v_last_seq + 1;
  v_width := GREATEST(3, LENGTH(v_next_seq::text));

  RETURN v_prefix || LPAD(v_next_seq::text, v_width, '0');
END;
$$;

-- 3) RLS
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS receipts_service ON public.receipts;
CREATE POLICY receipts_service ON public.receipts
  FOR ALL USING (true) WITH CHECK (true);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603280010_phase48_mobile_checkin.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 48: Mobile Check-in foundation
-- Lead-locked decisions:
-- - reservation.status adds only 'draft_checkin'
-- - passport_scans.created_by references auth.users(id)
-- - FO photo visibility follows Bangkok business date cutoff

create table if not exists public.passport_scans (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid references public.reservations(id) on delete cascade,
  guest_index int not null default 0,
  image_path text not null,
  ocr_raw jsonb,
  ocr_parsed jsonb,
  match_confidence numeric(5,2),
  matched_reservation_id uuid references public.reservations(id),
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null default (timezone('utc', now()) + interval '30 days'),
  created_by uuid references auth.users(id)
);

create index if not exists idx_passport_scans_reservation
  on public.passport_scans (reservation_id);

create index if not exists idx_passport_scans_matched_reservation
  on public.passport_scans (matched_reservation_id);

create index if not exists idx_passport_scans_expires
  on public.passport_scans (expires_at);

create index if not exists idx_passport_scans_created_at
  on public.passport_scans (created_at desc);

alter table public.passport_scans enable row level security;

drop policy if exists passport_scans_admin_full_access on public.passport_scans;
create policy passport_scans_admin_full_access
  on public.passport_scans
  for all
  to authenticated
  using (public.has_any_role(array['admin']::public.user_role[]))
  with check (public.has_any_role(array['admin']::public.user_role[]));

drop policy if exists passport_scans_fo_read_current_day on public.passport_scans;
create policy passport_scans_fo_read_current_day
  on public.passport_scans
  for select
  to authenticated
  using (
    public.has_any_role(array['frontdesk', 'supervisor']::public.user_role[])
    and (created_at at time zone 'Asia/Bangkok')::date >= (
      select hs.business_date
      from public.hotel_settings hs
      where hs.id = 1
    )
  );

drop policy if exists passport_scans_fo_insert on public.passport_scans;
create policy passport_scans_fo_insert
  on public.passport_scans
  for insert
  to authenticated
  with check (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]));

-- Reservation status enum extension for draft check-in state
alter type public.reservation_status add value if not exists 'draft_checkin';

-- Private storage bucket for passport snapshots (idempotent)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'passport-photos',
  'passport-photos',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603290001_gas_sync_toggle.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Add Google Sheet Sync toggle to hotel_settings
ALTER TABLE public.hotel_settings
  ADD COLUMN IF NOT EXISTS google_sheet_sync_enabled boolean NOT NULL DEFAULT true;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603290002_inventory_display_order.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 54: Inventory display order
-- Add explicit display order for products list rendering and manual reorder.

ALTER TABLE products
ADD COLUMN IF NOT EXISTS display_order integer DEFAULT 0;

-- Seed active products by current alphabetical order when display_order is unset.
WITH ranked AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY name ASC) AS rn
  FROM products
  WHERE is_active = true
)
UPDATE products
SET display_order = ranked.rn
FROM ranked
WHERE products.id = ranked.id
  AND COALESCE(products.display_order, 0) = 0;

-- Keep inactive products at the end.
UPDATE products
SET display_order = 9999
WHERE is_active = false
  AND COALESCE(display_order, 0) = 0;




-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603300001_phase53_passport_cleanup.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 53: Passport photo retention + cleanup telemetry

create extension if not exists pg_cron;
create extension if not exists pg_net;

alter table public.passport_scans
  add column if not exists cleaned_at timestamptz;

alter table public.hotel_settings
  add column if not exists passport_photo_retention_days integer;

update public.hotel_settings
set passport_photo_retention_days = 30
where passport_photo_retention_days is null;

alter table public.hotel_settings
  alter column passport_photo_retention_days set default 30;

alter table public.hotel_settings
  alter column passport_photo_retention_days set not null;

alter table public.hotel_settings
  drop constraint if exists chk_hotel_settings_passport_photo_retention_days;

alter table public.hotel_settings
  add constraint chk_hotel_settings_passport_photo_retention_days
  check (passport_photo_retention_days between 7 and 90);

alter table public.hotel_settings
  add column if not exists passport_cleanup_last_run_at timestamptz,
  add column if not exists passport_cleanup_last_deleted_count integer not null default 0,
  add column if not exists passport_cleanup_last_error text;

create table if not exists public.cleanup_logs (
  id uuid primary key default gen_random_uuid(),
  job_name text not null,
  ran_at timestamptz not null default timezone('utc', now()),
  deleted_count integer not null default 0,
  error_message text,
  duration_ms integer
);

create index if not exists idx_cleanup_logs_job_ran_at
  on public.cleanup_logs (job_name, ran_at desc);

create or replace function public.recalculate_passport_scan_expires_at(new_retention_days integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer := 0;
begin
  if new_retention_days is null or new_retention_days < 1 then
    raise exception 'new_retention_days must be >= 1';
  end if;

  update public.passport_scans
  set expires_at = created_at + make_interval(days => new_retention_days)
  where image_path is not null
    and cleaned_at is null;

  get diagnostics affected = row_count;
  return affected;
end;
$$;

grant execute on function public.recalculate_passport_scan_expires_at(integer) to authenticated;
grant execute on function public.recalculate_passport_scan_expires_at(integer) to service_role;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603310001_phase54_business_date_pos_deposit_hotfix.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Align POS + mobile deposit flows with hotel_settings.business_date
-- so transactions stay on the open business day until Night Audit closes it.

create or replace function public.apply_deposit_snapshot_lines(
  p_reservation_id uuid,
  p_lines jsonb default '[]'::jsonb,
  p_general_note text default null,
  p_cashier_name text default 'FO',
  p_paid_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation public.reservations%rowtype;
  v_lines jsonb := coalesce(p_lines, '[]'::jsonb);
  v_general_note text := nullif(trim(coalesce(p_general_note, '')), '');
  v_cashier_name text := nullif(trim(coalesce(p_cashier_name, '')), '');
  v_now timestamptz := timezone('utc', now());
  v_paid_date date := coalesce(p_paid_date, (v_now at time zone 'Asia/Bangkok')::date);
  v_method public.payment_method_type;
  v_current_amount numeric(10,2);
  v_target_amount numeric(10,2);
  v_diff numeric(10,2);
  v_note text;
  v_total numeric(10,2);
  v_snapshot_note text;
  v_last_paid_at timestamptz;
begin
  if p_reservation_id is null then
    raise exception 'reservation_id is required';
  end if;

  if jsonb_typeof(v_lines) is distinct from 'array' then
    raise exception 'deposit lines must be a JSON array';
  end if;

  select *
  into v_reservation
  from public.reservations
  where id = p_reservation_id
  for update;

  if v_reservation.id is null then
    raise exception 'Reservation not found';
  end if;

  for v_method, v_target_amount, v_note in
    select
      public.normalize_deposit_method_text(item ->> 'method') as method,
      round(coalesce((item ->> 'amount')::numeric, 0), 2) as amount,
      nullif(trim(coalesce(item ->> 'note', '')), '') as note
    from jsonb_array_elements(v_lines) as item
  loop
    if v_target_amount <= 0 then
      raise exception 'deposit line amount must be greater than 0';
    end if;
  end loop;

  for v_method in
    select unnest(enum_range(null::public.payment_method_type))
  loop
    select round(
      coalesce(
        sum(
          case
            when fp.tx_type = 'deposit' then fp.amount
            when fp.tx_type = 'refund' then -fp.amount
            else 0
          end
        ),
        0
      ),
      2
    )
    into v_current_amount
    from public.folio_payments fp
    where fp.reservation_id = p_reservation_id
      and fp.revenue_category = 'deposit'
      and coalesce(fp.is_record_only, false) = false
      and fp.method = v_method;

    select round(
      coalesce(sum((item ->> 'amount')::numeric), 0),
      2
    )
    into v_target_amount
    from jsonb_array_elements(v_lines) item
    where public.normalize_deposit_method_text(item ->> 'method') = v_method;

    select nullif(trim(coalesce(item ->> 'note', '')), '')
    into v_note
    from jsonb_array_elements(v_lines) item
    where public.normalize_deposit_method_text(item ->> 'method') = v_method
    order by (item ->> 'amount')::numeric desc
    limit 1;

    v_current_amount := coalesce(v_current_amount, 0);
    v_target_amount := coalesce(v_target_amount, 0);
    v_diff := round(v_target_amount - v_current_amount, 2);

    if v_diff > 0 then
      insert into public.folio_payments (
        reservation_id,
        tx_type,
        method,
        amount,
        note,
        paid_at,
        paid_date,
        revenue_category,
        cashier_name,
        is_record_only
      )
      values (
        p_reservation_id,
        'deposit',
        v_method,
        v_diff,
        coalesce(v_note, 'Deposit collected'),
        v_now,
        v_paid_date,
        'deposit',
        coalesce(v_cashier_name, 'FO'),
        false
      );
    elsif v_diff < 0 then
      insert into public.folio_payments (
        reservation_id,
        tx_type,
        method,
        amount,
        note,
        paid_at,
        paid_date,
        revenue_category,
        cashier_name,
        is_record_only
      )
      values (
        p_reservation_id,
        'refund',
        v_method,
        abs(v_diff),
        coalesce(v_note, 'Deposit refund'),
        v_now,
        v_paid_date,
        'deposit',
        coalesce(v_cashier_name, 'FO'),
        false
      );
    end if;
  end loop;

  select round(
    coalesce(
      sum(
        case
          when fp.tx_type = 'deposit' then fp.amount
          when fp.tx_type = 'refund' then -fp.amount
          else 0
        end
      ),
      0
    ),
    2
  )
  into v_total
  from public.folio_payments fp
  where fp.reservation_id = p_reservation_id
    and fp.revenue_category = 'deposit'
    and coalesce(fp.is_record_only, false) = false;

  select max(fp.paid_at)
  into v_last_paid_at
  from public.folio_payments fp
  where fp.reservation_id = p_reservation_id
    and fp.revenue_category = 'deposit'
    and fp.tx_type = 'deposit'
    and coalesce(fp.is_record_only, false) = false;

  select case
      when jsonb_array_length(v_lines) = 0 and v_general_note is null then null
      else jsonb_strip_nulls(
        jsonb_build_object(
          'lines',
          coalesce(
            (
              select jsonb_agg(
                jsonb_strip_nulls(
                  jsonb_build_object(
                    'method', public.normalize_deposit_method_text(item ->> 'method'),
                    'amount', round((item ->> 'amount')::numeric, 2),
                    'note', nullif(trim(coalesce(item ->> 'note', '')), '')
                  )
                )
              )
              from jsonb_array_elements(v_lines) item
            ),
            '[]'::jsonb
          ),
          'note',
          v_general_note
        )
      )::text
    end
  into v_snapshot_note;

  update public.reservations
  set deposit_amount = coalesce(v_total, 0),
      deposit_paid_at = case when coalesce(v_total, 0) > 0 then coalesce(v_last_paid_at, v_now) else null end,
      deposit_note = v_snapshot_note,
      updated_at = v_now
  where id = p_reservation_id;

  return jsonb_build_object(
    'success', true,
    'reservation_id', p_reservation_id,
    'deposit_amount', coalesce(v_total, 0),
    'deposit_paid_at', case when coalesce(v_total, 0) > 0 then coalesce(v_last_paid_at, v_now) else null end,
    'deposit_note', v_snapshot_note
  );
end;
$$;

create or replace function public.pos_create_order_v2(
  p_order_type text,
  p_items jsonb,
  p_payment_method text default null,
  p_reservation_id uuid default null,
  p_created_by text default null,
  p_note text default null,
  p_deposit_amount numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_type text := coalesce(trim(p_order_type), '');
  v_payment_method text := nullif(trim(coalesce(p_payment_method, '')), '');
  v_created_by text := nullif(trim(coalesce(p_created_by, '')), '');
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_now timestamptz := timezone('utc', now());
  v_calendar_date date := (v_now at time zone 'Asia/Bangkok')::date;
  v_order_id uuid;
  v_order_number text;
  v_guest_name text;
  v_room_number text;
  v_subtotal numeric(10,2) := 0;
  v_total numeric(10,2) := 0;
  v_item jsonb;
  v_product record;
  v_product_id uuid;
  v_qty int;
  v_line_total numeric(10,2);
  v_main_current int;
  v_deduct int;
  v_oversell int;
  v_order_date date := v_calendar_date;
  v_held numeric(10,2) := 0;
  v_deposit_amount numeric(10,2) := greatest(coalesce(p_deposit_amount, 0), 0);
  v_deposit_apply numeric(10,2) := 0;
  v_remaining numeric(10,2) := 0;
begin
  select coalesce(business_date, v_calendar_date)
  into v_order_date
  from public.hotel_settings
  where id = 1;

  v_order_date := coalesce(v_order_date, v_calendar_date);

  if v_order_type not in ('walkin', 'guest_charge') then
    raise exception 'invalid p_order_type: %', p_order_type;
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'p_items must be non-empty array';
  end if;

  if v_order_type = 'walkin' then
    if v_payment_method not in ('cash', 'transfer', 'credit_card') then
      raise exception 'walkin payment method must be cash|transfer|credit_card';
    end if;
    v_deposit_amount := 0;
  else
    if p_reservation_id is null then
      raise exception 'p_reservation_id is required for guest_charge';
    end if;

    select
      r.guest_name,
      rm.room_number
    into
      v_guest_name,
      v_room_number
    from public.reservations r
    left join lateral (
      select rooms.room_number
      from public.reservation_nights rn
      join public.rooms on rooms.id = rn.room_id
      where rn.reservation_id = r.id
        and rn.stay_date = v_order_date
        and rn.cancelled_at is null
      order by rooms.room_number
      limit 1
    ) rm on true
    where r.id = p_reservation_id
      and r.status = 'active'
    for update of r;

    if v_guest_name is null then
      raise exception 'reservation is not eligible for room deposit settlement';
    end if;

    if v_room_number is null then
      raise exception 'reservation has no active room night today';
    end if;

    select coalesce(
      sum(
        case
          when fp.tx_type = 'deposit' then fp.amount
          when fp.tx_type = 'refund'
            and (
              coalesce(fp.revenue_category, '') = 'deposit'
              or lower(coalesce(fp.note, '')) like '%deposit refund%'
              or lower(coalesce(fp.note, '')) like '%paid by deposit%'
            )
          then -fp.amount
          else 0
        end
      ),
      0
    )
    into v_held
    from public.folio_payments fp
    where fp.reservation_id = p_reservation_id;

    v_held := round(v_held::numeric, 2);
    v_deposit_apply := round(least(v_deposit_amount, v_held)::numeric, 2);
    v_remaining := round(greatest(v_total - v_deposit_apply, 0)::numeric, 2);
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_product_id := (v_item ->> 'product_id')::uuid;
    exception when others then
      v_product_id := null;
    end;

    v_qty := greatest(coalesce((v_item ->> 'quantity')::int, 0), 0);
    if v_product_id is null or v_qty <= 0 then
      raise exception 'invalid item payload, each row must include product_id + quantity > 0';
    end if;

    select p.id, p.name, p.category, p.sale_price, p.is_active
    into v_product
    from public.products p
    where p.id = v_product_id
    limit 1;

    if not found then
      raise exception 'product not found: %', v_product_id;
    end if;

    if not coalesce(v_product.is_active, false) then
      raise exception 'product inactive: %', v_product.name;
    end if;

    if v_product.category not in ('pos', 'both') then
      raise exception 'product is not POS sale item: %', v_product.name;
    end if;

    if v_product.sale_price is null then
      raise exception 'product sale_price is required for POS item: %', v_product.name;
    end if;

    v_line_total := round((v_product.sale_price * v_qty)::numeric, 2);
    v_subtotal := round((v_subtotal + v_line_total)::numeric, 2);
  end loop;

  v_total := v_subtotal;

  if v_order_type = 'guest_charge' then
    v_deposit_apply := round(least(v_deposit_amount, v_held, v_total)::numeric, 2);
    v_remaining := round(greatest(v_total - v_deposit_apply, 0)::numeric, 2);

    if v_deposit_apply <= 0 then
      raise exception 'deposit held is required for room settlement';
    end if;

    if v_remaining > 0 and v_payment_method not in ('cash', 'transfer', 'credit_card') then
      raise exception 'remaining payment method must be cash|transfer|credit_card';
    end if;

    if v_remaining = 0 then
      v_payment_method := null;
    end if;
  end if;

  insert into public.pos_orders (
    order_number,
    order_type,
    reservation_id,
    guest_name,
    status,
    subtotal,
    total,
    payment_method,
    note,
    created_by,
    order_date,
    created_at,
    updated_at
  )
  values (
    public.generate_pos_order_number(),
    v_order_type,
    case when v_order_type = 'guest_charge' then p_reservation_id else null end,
    case when v_order_type = 'guest_charge' then v_guest_name else null end,
    'completed',
    v_subtotal,
    v_total,
    case when v_order_type = 'walkin' then v_payment_method else null end,
    v_note,
    v_created_by,
    v_order_date,
    v_now,
    v_now
  )
  returning id, order_number into v_order_id, v_order_number;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_qty := greatest(coalesce((v_item ->> 'quantity')::int, 0), 0);

    select p.id, p.name, p.category, p.sale_price, p.is_active
    into v_product
    from public.products p
    where p.id = v_product_id
    limit 1;

    v_line_total := round((v_product.sale_price * v_qty)::numeric, 2);

    insert into public.pos_order_items (
      order_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      line_total,
      created_at
    )
    values (
      v_order_id,
      v_product_id,
      v_product.name,
      v_qty,
      v_product.sale_price,
      v_line_total,
      v_now
    );

    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    select quantity
    into v_main_current
    from public.main_stock
    where product_id = v_product_id
    for update;

    v_deduct := least(v_main_current, v_qty);
    v_oversell := greatest(v_qty - v_main_current, 0);

    update public.main_stock
    set quantity = greatest(v_main_current - v_qty, 0),
        updated_at = v_now
    where product_id = v_product_id;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      performed_by,
      note,
      created_at
    )
    values (
      v_order_date,
      v_product_id,
      'sale',
      -v_deduct,
      'main',
      null,
      'pos_order',
      v_order_id,
      v_created_by,
      case
        when v_oversell > 0 then format('oversell warning: sold %s, deducted %s, missing %s', v_qty, v_deduct, v_oversell)
        else format('sold %s', v_qty)
      end,
      v_now
    );
  end loop;

  if v_order_type = 'walkin' then
    return jsonb_build_object(
      'order_id', v_order_id,
      'order_number', v_order_number,
      'subtotal', v_subtotal,
      'total', v_total,
      'deposit_used_amount', 0,
      'remaining_paid_amount', v_total,
      'payment_method', v_payment_method
    );
  end if;

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    paid_at,
    paid_date,
    revenue_category,
    cashier_name,
    pos_order_id
  )
  values (
    p_reservation_id,
    'refund',
    'cash',
    v_deposit_apply,
    format('Paid by Deposit for POS order %s (%s)', v_order_number, coalesce(v_room_number, 'no room')),
    v_now,
    v_order_date,
    'deposit',
    coalesce(v_created_by, 'FO'),
    v_order_id
  );

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    paid_at,
    paid_date,
    revenue_category,
    cashier_name,
    pos_order_id,
    is_record_only
  )
  values (
    p_reservation_id,
    'payment',
    'cash',
    v_deposit_apply,
    format('Paid by Deposit from room %s for POS order %s', coalesce(v_room_number, 'N/A'), v_order_number),
    v_now,
    v_order_date,
    'pos_revenue',
    coalesce(v_created_by, 'FO'),
    v_order_id,
    true
  );

  if v_remaining > 0 then
    insert into public.folio_payments (
      reservation_id,
      tx_type,
      method,
      amount,
      note,
      paid_at,
      paid_date,
      revenue_category,
      cashier_name,
      pos_order_id,
      is_record_only
    )
    values (
      p_reservation_id,
      'payment',
      v_payment_method::public.payment_method_type,
      v_remaining,
      format('POS remainder for room %s on order %s', coalesce(v_room_number, 'N/A'), v_order_number),
      v_now,
      v_order_date,
      'pos_revenue',
      coalesce(v_created_by, 'FO'),
      v_order_id,
      true
    );
  end if;

  update public.reservations
  set deposit_amount = greatest(
        0,
        coalesce((
          select round(sum(
            case
              when fp.tx_type = 'deposit' then fp.amount
              when fp.tx_type = 'refund'
                and (
                  coalesce(fp.revenue_category, '') = 'deposit'
                  or lower(coalesce(fp.note, '')) like '%deposit refund%'
                  or lower(coalesce(fp.note, '')) like '%paid by deposit%'
                )
              then -fp.amount
              else 0
            end
          )::numeric, 2)
          from public.folio_payments fp
          where fp.reservation_id = p_reservation_id
        ), 0)
      )
  where id = p_reservation_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'subtotal', v_subtotal,
    'total', v_total,
    'deposit_used_amount', v_deposit_apply,
    'remaining_paid_amount', v_remaining,
    'payment_method', case when v_remaining > 0 then v_payment_method else null end,
    'room_number', v_room_number
  );
end;
$$;

create or replace function public.pos_void_order_v2(
  p_order_id uuid,
  p_note text default null,
  p_voided_by text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.pos_orders%rowtype;
  v_item record;
  v_now timestamptz := timezone('utc', now());
  v_calendar_date date := (v_now at time zone 'Asia/Bangkok')::date;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_voided_by text := nullif(trim(coalesce(p_voided_by, '')), '');
  v_order_date date := v_calendar_date;
  v_room_number text;
  v_record record;
begin
  select coalesce(business_date, v_calendar_date)
  into v_order_date
  from public.hotel_settings
  where id = 1;

  v_order_date := coalesce(v_order_date, v_calendar_date);

  if p_order_id is null then
    raise exception 'p_order_id is required';
  end if;

  select *
  into v_order
  from public.pos_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.status = 'voided' then
    raise exception 'order already voided';
  end if;

  if v_order.status <> 'completed' then
    raise exception 'only completed order can be voided';
  end if;

  if v_order.reservation_id is not null then
    perform 1
    from public.reservations
    where id = v_order.reservation_id
      and status = 'active'
    for update;

    if not found then
      raise exception 'Cannot return to deposit: reservation already checked out. Use manual adjustment.';
    end if;

    select rooms.room_number
    into v_room_number
    from public.reservation_nights rn
    join public.rooms on rooms.id = rn.room_id
    where rn.reservation_id = v_order.reservation_id
      and rn.stay_date = v_order_date
      and rn.cancelled_at is null
    order by rooms.room_number
    limit 1;
  end if;

  update public.pos_orders
  set status = 'voided',
      note = coalesce(v_order.note, '') || case when v_note is null then '' else ('\nVOID: ' || v_note) end,
      updated_at = v_now
  where id = p_order_id;

  for v_item in
    select poi.product_id, poi.quantity
    from public.pos_order_items poi
    where poi.order_id = p_order_id
  loop
    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_item.product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    update public.main_stock
    set quantity = quantity + v_item.quantity,
        updated_at = v_now
    where product_id = v_item.product_id;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      performed_by,
      note,
      created_at
    )
    values (
      v_order_date,
      v_item.product_id,
      'return',
      v_item.quantity,
      null,
      'main',
      'pos_order',
      p_order_id,
      v_voided_by,
      coalesce(v_note, 'pos order void return'),
      v_now
    );
  end loop;

  if v_order.order_type = 'guest_charge' and v_order.reservation_id is not null then
    if exists (
      select 1
      from public.reservations r
      where r.id = v_order.reservation_id
        and r.status = 'checked_out'
    ) then
      raise exception 'Cannot return to deposit: reservation already checked out. Use manual adjustment.';
    end if;

    for v_record in
      select
        id,
        tx_type,
        method,
        amount,
        note,
        revenue_category,
        is_record_only
      from public.folio_payments
      where pos_order_id = p_order_id
      order by paid_at asc, created_at asc, id asc
    loop
      if v_record.tx_type = 'refund' and coalesce(v_record.revenue_category, '') = 'deposit' then
        insert into public.folio_payments (
          reservation_id,
          tx_type,
          method,
          amount,
          note,
          paid_at,
          paid_date,
          revenue_category,
          cashier_name,
          pos_order_id
        )
        values (
          v_order.reservation_id,
          'deposit',
          'cash',
          v_record.amount,
          coalesce(v_note, format('Void return to deposit for POS order %s', v_order.order_number)),
          v_now,
          v_order_date,
          'deposit',
          coalesce(v_voided_by, 'FO'),
          p_order_id
        );
      elsif coalesce(v_record.is_record_only, false) then
        insert into public.folio_payments (
          reservation_id,
          tx_type,
          method,
          amount,
          note,
          paid_at,
          paid_date,
          revenue_category,
          cashier_name,
          pos_order_id,
          is_record_only
        )
        values (
          v_order.reservation_id,
          'refund',
          coalesce(v_record.method::text, 'cash')::public.payment_method_type,
          v_record.amount,
          coalesce(v_note, format('Void return to deposit for POS order %s', v_order.order_number)),
          v_now,
          v_order_date,
          coalesce(v_record.revenue_category, 'pos_revenue'),
          coalesce(v_voided_by, 'FO'),
          p_order_id,
          true
        );
      end if;
    end loop;

    update public.reservations
    set deposit_amount = greatest(
          0,
          coalesce((
            select round(sum(
              case
                when fp.tx_type = 'deposit' then fp.amount
                when fp.tx_type = 'refund'
                  and (
                    coalesce(fp.revenue_category, '') = 'deposit'
                    or lower(coalesce(fp.note, '')) like '%deposit refund%'
                    or lower(coalesce(fp.note, '')) like '%paid by deposit%'
                  )
                then -fp.amount
                else 0
              end
            )::numeric, 2)
            from public.folio_payments fp
            where fp.reservation_id = v_order.reservation_id
          ), 0)
        )
    where id = v_order.reservation_id;
  end if;

  return jsonb_build_object(
    'order_id', p_order_id,
    'order_number', v_order.order_number,
    'status', 'voided'
  );
end;
$$;

grant execute on function public.apply_deposit_snapshot_lines(uuid, jsonb, text, text, date) to authenticated, service_role;
grant execute on function public.pos_create_order_v2(text, jsonb, text, uuid, text, text, numeric) to anon, authenticated;
grant execute on function public.pos_void_order_v2(uuid, text, text) to anon, authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202603310002_phase54_deposit_wrapper.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create or replace function public.apply_deposit_snapshot_lines_v2(
  p_reservation_id uuid,
  p_lines jsonb default '[]'::jsonb,
  p_general_note text default null,
  p_cashier_name text default 'FO',
  p_paid_date date default null
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.apply_deposit_snapshot_lines(
    p_reservation_id,
    p_lines,
    p_general_note,
    p_cashier_name,
    p_paid_date
  );
$$;

grant execute on function public.apply_deposit_snapshot_lines_v2(uuid, jsonb, text, text, date) to authenticated, service_role;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604010001_phase55_scb_transfer_core.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 55: SCB Mae Manee transfer automation core
-- Sandbox-first rollout

create table if not exists public.scb_payment_requests (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('reservation', 'pos_order')),
  target_id uuid not null,
  channel text not null check (channel in ('booking_folio', 'mobile_checkin', 'pos')),
  mode text not null check (mode in ('outstanding', 'custom')),
  currency text not null default 'THB',
  request_amount_total numeric(12,2) not null check (request_amount_total > 0),
  room_amount numeric(12,2) not null default 0 check (room_amount >= 0),
  deposit_amount numeric(12,2) not null default 0 check (deposit_amount >= 0),
  status text not null check (status in ('pending', 'paid', 'expired', 'cancelled', 'failed', 'unmatched')),
  partner_reference_no text not null unique,
  scb_order_id text null,
  wallet_id text null,
  scb_ref_1 text null,
  scb_ref_2 text null,
  scb_ref_3 text null,
  qr_payload text null,
  qr_image_base64 text null,
  request_payload jsonb not null default '{}'::jsonb,
  provider_raw_response jsonb null,
  error_message text null,
  expires_at timestamptz not null,
  auto_inquiry_after_expiry_at timestamptz not null,
  paid_transaction_id uuid null,
  created_by uuid null references public.profiles(user_id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists uq_scb_payment_requests_active_pending_target
  on public.scb_payment_requests (target_type, target_id)
  where status = 'pending';

create index if not exists idx_scb_payment_requests_status_created
  on public.scb_payment_requests (status, created_at desc);

create index if not exists idx_scb_payment_requests_expires_at
  on public.scb_payment_requests (expires_at);

create table if not exists public.scb_payment_transactions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid null references public.scb_payment_requests(id) on delete set null,
  transaction_id text not null unique,
  order_id text null,
  partner_reference_no text null,
  amount numeric(12,2) not null default 0,
  currency text not null default 'THB',
  payer_name text null,
  payer_account text null,
  payment_channel text null,
  paid_at timestamptz null,
  status text not null check (status in ('pending', 'success', 'failed', 'expired')),
  match_status text not null check (match_status in ('matched', 'unmatched', 'ignored', 'duplicate', 'matching')),
  raw_payload jsonb not null default '{}'::jsonb,
  processed_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_scb_payment_transactions_request_id
  on public.scb_payment_transactions (request_id);

create index if not exists idx_scb_payment_transactions_match_status_created
  on public.scb_payment_transactions (match_status, created_at desc);

create table if not exists public.scb_recheck_logs (
  id uuid primary key default gen_random_uuid(),
  request_id uuid null references public.scb_payment_requests(id) on delete set null,
  transaction_id text null,
  triggered_by uuid null references public.profiles(user_id),
  source text not null check (source in ('callback_retry', 'manual', 'scheduled')),
  result_status text not null,
  raw_payload jsonb null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_scb_recheck_logs_request_id_created
  on public.scb_recheck_logs (request_id, created_at desc);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604010002_phase55_scb_notifications.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 55: SCB payment notifications

create table if not exists public.scb_payment_notifications (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid null references public.scb_payment_transactions(id) on delete set null,
  target_type text not null check (target_type in ('reservation', 'pos_order')),
  target_id uuid not null,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.scb_notification_reads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  notification_id uuid not null references public.scb_payment_notifications(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists uq_scb_notification_reads_user_notification
  on public.scb_notification_reads (user_id, notification_id);

create index if not exists idx_scb_payment_notifications_is_read_created
  on public.scb_payment_notifications (is_read, created_at desc);

create index if not exists idx_scb_payment_notifications_target
  on public.scb_payment_notifications (target_type, target_id, created_at desc);

create index if not exists idx_scb_notification_reads_user_created
  on public.scb_notification_reads (user_id, created_at desc);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604020001_phase56_guest_profile_conflict_events.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create table if not exists public.guest_profile_conflict_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null default (timezone('utc', now()) + interval '7 days'),
  actor_user_id uuid references public.profiles (user_id),
  reservation_id uuid references public.reservations (id) on delete set null,
  attempted_profile_id uuid references public.guest_profiles (id) on delete set null,
  resolved_profile_id uuid not null references public.guest_profiles (id) on delete cascade,
  source_flow text not null,
  document_type text,
  document_masked text,
  business_date date not null default ((timezone('Asia/Bangkok', now()))::date),
  retry_count integer not null default 1,
  terminal_id text,
  user_agent text,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists idx_guest_profile_conflict_events_created_at
  on public.guest_profile_conflict_events (created_at desc);

create index if not exists idx_guest_profile_conflict_events_expires_at
  on public.guest_profile_conflict_events (expires_at);

create index if not exists idx_guest_profile_conflict_events_source_flow
  on public.guest_profile_conflict_events (source_flow, created_at desc);

create index if not exists idx_guest_profile_conflict_events_reservation
  on public.guest_profile_conflict_events (reservation_id, created_at desc);

alter table public.guest_profile_conflict_events enable row level security;

drop policy if exists guest_profile_conflict_events_service_read on public.guest_profile_conflict_events;
create policy guest_profile_conflict_events_service_read
  on public.guest_profile_conflict_events
  for select
  to authenticated
  using (public.has_any_role(array['admin'::public.user_role, 'supervisor'::public.user_role]));

create or replace function public.cleanup_guest_profile_conflict_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count integer := 0;
begin
  delete from public.guest_profile_conflict_events
  where expires_at < timezone('utc', now());

  get diagnostics deleted_count = row_count;

  insert into public.cleanup_logs (job_name, deleted_count)
  values ('guest_profile_conflict_events', deleted_count);

  return deleted_count;
end;
$$;

grant execute on function public.cleanup_guest_profile_conflict_events() to service_role;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604020002_phase56_guest_profile_conflict_events_hardening.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.guest_profile_conflict_events
  alter column resolved_profile_id drop not null;

alter table public.guest_profile_conflict_events
  drop constraint if exists guest_profile_conflict_events_resolved_profile_id_fkey;

alter table public.guest_profile_conflict_events
  add constraint guest_profile_conflict_events_resolved_profile_id_fkey
  foreign key (resolved_profile_id)
  references public.guest_profiles (id)
  on delete set null;

create index if not exists idx_guest_profile_conflict_events_business_date
  on public.guest_profile_conflict_events (business_date desc);

drop policy if exists guest_profile_conflict_events_no_client_insert on public.guest_profile_conflict_events;
create policy guest_profile_conflict_events_no_client_insert
  on public.guest_profile_conflict_events
  for insert
  to authenticated
  with check (false);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604020003_phase57_guest_merge_preserve_legacy_counters.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 57: Preserve legacy counters when merging guest profiles
-- Root cause:
--   merge_guest_profiles() recalculated stay_count from reservations only.
--   Legacy-imported guest profiles may have stay_count / legacy_night_count / legacy_stays
--   without PMS reservation rows, so merge wiped their historical totals.

create or replace function public.merge_guest_profiles(
  p_master_id uuid,
  p_source_id uuid,
  p_reason text default 'manual_merge'
) returns jsonb
language plpgsql
as $$
declare
  v_master public.guest_profiles%rowtype;
  v_source public.guest_profiles%rowtype;

  v_has_transfers_guest_profile boolean;
  v_has_transfer_tx_guest_profile boolean;
  v_has_commission_guest_profile boolean;
  v_has_tip_guest_profile boolean;
  v_has_reservation_guests boolean;
  v_has_legacy_stays boolean;
begin
  select * into v_master
  from public.guest_profiles
  where id = p_master_id
  for update;

  select * into v_source
  from public.guest_profiles
  where id = p_source_id
  for update;

  if v_master.id is null then
    raise exception 'Master profile not found';
  end if;
  if v_source.id is null then
    raise exception 'Source profile not found';
  end if;
  if p_master_id = p_source_id then
    raise exception 'Cannot merge profile with itself';
  end if;
  if v_master.do_not_merge or v_source.do_not_merge then
    raise exception 'Profile has do_not_merge flag';
  end if;
  if v_source.profile_status = 'merged' then
    raise exception 'Source already merged';
  end if;

  update public.reservations
  set guest_profile_id = p_master_id
  where guest_profile_id = p_source_id;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'transfers'
      and column_name = 'guest_profile_id'
  ) into v_has_transfers_guest_profile;

  if v_has_transfers_guest_profile then
    execute 'update public.transfers set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'transfer_transactions'
      and column_name = 'guest_profile_id'
  ) into v_has_transfer_tx_guest_profile;

  if v_has_transfer_tx_guest_profile then
    execute 'update public.transfer_transactions set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'commission_ledger'
      and column_name = 'guest_profile_id'
  ) into v_has_commission_guest_profile;

  if v_has_commission_guest_profile then
    execute 'update public.commission_ledger set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tip_ledger'
      and column_name = 'guest_profile_id'
  ) into v_has_tip_guest_profile;

  if v_has_tip_guest_profile then
    execute 'update public.tip_ledger set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  select exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'reservation_guests'
  ) into v_has_reservation_guests;

  if v_has_reservation_guests then
    execute $q$
      delete from public.reservation_guests src
      using public.reservation_guests other_row
      where src.guest_profile_id = $1
        and src.reservation_id = other_row.reservation_id
        and other_row.guest_profile_id <> $1
        and (
          other_row.guest_profile_id = $2
          or (
            src.role = 'accompanying'
            and other_row.role = 'accompanying'
            and src.display_order = other_row.display_order
          )
          or (src.role = 'primary' and other_row.role = 'primary')
        )
    $q$ using p_source_id, p_master_id;

    execute 'update public.reservation_guests set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  select exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'legacy_stays'
  ) into v_has_legacy_stays;

  if v_has_legacy_stays then
    execute 'update public.legacy_stays set guest_profile_id = $1 where guest_profile_id = $2'
      using p_master_id, p_source_id;
  end if;

  update public.guest_profiles
  set
    stay_count = coalesce(v_master.stay_count, 0) + coalesce(v_source.stay_count, 0),
    night_count = coalesce(v_master.night_count, 0) + coalesce(v_source.night_count, 0),
    main_stay_count = coalesce(v_master.main_stay_count, 0) + coalesce(v_source.main_stay_count, 0),
    accompanying_stay_count = coalesce(v_master.accompanying_stay_count, 0) + coalesce(v_source.accompanying_stay_count, 0),
    main_night_count = coalesce(v_master.main_night_count, 0) + coalesce(v_source.main_night_count, 0),
    accompanying_night_count = coalesce(v_master.accompanying_night_count, 0) + coalesce(v_source.accompanying_night_count, 0),
    legacy_night_count = coalesce(v_master.legacy_night_count, 0) + coalesce(v_source.legacy_night_count, 0),
    last_stay_date = greatest(v_master.last_stay_date, v_source.last_stay_date),
    updated_at = now()
  where id = p_master_id;

  update public.guest_profiles
  set
    profile_status = 'merged',
    merged_into = p_master_id,
    updated_at = now()
  where id = p_source_id;

  update public.profile_match_scores
  set status = 'merged'
  where (profile_a = p_source_id or profile_b = p_source_id)
    and status = 'pending';

  insert into public.audit_logs (action, entity_type, entity_id, before_json, after_json, change_reason)
  values (
    'profile_merged',
    'guest_profiles',
    p_master_id::text,
    jsonb_build_object(
      'source_id', p_source_id,
      'source_name', concat(v_source.first_name, ' ', v_source.last_name),
      'source_stay_count', coalesce(v_source.stay_count, 0),
      'source_legacy_night_count', coalesce(v_source.legacy_night_count, 0)
    ),
    jsonb_build_object(
      'master_id', p_master_id,
      'master_name', concat(v_master.first_name, ' ', v_master.last_name),
      'master_stay_count_before', coalesce(v_master.stay_count, 0),
      'master_stay_count_after', coalesce(v_master.stay_count, 0) + coalesce(v_source.stay_count, 0),
      'master_legacy_night_count_before', coalesce(v_master.legacy_night_count, 0),
      'master_legacy_night_count_after', coalesce(v_master.legacy_night_count, 0) + coalesce(v_source.legacy_night_count, 0)
    ),
    p_reason
  );

  return jsonb_build_object(
    'success', true,
    'master_id', p_master_id,
    'source_id', p_source_id
  );
end;
$$;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604030001_phase56_tax_invoice_reuse.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS cancelled_invoice_no text;

COMMENT ON COLUMN public.invoices.cancelled_invoice_no IS
  'Stores the previous invoice number for cancelled invoices when the number is released for reuse by the next invoice.';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604030002_phase58_tm30_late_added_exclusions.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

create table if not exists public.tm30_report_exclusions (
  id uuid primary key default gen_random_uuid(),
  report_date date not null,
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  guest_profile_id uuid not null references public.guest_profiles(id) on delete cascade,
  exclusion_type text not null default 'late_added_duplicate',
  created_by uuid null,
  created_at timestamptz not null default now(),
  constraint tm30_report_exclusions_type_check check (exclusion_type in ('late_added_duplicate')),
  constraint tm30_report_exclusions_unique unique (report_date, reservation_id, guest_profile_id, exclusion_type)
);

create index if not exists tm30_report_exclusions_report_date_idx
  on public.tm30_report_exclusions(report_date);

comment on table public.tm30_report_exclusions is
  'Persistent TM.30 exclusions for late-added duplicate guests so users can avoid re-exporting the same guest on the later report date.';

comment on column public.tm30_report_exclusions.report_date is
  'The TM.30 report date whose export should exclude this guest.';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604030003_phase59_guest_booking_name_aliases.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

create table if not exists public.guest_profile_booking_names (
  id uuid primary key default gen_random_uuid(),
  guest_profile_id uuid not null references public.guest_profiles(id) on delete cascade,
  booking_name text not null,
  normalized_booking_name text not null,
  source_reservation_id uuid null references public.reservations(id) on delete set null,
  first_seen_at timestamptz null default now(),
  last_seen_at timestamptz null default now(),
  seen_count integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint guest_profile_booking_names_profile_normalized_unique unique (guest_profile_id, normalized_booking_name)
);

create index if not exists guest_profile_booking_names_normalized_idx
  on public.guest_profile_booking_names (normalized_booking_name);

create index if not exists guest_profile_booking_names_profile_idx
  on public.guest_profile_booking_names (guest_profile_id, last_seen_at desc);

create or replace function public.set_guest_profile_booking_names_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_guest_profile_booking_names_updated_at on public.guest_profile_booking_names;
create trigger trg_guest_profile_booking_names_updated_at
before update on public.guest_profile_booking_names
for each row
execute function public.set_guest_profile_booking_names_updated_at();

insert into public.guest_profile_booking_names (
  guest_profile_id,
  booking_name,
  normalized_booking_name,
  first_seen_at,
  last_seen_at,
  seen_count
)
select
  gp.id,
  trim(regexp_replace(note_line, '^จองมาในชื่อ\\s*', '', 'g')) as booking_name,
  lower(trim(regexp_replace(regexp_replace(note_line, '^จองมาในชื่อ\\s*', '', 'g'), '\\s+', ' ', 'g'))) as normalized_booking_name,
  gp.created_at,
  gp.updated_at,
  1
from public.guest_profiles gp
cross join lateral regexp_split_to_table(coalesce(gp.notes, ''), E'\\r?\\n') as note_line
where trim(note_line) like 'จองมาในชื่อ %'
  and trim(regexp_replace(note_line, '^จองมาในชื่อ\\s*', '', 'g')) <> ''
on conflict (guest_profile_id, normalized_booking_name) do nothing;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604040001_phase60_transport_alert_lead.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

alter table public.hotel_settings
add column if not exists transport_alert_lead_min integer not null default 60;

update public.hotel_settings
set transport_alert_lead_min = coalesce(transport_alert_lead_min, 60)
where id = 1;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604040002_phase61_ui_event_logs.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

create table if not exists public.ui_event_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles (user_id) on delete set null,
  actor_name text,
  actor_role text,
  pathname text not null,
  event_type text not null,
  event_name text not null,
  severity text not null default 'info',
  entity_type text,
  entity_id text,
  request_id text,
  message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ui_event_logs_created_at
  on public.ui_event_logs (created_at desc);

create index if not exists idx_ui_event_logs_type_created
  on public.ui_event_logs (event_type, created_at desc);

create index if not exists idx_ui_event_logs_path_created
  on public.ui_event_logs (pathname, created_at desc);

create index if not exists idx_ui_event_logs_actor_created
  on public.ui_event_logs (actor_user_id, created_at desc);

create index if not exists idx_ui_event_logs_severity_created
  on public.ui_event_logs (severity, created_at desc);

alter table public.ui_event_logs enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'ui_event_logs'
      and policyname = 'ui_event_logs_read_policy'
  ) then
    create policy ui_event_logs_read_policy
      on public.ui_event_logs
      for select
      using (auth.role() = 'authenticated');
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'ui_event_logs'
      and policyname = 'ui_event_logs_insert_policy'
  ) then
    create policy ui_event_logs_insert_policy
      on public.ui_event_logs
      for insert
      with check (auth.role() = 'authenticated');
  end if;
end $$;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604040003_phase62_ui_event_log_capture_emails.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

alter table public.hotel_settings
add column if not exists ui_event_log_capture_emails text not null default 'ops@example.com';

update public.hotel_settings
set ui_event_log_capture_emails = coalesce(nullif(trim(ui_event_log_capture_emails), ''), 'ops@example.com')
where id = 1;

alter table public.ui_event_logs
add column if not exists actor_email text;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604040004_phase56_lost_found.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create table if not exists public.lost_found_items (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id),
  room_number text not null,
  reservation_id uuid null references public.reservations(id) on delete set null,
  guest_profile_id uuid null references public.guest_profiles(id) on delete set null,
  booking_code text null,
  guest_name text null,
  checkin_date date null,
  checkout_date date null,
  description text not null,
  photo_path text null,
  category text not null default 'general',
  status text not null default 'pending',
  found_date date not null default current_date,
  found_by text not null,
  reported_by_user_id uuid null references auth.users(id) on delete set null,
  location_detail text null,
  claim_note text null,
  claimed_at timestamptz null,
  claimed_by text null,
  cleared_at timestamptz null,
  cleared_by text null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint lost_found_items_category_check check (
    category in ('general', 'electronics', 'clothing', 'documents', 'valuables', 'other')
  ),
  constraint lost_found_items_status_check check (
    status in ('pending', 'claimed')
  )
);

create index if not exists idx_lf_guest_profile
  on public.lost_found_items (guest_profile_id)
  where guest_profile_id is not null;

create index if not exists idx_lf_status
  on public.lost_found_items (status);

create index if not exists idx_lf_found_date
  on public.lost_found_items (found_date desc);

create index if not exists idx_lf_room
  on public.lost_found_items (room_id);

create index if not exists idx_lf_cleared_at
  on public.lost_found_items (cleared_at);

drop trigger if exists trg_lost_found_items_updated_at on public.lost_found_items;
create trigger trg_lost_found_items_updated_at
before update on public.lost_found_items
for each row execute function public.set_updated_at();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'lost-found-photos',
  'lost-found-photos',
  false,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604040005_phase56_lost_found_no_room_hotfix.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

alter table public.lost_found_items
  alter column room_id drop not null,
  alter column room_number drop not null;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604050001_phase63_lost_found_photo_limit_5mb.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

update storage.buckets
set file_size_limit = 5242880
where id = 'lost-found-photos';

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604070001_phase64_mobile_user_role.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    where t.typname = 'user_role'
      and e.enumlabel = 'mobile'
  ) then
    alter type public.user_role add value 'mobile';
  end if;
end $$;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604070002_phase64_mobile_passport_scan_policy.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

drop policy if exists passport_scans_fo_read_current_day on public.passport_scans;
create policy passport_scans_fo_read_current_day
  on public.passport_scans
  for select
  to authenticated
  using (
    public.has_any_role(array['frontdesk', 'supervisor', 'mobile']::public.user_role[])
    and (created_at at time zone 'Asia/Bangkok')::date >= (
      select hs.business_date
      from public.hotel_settings hs
      where hs.id = 1
    )
  );

drop policy if exists passport_scans_fo_insert on public.passport_scans;
create policy passport_scans_fo_insert
  on public.passport_scans
  for insert
  to authenticated
  with check (
    public.has_any_role(array['admin', 'frontdesk', 'supervisor', 'mobile']::public.user_role[])
  );

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604070010_phase57_vehicle_registry.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create table if not exists public.guest_vehicles (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null,
  guest_profile_id uuid null references public.guest_profiles(id) on delete set null,
  room_id uuid null references public.rooms(id) on delete set null,
  room_number text null,
  booking_code text null,
  guest_name text null,
  vehicle_type text not null default 'car',
  plate_number text null,
  plate_province text null,
  plate_country text not null default 'TH',
  vehicle_brand text null,
  vehicle_model text null,
  vehicle_color text not null default 'white',
  description text null,
  registered_at timestamptz not null default timezone('utc', now()),
  registered_by text null,
  checked_out_at timestamptz null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_guest_vehicles_vehicle_type'
  ) then
    alter table public.guest_vehicles
      add constraint chk_guest_vehicles_vehicle_type
      check (vehicle_type in ('car', 'motorcycle', 'bicycle'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_guest_vehicles_plate_country'
  ) then
    alter table public.guest_vehicles
      add constraint chk_guest_vehicles_plate_country
      check (plate_country in ('TH', 'MY'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_guest_vehicles_vehicle_color'
  ) then
    alter table public.guest_vehicles
      add constraint chk_guest_vehicles_vehicle_color
      check (vehicle_color in ('white', 'black', 'silver', 'red', 'blue', 'yellow', 'other'));
  end if;
end $$;

create index if not exists idx_gv_reservation
  on public.guest_vehicles (reservation_id);

create index if not exists idx_gv_guest_profile
  on public.guest_vehicles (guest_profile_id)
  where guest_profile_id is not null;

create index if not exists idx_gv_room
  on public.guest_vehicles (room_id)
  where room_id is not null;

create index if not exists idx_gv_active
  on public.guest_vehicles (checked_out_at)
  where checked_out_at is null;

create index if not exists idx_gv_plate
  on public.guest_vehicles (plate_number)
  where plate_number is not null;

drop trigger if exists trg_guest_vehicles_updated_at on public.guest_vehicles;
create trigger trg_guest_vehicles_updated_at
before update on public.guest_vehicles
for each row execute function public.set_updated_at();

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604110001_phase58_hk_return_stock.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

create table if not exists public.housekeeping_amenity_ledger (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.reservations(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  task_id uuid references public.housekeeping_tasks(id) on delete set null,
  stay_date date not null,
  room_number text not null,
  floor_number int not null,
  product_id uuid not null references public.products(id),
  item_name text not null,
  action text not null check (action in ('deliver', 'return')),
  quantity int not null check (quantity > 0),
  performed_by text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_hk_amenity_ledger_res_room_product
  on public.housekeeping_amenity_ledger (reservation_id, room_id, product_id);

create index if not exists idx_hk_amenity_ledger_task
  on public.housekeeping_amenity_ledger (task_id);

create index if not exists idx_hk_amenity_ledger_created_at
  on public.housekeeping_amenity_ledger (created_at desc);

create or replace function public.hk_return_floor_stock(
  p_task_id uuid,
  p_reservation_id uuid,
  p_room_id uuid,
  p_room_number text,
  p_floor_number int,
  p_maid_name text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_item jsonb;
  v_product_id uuid;
  v_quantity int;
  v_available int;
  v_current_floor_qty int;
  v_item_name text;
  v_processed int := 0;
begin
  if p_reservation_id is null then
    raise exception 'p_reservation_id is required';
  end if;

  if p_room_id is null then
    raise exception 'p_room_id is required';
  end if;

  if p_room_number is null or length(trim(p_room_number)) = 0 then
    raise exception 'p_room_number is required';
  end if;

  if p_floor_number is null or p_floor_number <= 0 then
    raise exception 'p_floor_number must be > 0';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    return jsonb_build_object('processed', 0);
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_product_id := (v_item ->> 'product_id')::uuid;
    exception when others then
      v_product_id := null;
    end;

    v_quantity := greatest(coalesce((v_item ->> 'quantity')::int, 0), 0);

    if v_product_id is null or v_quantity <= 0 then
      continue;
    end if;

    select
      greatest(
        coalesce(sum(case when action = 'deliver' then quantity else 0 end), 0) -
        coalesce(sum(case when action = 'return' then quantity else 0 end), 0),
        0
      )
    into v_available
    from public.housekeeping_amenity_ledger
    where reservation_id = p_reservation_id
      and room_id = p_room_id
      and product_id = v_product_id;

    if v_available < v_quantity then
      raise exception 'return quantity exceeds available delivered stock for product % (available %, requested %)',
        v_product_id, v_available, v_quantity;
    end if;

    insert into public.floor_stock (floor_number, product_id, quantity, updated_at)
    values (p_floor_number, v_product_id, 0, v_now)
    on conflict (floor_number, product_id) do nothing;

    select quantity
    into v_current_floor_qty
    from public.floor_stock
    where floor_number = p_floor_number
      and product_id = v_product_id
    for update;

    update public.floor_stock
    set quantity = coalesce(v_current_floor_qty, 0) + v_quantity,
        updated_at = v_now
    where floor_number = p_floor_number
      and product_id = v_product_id;

    select hal.item_name
    into v_item_name
    from public.housekeeping_amenity_ledger hal
    where hal.reservation_id = p_reservation_id
      and hal.room_id = p_room_id
      and hal.product_id = v_product_id
    order by hal.created_at desc
    limit 1;

    if v_item_name is null then
      select p.name
      into v_item_name
      from public.products p
      where p.id = v_product_id
      limit 1;
    end if;

    insert into public.stock_transactions_v2 (
      transaction_date,
      product_id,
      action,
      quantity_change,
      from_location,
      to_location,
      reference_type,
      reference_id,
      room_number,
      floor_number,
      performed_by,
      note,
      created_at
    )
    values (
      (v_now at time zone 'Asia/Bangkok')::date,
      v_product_id,
      'return',
      v_quantity,
      'room_' || trim(p_room_number),
      'floor_' || p_floor_number::text,
      'housekeeping_return',
      p_task_id,
      trim(p_room_number),
      p_floor_number,
      nullif(trim(coalesce(p_maid_name, '')), ''),
      coalesce(v_item_name, 'HK return'),
      v_now
    );

    insert into public.housekeeping_amenity_ledger (
      reservation_id,
      room_id,
      task_id,
      stay_date,
      room_number,
      floor_number,
      product_id,
      item_name,
      action,
      quantity,
      performed_by,
      created_at
    )
    values (
      p_reservation_id,
      p_room_id,
      p_task_id,
      (v_now at time zone 'Asia/Bangkok')::date,
      trim(p_room_number),
      p_floor_number,
      v_product_id,
      coalesce(v_item_name, 'Unknown'),
      'return',
      v_quantity,
      nullif(trim(coalesce(p_maid_name, '')), ''),
      v_now
    );

    v_processed := v_processed + 1;
  end loop;

  return jsonb_build_object('processed', v_processed);
end;
$$;

grant execute on function public.hk_return_floor_stock(uuid, uuid, uuid, text, int, text, jsonb) to anon, authenticated;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604140001_phase58_backup_dr.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

create table if not exists public.backup_logs (
  id uuid primary key default gen_random_uuid(),
  backup_type text not null,
  status text not null default 'started',
  file_name text null,
  file_size_bytes bigint null,
  record_count integer null,
  error_message text null,
  started_at timestamptz not null default now(),
  completed_at timestamptz null,
  created_at timestamptz not null default now()
);

create index if not exists idx_backup_logs_type_date
  on public.backup_logs (backup_type, created_at desc);

create table if not exists public.backup_snapshots (
  id uuid primary key default gen_random_uuid(),
  snapshot_date date not null,
  snapshot_data jsonb not null,
  record_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_backup_snapshots_date
  on public.backup_snapshots (created_at desc);

create table if not exists public.backup_config (
  id integer primary key default 1,
  offline_pin text null,
  r2_bucket text not null default 'pms-backups',
  retention_days integer not null default 60,
  updated_at timestamptz not null default now(),
  constraint backup_config_singleton check (id = 1)
);

insert into public.backup_config (id)
values (1)
on conflict (id) do nothing;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604140002_phase58_backup_device_pairing.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

create table if not exists public.backup_pairing_tokens (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique,
  device_name text null,
  expires_at timestamptz not null,
  used_at timestamptz null,
  created_by_user_id uuid null,
  created_at timestamptz not null default now()
);

create index if not exists idx_backup_pairing_tokens_expires_at
  on public.backup_pairing_tokens (expires_at desc);

create table if not exists public.backup_trusted_devices (
  id uuid primary key default gen_random_uuid(),
  device_name text not null,
  device_token_hash text not null unique,
  paired_via_token_id uuid null references public.backup_pairing_tokens(id) on delete set null,
  user_agent text null,
  paired_at timestamptz not null default now(),
  last_seen_at timestamptz null,
  revoked_at timestamptz null
);

create index if not exists idx_backup_trusted_devices_active
  on public.backup_trusted_devices (revoked_at, paired_at desc);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604150001_phase65_stock_snapshot_amenity_audit.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create extension if not exists "pgcrypto";

-- ============================================================
-- Phase 65: Stock Snapshot + FO Amenity Audit
-- ============================================================

create table if not exists public.stock_daily_snapshots (
  id uuid primary key default gen_random_uuid(),
  business_date date not null,
  product_id uuid not null references public.products(id),
  product_name text not null,
  category text not null,
  tracking_mode text not null,
  opening_main int not null default 0,
  opening_floor int not null default 0,
  sold_qty int not null default 0,
  voided_qty int not null default 0,
  used_qty int not null default 0,
  hk_returned_qty int not null default 0,
  transferred_main_to_floor int not null default 0,
  transferred_floor_to_main int not null default 0,
  received_qty int not null default 0,
  adjusted_qty int not null default 0,
  audit_correction_qty int not null default 0,
  audit_refill_qty int not null default 0,
  expected_closing_main int not null,
  expected_closing_floor int not null,
  actual_closing_main int not null,
  actual_closing_floor int not null,
  variance_main int not null,
  variance_floor int not null,
  floor_breakdown jsonb not null default '[]'::jsonb,
  computed_at timestamptz not null default timezone('utc', now()),
  computed_by uuid references public.profiles(user_id),
  recomputed_count int not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (business_date, product_id)
);

create index if not exists idx_stock_snapshots_date
  on public.stock_daily_snapshots (business_date desc);

create index if not exists idx_stock_snapshots_variance
  on public.stock_daily_snapshots (business_date)
  where variance_main <> 0 or variance_floor <> 0;

create index if not exists idx_stock_snapshots_mode
  on public.stock_daily_snapshots (tracking_mode, business_date);

create table if not exists public.fo_amenity_audit_sessions (
  id uuid primary key default gen_random_uuid(),
  business_date date not null,
  floor_number int not null check (floor_number > 0),
  audited_by text not null,
  audited_by_user_id uuid references public.profiles(user_id),
  session_note text,
  total_items int not null default 0,
  total_overclick_units int not null default 0,
  total_underclick_units int not null default 0,
  total_refill_units int not null default 0,
  submitted_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_fo_audit_sessions_date
  on public.fo_amenity_audit_sessions (business_date desc);

create index if not exists idx_fo_audit_sessions_floor
  on public.fo_amenity_audit_sessions (floor_number, business_date desc);

create table if not exists public.fo_amenity_audit_items (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.fo_amenity_audit_sessions(id) on delete cascade,
  product_id uuid not null references public.products(id),
  product_name text not null,
  system_qty_before int not null,
  physical_qty int not null,
  overclick_delta int not null,
  refill_to int not null,
  refill_delta int not null,
  item_note text,
  correction_tx_id uuid references public.stock_transactions_v2(id),
  refill_out_tx_id uuid references public.stock_transactions_v2(id),
  refill_in_tx_id uuid references public.stock_transactions_v2(id),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_fo_audit_items_session
  on public.fo_amenity_audit_items (session_id);

create index if not exists idx_fo_audit_items_product
  on public.fo_amenity_audit_items (product_id);

create index if not exists idx_fo_audit_items_overclick
  on public.fo_amenity_audit_items (overclick_delta)
  where overclick_delta <> 0;

alter table public.products
  add column if not exists stock_tracking_mode text;

alter table public.products
  alter column stock_tracking_mode set default 'amenity_direct';

update public.products
set stock_tracking_mode = 'amenity_direct'
where stock_tracking_mode is null
   or trim(stock_tracking_mode) = ''
   or stock_tracking_mode not in ('pos_main_only', 'amenity_prepare', 'amenity_direct');

update public.products
set stock_tracking_mode = 'amenity_prepare'
where lower(trim(name)) in ('water bottle', 'water for room', 'coffee');

update public.products
set stock_tracking_mode = 'amenity_direct'
where lower(trim(name)) in ('soap', 'shampoo', 'toothbrush set', 'sewing kit', 'shower cap', 'razor');

update public.products
set stock_tracking_mode = 'pos_main_only'
where category = 'pos';

alter table public.products
  alter column stock_tracking_mode set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'products_stock_tracking_mode_check'
      and conrelid = 'public.products'::regclass
  ) then
    alter table public.products
      add constraint products_stock_tracking_mode_check
      check (stock_tracking_mode in ('pos_main_only', 'amenity_prepare', 'amenity_direct'));
  end if;
end $$;

create index if not exists idx_products_tracking_mode
  on public.products (stock_tracking_mode)
  where is_active = true;

alter table public.hotel_settings
  add column if not exists amenity_audit_warn_days int;

update public.hotel_settings
set amenity_audit_warn_days = 3
where amenity_audit_warn_days is null;

alter table public.hotel_settings
  alter column amenity_audit_warn_days set default 3,
  alter column amenity_audit_warn_days set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'hotel_settings_amenity_audit_warn_days_check'
      and conrelid = 'public.hotel_settings'::regclass
  ) then
    alter table public.hotel_settings
      add constraint hotel_settings_amenity_audit_warn_days_check
      check (amenity_audit_warn_days between 1 and 30);
  end if;
end $$;

alter table public.daily_snapshots
  add column if not exists stock_variance_count int not null default 0,
  add column if not exists stock_total_products int not null default 0,
  add column if not exists stock_reconcile_status text not null default 'pending',
  add column if not exists stock_reconcile_note text,
  add column if not exists stock_reconcile_ack jsonb not null default '{}'::jsonb,
  add column if not exists stock_computed_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'daily_snapshots_stock_reconcile_status_check'
      and conrelid = 'public.daily_snapshots'::regclass
  ) then
    alter table public.daily_snapshots
      add constraint daily_snapshots_stock_reconcile_status_check
      check (stock_reconcile_status in ('pending', 'clean', 'acknowledged'));
  end if;
end $$;

create or replace function public.compute_stock_snapshot(p_business_date date)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_product record;
  v_tx record;
  v_prev_main int;
  v_prev_floor int;
  v_actual_main int;
  v_actual_floor int;
  v_opening_main int;
  v_opening_floor int;
  v_expected_main int;
  v_expected_floor int;
  v_floor_breakdown jsonb;
  v_products_computed int := 0;
  v_variance_count int := 0;
begin
  if p_business_date is null then
    raise exception 'business_date is required';
  end if;

  insert into public.daily_snapshots (business_date)
  values (p_business_date)
  on conflict (business_date) do nothing;

  for v_product in
    select
      p.id,
      p.name,
      p.category,
      p.stock_tracking_mode
    from public.products p
    where p.is_active = true
    order by p.name
  loop
    select
      coalesce(sum(st.quantity_change) filter (where st.action = 'sale'), 0) as sale_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'return' and st.reference_type = 'pos_order'), 0) as pos_return_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'use'), 0) as use_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'return' and st.reference_type = 'housekeeping_return'), 0) as hk_return_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'return' and st.reference_type = 'fo_return'), 0) as fo_return_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'receive'), 0) as receive_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'adjust' and coalesce(st.reference_type, '') <> 'fo_amenity_audit_correction'), 0) as adjust_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'adjust' and st.reference_type = 'fo_amenity_audit_correction'), 0) as audit_correction_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'transfer_out' and st.from_location = 'main'), 0) as transfer_main_out_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'transfer_in' and st.to_location = 'main'), 0) as transfer_main_in_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'transfer_in' and st.to_location like 'floor_%'), 0) as transfer_floor_in_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'transfer_out' and st.from_location like 'floor_%'), 0) as transfer_floor_out_delta,
      coalesce(sum(st.quantity_change) filter (where st.action = 'transfer_in' and st.reference_type = 'fo_amenity_audit_refill'), 0) as audit_refill_delta,
      coalesce(sum(
        case
          when st.action = 'sale' then st.quantity_change
          when st.action = 'return' and st.reference_type = 'pos_order' then st.quantity_change
          when st.action = 'receive' then st.quantity_change
          when st.action = 'adjust' and (st.floor_number is null or st.from_location = 'main' or st.to_location = 'main') then st.quantity_change
          when st.action = 'transfer_out' and st.from_location = 'main' then st.quantity_change
          when st.action = 'transfer_in' and st.to_location = 'main' then st.quantity_change
          else 0
        end
      ), 0) as net_main_delta,
      coalesce(sum(
        case
          when st.action = 'use' then st.quantity_change
          when st.action = 'return' and st.reference_type in ('housekeeping_return', 'fo_return') then st.quantity_change
          when st.action = 'adjust' and st.floor_number is not null then st.quantity_change
          when st.action = 'transfer_in' and st.to_location like 'floor_%' then st.quantity_change
          when st.action = 'transfer_out' and st.from_location like 'floor_%' then st.quantity_change
          else 0
        end
      ), 0) as net_floor_delta
    into v_tx
    from public.stock_transactions_v2 st
    where st.transaction_date = p_business_date
      and st.product_id = v_product.id;

    select s.actual_closing_main, s.actual_closing_floor
    into v_prev_main, v_prev_floor
    from public.stock_daily_snapshots s
    where s.business_date = p_business_date - 1
      and s.product_id = v_product.id
    limit 1;

    select coalesce(ms.quantity, 0)
    into v_actual_main
    from public.main_stock ms
    where ms.product_id = v_product.id;

    v_actual_main := coalesce(v_actual_main, 0);

    select coalesce(sum(fs.quantity), 0)
    into v_actual_floor
    from public.floor_stock fs
    where fs.product_id = v_product.id;

    v_actual_floor := coalesce(v_actual_floor, 0);
    v_opening_main := coalesce(v_prev_main, v_actual_main - coalesce(v_tx.net_main_delta, 0));
    v_opening_floor := coalesce(v_prev_floor, v_actual_floor - coalesce(v_tx.net_floor_delta, 0));
    v_expected_main := v_opening_main + coalesce(v_tx.net_main_delta, 0);
    v_expected_floor := v_opening_floor + coalesce(v_tx.net_floor_delta, 0);

    select coalesce(jsonb_agg(row_to_json(floor_row)::jsonb order by floor), '[]'::jsonb)
    into v_floor_breakdown
    from (
      select
        fs.floor_number as floor,
        greatest(coalesce(fs.quantity, 0) - coalesce(sum(
          case
            when st.action = 'use' then st.quantity_change
            when st.action = 'return' and st.reference_type in ('housekeeping_return', 'fo_return') then st.quantity_change
            when st.action = 'adjust' and st.floor_number is not null then st.quantity_change
            when st.action = 'transfer_in' and st.to_location like 'floor_%' then st.quantity_change
            when st.action = 'transfer_out' and st.from_location like 'floor_%' then st.quantity_change
            else 0
          end
        ), 0), 0) as opening,
        abs(coalesce(sum(st.quantity_change) filter (where st.action = 'use'), 0)) as used,
        coalesce(sum(st.quantity_change) filter (where st.action = 'adjust' and st.reference_type = 'fo_amenity_audit_correction'), 0) as audit_correction,
        coalesce(sum(st.quantity_change) filter (where st.action = 'transfer_in' and st.reference_type = 'fo_amenity_audit_refill'), 0) as refill,
        coalesce(fs.quantity, 0) as closing,
        0 as variance
      from public.floor_stock fs
      left join public.stock_transactions_v2 st
        on st.product_id = fs.product_id
       and st.floor_number = fs.floor_number
       and st.transaction_date = p_business_date
      where fs.product_id = v_product.id
      group by fs.floor_number, fs.quantity
    ) floor_row;

    insert into public.stock_daily_snapshots (
      business_date,
      product_id,
      product_name,
      category,
      tracking_mode,
      opening_main,
      opening_floor,
      sold_qty,
      voided_qty,
      used_qty,
      hk_returned_qty,
      transferred_main_to_floor,
      transferred_floor_to_main,
      received_qty,
      adjusted_qty,
      audit_correction_qty,
      audit_refill_qty,
      expected_closing_main,
      expected_closing_floor,
      actual_closing_main,
      actual_closing_floor,
      variance_main,
      variance_floor,
      floor_breakdown,
      computed_at,
      updated_at
    )
    values (
      p_business_date,
      v_product.id,
      v_product.name,
      v_product.category,
      v_product.stock_tracking_mode,
      v_opening_main,
      v_opening_floor,
      abs(coalesce(v_tx.sale_delta, 0)),
      coalesce(v_tx.pos_return_delta, 0),
      abs(coalesce(v_tx.use_delta, 0)),
      coalesce(v_tx.hk_return_delta, 0),
      abs(coalesce(v_tx.transfer_main_out_delta, 0)),
      coalesce(v_tx.fo_return_delta, 0) + abs(coalesce(v_tx.transfer_floor_out_delta, 0)),
      coalesce(v_tx.receive_delta, 0),
      coalesce(v_tx.adjust_delta, 0),
      coalesce(v_tx.audit_correction_delta, 0),
      coalesce(v_tx.audit_refill_delta, 0),
      v_expected_main,
      v_expected_floor,
      v_actual_main,
      v_actual_floor,
      v_actual_main - v_expected_main,
      v_actual_floor - v_expected_floor,
      case when v_product.stock_tracking_mode = 'pos_main_only' then '[]'::jsonb else coalesce(v_floor_breakdown, '[]'::jsonb) end,
      v_now,
      v_now
    )
    on conflict (business_date, product_id) do update
    set
      product_name = excluded.product_name,
      category = excluded.category,
      tracking_mode = excluded.tracking_mode,
      opening_main = excluded.opening_main,
      opening_floor = excluded.opening_floor,
      sold_qty = excluded.sold_qty,
      voided_qty = excluded.voided_qty,
      used_qty = excluded.used_qty,
      hk_returned_qty = excluded.hk_returned_qty,
      transferred_main_to_floor = excluded.transferred_main_to_floor,
      transferred_floor_to_main = excluded.transferred_floor_to_main,
      received_qty = excluded.received_qty,
      adjusted_qty = excluded.adjusted_qty,
      audit_correction_qty = excluded.audit_correction_qty,
      audit_refill_qty = excluded.audit_refill_qty,
      expected_closing_main = excluded.expected_closing_main,
      expected_closing_floor = excluded.expected_closing_floor,
      actual_closing_main = excluded.actual_closing_main,
      actual_closing_floor = excluded.actual_closing_floor,
      variance_main = excluded.variance_main,
      variance_floor = excluded.variance_floor,
      floor_breakdown = excluded.floor_breakdown,
      computed_at = excluded.computed_at,
      updated_at = excluded.updated_at,
      recomputed_count = public.stock_daily_snapshots.recomputed_count + 1;

    v_products_computed := v_products_computed + 1;
    if (v_actual_main - v_expected_main) <> 0 or (v_actual_floor - v_expected_floor) <> 0 then
      v_variance_count := v_variance_count + 1;
    end if;
  end loop;

  update public.daily_snapshots ds
  set
    stock_variance_count = v_variance_count,
    stock_total_products = v_products_computed,
    stock_reconcile_status = case when v_variance_count = 0 then 'clean' else 'pending' end,
    stock_computed_at = v_now
  where ds.business_date = p_business_date;

  return jsonb_build_object(
    'products_computed', v_products_computed,
    'variance_count', v_variance_count,
    'clean_count', greatest(v_products_computed - v_variance_count, 0)
  );
end;
$$;

create or replace function public.fo_amenity_audit_submit(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_business_date date;
  v_floor_number int;
  v_audited_by text;
  v_audited_by_user_id uuid;
  v_session_note text;
  v_items jsonb;
  v_item jsonb;
  v_session_id uuid;
  v_product_id uuid;
  v_product_name text;
  v_product_mode text;
  v_product_active boolean;
  v_system_qty_before int;
  v_physical_qty int;
  v_refill_to int;
  v_overclick_delta int;
  v_refill_delta int;
  v_item_note text;
  v_floor_current int;
  v_main_current int;
  v_correction_tx_id uuid;
  v_refill_out_tx_id uuid;
  v_refill_in_tx_id uuid;
  v_total_items int := 0;
  v_total_overclick int := 0;
  v_total_underclick int := 0;
  v_total_refill int := 0;
begin
  v_business_date := nullif(p_payload ->> 'business_date', '')::date;
  v_floor_number := (p_payload ->> 'floor_number')::int;
  v_audited_by := nullif(trim(coalesce(p_payload ->> 'audited_by', '')), '');
  v_audited_by_user_id := nullif(p_payload ->> 'audited_by_user_id', '')::uuid;
  v_session_note := nullif(trim(coalesce(p_payload ->> 'session_note', '')), '');
  v_items := coalesce(p_payload -> 'items', '[]'::jsonb);

  if v_business_date is null then
    select hs.business_date into v_business_date
    from public.hotel_settings hs
    where hs.id = 1;
  end if;

  if v_business_date is null then
    raise exception 'business_date is required';
  end if;

  if v_floor_number is null or v_floor_number <= 0 then
    raise exception 'floor_number is required';
  end if;

  if v_audited_by is null then
    raise exception 'audited_by is required';
  end if;

  if jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) = 0 then
    raise exception 'items is required';
  end if;

  insert into public.fo_amenity_audit_sessions (
    business_date,
    floor_number,
    audited_by,
    audited_by_user_id,
    session_note,
    submitted_at,
    created_at
  )
  values (
    v_business_date,
    v_floor_number,
    v_audited_by,
    v_audited_by_user_id,
    v_session_note,
    v_now,
    v_now
  )
  returning id into v_session_id;

  for v_item in select value from jsonb_array_elements(v_items)
  loop
    v_product_id := nullif(v_item ->> 'product_id', '')::uuid;
    v_system_qty_before := (v_item ->> 'system_qty_before')::int;
    v_physical_qty := (v_item ->> 'physical_qty')::int;
    v_refill_to := coalesce(nullif(v_item ->> 'refill_to', '')::int, v_physical_qty);
    v_item_note := nullif(trim(coalesce(v_item ->> 'item_note', '')), '');

    if v_product_id is null then
      raise exception 'product_id is required';
    end if;

    if v_system_qty_before is null or v_system_qty_before < 0 then
      raise exception 'system_qty_before must be >= 0';
    end if;

    if v_physical_qty is null or v_physical_qty < 0 then
      raise exception 'physical_qty must be >= 0';
    end if;

    if v_refill_to < v_physical_qty then
      raise exception 'refill_to must be >= physical_qty';
    end if;

    select p.name, p.stock_tracking_mode, p.is_active
    into v_product_name, v_product_mode, v_product_active
    from public.products p
    where p.id = v_product_id;

    if v_product_name is null or v_product_active is not true or v_product_mode <> 'amenity_direct' then
      raise exception 'Product % is not an active amenity_direct product', v_product_id;
    end if;

    select fs.quantity
    into v_floor_current
    from public.floor_stock fs
    where fs.floor_number = v_floor_number
      and fs.product_id = v_product_id
    for update;

    if v_floor_current is null then
      raise exception 'Floor stock row missing for product % on floor %', v_product_id, v_floor_number;
    end if;

    if v_floor_current <> v_system_qty_before then
      raise exception 'STOCK_CONFLICT product_id=% system_qty_submitted=% system_qty_now=%',
        v_product_id,
        v_system_qty_before,
        v_floor_current;
    end if;

    v_overclick_delta := v_physical_qty - v_system_qty_before;
    v_refill_delta := v_refill_to - v_physical_qty;

    if v_overclick_delta <> 0 and v_item_note is null then
      raise exception 'item_note is required when physical_qty differs from system_qty_before';
    end if;

    v_correction_tx_id := null;
    v_refill_out_tx_id := null;
    v_refill_in_tx_id := null;

    if v_overclick_delta <> 0 then
      insert into public.stock_transactions_v2 (
        transaction_date,
        product_id,
        action,
        quantity_change,
        from_location,
        to_location,
        reference_type,
        reference_id,
        floor_number,
        performed_by,
        note,
        created_at
      )
      values (
        v_business_date,
        v_product_id,
        'adjust',
        v_overclick_delta,
        'floor_' || v_floor_number::text,
        'floor_' || v_floor_number::text,
        'fo_amenity_audit_correction',
        v_session_id,
        v_floor_number,
        v_audited_by,
        v_item_note,
        v_now
      )
      returning id into v_correction_tx_id;

      update public.floor_stock
      set quantity = quantity + v_overclick_delta,
          updated_at = v_now
      where floor_number = v_floor_number
        and product_id = v_product_id;
    end if;

    if v_refill_delta > 0 then
      insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
      values (v_product_id, 0, 10, v_now)
      on conflict (product_id) do nothing;

      select ms.quantity
      into v_main_current
      from public.main_stock ms
      where ms.product_id = v_product_id
      for update;

      if coalesce(v_main_current, 0) < v_refill_delta then
        raise exception 'Insufficient main stock for %, required %, available %',
          v_product_name,
          v_refill_delta,
          coalesce(v_main_current, 0);
      end if;

      insert into public.stock_transactions_v2 (
        transaction_date,
        product_id,
        action,
        quantity_change,
        from_location,
        to_location,
        reference_type,
        reference_id,
        floor_number,
        performed_by,
        note,
        created_at
      )
      values (
        v_business_date,
        v_product_id,
        'transfer_out',
        -v_refill_delta,
        'main',
        'floor_' || v_floor_number::text,
        'fo_amenity_audit_refill',
        v_session_id,
        v_floor_number,
        v_audited_by,
        coalesce(v_item_note, v_session_note, 'FO amenity audit refill'),
        v_now
      )
      returning id into v_refill_out_tx_id;

      insert into public.stock_transactions_v2 (
        transaction_date,
        product_id,
        action,
        quantity_change,
        from_location,
        to_location,
        reference_type,
        reference_id,
        floor_number,
        performed_by,
        note,
        created_at
      )
      values (
        v_business_date,
        v_product_id,
        'transfer_in',
        v_refill_delta,
        'main',
        'floor_' || v_floor_number::text,
        'fo_amenity_audit_refill',
        v_session_id,
        v_floor_number,
        v_audited_by,
        coalesce(v_item_note, v_session_note, 'FO amenity audit refill'),
        v_now
      )
      returning id into v_refill_in_tx_id;

      update public.main_stock
      set quantity = quantity - v_refill_delta,
          updated_at = v_now
      where product_id = v_product_id;

      update public.floor_stock
      set quantity = quantity + v_refill_delta,
          updated_at = v_now
      where floor_number = v_floor_number
        and product_id = v_product_id;
    end if;

    insert into public.fo_amenity_audit_items (
      session_id,
      product_id,
      product_name,
      system_qty_before,
      physical_qty,
      overclick_delta,
      refill_to,
      refill_delta,
      item_note,
      correction_tx_id,
      refill_out_tx_id,
      refill_in_tx_id,
      created_at
    )
    values (
      v_session_id,
      v_product_id,
      v_product_name,
      v_system_qty_before,
      v_physical_qty,
      v_overclick_delta,
      v_refill_to,
      v_refill_delta,
      v_item_note,
      v_correction_tx_id,
      v_refill_out_tx_id,
      v_refill_in_tx_id,
      v_now
    );

    v_total_items := v_total_items + 1;
    v_total_overclick := v_total_overclick + greatest(v_overclick_delta, 0);
    v_total_underclick := v_total_underclick + abs(least(v_overclick_delta, 0));
    v_total_refill := v_total_refill + v_refill_delta;
  end loop;

  update public.fo_amenity_audit_sessions
  set
    total_items = v_total_items,
    total_overclick_units = v_total_overclick,
    total_underclick_units = v_total_underclick,
    total_refill_units = v_total_refill
  where id = v_session_id;

  return jsonb_build_object(
    'session_id', v_session_id,
    'items_count', v_total_items,
    'total_overclick', v_total_overclick,
    'total_underclick', v_total_underclick,
    'total_refill', v_total_refill
  );
end;
$$;

create or replace function public.acknowledge_stock_reconcile_section(
  p_business_date date,
  p_section text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ack jsonb;
  v_all_sections_acked boolean;
  v_summary text;
begin
  if p_business_date is null then
    raise exception 'business_date is required';
  end if;

  if p_section not in ('pos', 'amenity_prepare', 'amenity_direct') then
    raise exception 'Invalid stock reconcile section: %', p_section;
  end if;

  insert into public.daily_snapshots (business_date)
  values (p_business_date)
  on conflict (business_date) do nothing;

  update public.daily_snapshots
  set stock_reconcile_ack = jsonb_set(
        coalesce(stock_reconcile_ack, '{}'::jsonb),
        array[p_section],
        coalesce(p_payload, '{}'::jsonb),
        true
      )
  where business_date = p_business_date
  returning stock_reconcile_ack into v_ack;

  v_all_sections_acked :=
    (v_ack ? 'pos') and
    (v_ack ? 'amenity_prepare') and
    (v_ack ? 'amenity_direct');

  select string_agg(
    key || ': ' || coalesce(nullif(value ->> 'note', ''), value ->> 'status', 'acknowledged'),
    '; ' order by key
  )
  into v_summary
  from jsonb_each(coalesce(v_ack, '{}'::jsonb));

  update public.daily_snapshots
  set
    stock_reconcile_status = case when v_all_sections_acked then 'acknowledged' else 'pending' end,
    stock_reconcile_note = nullif(v_summary, '')
  where business_date = p_business_date;

  return jsonb_build_object(
    'acknowledged_at', p_payload ->> 'acknowledged_at',
    'acknowledged_by', p_payload ->> 'acknowledged_by',
    'all_sections_acked', v_all_sections_acked,
    'acknowledgment', p_payload
  );
end;
$$;

alter table public.stock_daily_snapshots enable row level security;
alter table public.fo_amenity_audit_sessions enable row level security;
alter table public.fo_amenity_audit_items enable row level security;

drop policy if exists stock_daily_snapshots_allow_all on public.stock_daily_snapshots;
create policy stock_daily_snapshots_allow_all
  on public.stock_daily_snapshots
  for all
  using (true)
  with check (true);

drop policy if exists fo_amenity_audit_sessions_allow_all on public.fo_amenity_audit_sessions;
create policy fo_amenity_audit_sessions_allow_all
  on public.fo_amenity_audit_sessions
  for all
  using (true)
  with check (true);

drop policy if exists fo_amenity_audit_items_allow_all on public.fo_amenity_audit_items;
create policy fo_amenity_audit_items_allow_all
  on public.fo_amenity_audit_items
  for all
  using (true)
  with check (true);

grant select, insert, update, delete on table public.stock_daily_snapshots to anon, authenticated;
grant select, insert, update, delete on table public.fo_amenity_audit_sessions to anon, authenticated;
grant select, insert, update, delete on table public.fo_amenity_audit_items to anon, authenticated;
grant execute on function public.compute_stock_snapshot(date) to anon, authenticated;
grant execute on function public.fo_amenity_audit_submit(jsonb) to anon, authenticated;
grant execute on function public.acknowledge_stock_reconcile_section(date, text, jsonb) to anon, authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604150002_phase65_daily_snapshot_eod_closed_flag.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 65 hotfix:
-- daily_snapshots can now hold pre-EOD stock reconcile state, so row existence
-- can no longer mean "Night Audit closed this business date".
alter table public.daily_snapshots
  add column if not exists is_eod_closed boolean not null default false;

update public.daily_snapshots ds
set is_eod_closed = true
where ds.business_date < coalesce(
  (select hs.business_date from public.hotel_settings hs where hs.id = 1),
  current_date
);

comment on column public.daily_snapshots.is_eod_closed is
  'True only when Night Audit/EOD has actually closed the date. Phase 65 stock reconcile may create/update rows before close.';

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604150002_phase65_hotfix_water_coffee_classification.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 65 hotfix — 2026-04-15
-- Problem: 202604150001 backfill used exact name match `lower(trim(name)) in ('water bottle', 'water for room', 'coffee')`
-- Actual product names in the catalog are:
--   - "Water Bottle For Room" (amenity, should be amenity_prepare)
--   - "Coffee For Room"       (amenity, should be amenity_prepare)
--   - "Water Bottle For Sale" (POS, already pos_main_only via category=pos rule — untouched)
--   - "Coffee"                (POS, already pos_main_only via category=pos rule — untouched)
--
-- Effect: the two amenity items fell through to the default `amenity_direct` and started showing
-- in the FO Amenity Audit page even though they belong to the FO Prepare flow.
--
-- This hotfix only touches rows currently mis-classified as `amenity_direct`. It does not
-- overwrite any row that an admin may have fixed manually after the original backfill.

do $$
declare
  v_updated int;
begin
  update public.products
  set stock_tracking_mode = 'amenity_prepare',
      updated_at = timezone('utc', now())
  where is_active = true
    and stock_tracking_mode = 'amenity_direct'
    and lower(trim(name)) in (
      'water bottle for room',
      'coffee for room'
    );

  get diagnostics v_updated = row_count;
  raise notice 'phase65 hotfix: reclassified % product row(s) from amenity_direct to amenity_prepare', v_updated;
end $$;

-- Defensive sweep (belt-and-suspenders): any product with category='pos' must be pos_main_only.
-- This guards against a future admin accidentally classifying a POS product as amenity_direct.
do $$
declare
  v_fixed int;
begin
  update public.products
  set stock_tracking_mode = 'pos_main_only',
      updated_at = timezone('utc', now())
  where is_active = true
    and category = 'pos'
    and stock_tracking_mode <> 'pos_main_only';

  get diagnostics v_fixed = row_count;
  raise notice 'phase65 hotfix: repaired % POS product(s) to pos_main_only', v_fixed;
end $$;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604160001_phase66_linen_master_data.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create table if not exists public.linen_items (
  id serial primary key,
  item_number smallint not null unique,
  name_th text not null,
  name_en text not null,
  category text not null check (category in ('bed', 'bath', 'misc')),
  is_active boolean not null default true,
  laundry_rate_per_piece numeric(8, 2) not null default 0,
  sort_order smallint not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.room_linen_setups (
  id serial primary key,
  room_type_code text not null,
  linen_item_id int not null references public.linen_items(id) on delete cascade,
  qty smallint not null default 0 check (qty >= 0),
  unique (room_type_code, linen_item_id)
);

create table if not exists public.linen_dayuse_setup (
  id serial primary key,
  linen_item_id int not null references public.linen_items(id) on delete cascade unique,
  qty_per_room smallint not null default 0 check (qty_per_room >= 0)
);

create table if not exists public.linen_usage_rules (
  id serial primary key,
  category text not null check (category in (
    'checkout_serviced',
    'checkout_towel_only',
    'inhouse_serviced',
    'inhouse_not_started',
    'inhouse_no_task',
    'inhouse_no_service',
    'after_cutoff'
  )),
  linen_item_id int not null references public.linen_items(id) on delete cascade,
  percentage smallint not null default 0 check (percentage >= 0 and percentage <= 100),
  use_checklist boolean not null default false,
  notes text,
  unique (category, linen_item_id)
);

alter table public.linen_items enable row level security;
alter table public.room_linen_setups enable row level security;
alter table public.linen_dayuse_setup enable row level security;
alter table public.linen_usage_rules enable row level security;

drop policy if exists linen_items_read on public.linen_items;
create policy linen_items_read on public.linen_items
  for select to authenticated
  using (true);

drop policy if exists linen_items_write on public.linen_items;
create policy linen_items_write on public.linen_items
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists room_linen_setups_read on public.room_linen_setups;
create policy room_linen_setups_read on public.room_linen_setups
  for select to authenticated
  using (true);

drop policy if exists room_linen_setups_write on public.room_linen_setups;
create policy room_linen_setups_write on public.room_linen_setups
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists linen_dayuse_setup_read on public.linen_dayuse_setup;
create policy linen_dayuse_setup_read on public.linen_dayuse_setup
  for select to authenticated
  using (true);

drop policy if exists linen_dayuse_setup_write on public.linen_dayuse_setup;
create policy linen_dayuse_setup_write on public.linen_dayuse_setup
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists linen_usage_rules_read on public.linen_usage_rules;
create policy linen_usage_rules_read on public.linen_usage_rules
  for select to authenticated
  using (true);

drop policy if exists linen_usage_rules_write on public.linen_usage_rules;
create policy linen_usage_rules_write on public.linen_usage_rules
  for all to authenticated
  using (true)
  with check (true);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604160002_phase66_linen_seed_data.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

insert into public.linen_items (item_number, name_th, name_en, category, is_active, sort_order)
values
  (1, 'ปลอกหมอน', 'Pillowcase', 'bed', true, 1),
  (2, 'ผ้าขนหนู', 'Towel', 'bath', true, 2),
  (3, 'ผ้าเช็ดเท้า', 'Bath Mat', 'bath', true, 3),
  (4, 'ผ้าปูเล็ก', 'Single Bed Sheet', 'bed', true, 4),
  (5, 'ผ้าปูกลาง', 'Double Bed Sheet', 'bed', true, 5),
  (6, 'ผ้าปูใหญ่', 'King Bed Sheet', 'bed', true, 6),
  (7, 'ปลอกผ้านวมเล็ก', 'Single Duvet Cover', 'bed', true, 7),
  (8, 'ปลอกผ้านวมกลาง', 'Double Duvet Cover', 'bed', true, 8),
  (9, 'ปลอกผ้านวมใหญ่', 'King Duvet Cover', 'bed', true, 9),
  (10, 'รองกันเปื้อนเล็ก', 'Single Mattress Protector', 'bed', false, 10),
  (11, 'รองกันเปื้อนกลาง', 'Double Mattress Protector', 'bed', false, 11),
  (12, 'รองกันเปื้อนใหญ่', 'King Mattress Protector', 'bed', false, 12),
  (13, 'ผ้าห่มเล็ก', 'Single Blanket', 'bed', false, 13),
  (14, 'ผ้าห่มกลาง', 'Double Blanket', 'bed', false, 14),
  (15, 'ผ้าห่มใหญ่', 'King Blanket', 'bed', false, 15),
  (16, 'หมอน', 'Pillow', 'bed', false, 16)
on conflict (item_number) do update set
  name_th = excluded.name_th,
  name_en = excluded.name_en,
  category = excluded.category,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

with setup(room_type_code, item_number, qty) as (
  values
    ('TS', 1, 2), ('TS', 2, 2), ('TS', 3, 0), ('TS', 4, 2), ('TS', 5, 0), ('TS', 6, 0), ('TS', 7, 2), ('TS', 8, 0), ('TS', 9, 0),
    ('DS', 1, 2), ('DS', 2, 2), ('DS', 3, 0), ('DS', 4, 0), ('DS', 5, 1), ('DS', 6, 0), ('DS', 7, 0), ('DS', 8, 1), ('DS', 9, 0),
    ('DQ', 1, 2), ('DQ', 2, 2), ('DQ', 3, 1), ('DQ', 4, 0), ('DQ', 5, 1), ('DQ', 6, 0), ('DQ', 7, 0), ('DQ', 8, 1), ('DQ', 9, 0),
    ('DT', 1, 2), ('DT', 2, 2), ('DT', 3, 1), ('DT', 4, 2), ('DT', 5, 0), ('DT', 6, 0), ('DT', 7, 2), ('DT', 8, 0), ('DT', 9, 0),
    ('JS', 1, 2), ('JS', 2, 2), ('JS', 3, 1), ('JS', 4, 0), ('JS', 5, 0), ('JS', 6, 1), ('JS', 7, 0), ('JS', 8, 0), ('JS', 9, 1),
    ('TB', 1, 3), ('TB', 2, 3), ('TB', 3, 1), ('TB', 4, 3), ('TB', 5, 0), ('TB', 6, 0), ('TB', 7, 3), ('TB', 8, 0), ('TB', 9, 0),
    ('FR', 1, 3), ('FR', 2, 3), ('FR', 3, 1), ('FR', 4, 1), ('FR', 5, 0), ('FR', 6, 1), ('FR', 7, 1), ('FR', 8, 0), ('FR', 9, 1)
)
insert into public.room_linen_setups (room_type_code, linen_item_id, qty)
select setup.room_type_code, li.id, setup.qty
from setup
join public.linen_items li on li.item_number = setup.item_number
where li.is_active = true
on conflict (room_type_code, linen_item_id) do update set
  qty = excluded.qty;

with setup(item_number, qty_per_room) as (
  values (1, 2), (2, 2), (5, 1)
)
insert into public.linen_dayuse_setup (linen_item_id, qty_per_room)
select li.id, setup.qty_per_room
from setup
join public.linen_items li on li.item_number = setup.item_number
on conflict (linen_item_id) do update set
  qty_per_room = excluded.qty_per_room;

with rules(category, item_number, percentage, use_checklist, notes) as (
  values
    ('checkout_serviced', 1, 100, false, null),
    ('checkout_serviced', 2, 100, false, null),
    ('checkout_serviced', 3, 100, false, null),
    ('checkout_serviced', 4, 100, false, null),
    ('checkout_serviced', 5, 100, false, null),
    ('checkout_serviced', 6, 100, false, null),
    ('checkout_serviced', 7, 50, false, 'ปลอกผ้านวมไม่เปลี่ยนทุกห้อง'),
    ('checkout_serviced', 8, 50, false, 'ปลอกผ้านวมไม่เปลี่ยนทุกห้อง'),
    ('checkout_serviced', 9, 50, false, 'ปลอกผ้านวมไม่เปลี่ยนทุกห้อง'),
    ('checkout_towel_only', 1, 0, false, null),
    ('checkout_towel_only', 2, 100, false, 'FO รวบรวมผ้าขนหนูก่อน cutoff'),
    ('checkout_towel_only', 3, 0, false, null),
    ('checkout_towel_only', 4, 0, false, null),
    ('checkout_towel_only', 5, 0, false, null),
    ('checkout_towel_only', 6, 0, false, null),
    ('checkout_towel_only', 7, 0, false, null),
    ('checkout_towel_only', 8, 0, false, null),
    ('checkout_towel_only', 9, 0, false, null),
    ('inhouse_serviced', 1, 100, false, null),
    ('inhouse_serviced', 2, 0, true, 'ใช้ยอดจาก HK checklist'),
    ('inhouse_serviced', 3, 100, false, null),
    ('inhouse_serviced', 4, 80, false, 'บางห้องไม่เปลี่ยนผ้าปู'),
    ('inhouse_serviced', 5, 80, false, 'บางห้องไม่เปลี่ยนผ้าปู'),
    ('inhouse_serviced', 6, 80, false, 'บางห้องไม่เปลี่ยนผ้าปู'),
    ('inhouse_serviced', 7, 50, false, 'ปลอกผ้านวมไม่เปลี่ยนทุกห้อง'),
    ('inhouse_serviced', 8, 50, false, 'ปลอกผ้านวมไม่เปลี่ยนทุกห้อง'),
    ('inhouse_serviced', 9, 50, false, 'ปลอกผ้านวมไม่เปลี่ยนทุกห้อง'),
    ('inhouse_not_started', 1, 0, false, null),
    ('inhouse_not_started', 2, 0, false, null),
    ('inhouse_not_started', 3, 0, false, null),
    ('inhouse_not_started', 4, 0, false, null),
    ('inhouse_not_started', 5, 0, false, null),
    ('inhouse_not_started', 6, 0, false, null),
    ('inhouse_not_started', 7, 0, false, null),
    ('inhouse_not_started', 8, 0, false, null),
    ('inhouse_not_started', 9, 0, false, null),
    ('inhouse_no_task', 1, 0, false, null),
    ('inhouse_no_task', 2, 0, false, null),
    ('inhouse_no_task', 3, 0, false, null),
    ('inhouse_no_task', 4, 0, false, null),
    ('inhouse_no_task', 5, 0, false, null),
    ('inhouse_no_task', 6, 0, false, null),
    ('inhouse_no_task', 7, 0, false, null),
    ('inhouse_no_task', 8, 0, false, null),
    ('inhouse_no_task', 9, 0, false, null),
    ('inhouse_no_service', 1, 0, false, null),
    ('inhouse_no_service', 2, 0, true, 'ใช้ยอดจาก HK checklist ถ้ามี'),
    ('inhouse_no_service', 3, 0, false, null),
    ('inhouse_no_service', 4, 0, false, null),
    ('inhouse_no_service', 5, 0, false, null),
    ('inhouse_no_service', 6, 0, false, null),
    ('inhouse_no_service', 7, 0, false, null),
    ('inhouse_no_service', 8, 0, false, null),
    ('inhouse_no_service', 9, 0, false, null),
    ('after_cutoff', 1, 0, false, 'นับเป็นพรุ่งนี้'),
    ('after_cutoff', 2, 0, false, 'นับเป็นพรุ่งนี้'),
    ('after_cutoff', 3, 0, false, 'นับเป็นพรุ่งนี้'),
    ('after_cutoff', 4, 0, false, 'นับเป็นพรุ่งนี้'),
    ('after_cutoff', 5, 0, false, 'นับเป็นพรุ่งนี้'),
    ('after_cutoff', 6, 0, false, 'นับเป็นพรุ่งนี้'),
    ('after_cutoff', 7, 0, false, 'นับเป็นพรุ่งนี้'),
    ('after_cutoff', 8, 0, false, 'นับเป็นพรุ่งนี้'),
    ('after_cutoff', 9, 0, false, 'นับเป็นพรุ่งนี้')
)
insert into public.linen_usage_rules (category, linen_item_id, percentage, use_checklist, notes)
select rules.category, li.id, rules.percentage, rules.use_checklist, rules.notes
from rules
join public.linen_items li on li.item_number = rules.item_number
where li.is_active = true
on conflict (category, linen_item_id) do update set
  percentage = excluded.percentage,
  use_checklist = excluded.use_checklist,
  notes = excluded.notes;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604160003_phase66_linen_batch_operations.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create table if not exists public.laundry_batches (
  id uuid primary key default gen_random_uuid(),
  business_date date not null,
  pickup_round smallint not null default 1 check (pickup_round > 0),
  vendor_name text,
  status text not null default 'draft' check (status in (
    'draft',
    'fo_dirty_counted',
    'fo_return_counted',
    'vendor_signed',
    'fo_return_signed',
    'closed',
    'partial',
    'disputed'
  )),
  cutoff_time time default '11:00',
  vendor_pickup_signature_url text,
  fo_return_signature_url text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (business_date, pickup_round)
);

create table if not exists public.laundry_batch_items (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.laundry_batches(id) on delete cascade,
  linen_item_id int not null references public.linen_items(id),
  is_dayuse boolean not null default false,
  estimated_qty smallint not null default 0 check (estimated_qty >= 0),
  sent_by_hotel smallint not null default 0 check (sent_by_hotel >= 0),
  received_back smallint not null default 0 check (received_back >= 0),
  damaged_qty smallint not null default 0 check (damaged_qty >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  unique (batch_id, linen_item_id, is_dayuse)
);

create table if not exists public.laundry_batch_events (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.laundry_batches(id) on delete cascade,
  event_type text not null check (event_type in (
    'created',
    'fo_dirty_counted',
    'fo_return_counted',
    'vendor_signed',
    'fo_return_signed',
    'vendor_shop_confirmed',
    'closed',
    'partial_closed',
    'disputed',
    'reopened',
    'dayuse_added',
    'pending_resolved'
  )),
  actor_name text,
  actor_role text check (actor_role in ('fo', 'vendor', 'admin')),
  data jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.laundry_vendor_tokens (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.laundry_batches(id) on delete cascade,
  token uuid not null default gen_random_uuid() unique,
  vendor_name text,
  expires_at timestamptz not null,
  revoked boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.laundry_pending_items (
  id uuid primary key default gen_random_uuid(),
  source_batch_id uuid not null references public.laundry_batches(id),
  linen_item_id int not null references public.linen_items(id),
  pending_qty smallint not null check (pending_qty > 0),
  created_by_batch_id uuid references public.laundry_batches(id),
  resolved_batch_id uuid references public.laundry_batches(id),
  resolved_at timestamptz,
  reason text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.linen_dayuse_pending (
  id uuid primary key default gen_random_uuid(),
  linen_item_id int not null references public.linen_items(id) unique,
  qty_accumulated smallint not null default 0 check (qty_accumulated >= 0),
  last_added_date date,
  sent_in_batch_id uuid references public.laundry_batches(id),
  sent_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_laundry_batches_date on public.laundry_batches (business_date);
create index if not exists idx_laundry_batches_status on public.laundry_batches (status);
create index if not exists idx_laundry_batch_items_batch on public.laundry_batch_items (batch_id);
create index if not exists idx_laundry_batch_events_batch on public.laundry_batch_events (batch_id);
create index if not exists idx_laundry_vendor_tokens_token on public.laundry_vendor_tokens (token);
create index if not exists idx_laundry_vendor_tokens_batch on public.laundry_vendor_tokens (batch_id);
create index if not exists idx_laundry_pending_items_source on public.laundry_pending_items (source_batch_id);
create index if not exists idx_laundry_pending_items_created_by on public.laundry_pending_items (created_by_batch_id);
create index if not exists idx_laundry_pending_items_unresolved on public.laundry_pending_items (resolved_at) where resolved_at is null;

drop trigger if exists trg_laundry_batches_updated_at on public.laundry_batches;
create trigger trg_laundry_batches_updated_at
before update on public.laundry_batches
for each row execute function public.set_updated_at();

alter table public.laundry_batches enable row level security;
alter table public.laundry_batch_items enable row level security;
alter table public.laundry_batch_events enable row level security;
alter table public.laundry_vendor_tokens enable row level security;
alter table public.laundry_pending_items enable row level security;
alter table public.linen_dayuse_pending enable row level security;

drop policy if exists laundry_batches_auth on public.laundry_batches;
create policy laundry_batches_auth on public.laundry_batches
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists laundry_batch_items_auth on public.laundry_batch_items;
create policy laundry_batch_items_auth on public.laundry_batch_items
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists laundry_batch_events_auth on public.laundry_batch_events;
create policy laundry_batch_events_auth on public.laundry_batch_events
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists laundry_vendor_tokens_auth on public.laundry_vendor_tokens;
create policy laundry_vendor_tokens_auth on public.laundry_vendor_tokens
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists laundry_pending_items_auth on public.laundry_pending_items;
create policy laundry_pending_items_auth on public.laundry_pending_items
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists linen_dayuse_pending_auth on public.linen_dayuse_pending;
create policy linen_dayuse_pending_auth on public.linen_dayuse_pending
  for all to authenticated
  using (true)
  with check (true);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604170001_phase66_2_monthly.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 66.2: Monthly linen reconciliation, vendor rates, and month close.

-- 1. Rename inactive extra items 13-15 per user lock-in.
update public.linen_items
set name_th = 'ไส้นวมเล็ก', name_en = 'Single Comforter'
where item_number = 13;

update public.linen_items
set name_th = 'ไส้นวมกลาง', name_en = 'Double Comforter'
where item_number = 14;

update public.linen_items
set name_th = 'ไส้นวมใหญ่', name_en = 'King Comforter'
where item_number = 15;

-- 2. Vendor rate history by effective month.
create table if not exists public.linen_item_rates (
  id uuid primary key default gen_random_uuid(),
  linen_item_id int not null references public.linen_items(id) on delete cascade,
  effective_month date not null check (extract(day from effective_month) = 1),
  rate_per_piece numeric(10, 2) not null check (rate_per_piece >= 0),
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  created_by uuid references auth.users(id),
  unique (linen_item_id, effective_month)
);

create index if not exists idx_linen_item_rates_item_month
  on public.linen_item_rates (linen_item_id, effective_month desc);

alter table public.linen_item_rates enable row level security;

drop policy if exists linen_item_rates_read on public.linen_item_rates;
create policy linen_item_rates_read on public.linen_item_rates
  for select to authenticated
  using (true);

drop policy if exists linen_item_rates_admin_write on public.linen_item_rates;
create policy linen_item_rates_admin_write on public.linen_item_rates
  for all to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and lower(coalesce(p.role::text, '')) in ('admin', 'supervisor')
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and lower(coalesce(p.role::text, '')) in ('admin', 'supervisor')
    )
  );

with seed(item_number, rate) as (values
  (1, 3), (2, 5), (3, 3), (4, 8), (5, 9), (6, 9),
  (7, 15), (8, 20), (9, 20),
  (10, 30), (11, 30), (12, 30),
  (13, 30), (14, 40), (15, 40), (16, 50)
)
insert into public.linen_item_rates (linen_item_id, effective_month, rate_per_piece, note)
select li.id, date '2026-04-01', seed.rate, 'Initial seed from Phase 66.2'
from seed
join public.linen_items li on li.item_number = seed.item_number
on conflict (linen_item_id, effective_month) do update
set rate_per_piece = excluded.rate_per_piece,
    note = excluded.note;

-- 3. Month close state.
create table if not exists public.laundry_monthly_close (
  id uuid primary key default gen_random_uuid(),
  year smallint not null,
  month smallint not null check (month between 1 and 12),
  closed_at timestamptz not null default timezone('utc', now()),
  closed_by uuid references auth.users(id),
  total_pieces int not null,
  total_baht numeric(12, 2) not null,
  reopened_at timestamptz,
  reopened_by uuid references auth.users(id),
  reopen_reason text,
  unique (year, month)
);

create index if not exists idx_laundry_monthly_close_open
  on public.laundry_monthly_close (year, month)
  where reopened_at is null;

alter table public.laundry_monthly_close enable row level security;

drop policy if exists laundry_monthly_close_read on public.laundry_monthly_close;
create policy laundry_monthly_close_read on public.laundry_monthly_close
  for select to authenticated
  using (true);

drop policy if exists laundry_monthly_close_admin_write on public.laundry_monthly_close;
create policy laundry_monthly_close_admin_write on public.laundry_monthly_close
  for all to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and lower(coalesce(p.role::text, '')) in ('admin', 'supervisor')
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and lower(coalesce(p.role::text, '')) in ('admin', 'supervisor')
    )
  );

-- 4. Variance thresholds.
create table if not exists public.linen_variance_config (
  id smallint primary key default 1 check (id = 1),
  green_min smallint not null default 90,
  green_max smallint not null default 110,
  yellow_min smallint not null default 70,
  yellow_max smallint not null default 130,
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references auth.users(id),
  check (yellow_min <= green_min),
  check (green_min <= green_max),
  check (green_max <= yellow_max)
);

insert into public.linen_variance_config (id) values (1)
on conflict (id) do nothing;

alter table public.linen_variance_config enable row level security;

drop policy if exists linen_variance_config_read on public.linen_variance_config;
create policy linen_variance_config_read on public.linen_variance_config
  for select to authenticated
  using (true);

drop policy if exists linen_variance_config_admin_write on public.linen_variance_config;
create policy linen_variance_config_admin_write on public.linen_variance_config
  for all to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and lower(coalesce(p.role::text, '')) in ('admin', 'supervisor')
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and lower(coalesce(p.role::text, '')) in ('admin', 'supervisor')
    )
  );

-- 5. Rate lookup helper. Carry-forward is automatic by latest effective month.
create or replace function public.fn_linen_rate(p_linen_item_id int, p_business_date date)
returns numeric(10, 2)
language sql
stable
as $$
  select coalesce((
    select r.rate_per_piece
    from public.linen_item_rates r
    where r.linen_item_id = p_linen_item_id
      and r.effective_month <= date_trunc('month', p_business_date)::date
    order by r.effective_month desc
    limit 1
  ), 0)::numeric(10, 2);
$$;

-- 6. Monthly summary RPC. Billing canonical is sent_by_hotel, not received_back.
create or replace function public.fn_linen_monthly_summary(p_year int, p_month int)
returns table (
  linen_item_id int,
  item_number smallint,
  name_th text,
  name_en text,
  rate numeric,
  qty_sent bigint,
  qty_returned bigint,
  qty_pending bigint,
  qty_extra bigint,
  qty_dayuse bigint,
  total_baht numeric
)
language sql
stable
as $$
  with bounds as (
    select make_date(p_year, p_month, 1) as start_date,
           (make_date(p_year, p_month, 1) + interval '1 month')::date as end_date
  ),
  item_agg as (
    select
      i.linen_item_id,
      sum(case when i.is_dayuse is false then i.sent_by_hotel else 0 end)::bigint as qty_sent,
      sum(case when i.is_dayuse is false then i.received_back else 0 end)::bigint as qty_returned,
      sum(case when i.is_dayuse is false and li.item_number in (1, 2)
          then greatest(i.sent_by_hotel - i.estimated_qty, 0)
          else 0 end)::bigint as qty_extra,
      sum(case when i.is_dayuse is true then i.sent_by_hotel else 0 end)::bigint as qty_dayuse
    from public.laundry_batches b
    join public.laundry_batch_items i on i.batch_id = b.id
    join public.linen_items li on li.id = i.linen_item_id
    cross join bounds
    where b.business_date >= bounds.start_date
      and b.business_date < bounds.end_date
    group by i.linen_item_id
  )
  select
    li.id as linen_item_id,
    li.item_number,
    li.name_th,
    li.name_en,
    public.fn_linen_rate(li.id, bounds.start_date) as rate,
    coalesce(a.qty_sent, 0) as qty_sent,
    coalesce(a.qty_returned, 0) as qty_returned,
    greatest(coalesce(a.qty_sent, 0) - coalesce(a.qty_returned, 0), 0) as qty_pending,
    coalesce(a.qty_extra, 0) as qty_extra,
    coalesce(a.qty_dayuse, 0) as qty_dayuse,
    (public.fn_linen_rate(li.id, bounds.start_date) * coalesce(a.qty_sent, 0))::numeric(12, 2) as total_baht
  from public.linen_items li
  cross join bounds
  left join item_agg a on a.linen_item_id = li.id
  order by li.item_number;
$$;

-- 7. Daily grid RPC. Returns a full item x day matrix with zeros.
create or replace function public.fn_linen_monthly_daily(p_year int, p_month int)
returns table (
  linen_item_id int,
  item_number smallint,
  day_of_month int,
  qty_sent bigint
)
language sql
stable
as $$
  with bounds as (
    select make_date(p_year, p_month, 1) as start_date,
           (make_date(p_year, p_month, 1) + interval '1 month')::date as end_date
  ),
  days as (
    select generate_series(bounds.start_date, bounds.end_date - 1, interval '1 day')::date as business_date
    from bounds
  ),
  agg as (
    select i.linen_item_id, b.business_date, sum(i.sent_by_hotel)::bigint as qty_sent
    from public.laundry_batches b
    join public.laundry_batch_items i on i.batch_id = b.id
    cross join bounds
    where b.business_date >= bounds.start_date
      and b.business_date < bounds.end_date
      and i.is_dayuse is false
    group by i.linen_item_id, b.business_date
  )
  select
    li.id as linen_item_id,
    li.item_number,
    extract(day from days.business_date)::int as day_of_month,
    coalesce(agg.qty_sent, 0) as qty_sent
  from public.linen_items li
  cross join days
  left join agg on agg.linen_item_id = li.id and agg.business_date = days.business_date
  order by li.item_number, day_of_month;
$$;

create or replace function public.fn_linen_month_is_closed(p_business_date date)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.laundry_monthly_close c
    where c.year = extract(year from p_business_date)::int
      and c.month = extract(month from p_business_date)::int
      and c.reopened_at is null
  );
$$;

-- 8. Close/reopen RPCs. API layer performs admin role checks before calling.
create or replace function public.fn_linen_monthly_close(p_year int, p_month int, p_actor uuid default auth.uid())
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start date := make_date(p_year, p_month, 1);
  v_end date := (make_date(p_year, p_month, 1) + interval '1 month')::date;
  v_disputed jsonb;
  v_pending jsonb;
  v_open jsonb;
  v_errors text[] := array[]::text[];
  v_total_pieces int := 0;
  v_total_baht numeric(12, 2) := 0;
  v_close public.laundry_monthly_close%rowtype;
begin
  select coalesce(jsonb_agg(b.id::text order by b.business_date, b.pickup_round), '[]'::jsonb)
  into v_disputed
  from public.laundry_batches b
  where b.business_date >= v_start
    and b.business_date < v_end
    and b.status = 'disputed';

  if jsonb_array_length(v_disputed) > 0 then
    v_errors := array_append(v_errors, 'dispute_exists');
  end if;

  select coalesce(jsonb_agg(p.id::text order by b.business_date, b.pickup_round), '[]'::jsonb)
  into v_pending
  from public.laundry_pending_items p
  join public.laundry_batches b on b.id = p.source_batch_id
  where p.resolved_batch_id is null
    and b.business_date >= v_start
    and b.business_date < v_end;

  if jsonb_array_length(v_pending) > 0 then
    v_errors := array_append(v_errors, 'pending_exists');
  end if;

  select coalesce(jsonb_agg(b.id::text order by b.business_date, b.pickup_round), '[]'::jsonb)
  into v_open
  from public.laundry_batches b
  where b.business_date >= v_start
    and b.business_date < v_end
    and b.status not in ('closed', 'partial');

  if jsonb_array_length(v_open) > 0 then
    v_errors := array_append(v_errors, 'open_batch_exists');
  end if;

  if array_length(v_errors, 1) is not null then
    return jsonb_build_object(
      'success', false,
      'close', null,
      'errors', to_jsonb(v_errors),
      'error_details', jsonb_build_object(
        'disputed_batch_ids', v_disputed,
        'pending_item_ids', v_pending,
        'open_batch_ids', v_open
      )
    );
  end if;

  select
    coalesce(sum(i.sent_by_hotel), 0)::int,
    coalesce(sum(i.sent_by_hotel * public.fn_linen_rate(i.linen_item_id, b.business_date)), 0)::numeric(12, 2)
  into v_total_pieces, v_total_baht
  from public.laundry_batches b
  join public.laundry_batch_items i on i.batch_id = b.id
  where b.business_date >= v_start
    and b.business_date < v_end;

  insert into public.laundry_monthly_close (
    year, month, closed_at, closed_by, total_pieces, total_baht,
    reopened_at, reopened_by, reopen_reason
  )
  values (p_year, p_month, timezone('utc', now()), p_actor, v_total_pieces, v_total_baht, null, null, null)
  on conflict (year, month) do update set
    closed_at = excluded.closed_at,
    closed_by = excluded.closed_by,
    total_pieces = excluded.total_pieces,
    total_baht = excluded.total_baht,
    reopened_at = null,
    reopened_by = null,
    reopen_reason = null
  returning * into v_close;

  return jsonb_build_object('success', true, 'close', to_jsonb(v_close));
end;
$$;

create or replace function public.fn_linen_monthly_reopen(p_year int, p_month int, p_reason text, p_actor uuid default auth.uid())
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_close public.laundry_monthly_close%rowtype;
begin
  update public.laundry_monthly_close
  set reopened_at = timezone('utc', now()),
      reopened_by = p_actor,
      reopen_reason = nullif(trim(p_reason), '')
  where year = p_year
    and month = p_month
    and reopened_at is null
  returning * into v_close;

  if v_close.id is null then
    return jsonb_build_object('success', false, 'close', null, 'error', 'month_not_closed');
  end if;

  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, after_json)
  values (
    p_actor,
    'linen_monthly_reopened',
    'laundry_monthly_close',
    v_close.id::text,
    jsonb_build_object('year', p_year, 'month', p_month, 'reason', p_reason)
  );

  return jsonb_build_object('success', true, 'close', to_jsonb(v_close));
end;
$$;

-- 9. Freeze guards for closed months.
create or replace function public.fn_laundry_batches_freeze_closed_month()
returns trigger
language plpgsql
as $$
declare
  v_date date;
begin
  v_date := case when tg_op = 'DELETE' then old.business_date else new.business_date end;
  if public.fn_linen_month_is_closed(v_date) then
    raise exception 'Linen month % is closed. Reopen month before editing.', to_char(v_date, 'YYYY-MM')
      using errcode = 'P0001';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.fn_laundry_batch_items_freeze_closed_month()
returns trigger
language plpgsql
as $$
declare
  v_old_date date;
  v_new_date date;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    select b.business_date into v_old_date from public.laundry_batches b where b.id = old.batch_id;
    if v_old_date is not null and public.fn_linen_month_is_closed(v_old_date) then
      raise exception 'Linen month % is closed. Reopen month before editing.', to_char(v_old_date, 'YYYY-MM')
        using errcode = 'P0001';
    end if;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select b.business_date into v_new_date from public.laundry_batches b where b.id = new.batch_id;
    if v_new_date is not null and public.fn_linen_month_is_closed(v_new_date) then
      raise exception 'Linen month % is closed. Reopen month before editing.', to_char(v_new_date, 'YYYY-MM')
        using errcode = 'P0001';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function public.fn_linen_item_rates_freeze_closed_month()
returns trigger
language plpgsql
as $$
declare
  v_old_month date;
  v_new_month date;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    v_old_month := old.effective_month;
    if public.fn_linen_month_is_closed(v_old_month) then
      raise exception 'Linen month % is closed. Reopen month before editing rates.', to_char(v_old_month, 'YYYY-MM')
        using errcode = 'P0001';
    end if;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    v_new_month := new.effective_month;
    if public.fn_linen_month_is_closed(v_new_month) then
      raise exception 'Linen month % is closed. Reopen month before editing rates.', to_char(v_new_month, 'YYYY-MM')
        using errcode = 'P0001';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_laundry_batches_freeze_closed_month on public.laundry_batches;
create trigger trg_laundry_batches_freeze_closed_month
before insert or update or delete on public.laundry_batches
for each row execute function public.fn_laundry_batches_freeze_closed_month();

drop trigger if exists trg_laundry_batch_items_freeze_closed_month on public.laundry_batch_items;
create trigger trg_laundry_batch_items_freeze_closed_month
before insert or update or delete on public.laundry_batch_items
for each row execute function public.fn_laundry_batch_items_freeze_closed_month();

drop trigger if exists trg_linen_item_rates_freeze_closed_month on public.linen_item_rates;
create trigger trg_linen_item_rates_freeze_closed_month
before insert or update or delete on public.linen_item_rates
for each row execute function public.fn_linen_item_rates_freeze_closed_month();

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604170002_phase66_3_rewash.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 66.3: Rewash flow, monthly reopen audit, and linen edit audit.

-- ─── Rewash Events ────────────────────────────────────────────────────────────
create table if not exists public.laundry_rewash_events (
  id bigserial primary key,
  sent_in_batch_id uuid not null references public.laundry_batches(id) on delete cascade,
  linen_item_id int not null references public.linen_items(id),
  is_dayuse boolean not null default false,
  qty int not null check (qty > 0),
  photo_keys text[] not null default '{}'::text[],
  status text not null default 'pending' check (status in ('pending', 'resolved', 'expired')),
  resolved_batch_id uuid references public.laundry_batches(id),
  resolved_qty int check (resolved_qty is null or resolved_qty >= 0),
  resolved_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default timezone('utc', now()),
  note text,
  check (status <> 'pending' or coalesce(array_length(photo_keys, 1), 0) >= 1)
);

create index if not exists idx_rewash_sent_batch
  on public.laundry_rewash_events(sent_in_batch_id);
create index if not exists idx_rewash_resolved_batch
  on public.laundry_rewash_events(resolved_batch_id);
create index if not exists idx_rewash_status
  on public.laundry_rewash_events(status)
  where status = 'pending';
create index if not exists idx_rewash_created_at
  on public.laundry_rewash_events(created_at);

alter table public.laundry_rewash_events enable row level security;

drop policy if exists rewash_all_auth on public.laundry_rewash_events;
create policy rewash_all_auth on public.laundry_rewash_events
  for all to authenticated
  using (true)
  with check (true);

-- ─── Monthly Reopen Log ───────────────────────────────────────────────────────
create table if not exists public.linen_month_close_reopen_log (
  id bigserial primary key,
  year int not null,
  month int not null check (month between 1 and 12),
  close_id uuid references public.laundry_monthly_close(id),
  reopened_by uuid not null references auth.users(id),
  reopened_at timestamptz not null default timezone('utc', now()),
  reason text not null check (char_length(trim(reason)) >= 10),
  reclosed_at timestamptz,
  reclosed_by uuid references auth.users(id)
);

create index if not exists idx_reopen_log_ym
  on public.linen_month_close_reopen_log(year, month);
create index if not exists idx_reopen_log_close
  on public.linen_month_close_reopen_log(close_id);

alter table public.linen_month_close_reopen_log enable row level security;

drop policy if exists reopen_log_all_auth on public.linen_month_close_reopen_log;
create policy reopen_log_all_auth on public.linen_month_close_reopen_log
  for all to authenticated
  using (true)
  with check (true);

-- ─── Edit Audit Log ───────────────────────────────────────────────────────────
create table if not exists public.linen_edit_audit_log (
  id bigserial primary key,
  batch_id uuid references public.laundry_batches(id) on delete cascade,
  rate_id uuid references public.linen_item_rates(id),
  entity_type text not null check (entity_type in ('batch_item', 'return_item', 'extra_item', 'rewash_event', 'rate', 'note')),
  entity_id text,
  field_name text not null,
  old_value text,
  new_value text,
  reason text,
  edited_by uuid not null references auth.users(id),
  edited_at timestamptz not null default timezone('utc', now()),
  check (batch_id is not null or rate_id is not null or entity_type = 'note')
);

create index if not exists idx_edit_log_batch
  on public.linen_edit_audit_log(batch_id);
create index if not exists idx_edit_log_rate
  on public.linen_edit_audit_log(rate_id);
create index if not exists idx_edit_log_edited_at
  on public.linen_edit_audit_log(edited_at);

alter table public.linen_edit_audit_log enable row level security;

drop policy if exists edit_log_all_auth on public.linen_edit_audit_log;
create policy edit_log_all_auth on public.linen_edit_audit_log
  for all to authenticated
  using (true)
  with check (true);

-- ─── Reopen Count on Existing Monthly Close Table ─────────────────────────────
alter table public.laundry_monthly_close
  add column if not exists reopen_count int not null default 0,
  add column if not exists last_reopened_at timestamptz,
  add column if not exists last_reopen_reason text;

-- Allow rewash events to be visible in the existing batch event timeline.
alter table public.laundry_batch_events
  drop constraint if exists laundry_batch_events_event_type_check;

alter table public.laundry_batch_events
  add constraint laundry_batch_events_event_type_check
  check (event_type in (
    'created',
    'fo_dirty_counted',
    'fo_return_counted',
    'vendor_signed',
    'fo_return_signed',
    'vendor_shop_confirmed',
    'closed',
    'partial_closed',
    'disputed',
    'reopened',
    'dayuse_added',
    'pending_resolved',
    'rewash_created',
    'rewash_resolved',
    'rewash_expired',
    'edit_applied'
  ));

-- ─── Atomic Batch Create + Rewash RPC ─────────────────────────────────────────
create or replace function public.fn_create_laundry_batch_with_rewash(
  p_batch jsonb,
  p_items jsonb,
  p_rewash jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch public.laundry_batches%rowtype;
  v_item jsonb;
  v_rewash jsonb;
  v_rewash_event_ids bigint[] := array[]::bigint[];
  v_rewash_event_id bigint;
  v_created_by uuid := nullif(p_batch->>'created_by', '')::uuid;
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'items are required';
  end if;

  if p_rewash is null then
    p_rewash := '[]'::jsonb;
  end if;

  if jsonb_typeof(p_rewash) <> 'array' then
    raise exception 'rewash must be an array';
  end if;

  insert into public.laundry_batches (
    business_date,
    pickup_round,
    vendor_name,
    status,
    created_by,
    notes
  )
  values (
    (p_batch->>'business_date')::date,
    coalesce((p_batch->>'pickup_round')::smallint, 1),
    nullif(p_batch->>'vendor_name', ''),
    'fo_dirty_counted',
    v_created_by,
    nullif(p_batch->>'notes', '')
  )
  returning * into v_batch;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    insert into public.laundry_batch_items (
      batch_id,
      linen_item_id,
      is_dayuse,
      estimated_qty,
      sent_by_hotel
    )
    values (
      v_batch.id,
      (v_item->>'linen_item_id')::int,
      coalesce((v_item->>'is_dayuse')::boolean, false),
      greatest(coalesce((v_item->>'estimated_qty')::int, 0), 0),
      greatest(coalesce((v_item->>'sent_by_hotel')::int, 0), 0)
    );
  end loop;

  for v_rewash in select * from jsonb_array_elements(p_rewash)
  loop
    if coalesce(array_length(array(select jsonb_array_elements_text(v_rewash->'photo_keys')), 1), 0) < 1 then
      raise exception 'rewash photo_keys are required';
    end if;

    insert into public.laundry_rewash_events (
      sent_in_batch_id,
      linen_item_id,
      is_dayuse,
      qty,
      photo_keys,
      created_by,
      note
    )
    values (
      v_batch.id,
      (v_rewash->>'linen_item_id')::int,
      coalesce((v_rewash->>'is_dayuse')::boolean, false),
      (v_rewash->>'qty')::int,
      array(select jsonb_array_elements_text(v_rewash->'photo_keys')),
      v_created_by,
      nullif(v_rewash->>'note', '')
    )
    returning id into v_rewash_event_id;

    v_rewash_event_ids := array_append(v_rewash_event_ids, v_rewash_event_id);
  end loop;

  insert into public.laundry_batch_events (batch_id, event_type, actor_role, data)
  values
    (v_batch.id, 'created', 'fo', jsonb_build_object('pickup_round', v_batch.pickup_round)),
    (
      v_batch.id,
      'fo_dirty_counted',
      'fo',
      jsonb_build_object(
        'item_count',
        jsonb_array_length(p_items),
        'rewash_event_ids',
        to_jsonb(v_rewash_event_ids)
      )
    );

  if array_length(v_rewash_event_ids, 1) is not null then
    insert into public.laundry_batch_events (batch_id, event_type, actor_role, data)
    values (
      v_batch.id,
      'rewash_created',
      'fo',
      jsonb_build_object('rewash_event_ids', to_jsonb(v_rewash_event_ids))
    );
  end if;

  return jsonb_build_object(
    'batch_id',
    v_batch.id,
    'rewash_event_ids',
    to_jsonb(v_rewash_event_ids)
  );
end;
$$;

-- ─── Reclose/Reopen Functions (preserve reopened_at status model) ─────────────
create or replace function public.fn_linen_monthly_close(p_year int, p_month int, p_actor uuid default auth.uid())
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start date := make_date(p_year, p_month, 1);
  v_end date := (make_date(p_year, p_month, 1) + interval '1 month')::date;
  v_disputed jsonb;
  v_pending jsonb;
  v_open jsonb;
  v_errors text[] := array[]::text[];
  v_total_pieces int := 0;
  v_total_baht numeric(12, 2) := 0;
  v_close public.laundry_monthly_close%rowtype;
begin
  select coalesce(jsonb_agg(b.id::text order by b.business_date, b.pickup_round), '[]'::jsonb)
  into v_disputed
  from public.laundry_batches b
  where b.business_date >= v_start
    and b.business_date < v_end
    and b.status = 'disputed';

  if jsonb_array_length(v_disputed) > 0 then
    v_errors := array_append(v_errors, 'dispute_exists');
  end if;

  select coalesce(jsonb_agg(p.id::text order by b.business_date, b.pickup_round), '[]'::jsonb)
  into v_pending
  from public.laundry_pending_items p
  join public.laundry_batches b on b.id = p.source_batch_id
  where p.resolved_batch_id is null
    and b.business_date >= v_start
    and b.business_date < v_end;

  if jsonb_array_length(v_pending) > 0 then
    v_errors := array_append(v_errors, 'pending_exists');
  end if;

  select coalesce(jsonb_agg(b.id::text order by b.business_date, b.pickup_round), '[]'::jsonb)
  into v_open
  from public.laundry_batches b
  where b.business_date >= v_start
    and b.business_date < v_end
    and b.status not in ('closed', 'partial');

  if jsonb_array_length(v_open) > 0 then
    v_errors := array_append(v_errors, 'open_batch_exists');
  end if;

  if array_length(v_errors, 1) is not null then
    return jsonb_build_object(
      'success', false,
      'close', null,
      'errors', to_jsonb(v_errors),
      'error_details', jsonb_build_object(
        'disputed_batch_ids', v_disputed,
        'pending_item_ids', v_pending,
        'open_batch_ids', v_open
      )
    );
  end if;

  select
    coalesce(sum(i.sent_by_hotel), 0)::int,
    coalesce(sum(i.sent_by_hotel * public.fn_linen_rate(i.linen_item_id, b.business_date)), 0)::numeric(12, 2)
  into v_total_pieces, v_total_baht
  from public.laundry_batches b
  join public.laundry_batch_items i on i.batch_id = b.id
  where b.business_date >= v_start
    and b.business_date < v_end;

  insert into public.laundry_monthly_close (
    year, month, closed_at, closed_by, total_pieces, total_baht,
    reopened_at, reopened_by, reopen_reason
  )
  values (p_year, p_month, timezone('utc', now()), p_actor, v_total_pieces, v_total_baht, null, null, null)
  on conflict (year, month) do update set
    closed_at = excluded.closed_at,
    closed_by = excluded.closed_by,
    total_pieces = excluded.total_pieces,
    total_baht = excluded.total_baht,
    reopened_at = null,
    reopened_by = null,
    reopen_reason = null
  returning * into v_close;

  update public.linen_month_close_reopen_log
  set reclosed_at = timezone('utc', now()),
      reclosed_by = p_actor
  where close_id = v_close.id
    and reclosed_at is null;

  return jsonb_build_object('success', true, 'close', to_jsonb(v_close));
end;
$$;

create or replace function public.fn_linen_monthly_reopen(p_year int, p_month int, p_reason text, p_actor uuid default auth.uid())
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_close public.laundry_monthly_close%rowtype;
  v_reason text := trim(coalesce(p_reason, ''));
  v_log_id bigint;
begin
  if char_length(v_reason) < 10 then
    return jsonb_build_object('success', false, 'close', null, 'error', 'reason_too_short');
  end if;

  update public.laundry_monthly_close
  set reopened_at = timezone('utc', now()),
      reopened_by = p_actor,
      reopen_reason = v_reason,
      reopen_count = reopen_count + 1,
      last_reopened_at = timezone('utc', now()),
      last_reopen_reason = v_reason
  where year = p_year
    and month = p_month
    and reopened_at is null
  returning * into v_close;

  if v_close.id is null then
    return jsonb_build_object('success', false, 'close', null, 'error', 'month_not_closed');
  end if;

  insert into public.linen_month_close_reopen_log (
    year,
    month,
    close_id,
    reopened_by,
    reason
  )
  values (
    p_year,
    p_month,
    v_close.id,
    p_actor,
    v_reason
  )
  returning id into v_log_id;

  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, after_json)
  values (
    p_actor,
    'linen_monthly_reopened',
    'laundry_monthly_close',
    v_close.id::text,
    jsonb_build_object('year', p_year, 'month', p_month, 'reason', v_reason, 'log_id', v_log_id)
  );

  return jsonb_build_object('success', true, 'close', to_jsonb(v_close), 'log_id', v_log_id);
end;
$$;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604180001_phase68_1_linen_analytics.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 68.1: Linen analytics read helpers.
-- Predict baseline intentionally stays in TypeScript via calculateExpectedLinen().

create or replace function public.fn_linen_analytics_category_key(
  p_item_number int,
  p_name_en text
)
returns text
language sql
immutable
as $$
  select case p_item_number
    when 1 then 'linen.pillowcase'
    when 2 then 'linen.bath_towel'
    when 3 then 'linen.bath_mat'
    when 4 then 'linen.single_bed_sheet'
    when 5 then 'linen.double_bed_sheet'
    when 6 then 'linen.king_bed_sheet'
    when 7 then 'linen.single_duvet_cover'
    when 8 then 'linen.double_duvet_cover'
    when 9 then 'linen.king_duvet_cover'
    else 'linen.' || regexp_replace(lower(coalesce(p_name_en, p_item_number::text)), '[^a-z0-9]+', '_', 'g')
  end
$$;

create or replace function public.fn_linen_analytics_variance(
  p_start date,
  p_end date,
  p_categories text[] default null,
  p_room_types text[] default null
)
returns table (
  linen_item_id int,
  item_number text,
  name_th text,
  name_en text,
  category_key text,
  actual_qty numeric,
  predict_qty numeric,
  max_qty numeric,
  active_rooms int,
  days_in_period int
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select
      least(p_start, p_end) as start_date,
      greatest(p_start, p_end) as end_date,
      greatest((greatest(p_start, p_end) - least(p_start, p_end) + 1), 0)::int as days_in_period
  ),
  items as (
    select
      li.id,
      li.item_number,
      li.name_th,
      li.name_en,
      public.fn_linen_analytics_category_key(li.item_number, li.name_en) as category_key
    from public.linen_items li
    where li.is_active = true
      and (
        p_categories is null
        or cardinality(p_categories) = 0
        or public.fn_linen_analytics_category_key(li.item_number, li.name_en) = any(p_categories)
        or li.item_number::text = any(p_categories)
      )
  ),
  actuals as (
    select
      lbi.linen_item_id,
      coalesce(sum(lbi.sent_by_hotel), 0)::numeric as actual_qty
    from public.laundry_batches lb
    join public.laundry_batch_items lbi on lbi.batch_id = lb.id
    cross join params p
    where lb.business_date >= p.start_date
      and lb.business_date <= p.end_date
      and coalesce(lbi.is_dayuse, false) = false
    group by lbi.linen_item_id
  ),
  room_counts as (
    select
      rt.code as room_type_code,
      count(*)::int as active_rooms
    from public.rooms r
    join public.room_types rt on rt.id = r.room_type_id
    where r.is_sellable = true
      and coalesce(r.is_dayuse, false) = false
    group by rt.code
  ),
  max_daily as (
    select
      rls.linen_item_id,
      coalesce(sum(rls.qty * rc.active_rooms), 0)::numeric as daily_max,
      coalesce(sum(rc.active_rooms), 0)::int as active_rooms
    from public.room_linen_setups rls
    join room_counts rc on rc.room_type_code = rls.room_type_code
    group by rls.linen_item_id
  )
  select
    i.id as linen_item_id,
    i.item_number::text,
    i.name_th,
    i.name_en,
    i.category_key,
    coalesce(a.actual_qty, 0)::numeric as actual_qty,
    0::numeric as predict_qty,
    (coalesce(md.daily_max, 0) * p.days_in_period)::numeric as max_qty,
    coalesce(md.active_rooms, 0)::int as active_rooms,
    p.days_in_period
  from items i
  cross join params p
  left join actuals a on a.linen_item_id = i.id
  left join max_daily md on md.linen_item_id = i.id
  order by i.item_number;
$$;

create or replace function public.fn_linen_analytics_trend(
  p_start date,
  p_end date,
  p_window text default 'day',
  p_categories text[] default null,
  p_room_types text[] default null
)
returns table (
  period_start date,
  actual_qty numeric,
  predict_qty numeric,
  max_qty numeric,
  statistical_qty numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select least(p_start, p_end) as start_date, greatest(p_start, p_end) as end_date
  ),
  days as (
    select d::date as business_date
    from params p
    cross join generate_series(p.start_date, p.end_date, interval '1 day') d
  ),
  day_periods as (
    select
      business_date,
      case
        when p_window = 'week' then date_trunc('week', business_date)::date
        when p_window = 'month' then date_trunc('month', business_date)::date
        else business_date
      end as period_start
    from days
  ),
  item_filter as (
    select li.id
    from public.linen_items li
    where li.is_active = true
      and (
        p_categories is null
        or cardinality(p_categories) = 0
        or public.fn_linen_analytics_category_key(li.item_number, li.name_en) = any(p_categories)
        or li.item_number::text = any(p_categories)
      )
  ),
  actual_daily as (
    select
      lb.business_date,
      coalesce(sum(lbi.sent_by_hotel), 0)::numeric as actual_qty
    from public.laundry_batches lb
    join public.laundry_batch_items lbi on lbi.batch_id = lb.id
    join item_filter f on f.id = lbi.linen_item_id
    cross join params p
    where lb.business_date >= p.start_date
      and lb.business_date <= p.end_date
      and coalesce(lbi.is_dayuse, false) = false
    group by lb.business_date
  ),
  room_counts as (
    select rt.code as room_type_code, count(*)::int as active_rooms
    from public.rooms r
    join public.room_types rt on rt.id = r.room_type_id
    where r.is_sellable = true
      and coalesce(r.is_dayuse, false) = false
    group by rt.code
  ),
  max_daily as (
    select coalesce(sum(rls.qty * rc.active_rooms), 0)::numeric as daily_max
    from public.room_linen_setups rls
    join room_counts rc on rc.room_type_code = rls.room_type_code
    join item_filter f on f.id = rls.linen_item_id
  )
  select
    dp.period_start,
    coalesce(sum(ad.actual_qty), 0)::numeric as actual_qty,
    0::numeric as predict_qty,
    (count(*)::numeric * coalesce((select daily_max from max_daily), 0))::numeric as max_qty,
    null::numeric as statistical_qty
  from day_periods dp
  left join actual_daily ad on ad.business_date = dp.business_date
  group by dp.period_start
  order by dp.period_start;
$$;

grant execute on function public.fn_linen_analytics_category_key(int, text) to authenticated;
grant execute on function public.fn_linen_analytics_variance(date, date, text[], text[]) to authenticated;
grant execute on function public.fn_linen_analytics_trend(date, date, text, text[], text[]) to authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604180002_phase68_2a_amenity_recon.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 68.2a: FO Prepare/Return reconciliation for amenity analytics.

create table if not exists public.fo_prepare_batch_returns (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.fo_prepare_batches(id) on delete cascade,
  product_id uuid not null references public.products(id),
  prepared_qty numeric not null check (prepared_qty >= 0),
  returned_qty numeric not null default 0 check (returned_qty >= 0),
  damaged_qty numeric not null default 0 check (damaged_qty >= 0),
  consumed_qty numeric generated always as (prepared_qty - returned_qty - damaged_qty) stored,
  note text,
  recorded_by uuid references auth.users(id),
  recorded_at timestamptz not null default timezone('utc', now()),
  unique (batch_id, product_id),
  check (returned_qty + damaged_qty <= prepared_qty)
);

create index if not exists ix_fo_prepare_batch_returns_batch
  on public.fo_prepare_batch_returns(batch_id);
create index if not exists ix_fo_prepare_batch_returns_recorded
  on public.fo_prepare_batch_returns(recorded_at);
create index if not exists ix_fo_prepare_batch_returns_product_recorded
  on public.fo_prepare_batch_returns(product_id, recorded_at);

alter table public.fo_prepare_batch_returns enable row level security;

drop policy if exists fo_prepare_batch_returns_auth_all on public.fo_prepare_batch_returns;
create policy fo_prepare_batch_returns_auth_all
  on public.fo_prepare_batch_returns
  for all to authenticated
  using (true)
  with check (true);

alter table public.fo_prepare_batches
  add column if not exists return_status text not null default 'pending'
  check (return_status in ('pending', 'reconciled', 'legacy'));

update public.fo_prepare_batches
set return_status = 'legacy'
where return_status = 'pending';

create index if not exists idx_fo_prepare_batches_return_status
  on public.fo_prepare_batches(return_status);

create or replace view public.v_amenity_consumption_daily as
select
  b.business_date::date as business_date,
  r.product_id,
  p.name as product_name,
  sum(r.consumed_qty)::numeric as consumed_qty,
  sum(r.prepared_qty)::numeric as prepared_qty,
  sum(r.returned_qty)::numeric as returned_qty,
  sum(r.damaged_qty)::numeric as damaged_qty,
  count(distinct b.id)::int as batch_count
from public.fo_prepare_batch_returns r
join public.fo_prepare_batches b on b.id = r.batch_id
join public.products p on p.id = r.product_id
where b.return_status = 'reconciled'
  and p.stock_tracking_mode = 'amenity_prepare'
group by b.business_date, r.product_id, p.name;

create or replace function public.fn_fo_prepare_return_submit(
  p_batch_id uuid,
  p_returned_by text default null,
  p_return_note text default null,
  p_items jsonb default '[]'::jsonb,
  p_force boolean default false,
  p_override_note text default null,
  p_recorded_by uuid default auth.uid()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_actor text := nullif(trim(coalesce(p_returned_by, '')), '');
  v_note text := nullif(trim(coalesce(p_return_note, '')), '');
  v_override_note text := nullif(trim(coalesce(p_override_note, '')), '');
  v_batch public.fo_prepare_batches%rowtype;
  v_item jsonb;
  v_item_id uuid;
  v_return_qty int;
  v_damaged_qty int;
  v_item_note text;
  v_line public.fo_prepare_batch_items%rowtype;
  v_used_qty int;
  v_system_remaining int;
  v_floor_current int;
  v_main_current int;
  v_processed_count int := 0;
  v_expected_count int := 0;
  v_total_returned int := 0;
  v_total_damaged int := 0;
  v_total_consumed int := 0;
  v_seen_ids uuid[] := '{}'::uuid[];
begin
  if p_batch_id is null then
    raise exception 'p_batch_id is required';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'p_items must be non-empty array';
  end if;

  select *
  into v_batch
  from public.fo_prepare_batches
  where id = p_batch_id
  for update;

  if not found then
    raise exception 'FO prepare batch not found';
  end if;

  if v_batch.status <> 'prepared' then
    raise exception 'Batch status must be prepared (current: %)', v_batch.status;
  end if;

  select count(*)
  into v_expected_count
  from public.fo_prepare_batch_items
  where batch_id = p_batch_id
    and prepared_qty > 0;

  if v_expected_count = 0 then
    raise exception 'No prepared items found in batch';
  end if;

  delete from public.fo_prepare_batch_returns
  where batch_id = p_batch_id;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_item_id := null;
    v_return_qty := 0;
    v_damaged_qty := 0;
    v_item_note := null;

    begin
      v_item_id := (v_item ->> 'item_id')::uuid;
    exception when others then
      v_item_id := null;
    end;

    begin
      v_return_qty := greatest(coalesce((coalesce(v_item ->> 'return_qty', v_item ->> 'returned_qty'))::int, 0), 0);
    exception when others then
      v_return_qty := 0;
    end;

    begin
      v_damaged_qty := greatest(coalesce((v_item ->> 'damaged_qty')::int, 0), 0);
    exception when others then
      v_damaged_qty := 0;
    end;

    v_item_note := nullif(trim(coalesce(v_item ->> 'note', '')), '');

    if v_item_id is null then
      raise exception 'Each return item must include valid item_id';
    end if;

    if v_item_id = any(v_seen_ids) then
      raise exception 'Duplicate return item_id in payload: %', v_item_id;
    end if;
    v_seen_ids := array_append(v_seen_ids, v_item_id);

    select *
    into v_line
    from public.fo_prepare_batch_items
    where id = v_item_id
      and batch_id = p_batch_id
    for update;

    if not found then
      raise exception 'Batch item not found: %', v_item_id;
    end if;

    if v_return_qty + v_damaged_qty > v_line.prepared_qty then
      raise exception 'returned_qty + damaged_qty exceeds prepared_qty for item % (prepared %, return %, damaged %)',
        v_item_id, v_line.prepared_qty, v_return_qty, v_damaged_qty;
    end if;

    if v_damaged_qty > 0 and v_item_note is null then
      raise exception 'Damage note is required for item %', v_item_id;
    end if;

    select coalesce(sum(abs(st.quantity_change)), 0)::int
    into v_used_qty
    from public.stock_transactions_v2 st
    where st.transaction_date = v_batch.business_date
      and st.action = 'use'
      and st.reference_type = 'housekeeping_task'
      and st.product_id = v_line.product_id
      and st.floor_number = v_line.floor_number;

    v_system_remaining := greatest(v_line.prepared_qty - v_used_qty, 0);

    if (v_return_qty + v_damaged_qty) <> v_system_remaining and v_item_note is null then
      raise exception
        'Return note is required when return/damage differs from system remaining (item %: return %, damaged %, system %)',
        v_item_id, v_return_qty, v_damaged_qty, v_system_remaining;
    end if;

    select quantity
    into v_floor_current
    from public.floor_stock
    where floor_number = v_line.floor_number
      and product_id = v_line.product_id
    for update;

    if not found then
      v_floor_current := 0;
    end if;

    if v_return_qty + v_damaged_qty > v_floor_current then
      raise exception
        'insufficient floor stock for return/damage (item %, floor %, have %, return %, damaged %)',
        v_item_id, v_line.floor_number, v_floor_current, v_return_qty, v_damaged_qty;
    end if;

    insert into public.main_stock (product_id, quantity, reorder_level, updated_at)
    values (v_line.product_id, 0, 10, v_now)
    on conflict (product_id) do nothing;

    select quantity
    into v_main_current
    from public.main_stock
    where product_id = v_line.product_id
    for update;

    if v_return_qty > 0 then
      update public.floor_stock
      set quantity = greatest(quantity - v_return_qty, 0),
          updated_at = v_now
      where floor_number = v_line.floor_number
        and product_id = v_line.product_id;

      update public.main_stock
      set quantity = coalesce(v_main_current, 0) + v_return_qty,
          updated_at = v_now
      where product_id = v_line.product_id;

      insert into public.stock_transactions_v2 (
        transaction_date,
        product_id,
        action,
        quantity_change,
        from_location,
        to_location,
        reference_type,
        reference_id,
        floor_number,
        performed_by,
        note,
        created_at
      )
      values (
        v_batch.business_date,
        v_line.product_id,
        'return',
        v_return_qty,
        'floor_' || v_line.floor_number::text,
        'main',
        'fo_prepare_return',
        p_batch_id,
        v_line.floor_number,
        v_actor,
        coalesce(v_item_note, v_note, 'FO prepare return remaining stock'),
        v_now
      );
    end if;

    if v_damaged_qty > 0 then
      update public.floor_stock
      set quantity = greatest(quantity - v_damaged_qty, 0),
          updated_at = v_now
      where floor_number = v_line.floor_number
        and product_id = v_line.product_id;

      insert into public.stock_transactions_v2 (
        transaction_date,
        product_id,
        action,
        quantity_change,
        from_location,
        to_location,
        reference_type,
        reference_id,
        floor_number,
        performed_by,
        note,
        created_at
      )
      values (
        v_batch.business_date,
        v_line.product_id,
        'adjust',
        -v_damaged_qty,
        'floor_' || v_line.floor_number::text,
        'write_off',
        'fo_prepare_damaged',
        p_batch_id,
        v_line.floor_number,
        v_actor,
        v_item_note,
        v_now
      );
    end if;

    insert into public.fo_prepare_batch_returns (
      batch_id,
      product_id,
      prepared_qty,
      returned_qty,
      damaged_qty,
      note,
      recorded_by,
      recorded_at
    )
    values (
      p_batch_id,
      v_line.product_id,
      v_line.prepared_qty,
      v_return_qty,
      v_damaged_qty,
      coalesce(v_item_note, v_note),
      p_recorded_by,
      v_now
    )
    on conflict (batch_id, product_id) do update set
      prepared_qty = public.fo_prepare_batch_returns.prepared_qty + excluded.prepared_qty,
      returned_qty = public.fo_prepare_batch_returns.returned_qty + excluded.returned_qty,
      damaged_qty = public.fo_prepare_batch_returns.damaged_qty + excluded.damaged_qty,
      note = nullif(concat_ws(' | ', public.fo_prepare_batch_returns.note, excluded.note), ''),
      recorded_by = excluded.recorded_by,
      recorded_at = excluded.recorded_at;

    update public.fo_prepare_batch_items
    set
      used_qty = v_used_qty,
      remaining_qty = greatest(v_system_remaining - v_return_qty - v_damaged_qty, 0),
      returned_qty = v_return_qty,
      return_note = coalesce(v_item_note, return_note),
      updated_at = v_now
    where id = v_item_id;

    v_total_returned := v_total_returned + v_return_qty;
    v_total_damaged := v_total_damaged + v_damaged_qty;
    v_total_consumed := v_total_consumed + greatest(v_line.prepared_qty - v_return_qty - v_damaged_qty, 0);
    v_processed_count := v_processed_count + 1;
  end loop;

  if v_processed_count <> v_expected_count then
    raise exception
      'Return payload incomplete. Expected % items, received %',
      v_expected_count, v_processed_count;
  end if;

  if coalesce(p_force, false) and v_override_note is null then
    raise exception 'override note is required when force return is true';
  end if;

  update public.fo_prepare_batches
  set
    status = 'returned',
    return_status = 'reconciled',
    returned_at = v_now,
    returned_by = v_actor,
    return_note = v_note,
    return_override_note = case when coalesce(p_force, false) then v_override_note else null end,
    updated_at = v_now
  where id = p_batch_id;

  return jsonb_build_object(
    'batch_id', p_batch_id,
    'processed_items', v_processed_count,
    'total_returned', v_total_returned,
    'total_damaged', v_total_damaged,
    'total_consumed', v_total_consumed,
    'return_status', 'reconciled',
    'force_return', coalesce(p_force, false)
  );
end;
$$;

grant select, insert, update, delete on table public.fo_prepare_batch_returns to authenticated;
grant select on public.v_amenity_consumption_daily to authenticated;
grant execute on function public.fn_fo_prepare_return_submit(uuid, text, text, jsonb, boolean, text, uuid) to authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604180003_phase68_1b_linen_sold_room_max.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 68.1B: Linen Analytics Max must be based on sold stay nights,
-- not total sellable room inventory. Pickup date D uses stay_date D - 1.

create or replace function public.fn_linen_analytics_variance(
  p_start date,
  p_end date,
  p_categories text[] default null,
  p_room_types text[] default null
)
returns table (
  linen_item_id int,
  item_number text,
  name_th text,
  name_en text,
  category_key text,
  actual_qty numeric,
  predict_qty numeric,
  max_qty numeric,
  active_rooms int,
  days_in_period int
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select
      least(p_start, p_end) as start_date,
      greatest(p_start, p_end) as end_date,
      greatest((greatest(p_start, p_end) - least(p_start, p_end) + 1), 0)::int as days_in_period,
      coalesce(cardinality(p_room_types), 0) > 0 as has_room_filter
  ),
  days as (
    select d::date as business_date
    from params p
    cross join generate_series(p.start_date, p.end_date, interval '1 day') d
  ),
  items as (
    select
      li.id,
      li.item_number,
      li.name_th,
      li.name_en,
      public.fn_linen_analytics_category_key(li.item_number, li.name_en) as category_key
    from public.linen_items li
    where li.is_active = true
      and (
        p_categories is null
        or cardinality(p_categories) = 0
        or public.fn_linen_analytics_category_key(li.item_number, li.name_en) = any(p_categories)
        or li.item_number::text = any(p_categories)
      )
  ),
  actuals as (
    select
      lbi.linen_item_id,
      coalesce(sum(lbi.sent_by_hotel), 0)::numeric as actual_qty
    from public.laundry_batches lb
    join public.laundry_batch_items lbi on lbi.batch_id = lb.id
    cross join params p
    where lb.business_date >= p.start_date
      and lb.business_date <= p.end_date
      and coalesce(lbi.is_dayuse, false) = false
    group by lbi.linen_item_id
  ),
  sold_nights as (
    select
      d.business_date,
      rt.code as room_type_code
    from days d
    join public.reservation_nights rn on rn.stay_date = (d.business_date - interval '1 day')::date
    join public.reservations res on res.id = rn.reservation_id
    join public.rooms r on r.id = rn.room_id
    join public.room_types rt on rt.id = r.room_type_id
    where rn.cancelled_at is null
      and res.status in ('active', 'checked_out')
      and coalesce(res.is_dayuse, false) = false
      and coalesce(r.is_dayuse, false) = false
  ),
  selected_sold_nights as (
    select sn.*
    from sold_nights sn
    cross join params p
    where not p.has_room_filter
      or sn.room_type_code = any(p_room_types)
  ),
  selected_max as (
    select
      rls.linen_item_id,
      coalesce(sum(rls.qty), 0)::numeric as max_qty,
      count(*)::int as sold_room_nights
    from selected_sold_nights sn
    join public.room_linen_setups rls on rls.room_type_code = sn.room_type_code
    group by rls.linen_item_id
  ),
  total_max as (
    select
      rls.linen_item_id,
      coalesce(sum(rls.qty), 0)::numeric as max_qty
    from sold_nights sn
    join public.room_linen_setups rls on rls.room_type_code = sn.room_type_code
    group by rls.linen_item_id
  )
  select
    i.id as linen_item_id,
    i.item_number::text,
    i.name_th,
    i.name_en,
    i.category_key,
    case
      when p.has_room_filter then
        case
          when coalesce(tm.max_qty, 0) > 0
            then (coalesce(a.actual_qty, 0) * coalesce(sm.max_qty, 0) / tm.max_qty)::numeric
          else 0::numeric
        end
      else coalesce(a.actual_qty, 0)::numeric
    end as actual_qty,
    0::numeric as predict_qty,
    coalesce(sm.max_qty, 0)::numeric as max_qty,
    coalesce(sm.sold_room_nights, 0)::int as active_rooms,
    p.days_in_period
  from items i
  cross join params p
  left join actuals a on a.linen_item_id = i.id
  left join selected_max sm on sm.linen_item_id = i.id
  left join total_max tm on tm.linen_item_id = i.id
  order by i.item_number;
$$;

create or replace function public.fn_linen_analytics_trend(
  p_start date,
  p_end date,
  p_window text default 'day',
  p_categories text[] default null,
  p_room_types text[] default null
)
returns table (
  period_start date,
  actual_qty numeric,
  predict_qty numeric,
  max_qty numeric,
  statistical_qty numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select
      least(p_start, p_end) as start_date,
      greatest(p_start, p_end) as end_date,
      coalesce(cardinality(p_room_types), 0) > 0 as has_room_filter
  ),
  days as (
    select d::date as business_date
    from params p
    cross join generate_series(p.start_date, p.end_date, interval '1 day') d
  ),
  day_periods as (
    select
      business_date,
      case
        when p_window = 'week' then date_trunc('week', business_date)::date
        when p_window = 'month' then date_trunc('month', business_date)::date
        else business_date
      end as period_start
    from days
  ),
  item_filter as (
    select li.id
    from public.linen_items li
    where li.is_active = true
      and (
        p_categories is null
        or cardinality(p_categories) = 0
        or public.fn_linen_analytics_category_key(li.item_number, li.name_en) = any(p_categories)
        or li.item_number::text = any(p_categories)
      )
  ),
  actual_period as (
    select
      dp.period_start,
      coalesce(sum(lbi.sent_by_hotel), 0)::numeric as actual_qty
    from day_periods dp
    join public.laundry_batches lb on lb.business_date = dp.business_date
    join public.laundry_batch_items lbi on lbi.batch_id = lb.id
    join item_filter f on f.id = lbi.linen_item_id
    where coalesce(lbi.is_dayuse, false) = false
    group by dp.period_start
  ),
  sold_nights as (
    select
      dp.period_start,
      rt.code as room_type_code
    from day_periods dp
    join public.reservation_nights rn on rn.stay_date = (dp.business_date - interval '1 day')::date
    join public.reservations res on res.id = rn.reservation_id
    join public.rooms r on r.id = rn.room_id
    join public.room_types rt on rt.id = r.room_type_id
    where rn.cancelled_at is null
      and res.status in ('active', 'checked_out')
      and coalesce(res.is_dayuse, false) = false
      and coalesce(r.is_dayuse, false) = false
  ),
  selected_sold_nights as (
    select sn.*
    from sold_nights sn
    cross join params p
    where not p.has_room_filter
      or sn.room_type_code = any(p_room_types)
  ),
  selected_max_period as (
    select
      sn.period_start,
      coalesce(sum(rls.qty), 0)::numeric as max_qty
    from selected_sold_nights sn
    join public.room_linen_setups rls on rls.room_type_code = sn.room_type_code
    join item_filter f on f.id = rls.linen_item_id
    group by sn.period_start
  ),
  total_max_period as (
    select
      sn.period_start,
      coalesce(sum(rls.qty), 0)::numeric as max_qty
    from sold_nights sn
    join public.room_linen_setups rls on rls.room_type_code = sn.room_type_code
    join item_filter f on f.id = rls.linen_item_id
    group by sn.period_start
  )
  select
    dp.period_start,
    case
      when max(p.has_room_filter::int) = 1 then
        case
          when coalesce(max(tmp.max_qty), 0) > 0
            then (coalesce(max(ap.actual_qty), 0) * coalesce(max(smp.max_qty), 0) / max(tmp.max_qty))::numeric
          else 0::numeric
        end
      else coalesce(max(ap.actual_qty), 0)::numeric
    end as actual_qty,
    0::numeric as predict_qty,
    coalesce(max(smp.max_qty), 0)::numeric as max_qty,
    null::numeric as statistical_qty
  from day_periods dp
  cross join params p
  left join actual_period ap on ap.period_start = dp.period_start
  left join selected_max_period smp on smp.period_start = dp.period_start
  left join total_max_period tmp on tmp.period_start = dp.period_start
  group by dp.period_start
  order by dp.period_start;
$$;

grant execute on function public.fn_linen_analytics_variance(date, date, text[], text[]) to authenticated;
grant execute on function public.fn_linen_analytics_trend(date, date, text, text[], text[]) to authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604180004_phase68_1b_exclude_closed_room_types.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 68.1B hotfix: CLOSED / non-sellable room types are not analytical
-- room types and must never contribute to Linen Max.

create or replace function public.fn_linen_analytics_variance(
  p_start date,
  p_end date,
  p_categories text[] default null,
  p_room_types text[] default null
)
returns table (
  linen_item_id int,
  item_number text,
  name_th text,
  name_en text,
  category_key text,
  actual_qty numeric,
  predict_qty numeric,
  max_qty numeric,
  active_rooms int,
  days_in_period int
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select
      least(p_start, p_end) as start_date,
      greatest(p_start, p_end) as end_date,
      greatest((greatest(p_start, p_end) - least(p_start, p_end) + 1), 0)::int as days_in_period,
      coalesce(cardinality(p_room_types), 0) > 0 as has_room_filter
  ),
  days as (
    select d::date as business_date
    from params p
    cross join generate_series(p.start_date, p.end_date, interval '1 day') d
  ),
  items as (
    select
      li.id,
      li.item_number,
      li.name_th,
      li.name_en,
      public.fn_linen_analytics_category_key(li.item_number, li.name_en) as category_key
    from public.linen_items li
    where li.is_active = true
      and (
        p_categories is null
        or cardinality(p_categories) = 0
        or public.fn_linen_analytics_category_key(li.item_number, li.name_en) = any(p_categories)
        or li.item_number::text = any(p_categories)
      )
  ),
  actuals as (
    select
      lbi.linen_item_id,
      coalesce(sum(lbi.sent_by_hotel), 0)::numeric as actual_qty
    from public.laundry_batches lb
    join public.laundry_batch_items lbi on lbi.batch_id = lb.id
    cross join params p
    where lb.business_date >= p.start_date
      and lb.business_date <= p.end_date
      and coalesce(lbi.is_dayuse, false) = false
    group by lbi.linen_item_id
  ),
  sold_nights as (
    select
      d.business_date,
      rt.code as room_type_code
    from days d
    join public.reservation_nights rn on rn.stay_date = (d.business_date - interval '1 day')::date
    join public.reservations res on res.id = rn.reservation_id
    join public.rooms r on r.id = rn.room_id
    join public.room_types rt on rt.id = r.room_type_id
    where rn.cancelled_at is null
      and res.status in ('active', 'checked_out')
      and coalesce(res.is_dayuse, false) = false
      and coalesce(r.is_dayuse, false) = false
      and coalesce(r.is_sellable, false) = true
      and upper(coalesce(rt.code, '')) <> 'CLOSED'
      and lower(coalesce(rt.name_en, '')) not like '%closed%'
  ),
  selected_sold_nights as (
    select sn.*
    from sold_nights sn
    cross join params p
    where not p.has_room_filter
      or sn.room_type_code = any(p_room_types)
  ),
  selected_max as (
    select
      rls.linen_item_id,
      coalesce(sum(rls.qty), 0)::numeric as max_qty,
      count(*)::int as sold_room_nights
    from selected_sold_nights sn
    join public.room_linen_setups rls on rls.room_type_code = sn.room_type_code
    group by rls.linen_item_id
  ),
  total_max as (
    select
      rls.linen_item_id,
      coalesce(sum(rls.qty), 0)::numeric as max_qty
    from sold_nights sn
    join public.room_linen_setups rls on rls.room_type_code = sn.room_type_code
    group by rls.linen_item_id
  )
  select
    i.id as linen_item_id,
    i.item_number::text,
    i.name_th,
    i.name_en,
    i.category_key,
    case
      when p.has_room_filter then
        case
          when coalesce(tm.max_qty, 0) > 0
            then (coalesce(a.actual_qty, 0) * coalesce(sm.max_qty, 0) / tm.max_qty)::numeric
          else 0::numeric
        end
      else coalesce(a.actual_qty, 0)::numeric
    end as actual_qty,
    0::numeric as predict_qty,
    coalesce(sm.max_qty, 0)::numeric as max_qty,
    coalesce(sm.sold_room_nights, 0)::int as active_rooms,
    p.days_in_period
  from items i
  cross join params p
  left join actuals a on a.linen_item_id = i.id
  left join selected_max sm on sm.linen_item_id = i.id
  left join total_max tm on tm.linen_item_id = i.id
  order by i.item_number;
$$;

create or replace function public.fn_linen_analytics_trend(
  p_start date,
  p_end date,
  p_window text default 'day',
  p_categories text[] default null,
  p_room_types text[] default null
)
returns table (
  period_start date,
  actual_qty numeric,
  predict_qty numeric,
  max_qty numeric,
  statistical_qty numeric
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select
      least(p_start, p_end) as start_date,
      greatest(p_start, p_end) as end_date,
      coalesce(cardinality(p_room_types), 0) > 0 as has_room_filter
  ),
  days as (
    select d::date as business_date
    from params p
    cross join generate_series(p.start_date, p.end_date, interval '1 day') d
  ),
  day_periods as (
    select
      business_date,
      case
        when p_window = 'week' then date_trunc('week', business_date)::date
        when p_window = 'month' then date_trunc('month', business_date)::date
        else business_date
      end as period_start
    from days
  ),
  item_filter as (
    select li.id
    from public.linen_items li
    where li.is_active = true
      and (
        p_categories is null
        or cardinality(p_categories) = 0
        or public.fn_linen_analytics_category_key(li.item_number, li.name_en) = any(p_categories)
        or li.item_number::text = any(p_categories)
      )
  ),
  actual_period as (
    select
      dp.period_start,
      coalesce(sum(lbi.sent_by_hotel), 0)::numeric as actual_qty
    from day_periods dp
    join public.laundry_batches lb on lb.business_date = dp.business_date
    join public.laundry_batch_items lbi on lbi.batch_id = lb.id
    join item_filter f on f.id = lbi.linen_item_id
    where coalesce(lbi.is_dayuse, false) = false
    group by dp.period_start
  ),
  sold_nights as (
    select
      dp.period_start,
      rt.code as room_type_code
    from day_periods dp
    join public.reservation_nights rn on rn.stay_date = (dp.business_date - interval '1 day')::date
    join public.reservations res on res.id = rn.reservation_id
    join public.rooms r on r.id = rn.room_id
    join public.room_types rt on rt.id = r.room_type_id
    where rn.cancelled_at is null
      and res.status in ('active', 'checked_out')
      and coalesce(res.is_dayuse, false) = false
      and coalesce(r.is_dayuse, false) = false
      and coalesce(r.is_sellable, false) = true
      and upper(coalesce(rt.code, '')) <> 'CLOSED'
      and lower(coalesce(rt.name_en, '')) not like '%closed%'
  ),
  selected_sold_nights as (
    select sn.*
    from sold_nights sn
    cross join params p
    where not p.has_room_filter
      or sn.room_type_code = any(p_room_types)
  ),
  selected_max_period as (
    select
      sn.period_start,
      coalesce(sum(rls.qty), 0)::numeric as max_qty
    from selected_sold_nights sn
    join public.room_linen_setups rls on rls.room_type_code = sn.room_type_code
    join item_filter f on f.id = rls.linen_item_id
    group by sn.period_start
  ),
  total_max_period as (
    select
      sn.period_start,
      coalesce(sum(rls.qty), 0)::numeric as max_qty
    from sold_nights sn
    join public.room_linen_setups rls on rls.room_type_code = sn.room_type_code
    join item_filter f on f.id = rls.linen_item_id
    group by sn.period_start
  )
  select
    dp.period_start,
    case
      when max(p.has_room_filter::int) = 1 then
        case
          when coalesce(max(tmp.max_qty), 0) > 0
            then (coalesce(max(ap.actual_qty), 0) * coalesce(max(smp.max_qty), 0) / max(tmp.max_qty))::numeric
          else 0::numeric
        end
      else coalesce(max(ap.actual_qty), 0)::numeric
    end as actual_qty,
    0::numeric as predict_qty,
    coalesce(max(smp.max_qty), 0)::numeric as max_qty,
    null::numeric as statistical_qty
  from day_periods dp
  cross join params p
  left join actual_period ap on ap.period_start = dp.period_start
  left join selected_max_period smp on smp.period_start = dp.period_start
  left join total_max_period tmp on tmp.period_start = dp.period_start
  group by dp.period_start
  order by dp.period_start;
$$;

grant execute on function public.fn_linen_analytics_variance(date, date, text[], text[]) to authenticated;
grant execute on function public.fn_linen_analytics_trend(date, date, text, text[], text[]) to authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604190001_phase68_2b_amenity_setup_table.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 68.2b: Amenity per-room setup used by Analytics Max baseline.
-- room_types.id is bigserial, so room_type_id must be bigint (not uuid).

create table if not exists public.room_type_amenity_setups (
  room_type_id bigint not null references public.room_types(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  units_per_occupied_night int not null default 0 check (units_per_occupied_night >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (room_type_id, product_id)
);

create index if not exists idx_room_type_amenity_setups_product
  on public.room_type_amenity_setups(product_id);

drop trigger if exists trg_room_type_amenity_setups_updated_at on public.room_type_amenity_setups;
create trigger trg_room_type_amenity_setups_updated_at
before update on public.room_type_amenity_setups
for each row execute function public.set_updated_at();

alter table public.room_type_amenity_setups enable row level security;

drop policy if exists room_type_amenity_setups_read on public.room_type_amenity_setups;
create policy room_type_amenity_setups_read on public.room_type_amenity_setups
  for select to authenticated
  using (true);

drop policy if exists room_type_amenity_setups_write on public.room_type_amenity_setups;
create policy room_type_amenity_setups_write on public.room_type_amenity_setups
  for all to authenticated
  using (true)
  with check (true);

grant select, insert, update, delete on table public.room_type_amenity_setups to authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604190002_phase68_2b_amenity_analytics.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 68.2b: Amenity Analytics RPCs.
-- Locks from Lead:
-- - room_type filter uses room type codes via p_room_type_codes (same contract as Linen)
-- - Max uses sold room nights from business_date - 1
-- - Actual roomtype filtering is allocated by setup × occupancy weighting
-- - Predict is trailing-14-day median from FO reconciled consumption only

create or replace function public.fn_amenity_analytics_category_key(p_product_name text)
returns text
language sql
immutable
as $$
  select 'amenity.' || coalesce(
    nullif(
      trim(both '_' from regexp_replace(lower(coalesce(p_product_name, 'item')), '[^a-z0-9]+', '_', 'g')),
      ''
    ),
    'item'
  );
$$;

create or replace function public.fn_amenity_analytics_categories()
returns table (
  category_key text,
  label text,
  source_hint text
)
language sql
security definer
set search_path = public
as $$
  select
    public.fn_amenity_analytics_category_key(p.name) as category_key,
    p.name as label,
    case
      when p.stock_tracking_mode = 'amenity_prepare' then 'fo_reconciled'
      else 'audit_adjusted'
    end as source_hint
  from public.products p
  where coalesce(p.is_active, true) = true
    and p.stock_tracking_mode in ('amenity_prepare', 'amenity_direct')
  order by
    case p.stock_tracking_mode
      when 'amenity_prepare' then 1
      when 'amenity_direct' then 2
      else 9
    end,
    p.name;
$$;

create or replace function public.fn_amenity_analytics_variance(
  p_start date,
  p_end date,
  p_categories text[] default null,
  p_source text default 'all',
  p_room_type_codes text[] default null
)
returns table (
  category text,
  label text,
  source text,
  actual_qty numeric,
  predict_qty numeric,
  max_qty numeric,
  statistical_qty numeric,
  actual_source text,
  has_setup boolean,
  history_sample_size int,
  days_in_period int
)
language sql
security definer
set search_path = public
as $$
  with params as (
    select
      p_start as start_date,
      p_end as end_date,
      greatest((p_end - p_start + 1), 0)::int as days_in_period,
      coalesce(nullif(p_source, ''), 'all') as source_filter,
      coalesce(cardinality(p_room_type_codes), 0) > 0 as has_room_filter
  ),
  requested_sources as (
    select unnest(
      case
        when (select source_filter from params) = 'all' then array['fo_reconciled', 'audit_adjusted']::text[]
        else array[(select source_filter from params)]::text[]
      end
    ) as source
  ),
  product_scope as (
    select
      p.id as product_id,
      p.name as label,
      p.stock_tracking_mode,
      case
        when p.stock_tracking_mode = 'amenity_prepare' then 'fo_reconciled'
        else 'audit_adjusted'
      end as source,
      public.fn_amenity_analytics_category_key(p.name) as category
    from public.products p
    join requested_sources rs
      on rs.source = case
        when p.stock_tracking_mode = 'amenity_prepare' then 'fo_reconciled'
        else 'audit_adjusted'
      end
    where coalesce(p.is_active, true) = true
      and p.stock_tracking_mode in ('amenity_prepare', 'amenity_direct')
      and (
        p_categories is null
        or cardinality(p_categories) = 0
        or public.fn_amenity_analytics_category_key(p.name) = any(p_categories)
      )
  ),
  setup_presence as (
    select rtas.product_id, count(*)::int as setup_count
    from public.room_type_amenity_setups rtas
    group by rtas.product_id
  ),
  days as (
    select generate_series(
      (select start_date from params),
      (select end_date from params),
      interval '1 day'
    )::date as business_date
  ),
  sold_nights as (
    select
      d.business_date,
      r.room_type_id,
      rt.code as room_type_code
    from days d
    join public.reservation_nights rn on rn.stay_date = (d.business_date - interval '1 day')::date
    join public.reservations res on res.id = rn.reservation_id
    join public.rooms r on r.id = rn.room_id
    join public.room_types rt on rt.id = r.room_type_id
    where rn.cancelled_at is null
      and res.status in ('active', 'checked_out')
      and coalesce(res.is_dayuse, false) = false
      and coalesce(r.is_dayuse, false) = false
      and coalesce(r.is_sellable, false) = true
      and upper(coalesce(rt.code, '')) <> 'CLOSED'
      and lower(coalesce(rt.name_en, '')) not like '%closed%'
  ),
  selected_sold_nights as (
    select sn.*
    from sold_nights sn
    cross join params p
    where not p.has_room_filter
      or sn.room_type_code = any(p_room_type_codes)
  ),
  selected_max as (
    select
      rtas.product_id,
      coalesce(sum(rtas.units_per_occupied_night), 0)::numeric as max_qty
    from selected_sold_nights sn
    join public.room_type_amenity_setups rtas on rtas.room_type_id = sn.room_type_id
    group by rtas.product_id
  ),
  total_max as (
    select
      rtas.product_id,
      coalesce(sum(rtas.units_per_occupied_night), 0)::numeric as max_qty
    from sold_nights sn
    join public.room_type_amenity_setups rtas on rtas.room_type_id = sn.room_type_id
    group by rtas.product_id
  ),
  fo_actual as (
    select
      v.product_id,
      'fo_reconciled'::text as source,
      coalesce(sum(v.consumed_qty), 0)::numeric as actual_qty
    from public.v_amenity_consumption_daily v
    cross join params p
    where v.business_date >= p.start_date
      and v.business_date <= p.end_date
    group by v.product_id
  ),
  audit_actual as (
    select
      ai.product_id,
      'audit_adjusted'::text as source,
      coalesce(sum(greatest(ai.refill_delta, 0)), 0)::numeric as actual_qty
    from public.fo_amenity_audit_sessions s
    join public.fo_amenity_audit_items ai on ai.session_id = s.id
    join public.products pdt on pdt.id = ai.product_id
    cross join params p
    where s.business_date >= p.start_date
      and s.business_date <= p.end_date
      and pdt.stock_tracking_mode = 'amenity_direct'
    group by ai.product_id
  ),
  actuals as (
    select * from fo_actual
    union all
    select * from audit_actual
  ),
  history as (
    select
      v.product_id,
      count(*)::int as sample_size,
      percentile_cont(0.5) within group (order by v.consumed_qty)::numeric as median_daily
    from public.v_amenity_consumption_daily v
    cross join params p
    where v.business_date >= (p.start_date - interval '14 days')::date
      and v.business_date < p.start_date
    group by v.product_id
  )
  select
    ps.category,
    ps.label,
    ps.source,
    case
      when max(par.has_room_filter::int) = 1 and coalesce(max(sp.setup_count), 0) > 0 then
        case
          when coalesce(max(tm.max_qty), 0) > 0
            then (coalesce(max(a.actual_qty), 0) * coalesce(max(sm.max_qty), 0) / max(tm.max_qty))::numeric
          else 0::numeric
        end
      else coalesce(max(a.actual_qty), 0)::numeric
    end as actual_qty,
    case
      when ps.source = 'fo_reconciled' and coalesce(max(h.sample_size), 0) >= 7
        then (max(h.median_daily) * max(par.days_in_period))::numeric
      else null::numeric
    end as predict_qty,
    case
      when coalesce(max(sp.setup_count), 0) = 0 then null::numeric
      else coalesce(max(sm.max_qty), 0)::numeric
    end as max_qty,
    null::numeric as statistical_qty,
    case
      when max(par.has_room_filter::int) = 1 and coalesce(max(sp.setup_count), 0) > 0 then 'allocated'
      else 'direct'
    end as actual_source,
    coalesce(max(sp.setup_count), 0) > 0 as has_setup,
    coalesce(max(h.sample_size), 0)::int as history_sample_size,
    max(par.days_in_period)::int as days_in_period
  from product_scope ps
  cross join params par
  left join actuals a on a.product_id = ps.product_id and a.source = ps.source
  left join selected_max sm on sm.product_id = ps.product_id
  left join total_max tm on tm.product_id = ps.product_id
  left join setup_presence sp on sp.product_id = ps.product_id
  left join history h on h.product_id = ps.product_id
  group by ps.product_id, ps.category, ps.label, ps.source
  order by ps.source, ps.label;
$$;

create or replace function public.fn_amenity_analytics_trend(
  p_start date,
  p_end date,
  p_window text default 'day',
  p_source text default 'all',
  p_room_type_codes text[] default null
)
returns table (
  period date,
  actual numeric,
  predict numeric,
  max numeric,
  statistical numeric
)
language sql
security definer
set search_path = public
as $$
  with params as (
    select
      p_start as start_date,
      p_end as end_date,
      case when p_window in ('day', 'week', 'month') then p_window else 'day' end as bucket_window,
      coalesce(nullif(p_source, ''), 'all') as source_filter,
      coalesce(cardinality(p_room_type_codes), 0) > 0 as has_room_filter
  ),
  day_periods as (
    select
      gs::date as business_date,
      case
        when (select bucket_window from params) = 'month' then date_trunc('month', gs)::date
        when (select bucket_window from params) = 'week' then date_trunc('week', gs)::date
        else gs::date
      end as period_start
    from generate_series(
      (select start_date from params),
      (select end_date from params),
      interval '1 day'
    ) gs
  ),
  period_days as (
    select period_start, count(*)::int as days_in_bucket
    from day_periods
    group by period_start
  ),
  requested_sources as (
    select unnest(
      case
        when (select source_filter from params) = 'all' then array['fo_reconciled', 'audit_adjusted']::text[]
        else array[(select source_filter from params)]::text[]
      end
    ) as source
  ),
  product_scope as (
    select
      p.id as product_id,
      p.stock_tracking_mode,
      case
        when p.stock_tracking_mode = 'amenity_prepare' then 'fo_reconciled'
        else 'audit_adjusted'
      end as source
    from public.products p
    join requested_sources rs
      on rs.source = case
        when p.stock_tracking_mode = 'amenity_prepare' then 'fo_reconciled'
        else 'audit_adjusted'
      end
    where coalesce(p.is_active, true) = true
      and p.stock_tracking_mode in ('amenity_prepare', 'amenity_direct')
  ),
  setup_presence as (
    select rtas.product_id, count(*)::int as setup_count
    from public.room_type_amenity_setups rtas
    group by rtas.product_id
  ),
  sold_nights as (
    select
      dp.business_date,
      dp.period_start,
      r.room_type_id,
      rt.code as room_type_code
    from day_periods dp
    join public.reservation_nights rn on rn.stay_date = (dp.business_date - interval '1 day')::date
    join public.reservations res on res.id = rn.reservation_id
    join public.rooms r on r.id = rn.room_id
    join public.room_types rt on rt.id = r.room_type_id
    where rn.cancelled_at is null
      and res.status in ('active', 'checked_out')
      and coalesce(res.is_dayuse, false) = false
      and coalesce(r.is_dayuse, false) = false
      and coalesce(r.is_sellable, false) = true
      and upper(coalesce(rt.code, '')) <> 'CLOSED'
      and lower(coalesce(rt.name_en, '')) not like '%closed%'
  ),
  selected_sold_nights as (
    select sn.*
    from sold_nights sn
    cross join params p
    where not p.has_room_filter
      or sn.room_type_code = any(p_room_type_codes)
  ),
  selected_max_daily as (
    select
      sn.business_date,
      rtas.product_id,
      coalesce(sum(rtas.units_per_occupied_night), 0)::numeric as max_qty
    from selected_sold_nights sn
    join public.room_type_amenity_setups rtas on rtas.room_type_id = sn.room_type_id
    group by sn.business_date, rtas.product_id
  ),
  total_max_daily as (
    select
      sn.business_date,
      rtas.product_id,
      coalesce(sum(rtas.units_per_occupied_night), 0)::numeric as max_qty
    from sold_nights sn
    join public.room_type_amenity_setups rtas on rtas.room_type_id = sn.room_type_id
    group by sn.business_date, rtas.product_id
  ),
  fo_actual_daily as (
    select
      v.business_date,
      v.product_id,
      'fo_reconciled'::text as source,
      coalesce(sum(v.consumed_qty), 0)::numeric as actual_qty
    from public.v_amenity_consumption_daily v
    cross join params p
    where v.business_date >= p.start_date
      and v.business_date <= p.end_date
    group by v.business_date, v.product_id
  ),
  audit_actual_daily as (
    select
      s.business_date,
      ai.product_id,
      'audit_adjusted'::text as source,
      coalesce(sum(greatest(ai.refill_delta, 0)), 0)::numeric as actual_qty
    from public.fo_amenity_audit_sessions s
    join public.fo_amenity_audit_items ai on ai.session_id = s.id
    join public.products pdt on pdt.id = ai.product_id
    cross join params p
    where s.business_date >= p.start_date
      and s.business_date <= p.end_date
      and pdt.stock_tracking_mode = 'amenity_direct'
    group by s.business_date, ai.product_id
  ),
  actual_daily as (
    select * from fo_actual_daily
    union all
    select * from audit_actual_daily
  ),
  allocated_actual_daily as (
    select
      dp.period_start,
      ps.product_id,
      ps.source,
      case
        when max(par.has_room_filter::int) = 1 and coalesce(max(sp.setup_count), 0) > 0 then
          case
            when coalesce(max(tmd.max_qty), 0) > 0
              then (coalesce(max(ad.actual_qty), 0) * coalesce(max(smd.max_qty), 0) / max(tmd.max_qty))::numeric
            else 0::numeric
          end
        else coalesce(max(ad.actual_qty), 0)::numeric
      end as actual_qty,
      case
        when coalesce(max(sp.setup_count), 0) = 0 then null::numeric
        else coalesce(max(smd.max_qty), 0)::numeric
      end as max_qty
    from day_periods dp
    cross join product_scope ps
    cross join params par
    left join actual_daily ad on ad.business_date = dp.business_date and ad.product_id = ps.product_id and ad.source = ps.source
    left join setup_presence sp on sp.product_id = ps.product_id
    left join selected_max_daily smd on smd.business_date = dp.business_date and smd.product_id = ps.product_id
    left join total_max_daily tmd on tmd.business_date = dp.business_date and tmd.product_id = ps.product_id
    group by dp.business_date, dp.period_start, ps.product_id, ps.source
  ),
  history as (
    select
      v.product_id,
      count(*)::int as sample_size,
      percentile_cont(0.5) within group (order by v.consumed_qty)::numeric as median_daily
    from public.v_amenity_consumption_daily v
    cross join params p
    where v.business_date >= (p.start_date - interval '14 days')::date
      and v.business_date < p.start_date
    group by v.product_id
  ),
  predict_period as (
    select
      pd.period_start,
      sum(h.median_daily * pd.days_in_bucket)::numeric as predict_qty
    from period_days pd
    join product_scope ps on ps.source = 'fo_reconciled'
    join history h on h.product_id = ps.product_id and h.sample_size >= 7
    group by pd.period_start
  )
  select
    pd.period_start as period,
    coalesce(sum(aad.actual_qty), 0)::numeric as actual,
    max(pp.predict_qty)::numeric as predict,
    case
      when count(aad.max_qty) filter (where aad.max_qty is not null) = 0 then null::numeric
      else coalesce(sum(aad.max_qty), 0)::numeric
    end as max,
    null::numeric as statistical
  from period_days pd
  left join allocated_actual_daily aad on aad.period_start = pd.period_start
  left join predict_period pp on pp.period_start = pd.period_start
  group by pd.period_start
  order by pd.period_start;
$$;

create or replace function public.fn_amenity_reconciliation_variance_notes(
  p_start date,
  p_end date,
  p_categories text[] default null
)
returns table (
  business_date date,
  product_id uuid,
  category text,
  label text,
  reconciled_consumed numeric,
  maid_tap_total numeric,
  delta numeric,
  fo_return_note text,
  recorded_at timestamptz,
  recorded_by uuid,
  batch_id uuid
)
language sql
security definer
set search_path = public
as $$
  with maid_taps as (
    select
      i.batch_id,
      i.product_id,
      coalesce(sum(i.used_qty), 0)::numeric as maid_tap_total
    from public.fo_prepare_batch_items i
    group by i.batch_id, i.product_id
  )
  select
    b.business_date,
    r.product_id,
    public.fn_amenity_analytics_category_key(p.name) as category,
    p.name as label,
    r.consumed_qty::numeric as reconciled_consumed,
    coalesce(mt.maid_tap_total, 0)::numeric as maid_tap_total,
    (r.consumed_qty - coalesce(mt.maid_tap_total, 0))::numeric as delta,
    r.note as fo_return_note,
    r.recorded_at,
    r.recorded_by,
    b.id as batch_id
  from public.fo_prepare_batch_returns r
  join public.fo_prepare_batches b on b.id = r.batch_id
  join public.products p on p.id = r.product_id
  left join maid_taps mt on mt.batch_id = r.batch_id and mt.product_id = r.product_id
  where b.return_status = 'reconciled'
    and p.stock_tracking_mode = 'amenity_prepare'
    and b.business_date >= p_start
    and b.business_date <= p_end
    and (
      p_categories is null
      or cardinality(p_categories) = 0
      or public.fn_amenity_analytics_category_key(p.name) = any(p_categories)
    )
    and (
      abs(r.consumed_qty - coalesce(mt.maid_tap_total, 0)) > 0
      or nullif(trim(coalesce(r.note, '')), '') is not null
    )
  order by b.business_date desc, category asc;
$$;

grant execute on function public.fn_amenity_analytics_category_key(text) to authenticated;
grant execute on function public.fn_amenity_analytics_categories() to authenticated;
grant execute on function public.fn_amenity_analytics_variance(date, date, text[], text, text[]) to authenticated;
grant execute on function public.fn_amenity_analytics_trend(date, date, text, text, text[]) to authenticated;
grant execute on function public.fn_amenity_reconciliation_variance_notes(date, date, text[]) to authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604190003_phase68_2b_backfill_amenity_setup.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 68.2b hotfix: reuse the existing room-type checklist setup as the
-- initial Max baseline config for Amenity Analytics.
--
-- The analytics RPC intentionally returns max_qty = NULL when a product has no
-- room_type_amenity_setups rows. Existing room setup already stores linked
-- amenity products in checklist_templates, so this backfill prevents operators
-- from having to re-enter the same matrix manually.

insert into public.room_type_amenity_setups (
  room_type_id,
  product_id,
  units_per_occupied_night
)
select
  rt.id as room_type_id,
  ct.product_id,
  max(ct.default_quantity)::int as units_per_occupied_night
from public.checklist_templates ct
join public.room_types rt
  on rt.code = ct.room_type_code
join public.products p
  on p.id = ct.product_id
where ct.is_active = true
  and ct.product_id is not null
  and coalesce(ct.default_quantity, 0) > 0
  and coalesce(p.is_active, true) = true
  and p.stock_tracking_mode in ('amenity_prepare', 'amenity_direct')
  and upper(coalesce(rt.code, '')) <> 'CLOSED'
  and lower(coalesce(rt.name_en, '')) not like '%closed%'
group by rt.id, ct.product_id
on conflict (room_type_id, product_id) do update
set units_per_occupied_night = excluded.units_per_occupied_night,
    updated_at = timezone('utc', now());

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604190004_phase68_2b_sync_amenity_setup_trigger.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Keep Amenity Analytics Max config in sync with the existing Room Setup
-- checklist. Operators should only need to link an amenity product once in
-- Room Setup; analytics reads the normalized room_type_amenity_setups table.

create or replace function public.sync_room_type_amenity_setup_from_checklist(p_room_type_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_type_id bigint;
begin
  if nullif(trim(coalesce(p_room_type_code, '')), '') is null then
    return;
  end if;

  select rt.id
  into v_room_type_id
  from public.room_types rt
  where rt.code = p_room_type_code
    and upper(coalesce(rt.code, '')) <> 'CLOSED'
    and lower(coalesce(rt.name_en, '')) not like '%closed%'
  limit 1;

  if v_room_type_id is null then
    return;
  end if;

  delete from public.room_type_amenity_setups rtas
  using public.products p
  where rtas.room_type_id = v_room_type_id
    and p.id = rtas.product_id
    and p.stock_tracking_mode in ('amenity_prepare', 'amenity_direct');

  insert into public.room_type_amenity_setups (
    room_type_id,
    product_id,
    units_per_occupied_night
  )
  select
    v_room_type_id,
    ct.product_id,
    max(ct.default_quantity)::int as units_per_occupied_night
  from public.checklist_templates ct
  join public.products p
    on p.id = ct.product_id
  where ct.room_type_code = p_room_type_code
    and ct.is_active = true
    and ct.product_id is not null
    and coalesce(ct.default_quantity, 0) > 0
    and coalesce(p.is_active, true) = true
    and p.stock_tracking_mode in ('amenity_prepare', 'amenity_direct')
  group by ct.product_id
  on conflict (room_type_id, product_id) do update
  set units_per_occupied_night = excluded.units_per_occupied_night,
      updated_at = timezone('utc', now());
end;
$$;

create or replace function public.trg_sync_room_type_amenity_setup_from_checklist()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_room_type_amenity_setup_from_checklist(coalesce(new.room_type_code, old.room_type_code));

  if tg_op = 'UPDATE' and old.room_type_code is distinct from new.room_type_code then
    perform public.sync_room_type_amenity_setup_from_checklist(old.room_type_code);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_sync_room_type_amenity_setup_from_checklist on public.checklist_templates;
create trigger trg_sync_room_type_amenity_setup_from_checklist
after insert or update or delete on public.checklist_templates
for each row execute function public.trg_sync_room_type_amenity_setup_from_checklist();

grant execute on function public.sync_room_type_amenity_setup_from_checklist(text) to authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604190005_phase68_2b_amenity_trend_category_filter.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 68.2b hotfix: variance already supports category filtering, but the
-- trend RPC did not accept p_categories, so the chart still displayed all
-- amenity products after selecting one item (for example Coffee).

drop function if exists public.fn_amenity_analytics_trend(date, date, text, text, text[]);

create or replace function public.fn_amenity_analytics_trend(
  p_start date,
  p_end date,
  p_window text default 'day',
  p_source text default 'all',
  p_room_type_codes text[] default null,
  p_categories text[] default null
)
returns table (
  period date,
  actual numeric,
  predict numeric,
  max numeric,
  statistical numeric
)
language sql
security definer
set search_path = public
as $$
  with params as (
    select
      p_start as start_date,
      p_end as end_date,
      case when p_window in ('day', 'week', 'month') then p_window else 'day' end as bucket_window,
      coalesce(nullif(p_source, ''), 'all') as source_filter,
      coalesce(cardinality(p_room_type_codes), 0) > 0 as has_room_filter
  ),
  day_periods as (
    select
      gs::date as business_date,
      case
        when (select bucket_window from params) = 'month' then date_trunc('month', gs)::date
        when (select bucket_window from params) = 'week' then date_trunc('week', gs)::date
        else gs::date
      end as period_start
    from generate_series(
      (select start_date from params),
      (select end_date from params),
      interval '1 day'
    ) gs
  ),
  period_days as (
    select period_start, count(*)::int as days_in_bucket
    from day_periods
    group by period_start
  ),
  requested_sources as (
    select unnest(
      case
        when (select source_filter from params) = 'all' then array['fo_reconciled', 'audit_adjusted']::text[]
        else array[(select source_filter from params)]::text[]
      end
    ) as source
  ),
  product_scope as (
    select
      p.id as product_id,
      p.stock_tracking_mode,
      case
        when p.stock_tracking_mode = 'amenity_prepare' then 'fo_reconciled'
        else 'audit_adjusted'
      end as source
    from public.products p
    join requested_sources rs
      on rs.source = case
        when p.stock_tracking_mode = 'amenity_prepare' then 'fo_reconciled'
        else 'audit_adjusted'
      end
    where coalesce(p.is_active, true) = true
      and p.stock_tracking_mode in ('amenity_prepare', 'amenity_direct')
      and (
        p_categories is null
        or cardinality(p_categories) = 0
        or public.fn_amenity_analytics_category_key(p.name) = any(p_categories)
      )
  ),
  setup_presence as (
    select rtas.product_id, count(*)::int as setup_count
    from public.room_type_amenity_setups rtas
    group by rtas.product_id
  ),
  sold_nights as (
    select
      dp.business_date,
      dp.period_start,
      r.room_type_id,
      rt.code as room_type_code
    from day_periods dp
    join public.reservation_nights rn on rn.stay_date = (dp.business_date - interval '1 day')::date
    join public.reservations res on res.id = rn.reservation_id
    join public.rooms r on r.id = rn.room_id
    join public.room_types rt on rt.id = r.room_type_id
    where rn.cancelled_at is null
      and res.status in ('active', 'checked_out')
      and coalesce(res.is_dayuse, false) = false
      and coalesce(r.is_dayuse, false) = false
      and coalesce(r.is_sellable, false) = true
      and upper(coalesce(rt.code, '')) <> 'CLOSED'
      and lower(coalesce(rt.name_en, '')) not like '%closed%'
  ),
  selected_sold_nights as (
    select sn.*
    from sold_nights sn
    cross join params p
    where not p.has_room_filter
      or sn.room_type_code = any(p_room_type_codes)
  ),
  selected_max_daily as (
    select
      sn.business_date,
      rtas.product_id,
      coalesce(sum(rtas.units_per_occupied_night), 0)::numeric as max_qty
    from selected_sold_nights sn
    join public.room_type_amenity_setups rtas on rtas.room_type_id = sn.room_type_id
    group by sn.business_date, rtas.product_id
  ),
  total_max_daily as (
    select
      sn.business_date,
      rtas.product_id,
      coalesce(sum(rtas.units_per_occupied_night), 0)::numeric as max_qty
    from sold_nights sn
    join public.room_type_amenity_setups rtas on rtas.room_type_id = sn.room_type_id
    group by sn.business_date, rtas.product_id
  ),
  fo_actual_daily as (
    select
      v.business_date,
      v.product_id,
      'fo_reconciled'::text as source,
      coalesce(sum(v.consumed_qty), 0)::numeric as actual_qty
    from public.v_amenity_consumption_daily v
    cross join params p
    where v.business_date >= p.start_date
      and v.business_date <= p.end_date
    group by v.business_date, v.product_id
  ),
  audit_actual_daily as (
    select
      s.business_date,
      ai.product_id,
      'audit_adjusted'::text as source,
      coalesce(sum(greatest(ai.refill_delta, 0)), 0)::numeric as actual_qty
    from public.fo_amenity_audit_sessions s
    join public.fo_amenity_audit_items ai on ai.session_id = s.id
    join public.products pdt on pdt.id = ai.product_id
    cross join params p
    where s.business_date >= p.start_date
      and s.business_date <= p.end_date
      and pdt.stock_tracking_mode = 'amenity_direct'
    group by s.business_date, ai.product_id
  ),
  actual_daily as (
    select * from fo_actual_daily
    union all
    select * from audit_actual_daily
  ),
  allocated_actual_daily as (
    select
      dp.period_start,
      ps.product_id,
      ps.source,
      case
        when max(par.has_room_filter::int) = 1 and coalesce(max(sp.setup_count), 0) > 0 then
          case
            when coalesce(max(tmd.max_qty), 0) > 0
              then (coalesce(max(ad.actual_qty), 0) * coalesce(max(smd.max_qty), 0) / max(tmd.max_qty))::numeric
            else 0::numeric
          end
        else coalesce(max(ad.actual_qty), 0)::numeric
      end as actual_qty,
      case
        when coalesce(max(sp.setup_count), 0) = 0 then null::numeric
        else coalesce(max(smd.max_qty), 0)::numeric
      end as max_qty
    from day_periods dp
    cross join product_scope ps
    cross join params par
    left join actual_daily ad on ad.business_date = dp.business_date and ad.product_id = ps.product_id and ad.source = ps.source
    left join setup_presence sp on sp.product_id = ps.product_id
    left join selected_max_daily smd on smd.business_date = dp.business_date and smd.product_id = ps.product_id
    left join total_max_daily tmd on tmd.business_date = dp.business_date and tmd.product_id = ps.product_id
    group by dp.business_date, dp.period_start, ps.product_id, ps.source
  ),
  history as (
    select
      v.product_id,
      count(*)::int as sample_size,
      percentile_cont(0.5) within group (order by v.consumed_qty)::numeric as median_daily
    from public.v_amenity_consumption_daily v
    cross join params p
    where v.business_date >= (p.start_date - interval '14 days')::date
      and v.business_date < p.start_date
    group by v.product_id
  ),
  predict_period as (
    select
      pd.period_start,
      sum(h.median_daily * pd.days_in_bucket)::numeric as predict_qty
    from period_days pd
    join product_scope ps on ps.source = 'fo_reconciled'
    join history h on h.product_id = ps.product_id and h.sample_size >= 7
    group by pd.period_start
  )
  select
    pd.period_start as period,
    coalesce(sum(aad.actual_qty), 0)::numeric as actual,
    max(pp.predict_qty)::numeric as predict,
    case
      when count(aad.max_qty) filter (where aad.max_qty is not null) = 0 then null::numeric
      else coalesce(sum(aad.max_qty), 0)::numeric
    end as max,
    null::numeric as statistical
  from period_days pd
  left join allocated_actual_daily aad on aad.period_start = pd.period_start
  left join predict_period pp on pp.period_start = pd.period_start
  group by pd.period_start
  order by pd.period_start;
$$;

grant execute on function public.fn_amenity_analytics_trend(date, date, text, text, text[], text[]) to authenticated;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604190006_phase69_historical_analytics.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Phase 69: Historical Consumption Analytics baseline snapshots.
-- Source: uploads/db_seed/*.csv generated from Jan 2025-Mar 2026 ETL.
-- Rev 3: roomtype seed uses 7 PMS codes directly (DS/DQ/TS/DT/TB/JS/FR).

create table if not exists public.analytics_historical_monthly_amenity (
  id bigserial primary key,
  period_start date not null,
  year smallint not null,
  month smallint not null check (month between 1 and 12),
  num_days smallint not null,
  total_room_nights int not null,
  thai_room_nights int not null,
  foreign_room_nights int not null,
  unknown_room_nights int not null,
  water_used int not null,
  water_max int not null,
  water_usage_pct numeric(6, 2),
  water_per_room_night numeric(6, 3),
  water_thai_allocated_qty numeric(8, 1) not null,
  water_foreign_allocated_qty numeric(8, 1) not null,
  water_unknown_allocated_qty numeric(8, 1) not null,
  water_thai_per_rn numeric(6, 3),
  water_foreign_per_rn numeric(6, 3),
  coffee_used int not null,
  coffee_max int not null,
  coffee_usage_pct numeric(6, 2),
  coffee_thai_allocated_qty numeric(8, 1) not null,
  coffee_foreign_allocated_qty numeric(8, 1) not null,
  coffee_unknown_allocated_qty numeric(8, 1) not null,
  data_source text default 'excel_etl',
  created_at timestamptz default now(),
  unique (year, month),
  check (period_start = make_date(year::int, month::int, 1))
);

create table if not exists public.analytics_historical_monthly_linen (
  id bigserial primary key,
  period_start date not null,
  year smallint not null,
  month smallint not null check (month between 1 and 12),
  linen_item_id int not null references public.linen_items(id),
  total_sent int not null,
  max_capacity int not null default 0,
  linen_usage_pct numeric(6, 2) default 0,
  price_per_piece numeric(6, 2) not null,
  total_cost numeric(10, 2) not null,
  thai_allocated_qty numeric(8, 1) not null default 0,
  foreign_allocated_qty numeric(8, 1) not null default 0,
  unknown_allocated_qty numeric(8, 1) not null default 0,
  data_source text default 'excel_etl',
  created_at timestamptz default now(),
  unique (year, month, linen_item_id),
  check (period_start = make_date(year::int, month::int, 1))
);

create table if not exists public.analytics_historical_monthly_roomtype (
  id bigserial primary key,
  period_start date not null,
  year smallint not null,
  month smallint not null check (month between 1 and 12),
  room_type_code text not null,
  room_nights int not null,
  thai_nights int not null,
  foreign_nights int not null,
  water_allocated_qty numeric(8, 1) not null default 0,
  coffee_allocated_qty numeric(8, 1) not null default 0,
  water_per_room_night numeric(6, 3) default 0,
  coffee_per_room_night numeric(6, 3) default 0,
  data_source text default 'excel_etl',
  created_at timestamptz default now(),
  unique (year, month, room_type_code),
  check (period_start = make_date(year::int, month::int, 1))
);

alter table public.analytics_historical_monthly_amenity enable row level security;
alter table public.analytics_historical_monthly_linen enable row level security;
alter table public.analytics_historical_monthly_roomtype enable row level security;

drop policy if exists analytics_historical_monthly_amenity_authenticated_read on public.analytics_historical_monthly_amenity;
create policy analytics_historical_monthly_amenity_authenticated_read
  on public.analytics_historical_monthly_amenity
  for select to authenticated
  using (true);

drop policy if exists analytics_historical_monthly_linen_authenticated_read on public.analytics_historical_monthly_linen;
create policy analytics_historical_monthly_linen_authenticated_read
  on public.analytics_historical_monthly_linen
  for select to authenticated
  using (true);

drop policy if exists analytics_historical_monthly_roomtype_authenticated_read on public.analytics_historical_monthly_roomtype;
create policy analytics_historical_monthly_roomtype_authenticated_read
  on public.analytics_historical_monthly_roomtype
  for select to authenticated
  using (true);

grant select on public.analytics_historical_monthly_amenity to authenticated;
grant select on public.analytics_historical_monthly_linen to authenticated;
grant select on public.analytics_historical_monthly_roomtype to authenticated;

with source (
  period_start, year, month, num_days,
  total_room_nights, thai_room_nights, foreign_room_nights, unknown_room_nights,
  water_used, water_max, water_usage_pct, water_per_room_night,
  water_thai_allocated_qty, water_foreign_allocated_qty, water_unknown_allocated_qty,
  water_thai_per_rn, water_foreign_per_rn,
  coffee_used, coffee_max, coffee_usage_pct,
  coffee_thai_allocated_qty, coffee_foreign_allocated_qty, coffee_unknown_allocated_qty
) as (
  values
    ('2025-01-01'::date, 2025, 1, 31, 521, 144, 344, 33, 972, 1103, 88.12, 1.866, 282.8, 657.1, 32.1, 1.964, 1.91, 148, 319, 46.39, 33.1, 109.9, 5.0),
    ('2025-02-01'::date, 2025, 2, 28, 398, 45, 323, 30, 757, 853, 88.75, 1.902, 85.9, 612.2, 58.9, 1.908, 1.895, 116, 251, 46.22, 4.0, 120.9, -8.9),
    ('2025-03-01'::date, 2025, 3, 31, 365, 138, 205, 22, 690, 768, 89.84, 1.89, 259.9, 373.9, 56.2, 1.884, 1.824, 76, 168, 45.24, 27.8, 47.5, 0.7),
    ('2025-04-01'::date, 2025, 4, 30, 317, 112, 182, 23, 602, 667, 90.25, 1.899, 211.9, 338.9, 51.2, 1.892, 1.862, 108, 184, 58.7, 45.2, 59.8, 3.0),
    ('2025-05-01'::date, 2025, 5, 31, 236, 87, 139, 10, 431, 507, 85.01, 1.826, 163.6, 257.1, 10.3, 1.88, 1.849, 64, 148, 43.24, 28.5, 42.5, -7.0),
    ('2025-06-01'::date, 2025, 6, 30, 202, 72, 119, 11, 371, 437, 84.9, 1.837, 133.3, 227.8, 9.9, 1.852, 1.914, 54, 121, 44.63, 11.8, 35.8, 6.4),
    ('2025-07-01'::date, 2025, 7, 31, 283, 96, 174, 13, 562, 605, 92.89, 1.986, 184.0, 340.4, 37.6, 1.917, 1.956, 50, 147, 34.01, 16.0, 45.0, -11.0),
    ('2025-08-01'::date, 2025, 8, 31, 316, 176, 123, 17, 615, 708, 86.86, 1.946, 354.6, 236.4, 24.0, 2.015, 1.922, 116, 200, 58.0, 73.3, 45.7, -3.0),
    ('2025-09-01'::date, 2025, 9, 30, 216, 81, 127, 8, 399, 468, 85.26, 1.847, 147.2, 235.5, 16.3, 1.818, 1.854, 47, 110, 42.73, 15.0, 35.0, -3.0),
    ('2025-10-01'::date, 2025, 10, 31, 306, 191, 97, 18, 582, 663, 87.78, 1.902, 369.7, 185.0, 27.3, 1.936, 1.907, 127, 185, 68.65, 65.8, 62.4, -1.2),
    ('2025-11-01'::date, 2025, 11, 30, 306, 148, 145, 13, 573, 657, 87.21, 1.873, 278.2, 262.4, 32.4, 1.879, 1.809, 35, 117, 29.91, 17.5, 31.0, -13.5),
    ('2025-12-01'::date, 2025, 12, 31, 316, 79, 217, 20, 594, 681, 87.22, 1.88, 156.9, 407.8, 29.3, 1.986, 1.879, 99, 195, 50.77, 24.5, 72.7, 1.8),
    ('2026-01-01'::date, 2026, 1, 31, 420, 173, 222, 25, 804, 941, 85.44, 1.914, 336.7, 430.8, 36.5, 1.946, 1.941, 149, 317, 47.0, 54.8, 97.4, -3.2),
    ('2026-02-01'::date, 2026, 2, 28, 400, 101, 279, 20, 799, 888, 89.98, 1.998, 207.1, 553.3, 38.6, 2.051, 1.983, 125, 262, 47.71, 17.8, 113.6, -6.4),
    ('2026-03-01'::date, 2026, 3, 31, 338, 96, 231, 11, 616, 711, 86.64, 1.822, 169.8, 417.9, 28.3, 1.769, 1.809, 82, 145, 56.55, 22.8, 58.2, 1.0)
)
insert into public.analytics_historical_monthly_amenity (
  period_start, year, month, num_days,
  total_room_nights, thai_room_nights, foreign_room_nights, unknown_room_nights,
  water_used, water_max, water_usage_pct, water_per_room_night,
  water_thai_allocated_qty, water_foreign_allocated_qty, water_unknown_allocated_qty,
  water_thai_per_rn, water_foreign_per_rn,
  coffee_used, coffee_max, coffee_usage_pct,
  coffee_thai_allocated_qty, coffee_foreign_allocated_qty, coffee_unknown_allocated_qty,
  data_source
)
select
  period_start, year, month, num_days,
  total_room_nights, thai_room_nights, foreign_room_nights, unknown_room_nights,
  water_used, water_max, water_usage_pct, water_per_room_night,
  water_thai_allocated_qty, water_foreign_allocated_qty, water_unknown_allocated_qty,
  water_thai_per_rn, water_foreign_per_rn,
  coffee_used, coffee_max, coffee_usage_pct,
  coffee_thai_allocated_qty, coffee_foreign_allocated_qty, coffee_unknown_allocated_qty,
  'excel_etl'
from source
on conflict (year, month) do update set
  period_start = excluded.period_start,
  num_days = excluded.num_days,
  total_room_nights = excluded.total_room_nights,
  thai_room_nights = excluded.thai_room_nights,
  foreign_room_nights = excluded.foreign_room_nights,
  unknown_room_nights = excluded.unknown_room_nights,
  water_used = excluded.water_used,
  water_max = excluded.water_max,
  water_usage_pct = excluded.water_usage_pct,
  water_per_room_night = excluded.water_per_room_night,
  water_thai_allocated_qty = excluded.water_thai_allocated_qty,
  water_foreign_allocated_qty = excluded.water_foreign_allocated_qty,
  water_unknown_allocated_qty = excluded.water_unknown_allocated_qty,
  water_thai_per_rn = excluded.water_thai_per_rn,
  water_foreign_per_rn = excluded.water_foreign_per_rn,
  coffee_used = excluded.coffee_used,
  coffee_max = excluded.coffee_max,
  coffee_usage_pct = excluded.coffee_usage_pct,
  coffee_thai_allocated_qty = excluded.coffee_thai_allocated_qty,
  coffee_foreign_allocated_qty = excluded.coffee_foreign_allocated_qty,
  coffee_unknown_allocated_qty = excluded.coffee_unknown_allocated_qty,
  data_source = excluded.data_source;

with source (
  period_start, year, month, item_number,
  total_sent, max_capacity, linen_usage_pct, price_per_piece, total_cost,
  thai_allocated_qty, foreign_allocated_qty, unknown_allocated_qty
) as (
  values
    ('2025-01-01'::date, 2025, 1, 1, 993, 1105, 89.86, 3.0, 2979.0, 272, 646, 75.0),
    ('2025-01-01'::date, 2025, 1, 2, 831, 1105, 75.2, 5.0, 4155.0, 272, 646, -87.0),
    ('2025-01-01'::date, 2025, 1, 3, 154, 245, 62.86, 3.0, 462.0, 30, 171, -47.0),
    ('2025-01-01'::date, 2025, 1, 4, 402, 557, 72.17, 8.0, 3216.0, 154, 298, -50.0),
    ('2025-01-01'::date, 2025, 1, 5, 167, 193, 86.53, 9.0, 1503.0, 71, 168, -72.0),
    ('2025-01-01'::date, 2025, 1, 6, 61, 81, 75.31, 9.0, 549.0, 7, 53, 1.0),
    ('2025-01-01'::date, 2025, 1, 7, 229, 557, 41.11, 15.0, 3435.0, 64.1, 158.9, 6.0),
    ('2025-01-01'::date, 2025, 1, 8, 95, 193, 49.22, 20.0, 1900.0, 26.2, 64.8, 4.0),
    ('2025-01-01'::date, 2025, 1, 9, 36, 81, 44.44, 20.0, 720.0, 10.7, 24.3, 1.0),
    ('2025-02-01'::date, 2025, 2, 1, 689, 853, 80.77, 3.0, 2067.0, 66, 537, 86.0),
    ('2025-02-01'::date, 2025, 2, 2, 677, 853, 79.37, 5.0, 3385.0, 66, 537, 74.0),
    ('2025-02-01'::date, 2025, 2, 3, 147, 196, 75.0, 3.0, 441.0, 11, 133, 3.0),
    ('2025-02-01'::date, 2025, 2, 4, 296, 415, 71.33, 8.0, 2368.0, 28, 237, 31.0),
    ('2025-02-01'::date, 2025, 2, 5, 130, 157, 82.8, 9.0, 1170.0, 18, 142, -30.0),
    ('2025-02-01'::date, 2025, 2, 6, 49, 62, 79.03, 9.0, 441.0, 1, 42, 6.0),
    ('2025-02-01'::date, 2025, 2, 7, 151, 415, 36.39, 15.0, 2265.0, 14.4, 131.6, 5.0),
    ('2025-02-01'::date, 2025, 2, 8, 67, 157, 42.68, 20.0, 1340.0, 6.5, 56.5, 4.0),
    ('2025-02-01'::date, 2025, 2, 9, 29, 62, 46.77, 20.0, 580.0, 2.6, 25.4, 1.0),
    ('2025-03-01'::date, 2025, 3, 1, 615, 764, 80.5, 3.0, 1845.0, 179, 299, 137.0),
    ('2025-03-01'::date, 2025, 3, 2, 574, 764, 75.13, 5.0, 2870.0, 179, 299, 96.0),
    ('2025-03-01'::date, 2025, 3, 3, 102, 155, 65.81, 3.0, 306.0, 34, 58, 10.0),
    ('2025-03-01'::date, 2025, 3, 4, 273, 378, 72.22, 8.0, 2184.0, 91, 139, 43.0),
    ('2025-03-01'::date, 2025, 3, 5, 127, 144, 88.19, 9.0, 1143.0, 44, 62, 21.0),
    ('2025-03-01'::date, 2025, 3, 6, 28, 49, 57.14, 9.0, 252.0, 4, 22, 2.0),
    ('2025-03-01'::date, 2025, 3, 7, 138, 378, 36.51, 15.0, 2070.0, 52.5, 83.5, 2.0),
    ('2025-03-01'::date, 2025, 3, 8, 69, 144, 47.92, 20.0, 1380.0, 25.2, 41.8, 2.0),
    ('2025-03-01'::date, 2025, 3, 9, 18, 49, 36.73, 20.0, 360.0, 7.0, 11.0, 0.0),
    ('2025-04-01'::date, 2025, 4, 1, 570, 668, 85.33, 3.0, 1710.0, 141, 298, 131.0),
    ('2025-04-01'::date, 2025, 4, 2, 506, 668, 75.75, 5.0, 2530.0, 141, 298, 67.0),
    ('2025-04-01'::date, 2025, 4, 3, 103, 156, 66.03, 3.0, 309.0, 30, 71, 2.0),
    ('2025-04-01'::date, 2025, 4, 4, 247, 298, 82.89, 8.0, 1976.0, 63, 106, 78.0),
    ('2025-04-01'::date, 2025, 4, 5, 121, 131, 92.37, 9.0, 1089.0, 29, 70, 22.0),
    ('2025-04-01'::date, 2025, 4, 6, 27, 54, 50.0, 9.0, 243.0, 14, 26, -13.0),
    ('2025-04-01'::date, 2025, 4, 7, 124, 298, 41.61, 15.0, 1860.0, 44.8, 77.2, 2.0),
    ('2025-04-01'::date, 2025, 4, 8, 57, 131, 43.51, 20.0, 1140.0, 19.5, 37.5, 0.0),
    ('2025-04-01'::date, 2025, 4, 9, 21, 54, 38.89, 20.0, 420.0, 9.2, 10.8, 1.0),
    ('2025-05-01'::date, 2025, 5, 1, 467, 507, 92.11, 3.0, 1401.0, 92, 163, 212.0),
    ('2025-05-01'::date, 2025, 5, 2, 410, 507, 80.87, 5.0, 2050.0, 92, 163, 155.0),
    ('2025-05-01'::date, 2025, 5, 3, 97, 132, 73.48, 3.0, 291.0, 27, 44, 26.0),
    ('2025-05-01'::date, 2025, 5, 4, 190, 221, 85.97, 8.0, 1520.0, 20, 61, 109.0),
    ('2025-05-01'::date, 2025, 5, 5, 101, 105, 96.19, 9.0, 909.0, 39, 39, 23.0),
    ('2025-05-01'::date, 2025, 5, 6, 28, 38, 73.68, 9.0, 252.0, 8, 12, 8.0),
    ('2025-05-01'::date, 2025, 5, 7, 95, 221, 42.99, 15.0, 1425.0, 34.2, 60.8, 0.0),
    ('2025-05-01'::date, 2025, 5, 8, 53, 105, 50.48, 20.0, 1060.0, 18.8, 34.2, 0.0),
    ('2025-05-01'::date, 2025, 5, 9, 19, 38, 50.0, 20.0, 380.0, 8.4, 10.6, 0.0),
    ('2025-06-01'::date, 2025, 6, 1, 396, 435, 91.03, 3.0, 1188.0, 77, 130, 189.0),
    ('2025-06-01'::date, 2025, 6, 2, 366, 435, 84.14, 5.0, 1830.0, 77, 130, 159.0),
    ('2025-06-01'::date, 2025, 6, 3, 89, 108, 82.41, 3.0, 267.0, 20, 35, 34.0),
    ('2025-06-01'::date, 2025, 6, 4, 176, 205, 85.85, 8.0, 1408.0, 31, 50, 95.0),
    ('2025-06-01'::date, 2025, 6, 5, 86, 92, 93.48, 9.0, 774.0, 21, 42, 23.0),
    ('2025-06-01'::date, 2025, 6, 6, 20, 23, 86.96, 9.0, 180.0, 2, 6, 12.0),
    ('2025-06-01'::date, 2025, 6, 7, 108, 205, 52.68, 15.0, 1620.0, 32.7, 70.3, 5.0),
    ('2025-06-01'::date, 2025, 6, 8, 47, 92, 51.09, 20.0, 940.0, 11.8, 34.2, 1.0),
    ('2025-06-01'::date, 2025, 6, 9, 13, 23, 56.52, 20.0, 260.0, 3.7, 9.3, 0.0),
    ('2025-07-01'::date, 2025, 7, 1, 528, 605, 87.27, 3.0, 1584.0, 94, 229, 205.0),
    ('2025-07-01'::date, 2025, 7, 2, 483, 605, 79.83, 5.0, 2415.0, 94, 229, 160.0),
    ('2025-07-01'::date, 2025, 7, 3, 109, 136, 80.15, 3.0, 327.0, 20, 57, 32.0),
    ('2025-07-01'::date, 2025, 7, 4, 263, 305, 86.23, 8.0, 2104.0, 36, 115, 112.0),
    ('2025-07-01'::date, 2025, 7, 5, 103, 120, 85.83, 9.0, 927.0, 27, 69, 7.0),
    ('2025-07-01'::date, 2025, 7, 6, 25, 30, 83.33, 9.0, 225.0, 2, 9, 14.0),
    ('2025-07-01'::date, 2025, 7, 7, 139, 305, 45.57, 15.0, 2085.0, 41.7, 95.3, 2.0),
    ('2025-07-01'::date, 2025, 7, 8, 62, 120, 51.67, 20.0, 1240.0, 19.2, 41.8, 1.0),
    ('2025-07-01'::date, 2025, 7, 9, 17, 30, 56.67, 20.0, 340.0, 5.9, 10.1, 1.0),
    ('2025-08-01'::date, 2025, 8, 1, 607, 688, 88.23, 3.0, 1821.0, 239, 175, 193.0),
    ('2025-08-01'::date, 2025, 8, 2, 568, 688, 82.56, 5.0, 2840.0, 239, 175, 154.0),
    ('2025-08-01'::date, 2025, 8, 3, 111, 159, 69.81, 3.0, 333.0, 43, 58, 10.0),
    ('2025-08-01'::date, 2025, 8, 4, 286, 360, 79.44, 8.0, 2288.0, 139, 73, 74.0),
    ('2025-08-01'::date, 2025, 8, 5, 107, 119, 89.92, 9.0, 963.0, 67, 48, -8.0),
    ('2025-08-01'::date, 2025, 8, 6, 30, 45, 66.67, 9.0, 270.0, 13, 6, 11.0),
    ('2025-08-01'::date, 2025, 8, 7, 158, 360, 43.89, 15.0, 2370.0, 86.3, 63.7, 8.0),
    ('2025-08-01'::date, 2025, 8, 8, 49, 119, 41.18, 20.0, 980.0, 26.2, 19.8, 3.0),
    ('2025-08-01'::date, 2025, 8, 9, 20, 45, 44.44, 20.0, 400.0, 11.6, 8.4, 0.0),
    ('2025-09-01'::date, 2025, 9, 1, 446, 462, 96.54, 3.0, 1338.0, 103, 152, 191.0),
    ('2025-09-01'::date, 2025, 9, 2, 411, 462, 88.96, 5.0, 2055.0, 103, 152, 156.0),
    ('2025-09-01'::date, 2025, 9, 3, 71, 102, 69.61, 3.0, 213.0, 21, 33, 17.0),
    ('2025-09-01'::date, 2025, 9, 4, 215, 238, 90.34, 8.0, 1720.0, 33, 92, 90.0),
    ('2025-09-01'::date, 2025, 9, 5, 85, 91, 93.41, 9.0, 765.0, 33, 25, 27.0),
    ('2025-09-01'::date, 2025, 9, 6, 17, 21, 80.95, 9.0, 153.0, 2, 5, 10.0),
    ('2025-09-01'::date, 2025, 9, 7, 122, 238, 51.26, 15.0, 1830.0, 31.3, 80.7, 10.0),
    ('2025-09-01'::date, 2025, 9, 8, 41, 91, 45.05, 20.0, 820.0, 9.7, 28.3, 3.0),
    ('2025-09-01'::date, 2025, 9, 9, 13, 21, 61.9, 20.0, 260.0, 4.2, 8.8, 0.0),
    ('2025-10-01'::date, 2025, 10, 1, 605, 653, 92.65, 3.0, 1815.0, 283, 129, 193.0),
    ('2025-10-01'::date, 2025, 10, 2, 564, 653, 86.37, 5.0, 2820.0, 283, 129, 152.0),
    ('2025-10-01'::date, 2025, 10, 3, 136, 157, 86.62, 3.0, 408.0, 66, 36, 34.0),
    ('2025-10-01'::date, 2025, 10, 4, 255, 309, 82.52, 8.0, 2040.0, 149, 29, 77.0),
    ('2025-10-01'::date, 2025, 10, 5, 110, 122, 90.16, 9.0, 990.0, 69, 33, 8.0),
    ('2025-10-01'::date, 2025, 10, 6, 41, 50, 82.0, 9.0, 369.0, 13, 17, 11.0),
    ('2025-10-01'::date, 2025, 10, 7, 130, 309, 42.07, 15.0, 1950.0, 83.6, 44.4, 2.0),
    ('2025-10-01'::date, 2025, 10, 8, 59, 122, 48.36, 20.0, 1180.0, 37.9, 20.1, 1.0),
    ('2025-10-01'::date, 2025, 10, 9, 25, 50, 50.0, 20.0, 500.0, 15.8, 9.2, 0.0),
    ('2025-11-01'::date, 2025, 11, 1, 543, 643, 84.45, 3.0, 1629.0, 170, 218, 155.0),
    ('2025-11-01'::date, 2025, 11, 2, 521, 643, 81.03, 5.0, 2605.0, 170, 218, 133.0),
    ('2025-11-01'::date, 2025, 11, 3, 89, 109, 81.65, 3.0, 267.0, 21, 32, 36.0),
    ('2025-11-01'::date, 2025, 11, 4, 260, 319, 81.5, 8.0, 2080.0, 78, 98, 84.0),
    ('2025-11-01'::date, 2025, 11, 5, 104, 142, 73.24, 9.0, 936.0, 44, 58, 2.0),
    ('2025-11-01'::date, 2025, 11, 6, 16, 20, 80.0, 9.0, 144.0, 2, 3, 11.0),
    ('2025-11-01'::date, 2025, 11, 7, 141, 319, 44.2, 15.0, 2115.0, 65.1, 65.9, 10.0),
    ('2025-11-01'::date, 2025, 11, 8, 60, 142, 42.25, 20.0, 1200.0, 27.8, 29.2, 3.0),
    ('2025-11-01'::date, 2025, 11, 9, 11, 20, 55.0, 20.0, 220.0, 6.7, 4.3, 0.0),
    ('2025-12-01'::date, 2025, 12, 1, 542, 675, 80.3, 3.0, 1626.0, 80, 315, 147.0),
    ('2025-12-01'::date, 2025, 12, 2, 498, 675, 73.78, 5.0, 2490.0, 80, 315, 103.0),
    ('2025-12-01'::date, 2025, 12, 3, 119, 152, 78.29, 3.0, 357.0, 16, 74, 29.0),
    ('2025-12-01'::date, 2025, 12, 4, 231, 315, 73.33, 8.0, 1848.0, 34, 127, 70.0),
    ('2025-12-01'::date, 2025, 12, 5, 99, 130, 76.15, 9.0, 891.0, 29, 79, -9.0),
    ('2025-12-01'::date, 2025, 12, 6, 35, 50, 70.0, 9.0, 315.0, 3, 24, 8.0),
    ('2025-12-01'::date, 2025, 12, 7, 129, 315, 40.95, 15.0, 1935.0, 31.1, 95.9, 2.0),
    ('2025-12-01'::date, 2025, 12, 8, 61, 130, 46.92, 20.0, 1220.0, 13.3, 45.7, 2.0),
    ('2025-12-01'::date, 2025, 12, 9, 28, 50, 56.0, 20.0, 560.0, 5.3, 20.7, 2.0),
    ('2026-01-01'::date, 2026, 1, 1, 775, 917, 84.51, 3.0, 2325.0, 282, 338, 155.0),
    ('2026-01-01'::date, 2026, 1, 2, 733, 917, 79.93, 5.0, 3665.0, 282, 338, 113.0),
    ('2026-01-01'::date, 2026, 1, 3, 183, 220, 83.18, 3.0, 549.0, 57, 102, 24.0),
    ('2026-01-01'::date, 2026, 1, 4, 340, 485, 70.1, 8.0, 2720.0, 158, 162, 20.0),
    ('2026-01-01'::date, 2026, 1, 5, 112, 139, 80.58, 9.0, 1008.0, 88, 74, -50.0),
    ('2026-01-01'::date, 2026, 1, 6, 58, 77, 75.32, 9.0, 522.0, 11, 38, 9.0),
    ('2026-01-01'::date, 2026, 1, 7, 194, 485, 40.0, 15.0, 2910.0, 71.9, 115.1, 7.0),
    ('2026-01-01'::date, 2026, 1, 8, 57, 139, 41.01, 20.0, 1140.0, 18.3, 37.7, 1.0),
    ('2026-01-01'::date, 2026, 1, 9, 36, 77, 46.75, 20.0, 720.0, 12.1, 23.9, 0.0),
    ('2026-02-01'::date, 2026, 2, 1, 715, 858, 83.33, 3.0, 2145.0, 159, 447, 109.0),
    ('2026-02-01'::date, 2026, 2, 2, 609, 858, 70.98, 5.0, 3045.0, 159, 447, 3.0),
    ('2026-02-01'::date, 2026, 2, 3, 153, 206, 74.27, 3.0, 459.0, 17, 131, 5.0),
    ('2026-02-01'::date, 2026, 2, 4, 293, 404, 72.52, 8.0, 2344.0, 65, 193, 35.0),
    ('2026-02-01'::date, 2026, 2, 5, 141, 152, 92.76, 9.0, 1269.0, 60, 120, -39.0),
    ('2026-02-01'::date, 2026, 2, 6, 49, 75, 65.33, 9.0, 441.0, 5, 44, 0.0),
    ('2026-02-01'::date, 2026, 2, 7, 158, 404, 39.11, 15.0, 2370.0, 37.6, 112.4, 8.0),
    ('2026-02-01'::date, 2026, 2, 8, 69, 152, 45.39, 20.0, 1380.0, 15.3, 49.7, 4.0),
    ('2026-02-01'::date, 2026, 2, 9, 37, 75, 49.33, 20.0, 740.0, 8.4, 27.6, 1.0),
    ('2026-03-01'::date, 2026, 3, 1, 707, 0, 0, 3, 2121, 135, 320, 252.0),
    ('2026-03-01'::date, 2026, 3, 2, 707, 0, 0, 5, 3535, 135, 320, 252.0),
    ('2026-03-01'::date, 2026, 3, 3, 151, 0, 0, 3, 453, 24, 73, 54.0),
    ('2026-03-01'::date, 2026, 3, 4, 371, 0, 0, 8, 2968, 61, 170, 140.0),
    ('2026-03-01'::date, 2026, 3, 5, 133, 0, 0, 9, 1197, 35, 59, 39.0),
    ('2026-03-01'::date, 2026, 3, 6, 35, 0, 0, 9, 315, 2, 16, 17.0)
)
insert into public.analytics_historical_monthly_linen (
  period_start, year, month, linen_item_id,
  total_sent, max_capacity, linen_usage_pct, price_per_piece, total_cost,
  thai_allocated_qty, foreign_allocated_qty, unknown_allocated_qty,
  data_source
)
select
  s.period_start, s.year, s.month, li.id,
  s.total_sent, s.max_capacity, s.linen_usage_pct, s.price_per_piece, s.total_cost,
  s.thai_allocated_qty, s.foreign_allocated_qty, s.unknown_allocated_qty,
  'excel_etl'
from source s
join public.linen_items li on li.item_number = s.item_number
on conflict (year, month, linen_item_id) do update set
  period_start = excluded.period_start,
  total_sent = excluded.total_sent,
  max_capacity = excluded.max_capacity,
  linen_usage_pct = excluded.linen_usage_pct,
  price_per_piece = excluded.price_per_piece,
  total_cost = excluded.total_cost,
  thai_allocated_qty = excluded.thai_allocated_qty,
  foreign_allocated_qty = excluded.foreign_allocated_qty,
  unknown_allocated_qty = excluded.unknown_allocated_qty,
  data_source = excluded.data_source;

with source (
  period_start, year, month, room_type_code,
  room_nights, thai_nights, foreign_nights,
  water_allocated_qty, coffee_allocated_qty,
  water_per_room_night, coffee_per_room_night
) as (
  values
    ('2025-01-01'::date, 2025, 1, 'DQ', 59, 10, 49, 113.3, 0, 1.92, 0.0),
    ('2025-01-01'::date, 2025, 1, 'DS', 128, 45, 81, 245.5, 0, 1.918, 0.0),
    ('2025-01-01'::date, 2025, 1, 'TB', 42, 11, 31, 82.6, 54.7, 1.966, 1.302),
    ('2025-01-01'::date, 2025, 1, 'DT', 57, 4, 52, 108.8, 0, 1.909, 0.0),
    ('2025-01-01'::date, 2025, 1, 'TS', 140, 62, 68, 270.3, 0, 1.931, 0.0),
    ('2025-01-01'::date, 2025, 1, 'JS', 48, 3, 43, 91.7, 58.2, 1.911, 1.212),
    ('2025-01-01'::date, 2025, 1, 'FR', 30, 9, 20, 59.7, 36.1, 1.992, 1.204),
    ('2025-02-01'::date, 2025, 2, 'DS', 102, 17, 82, 193.1, 0, 1.893, 0.0),
    ('2025-02-01'::date, 2025, 2, 'JS', 40, 0, 39, 75.8, 51.5, 1.894, 1.288),
    ('2025-02-01'::date, 2025, 2, 'TS', 89, 12, 60, 168.8, 0, 1.896, 0.0),
    ('2025-02-01'::date, 2025, 2, 'TB', 35, 2, 32, 66.4, 44.5, 1.897, 1.27),
    ('2025-02-01'::date, 2025, 2, 'DT', 47, 7, 37, 88.0, 0, 1.873, 0.0),
    ('2025-02-01'::date, 2025, 2, 'FR', 22, 2, 17, 42.2, 32.0, 1.917, 1.455),
    ('2025-02-01'::date, 2025, 2, 'DQ', 48, 4, 42, 90.8, 0, 1.892, 0.0),
    ('2025-03-01'::date, 2025, 3, 'JS', 32, 6, 24, 60.0, 37.4, 1.874, 1.167),
    ('2025-03-01'::date, 2025, 3, 'DQ', 46, 16, 29, 84.7, 0, 1.841, 0.0),
    ('2025-03-01'::date, 2025, 3, 'DS', 95, 40, 50, 174.0, 0, 1.831, 0.0),
    ('2025-03-01'::date, 2025, 3, 'TS', 112, 40, 55, 207.5, 0, 1.852, 0.0),
    ('2025-03-01'::date, 2025, 3, 'TB', 18, 6, 10, 34.4, 23.3, 1.914, 1.294),
    ('2025-03-01'::date, 2025, 3, 'DT', 39, 19, 18, 72.6, 0, 1.861, 0.0),
    ('2025-03-01'::date, 2025, 3, 'FR', 16, 5, 11, 28.9, 19.4, 1.809, 1.209),
    ('2025-04-01'::date, 2025, 4, 'JS', 45, 15, 26, 82.6, 64.3, 1.835, 1.43),
    ('2025-04-01'::date, 2025, 4, 'DQ', 44, 9, 31, 80.0, 0, 1.818, 0.0),
    ('2025-04-01'::date, 2025, 4, 'TB', 26, 12, 13, 47.2, 37.5, 1.814, 1.442),
    ('2025-04-01'::date, 2025, 4, 'TS', 75, 28, 37, 144.3, 0, 1.924, 0.0),
    ('2025-04-01'::date, 2025, 4, 'DS', 85, 29, 53, 161.6, 0, 1.902, 0.0),
    ('2025-04-01'::date, 2025, 4, 'DT', 31, 11, 17, 59.2, 0, 1.911, 0.0),
    ('2025-04-01'::date, 2025, 4, 'FR', 8, 6, 1, 15.2, 9.2, 1.895, 1.146),
    ('2025-05-01'::date, 2025, 5, 'DS', 59, 25, 33, 110.8, 0, 1.878, 0.0),
    ('2025-05-01'::date, 2025, 5, 'JS', 25, 7, 18, 43.6, 22.9, 1.743, 0.916),
    ('2025-05-01'::date, 2025, 5, 'DQ', 44, 20, 23, 84.2, 0, 1.914, 0.0),
    ('2025-05-01'::date, 2025, 5, 'TB', 24, 6, 17, 44.7, 34.6, 1.862, 1.44),
    ('2025-05-01'::date, 2025, 5, 'DT', 23, 10, 12, 45.1, 0, 1.959, 0.0),
    ('2025-05-01'::date, 2025, 5, 'TS', 42, 11, 30, 77.1, 0, 1.835, 0.0),
    ('2025-05-01'::date, 2025, 5, 'FR', 11, 7, 4, 19.6, 14.5, 1.782, 1.321),
    ('2025-06-01'::date, 2025, 6, 'JS', 14, 2, 12, 26.0, 12.2, 1.858, 0.869),
    ('2025-06-01'::date, 2025, 6, 'DQ', 43, 14, 28, 82.7, 0, 1.923, 0.0),
    ('2025-06-01'::date, 2025, 6, 'DS', 44, 18, 25, 76.1, 0, 1.731, 0.0),
    ('2025-06-01'::date, 2025, 6, 'TS', 41, 15, 26, 78.8, 0, 1.921, 0.0),
    ('2025-06-01'::date, 2025, 6, 'TB', 21, 3, 17, 45.2, 25.5, 2.152, 1.214),
    ('2025-06-01'::date, 2025, 6, 'FR', 8, 5, 2, 16.8, 12.3, 2.095, 1.542),
    ('2025-06-01'::date, 2025, 6, 'DT', 17, 12, 5, 32.5, 0, 1.909, 0.0),
    ('2025-07-01'::date, 2025, 7, 'DS', 70, 34, 32, 130.8, 0, 1.869, 0.0),
    ('2025-07-01'::date, 2025, 7, 'JS', 15, 2, 13, 27.2, 6.7, 1.816, 0.444),
    ('2025-07-01'::date, 2025, 7, 'DQ', 48, 12, 35, 93.4, 0, 1.945, 0.0),
    ('2025-07-01'::date, 2025, 7, 'TS', 75, 14, 48, 145.7, 0, 1.943, 0.0),
    ('2025-07-01'::date, 2025, 7, 'TB', 24, 4, 20, 49.7, 30.8, 2.069, 1.285),
    ('2025-07-01'::date, 2025, 7, 'DT', 30, 15, 13, 56.9, 0, 1.896, 0.0),
    ('2025-07-01'::date, 2025, 7, 'FR', 15, 4, 11, 30.3, 17.5, 2.02, 1.167),
    ('2025-08-01'::date, 2025, 8, 'DS', 68, 45, 22, 132.9, 0, 1.955, 0.0),
    ('2025-08-01'::date, 2025, 8, 'TS', 86, 57, 19, 167.4, 0, 1.946, 0.0),
    ('2025-08-01'::date, 2025, 8, 'DQ', 49, 15, 34, 93.7, 0, 1.913, 0.0),
    ('2025-08-01'::date, 2025, 8, 'JS', 20, 10, 9, 42.5, 29.6, 2.124, 1.48),
    ('2025-08-01'::date, 2025, 8, 'TB', 29, 16, 13, 56.7, 58.4, 1.956, 2.015),
    ('2025-08-01'::date, 2025, 8, 'DT', 34, 15, 19, 63.4, 0, 1.865, 0.0),
    ('2025-08-01'::date, 2025, 8, 'FR', 20, 16, 3, 40.3, 32.0, 2.016, 1.598),
    ('2025-09-01'::date, 2025, 9, 'JS', 9, 0, 9, 17.2, 5.1, 1.909, 0.567),
    ('2025-09-01'::date, 2025, 9, 'DS', 48, 29, 19, 87.7, 0, 1.827, 0.0),
    ('2025-09-01'::date, 2025, 9, 'TS', 63, 13, 41, 115.2, 0, 1.828, 0.0),
    ('2025-09-01'::date, 2025, 9, 'DT', 20, 11, 9, 38.2, 0, 1.908, 0.0),
    ('2025-09-01'::date, 2025, 9, 'TB', 18, 2, 16, 32.6, 21.8, 1.81, 1.209),
    ('2025-09-01'::date, 2025, 9, 'DQ', 39, 17, 22, 71.7, 0, 1.839, 0.0),
    ('2025-09-01'::date, 2025, 9, 'FR', 10, 4, 6, 18.5, 19.1, 1.848, 1.913),
    ('2025-10-01'::date, 2025, 10, 'DT', 36, 26, 7, 69.4, 0, 1.928, 0.0),
    ('2025-10-01'::date, 2025, 10, 'TS', 72, 49, 15, 139.5, 0, 1.937, 0.0),
    ('2025-10-01'::date, 2025, 10, 'DQ', 47, 31, 16, 90.7, 0, 1.93, 0.0),
    ('2025-10-01'::date, 2025, 10, 'JS', 29, 7, 20, 55.3, 52.9, 1.907, 1.825),
    ('2025-10-01'::date, 2025, 10, 'DS', 69, 43, 25, 134.6, 0, 1.951, 0.0),
    ('2025-10-01'::date, 2025, 10, 'FR', 19, 14, 5, 38.7, 34.3, 2.038, 1.807),
    ('2025-10-01'::date, 2025, 10, 'TB', 21, 16, 5, 40.8, 41.7, 1.944, 1.988),
    ('2025-11-01'::date, 2025, 11, 'JS', 11, 2, 9, 20.3, 8.3, 1.846, 0.758),
    ('2025-11-01'::date, 2025, 11, 'DQ', 38, 23, 15, 69.6, 0, 1.831, 0.0),
    ('2025-11-01'::date, 2025, 11, 'DS', 100, 45, 51, 181.0, 0, 1.81, 0.0),
    ('2025-11-01'::date, 2025, 11, 'TB', 23, 10, 13, 44.0, 25.9, 1.911, 1.127),
    ('2025-11-01'::date, 2025, 11, 'DT', 28, 14, 14, 50.9, 0, 1.818, 0.0),
    ('2025-11-01'::date, 2025, 11, 'TS', 89, 43, 35, 163.8, 0, 1.841, 0.0),
    ('2025-11-01'::date, 2025, 11, 'FR', 8, 5, 2, 15.4, 10.8, 1.923, 1.344),
    ('2025-12-01'::date, 2025, 12, 'DS', 86, 24, 61, 157.7, 0, 1.834, 0.0),
    ('2025-12-01'::date, 2025, 12, 'DT', 34, 10, 24, 65.2, 0, 1.917, 0.0),
    ('2025-12-01'::date, 2025, 12, 'TS', 69, 16, 43, 131.6, 0, 1.907, 0.0),
    ('2025-12-01'::date, 2025, 12, 'DQ', 39, 9, 29, 73.1, 0, 1.875, 0.0),
    ('2025-12-01'::date, 2025, 12, 'TB', 26, 7, 19, 54.1, 36.1, 2.08, 1.387),
    ('2025-12-01'::date, 2025, 12, 'FR', 17, 6, 9, 35.0, 25.7, 2.057, 1.511),
    ('2025-12-01'::date, 2025, 12, 'JS', 31, 3, 28, 59.3, 36.2, 1.913, 1.169),
    ('2026-01-01'::date, 2026, 1, 'JS', 41, 6, 33, 78.9, 54.9, 1.924, 1.339),
    ('2026-01-01'::date, 2026, 1, 'DQ', 50, 15, 32, 95.8, 0, 1.916, 0.0),
    ('2026-01-01'::date, 2026, 1, 'DS', 82, 47, 35, 157.6, 0, 1.923, 0.0),
    ('2026-01-01'::date, 2026, 1, 'TB', 42, 20, 22, 80.3, 57.8, 1.911, 1.376),
    ('2026-01-01'::date, 2026, 1, 'DT', 46, 17, 27, 89.7, 0, 1.951, 0.0),
    ('2026-01-01'::date, 2026, 1, 'TS', 110, 53, 41, 217.4, 0, 1.977, 0.0),
    ('2026-01-01'::date, 2026, 1, 'FR', 34, 8, 25, 67.3, 43.3, 1.978, 1.274),
    ('2026-02-01'::date, 2026, 2, 'DQ', 52, 3, 46, 103.5, 0, 1.99, 0.0),
    ('2026-02-01'::date, 2026, 2, 'DS', 94, 46, 47, 185.9, 0, 1.978, 0.0),
    ('2026-02-01'::date, 2026, 2, 'DT', 48, 8, 38, 94.5, 0, 1.969, 0.0),
    ('2026-02-01'::date, 2026, 2, 'TB', 27, 1, 26, 55.6, 35.8, 2.06, 1.327),
    ('2026-02-01'::date, 2026, 2, 'TS', 93, 28, 55, 185.5, 0, 1.995, 0.0),
    ('2026-02-01'::date, 2026, 2, 'FR', 27, 8, 19, 55.9, 35.7, 2.07, 1.321),
    ('2026-02-01'::date, 2026, 2, 'JS', 44, 2, 38, 88.0, 58.5, 2.0, 1.33),
    ('2026-03-01'::date, 2026, 3, 'JS', 26, 2, 23, 47.5, 38.8, 1.828, 1.491),
    ('2026-03-01'::date, 2026, 3, 'DQ', 43, 14, 28, 75.4, 0, 1.754, 0.0),
    ('2026-03-01'::date, 2026, 3, 'DS', 87, 34, 51, 154.7, 0, 1.778, 0.0),
    ('2026-03-01'::date, 2026, 3, 'DT', 49, 8, 36, 87.2, 0, 1.781, 0.0),
    ('2026-03-01'::date, 2026, 3, 'TS', 93, 23, 63, 166.8, 0, 1.794, 0.0),
    ('2026-03-01'::date, 2026, 3, 'FR', 9, 4, 5, 16.2, 10.7, 1.8, 1.191),
    ('2026-03-01'::date, 2026, 3, 'TB', 21, 7, 14, 39.1, 27.5, 1.863, 1.31)
)
insert into public.analytics_historical_monthly_roomtype (
  period_start, year, month, room_type_code,
  room_nights, thai_nights, foreign_nights,
  water_allocated_qty, coffee_allocated_qty,
  water_per_room_night, coffee_per_room_night,
  data_source
)
select
  period_start, year, month, room_type_code,
  room_nights, thai_nights, foreign_nights,
  water_allocated_qty, coffee_allocated_qty,
  water_per_room_night, coffee_per_room_night,
  'excel_etl'
from source
on conflict (year, month, room_type_code) do update set
  period_start = excluded.period_start,
  room_nights = excluded.room_nights,
  thai_nights = excluded.thai_nights,
  foreign_nights = excluded.foreign_nights,
  water_allocated_qty = excluded.water_allocated_qty,
  coffee_allocated_qty = excluded.coffee_allocated_qty,
  water_per_room_night = excluded.water_per_room_night,
  coffee_per_room_night = excluded.coffee_per_room_night,
  data_source = excluded.data_source;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604200001_phase70_room_group_map.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 70: Abbreviated Tax Invoice — Room Group Map
-- Maps room_type_code → tax_group (A/B/C/D/E) for ใบกำกับภาษีอย่างย่อ
-- Seed per WORK_ASSIGNMENT_PHASE70.md D14:
--   A = DS, TS   (Standard twin/double)
--   B = DQ, DT   (Deluxe queen/twin + DT moved from D per User correction)
--   C = JS       (Junior Suite)
--   D = TB       (Triple)
--   E = FR       (Family)

CREATE TABLE IF NOT EXISTS public.tax_invoice_room_group_map (
  id              serial PRIMARY KEY,
  room_type_code  text NOT NULL UNIQUE,
  tax_group       char(1) NOT NULL CHECK (tax_group IN ('A','B','C','D','E')),
  label_th        text NOT NULL,
  sort_order      smallint NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.tax_invoice_room_group_map
  IS 'Phase 70: maps PMS room_type_code to abbreviated tax invoice group (A-E) for ใบกำกับภาษีอย่างย่อ';

COMMENT ON COLUMN public.tax_invoice_room_group_map.tax_group
  IS 'A=Standard, B=Deluxe, C=Junior Suite, D=Triple, E=Family';

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
ALTER TABLE public.tax_invoice_room_group_map ENABLE ROW LEVEL SECURITY;

CREATE POLICY tirgm_select ON public.tax_invoice_room_group_map
  FOR SELECT TO authenticated USING (true);

CREATE POLICY tirgm_modify ON public.tax_invoice_room_group_map
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));

-- ------------------------------------------------------------
-- Seed (User-confirmed mapping, 2026-04-20)
-- ------------------------------------------------------------
INSERT INTO public.tax_invoice_room_group_map (room_type_code, tax_group, label_th, sort_order)
VALUES
  ('DS', 'A', 'ห้องพักแบบ A', 10),
  ('TS', 'A', 'ห้องพักแบบ A', 11),
  ('DQ', 'B', 'ห้องพักแบบ B', 20),
  ('DT', 'B', 'ห้องพักแบบ B', 21),
  ('JS', 'C', 'ห้องพักแบบ C', 30),
  ('TB', 'D', 'ห้องพักแบบ D', 40),
  ('FR', 'E', 'ห้องพักแบบ E', 50)
ON CONFLICT (room_type_code) DO UPDATE
  SET tax_group  = EXCLUDED.tax_group,
      label_th   = EXCLUDED.label_th,
      sort_order = EXCLUDED.sort_order;

-- ------------------------------------------------------------
-- Index
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tirgm_tax_group
  ON public.tax_invoice_room_group_map(tax_group, sort_order);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604200002_phase70_channel_flag.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 70: Monthly Audit channel flag layer
-- Additive tax-invoice channel override for abbreviated tax invoices.

CREATE TABLE IF NOT EXISTS public.monthly_audit_channel_flag (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_period_id uuid NOT NULL REFERENCES public.monthly_audit_periods(id) ON DELETE CASCADE,
  entry_id uuid NOT NULL REFERENCES public.monthly_audit_entries(id) ON DELETE CASCADE,
  actual_channel text NOT NULL CHECK (actual_channel IN ('ota','walkin','direct','agent')),
  tax_invoice_channel text NOT NULL CHECK (tax_invoice_channel IN ('ota','walkin','direct','agent')),
  reason text,
  flagged_by_user_id uuid REFERENCES auth.users(id),
  flagged_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (entry_id)
);

COMMENT ON TABLE public.monthly_audit_channel_flag
  IS 'Phase 70: additive channel override for abbreviated tax invoices; PMS reservation source remains unchanged.';

CREATE INDEX IF NOT EXISTS idx_macf_period
  ON public.monthly_audit_channel_flag(audit_period_id);

CREATE INDEX IF NOT EXISTS idx_macf_tax_channel
  ON public.monthly_audit_channel_flag(audit_period_id, tax_invoice_channel);

ALTER TABLE public.monthly_audit_channel_flag ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS macf_select ON public.monthly_audit_channel_flag;
CREATE POLICY macf_select ON public.monthly_audit_channel_flag
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS macf_modify ON public.monthly_audit_channel_flag;
CREATE POLICY macf_modify ON public.monthly_audit_channel_flag
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604200003_phase70_abbr_invoice.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 70: Abbreviated Tax Invoice head + lines

CREATE TABLE IF NOT EXISTS public.abbreviated_tax_invoice (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no text NOT NULL,
  book_no int NOT NULL,
  issue_date date NOT NULL,
  channel_group text NOT NULL CHECK (channel_group IN ('ota','walkin_direct')),
  tax_invoice_channel text NOT NULL CHECK (tax_invoice_channel IN ('ota','walkin','direct','agent')),
  audit_period_id uuid NOT NULL REFERENCES public.monthly_audit_periods(id) ON DELETE RESTRICT,
  stay_date_from date NOT NULL,
  stay_date_to date NOT NULL,
  subtotal_inc_vat numeric(12,2) NOT NULL,
  subtotal_ex_vat numeric(12,2) NOT NULL,
  vat_rate numeric(4,2) NOT NULL DEFAULT 7.00,
  vat_amount numeric(12,2) NOT NULL,
  seller_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','issued','cancelled')),
  generated_by_user_id uuid REFERENCES auth.users(id),
  generated_at timestamptz NOT NULL DEFAULT now(),
  cancelled_reason text,
  cancelled_at timestamptz
);

COMMENT ON TABLE public.abbreviated_tax_invoice
  IS 'Phase 70: daily abbreviated tax invoice, one invoice per issue_date and channel group.';

COMMENT ON COLUMN public.abbreviated_tax_invoice.invoice_no
  IS 'Exact legacy format: YYMMDD for OTA/agent, WYYMMDD for walkin/direct. YY is Buddhist year modulo 100.';

CREATE TABLE IF NOT EXISTS public.abbreviated_tax_invoice_line (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES public.abbreviated_tax_invoice(id) ON DELETE CASCADE,
  line_order int NOT NULL,
  tax_group char(1) NOT NULL CHECK (tax_group IN ('A','B','C','D','E')),
  label_th text NOT NULL,
  quantity int NOT NULL CHECK (quantity > 0),
  unit_price numeric(10,2) NOT NULL CHECK (unit_price >= 0),
  amount numeric(12,2) NOT NULL CHECK (amount >= 0),
  source_entry_ids uuid[] NOT NULL DEFAULT '{}'::uuid[],
  shifted_from_date date,
  shifted_reason text
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_abbr_invoice_no_active
  ON public.abbreviated_tax_invoice(invoice_no)
  WHERE status <> 'cancelled';

CREATE UNIQUE INDEX IF NOT EXISTS idx_abbr_invoice_day_channel_active
  ON public.abbreviated_tax_invoice(audit_period_id, issue_date, channel_group)
  WHERE status <> 'cancelled';

CREATE INDEX IF NOT EXISTS idx_abbr_invoice_period
  ON public.abbreviated_tax_invoice(audit_period_id, channel_group, issue_date);

CREATE INDEX IF NOT EXISTS idx_abbr_invoice_status
  ON public.abbreviated_tax_invoice(status, generated_at DESC);

CREATE INDEX IF NOT EXISTS idx_abbr_invoice_line_invoice
  ON public.abbreviated_tax_invoice_line(invoice_id, line_order);

ALTER TABLE public.abbreviated_tax_invoice ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abbreviated_tax_invoice_line ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ati_select ON public.abbreviated_tax_invoice;
CREATE POLICY ati_select ON public.abbreviated_tax_invoice
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS ati_modify ON public.abbreviated_tax_invoice;
CREATE POLICY ati_modify ON public.abbreviated_tax_invoice
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));

DROP POLICY IF EXISTS atil_select ON public.abbreviated_tax_invoice_line;
CREATE POLICY atil_select ON public.abbreviated_tax_invoice_line
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS atil_modify ON public.abbreviated_tax_invoice_line;
CREATE POLICY atil_modify ON public.abbreviated_tax_invoice_line
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604200004_phase70_abbr_overrides.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 70: Pre-generate abbreviated invoice override state

CREATE TABLE IF NOT EXISTS public.abbreviated_invoice_override (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_period_id uuid NOT NULL REFERENCES public.monthly_audit_periods(id) ON DELETE CASCADE,
  entry_id uuid NOT NULL REFERENCES public.monthly_audit_entries(id) ON DELETE CASCADE,
  night_date date NOT NULL,
  decision text NOT NULL CHECK (decision IN ('include_this_month','carry_to_next','excluded_full_tax')),
  reason text,
  set_by_user_id uuid REFERENCES auth.users(id),
  set_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (entry_id, night_date)
);

COMMENT ON TABLE public.abbreviated_invoice_override
  IS 'Phase 70: per-night carry/include/exclude decision before abbreviated tax invoice generation.';

CREATE TABLE IF NOT EXISTS public.abbreviated_row_shift_override (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_period_id uuid NOT NULL REFERENCES public.monthly_audit_periods(id) ON DELETE CASCADE,
  entry_id uuid NOT NULL REFERENCES public.monthly_audit_entries(id) ON DELETE CASCADE,
  tax_group char(1) NOT NULL CHECK (tax_group IN ('A','B','C','D','E')),
  unit_price numeric(10,2) NOT NULL CHECK (unit_price >= 0),
  quantity int NOT NULL CHECK (quantity > 0),
  original_date date NOT NULL,
  target_date date NOT NULL,
  reason text,
  set_by_user_id uuid REFERENCES auth.users(id),
  set_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.abbreviated_row_shift_override
  IS 'Phase 70: manual pre-generate row movement between issue dates.';

CREATE INDEX IF NOT EXISTS idx_aio_period_date
  ON public.abbreviated_invoice_override(audit_period_id, night_date);

CREATE INDEX IF NOT EXISTS idx_arso_period_target
  ON public.abbreviated_row_shift_override(audit_period_id, target_date);

CREATE INDEX IF NOT EXISTS idx_arso_entry_original
  ON public.abbreviated_row_shift_override(entry_id, original_date);

ALTER TABLE public.abbreviated_invoice_override ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abbreviated_row_shift_override ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS aio_select ON public.abbreviated_invoice_override;
CREATE POLICY aio_select ON public.abbreviated_invoice_override
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS aio_modify ON public.abbreviated_invoice_override;
CREATE POLICY aio_modify ON public.abbreviated_invoice_override
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));

DROP POLICY IF EXISTS arso_select ON public.abbreviated_row_shift_override;
CREATE POLICY arso_select ON public.abbreviated_row_shift_override
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS arso_modify ON public.abbreviated_row_shift_override;
CREATE POLICY arso_modify ON public.abbreviated_row_shift_override
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = auth.uid() AND p.role IN ('admin','supervisor')
  ));



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604200005_phase70_next_abbr_no_rpc.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 70: deterministic abbreviated tax invoice number

CREATE OR REPLACE FUNCTION public.next_abbreviated_invoice_no(
  p_date date,
  p_channel_group text
) RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_group text;
  v_prefix text;
  v_be_year int;
  v_no text;
BEGIN
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'next_abbreviated_invoice_no expects p_date';
  END IF;

  v_group := lower(coalesce(trim(p_channel_group), ''));
  IF v_group NOT IN ('ota', 'walkin_direct') THEN
    RAISE EXCEPTION 'next_abbreviated_invoice_no expects channel group ota or walkin_direct, got: %', p_channel_group;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('phase70-abbr-no:' || v_group || ':' || p_date::text));

  v_prefix := CASE WHEN v_group = 'walkin_direct' THEN 'W' ELSE '' END;
  v_be_year := extract(year from p_date)::int + 543;
  v_no := v_prefix
    || lpad((v_be_year % 100)::text, 2, '0')
    || to_char(p_date, 'MMDD');

  IF EXISTS (
    SELECT 1
    FROM public.abbreviated_tax_invoice i
    WHERE i.invoice_no = v_no
      AND i.status <> 'cancelled'
  ) THEN
    RAISE EXCEPTION 'Active abbreviated invoice number already exists: %', v_no
      USING ERRCODE = '23505';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.abbreviated_tax_invoice i
    WHERE i.issue_date = p_date
      AND i.channel_group = v_group
      AND i.status <> 'cancelled'
  ) THEN
    RAISE EXCEPTION 'Active abbreviated invoice already exists for % / %', p_date, v_group
      USING ERRCODE = '23505';
  END IF;

  RETURN v_no;
END;
$$;

COMMENT ON FUNCTION public.next_abbreviated_invoice_no(date, text)
  IS 'Phase 70: returns exact YYMMDD / WYYMMDD abbreviated tax invoice number using Buddhist year. Cancelled invoices do not block reuse.';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604210001_phase71_abbr_source_type.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 71: Abbreviated Tax Invoice — add `source_type` discriminator
-- Enables the Phase 70 `abbreviated_tax_invoice` table to host 3 sources:
--   - room   → Phase 70 original behaviour (daily, per channel_group)
--   - dayuse → Phase 71 monthly (Walk-in only, channel_group = NULL)
--   - pos    → Phase 71 daily   (Walk-in only, channel_group = NULL)
--
-- Contract locks (per Lead answer to Agent B, 2026-04-21):
--   1. source_type is NOT NULL, default 'room' (back-compat for Phase 70 rows).
--   2. channel_group is DROP NOT NULL — NULL for dayuse/pos.
--   3. tax_group on line table is DROP NOT NULL — NULL for dayuse/pos lines.
--   4. source_entry_ids is reused for all 3 types:
--         room/dayuse → monthly_audit_entries.id[]
--         pos         → pos_orders.id[]
--   5. Uniqueness indexes are partitioned per source_type (see below).

BEGIN;

-- ------------------------------------------------------------
-- 1) Create source_type enum
-- ------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'abbreviated_source_type') THEN
    CREATE TYPE public.abbreviated_source_type AS ENUM ('room', 'dayuse', 'pos');
  END IF;
END
$$;

-- ------------------------------------------------------------
-- 2) Head: add source_type, relax channel_group, add consistency CHECK
-- ------------------------------------------------------------
ALTER TABLE public.abbreviated_tax_invoice
  ADD COLUMN IF NOT EXISTS source_type public.abbreviated_source_type
    NOT NULL DEFAULT 'room';

COMMENT ON COLUMN public.abbreviated_tax_invoice.source_type
  IS 'Phase 71 discriminator: room | dayuse | pos. channel_group is NULL for dayuse/pos.';

ALTER TABLE public.abbreviated_tax_invoice
  ALTER COLUMN channel_group DROP NOT NULL;

-- Replace the original channel_group CHECK (which forbade NULL) with a
-- NULL-aware version, then add cross-column consistency against source_type.
-- The original check was inline (no explicit name) — drop by probing the
-- constraint catalog for whichever name PostgreSQL auto-assigned.
DO $$
DECLARE
  v_con text;
BEGIN
  FOR v_con IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.abbreviated_tax_invoice'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%channel_group%IN%(%ota%walkin_direct%)%'
  LOOP
    EXECUTE format('ALTER TABLE public.abbreviated_tax_invoice DROP CONSTRAINT %I', v_con);
  END LOOP;
END
$$;

ALTER TABLE public.abbreviated_tax_invoice
  ADD CONSTRAINT abbr_invoice_channel_group_valid
  CHECK (
    channel_group IS NULL
    OR channel_group IN ('ota', 'walkin_direct')
  );

ALTER TABLE public.abbreviated_tax_invoice
  ADD CONSTRAINT abbr_invoice_source_channel_consistency
  CHECK (
    (source_type = 'room'   AND channel_group IS NOT NULL) OR
    (source_type = 'dayuse' AND channel_group IS NULL)     OR
    (source_type = 'pos'    AND channel_group IS NULL)
  );

-- ------------------------------------------------------------
-- 3) Lines: allow NULL tax_group (dayuse/pos have no A-E semantics)
-- ------------------------------------------------------------
ALTER TABLE public.abbreviated_tax_invoice_line
  ALTER COLUMN tax_group DROP NOT NULL;

DO $$
DECLARE
  v_con text;
BEGIN
  FOR v_con IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.abbreviated_tax_invoice_line'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%tax_group%IN%(%A%B%C%D%E%)%'
  LOOP
    EXECUTE format('ALTER TABLE public.abbreviated_tax_invoice_line DROP CONSTRAINT %I', v_con);
  END LOOP;
END
$$;

ALTER TABLE public.abbreviated_tax_invoice_line
  ADD CONSTRAINT abbr_line_tax_group_valid
  CHECK (tax_group IS NULL OR tax_group IN ('A', 'B', 'C', 'D', 'E'));

-- ------------------------------------------------------------
-- 4) Uniqueness — partition per source_type
--
-- Drop the Phase 70 composite index that only covered (audit_period_id,
-- issue_date, channel_group). Replace with 3 partial indexes, one per
-- source_type, so each type has a correct uniqueness rule:
--   - room   → (audit_period_id, issue_date, channel_group)  ≤ 1 per day per channel
--   - dayuse → (audit_period_id)                             ≤ 1 per audit period
--   - pos    → (issue_date)                                  ≤ 1 per calendar date
-- ------------------------------------------------------------
DROP INDEX IF EXISTS public.idx_abbr_invoice_day_channel_active;

CREATE UNIQUE INDEX IF NOT EXISTS idx_abbr_invoice_room_day_channel_active
  ON public.abbreviated_tax_invoice(audit_period_id, issue_date, channel_group)
  WHERE source_type = 'room' AND status <> 'cancelled';

CREATE UNIQUE INDEX IF NOT EXISTS idx_abbr_invoice_dayuse_period_active
  ON public.abbreviated_tax_invoice(audit_period_id)
  WHERE source_type = 'dayuse' AND status <> 'cancelled';

CREATE UNIQUE INDEX IF NOT EXISTS idx_abbr_invoice_pos_date_active
  ON public.abbreviated_tax_invoice(issue_date)
  WHERE source_type = 'pos' AND status <> 'cancelled';

-- Helpful lookup index for source_type filtering
CREATE INDEX IF NOT EXISTS idx_abbr_invoice_source_type
  ON public.abbreviated_tax_invoice(source_type, issue_date);

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604210002_phase71_products_name_th.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 71: products — add name_th + pos_abbreviated_enabled, seed POS items
--
-- name_th                 → Thai label printed on ใบกำกับภาษีอย่างย่อ (POS)
-- pos_abbreviated_enabled → gate for POS abbreviated-invoice aggregation
--
-- Seed strategy (per WA Phase 71, verified against Phase 10 seed
-- 202603020001_phase10_pos_inventory.sql):
--   - Water Bottle  EXISTS (category='both', sale_price=20.00)
--                   → UPDATE: set name_th, enable POS abbreviated
--   - Coffee        EXISTS (category='amenity', sale_price=NULL)
--                   → UPDATE: promote to 'both', set name_th,
--                     enable POS abbreviated.  sale_price stays NULL until
--                     Admin sets it via ProductsTab (pos_create_order
--                     already guards NULL, double-guarded by is_active).
--   - Est           NEW   (insert inactive, sale_price NULL)
--   - Chang Beer    NEW   (insert inactive, sale_price NULL)
--   - Leo Beer      NEW   (insert inactive, sale_price NULL)
--   - Singha Beer   NEW   (insert inactive, sale_price NULL)
--
-- Beer + Est default to is_active=false so they cannot be sold until
-- Admin supplies sale_price. pos_create_order already raises if sale_price
-- is NULL, but is_active=false is the primary user-facing gate.

BEGIN;

-- ------------------------------------------------------------
-- 1) Schema additions
-- ------------------------------------------------------------
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS name_th text;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS pos_abbreviated_enabled boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.products.name_th
  IS 'Phase 71: Thai name printed on ใบกำกับภาษีอย่างย่อ (POS). Required when pos_abbreviated_enabled = true.';

COMMENT ON COLUMN public.products.pos_abbreviated_enabled
  IS 'Phase 71: true = include in POS daily abbreviated tax invoice aggregation.';

-- Row-level guard: if enabled, name_th must be non-empty.
-- (UI-level validation is enforced in ProductsTab; this is the DB defence.)
ALTER TABLE public.products
  DROP CONSTRAINT IF EXISTS products_name_th_required_when_abbr_enabled;
ALTER TABLE public.products
  ADD CONSTRAINT products_name_th_required_when_abbr_enabled
  CHECK (
    pos_abbreviated_enabled = false
    OR (name_th IS NOT NULL AND btrim(name_th) <> '')
  );

-- ------------------------------------------------------------
-- 2) Seed — existing rows
-- ------------------------------------------------------------
UPDATE public.products
  SET name_th = 'น้ำดื่ม',
      pos_abbreviated_enabled = true
  WHERE name = 'Water Bottle';

UPDATE public.products
  SET category = 'both',
      name_th  = 'กาแฟ',
      pos_abbreviated_enabled = true
  WHERE name = 'Coffee';

-- ------------------------------------------------------------
-- 3) Seed — new POS-only items (inactive until Admin sets sale_price)
-- ------------------------------------------------------------
INSERT INTO public.products (name, category, unit, sale_price, is_active, name_th, pos_abbreviated_enabled)
VALUES
  ('Est',         'pos', 'bottles', NULL, false, 'เอส',         true),
  ('Chang Beer',  'pos', 'bottles', NULL, false, 'เบียร์ช้าง',   true),
  ('Leo Beer',    'pos', 'bottles', NULL, false, 'เบียร์ลีโอ',   true),
  ('Singha Beer', 'pos', 'bottles', NULL, false, 'เบียร์สิงห์',  true)
ON CONFLICT (name) DO UPDATE
  SET category                 = EXCLUDED.category,
      unit                     = EXCLUDED.unit,
      name_th                  = EXCLUDED.name_th,
      pos_abbreviated_enabled  = EXCLUDED.pos_abbreviated_enabled;

-- ------------------------------------------------------------
-- 4) Lookup index — POS abbreviated aggregation query path
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_products_pos_abbreviated_enabled
  ON public.products(pos_abbreviated_enabled)
  WHERE pos_abbreviated_enabled = true;

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604210003_phase71_pos_items_seed.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 71: POS item seed
--
-- Lead folded the actual seed payload into 202604210002_phase71_products_name_th.sql
-- together with the schema additions (`name_th`, `pos_abbreviated_enabled`).
-- This no-op migration preserves the Phase 71 numbering / ownership contract
-- from WORK_ASSIGNMENT_PHASE71.md without duplicating seed writes.

BEGIN;
SELECT 1;
COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604210004_phase71_rpc_extend.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 71: extend abbreviated invoice number RPC for source_type
--
-- Supports:
--   room   → YYMMDD / WYYMMDD
--   dayuse → DY + YY + MM
--   pos    → D + YYMMDD

BEGIN;

DROP FUNCTION IF EXISTS public.next_abbreviated_invoice_no(date, text);

CREATE OR REPLACE FUNCTION public.next_abbreviated_invoice_no(
  p_date date,
  p_channel_group text DEFAULT NULL,
  p_source_type public.abbreviated_source_type DEFAULT 'room'
) RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_group text;
  v_source public.abbreviated_source_type;
  v_be_year int;
  v_yy text;
  v_no text;
BEGIN
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'next_abbreviated_invoice_no expects p_date';
  END IF;

  v_source := COALESCE(p_source_type, 'room');
  v_group := lower(nullif(trim(coalesce(p_channel_group, '')), ''));
  v_be_year := extract(year from p_date)::int + 543;
  v_yy := lpad((v_be_year % 100)::text, 2, '0');

  IF v_source = 'room' THEN
    IF v_group NOT IN ('ota', 'walkin_direct') THEN
      RAISE EXCEPTION 'room abbreviated invoice expects channel_group ota or walkin_direct, got: %', p_channel_group;
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('phase71-abbr-no:room:' || v_group || ':' || p_date::text));

    v_no := CASE WHEN v_group = 'walkin_direct' THEN 'W' ELSE '' END
      || v_yy
      || to_char(p_date, 'MMDD');

    IF EXISTS (
      SELECT 1
      FROM public.abbreviated_tax_invoice i
      WHERE i.source_type = 'room'
        AND i.issue_date = p_date
        AND i.channel_group = v_group
        AND i.status <> 'cancelled'
    ) THEN
      RAISE EXCEPTION 'Active room abbreviated invoice already exists for % / %', p_date, v_group
        USING ERRCODE = '23505';
    END IF;
  ELSIF v_source = 'dayuse' THEN
    IF v_group IS NOT NULL THEN
      RAISE EXCEPTION 'dayuse abbreviated invoice expects NULL channel_group, got: %', p_channel_group;
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('phase71-abbr-no:dayuse:' || to_char(p_date, 'YYYY-MM')));

    v_no := 'DY' || v_yy || to_char(p_date, 'MM');

    IF EXISTS (
      SELECT 1
      FROM public.abbreviated_tax_invoice i
      WHERE i.source_type = 'dayuse'
        AND i.issue_date = p_date
        AND i.status <> 'cancelled'
    ) THEN
      RAISE EXCEPTION 'Active dayuse abbreviated invoice already exists for %', p_date
        USING ERRCODE = '23505';
    END IF;
  ELSIF v_source = 'pos' THEN
    IF v_group IS NOT NULL THEN
      RAISE EXCEPTION 'pos abbreviated invoice expects NULL channel_group, got: %', p_channel_group;
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('phase71-abbr-no:pos:' || p_date::text));

    v_no := 'D' || v_yy || to_char(p_date, 'MMDD');

    IF EXISTS (
      SELECT 1
      FROM public.abbreviated_tax_invoice i
      WHERE i.source_type = 'pos'
        AND i.issue_date = p_date
        AND i.status <> 'cancelled'
    ) THEN
      RAISE EXCEPTION 'Active pos abbreviated invoice already exists for %', p_date
        USING ERRCODE = '23505';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported abbreviated invoice source_type: %', p_source_type;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.abbreviated_tax_invoice i
    WHERE i.invoice_no = v_no
      AND i.status <> 'cancelled'
  ) THEN
    RAISE EXCEPTION 'Active abbreviated invoice number already exists: %', v_no
      USING ERRCODE = '23505';
  END IF;

  RETURN v_no;
END;
$$;

COMMENT ON FUNCTION public.next_abbreviated_invoice_no(date, text, public.abbreviated_source_type)
  IS 'Phase 71: returns room/dayuse/pos abbreviated invoice number. room => YYMMDD/WYYMMDD, dayuse => DYYYMM, pos => DYYMMDD.';

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604220001_phase72_rate_floor_and_settings.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 72 · Migration 001 — Rate Floor + App Settings
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P1)
-- Depends on: 20260219_000001_init_core.sql (room_types), auth schema (users)
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- Agent B adds: ALTER TABLE room_types, app_settings table, seed rows.
-- See WORK_ASSIGNMENT_PHASE72.md §5.1 for full DDL reference.
-- ============================================================================

-- Agent B: implement full migration below this line.

alter table public.room_types
  add column if not exists min_rate_floor numeric(10, 2) null
    check (min_rate_floor is null or min_rate_floor >= 0);

comment on column public.room_types.min_rate_floor is
  'Admin-set hard floor for manual rate_templates edits. Rate Plan overrides bypass this floor by design (Phase 72 D3).';

create table if not exists public.app_settings (
  key text primary key,
  value_json jsonb not null,
  description text,
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references auth.users(id)
);

comment on table public.app_settings is
  'Phase 72 app-level settings for rate grid guard rails and OTA alarm delivery.';

insert into public.app_settings (key, value_json, description) values
  ('rate.price_delta_warn_threshold', '0.20'::jsonb, 'Fraction. Edits above this delta show a warning modal.'),
  ('ota.alarm_minutes', '120'::jsonb, 'Minutes before pending OTA sync tasks trigger a Telegram alert.'),
  ('telegram.admin_chat_id', '""'::jsonb, 'Admin Telegram chat id configured from the bot /start flow.')
on conflict (key) do nothing;

alter table public.app_settings enable row level security;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604220002_phase72_ota_channels_and_tasks.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 72 · Migration 002 — OTA Channels + Rate Sync Tasks
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P1)
-- Depends on: 001 (app_settings), 20260219_000001_init_core.sql (room_types)
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- Agent B creates: ota_channels, ota_rate_sync_tasks, indexes, BOOKING seed.
-- See WORK_ASSIGNMENT_PHASE72.md §5.2 for full DDL reference.
--
-- NOTE (D-B4 reply): created_by is NULLABLE (trigger-inserted tasks have no
-- session actor). acked_by is NULLABLE at DB level; API layer enforces NOT
-- NULL when status transitions to 'synced' | 'skipped'.
-- ============================================================================

-- Agent B: implement full migration below this line.

create table if not exists public.ota_channels (
  code text primary key,
  name_en text not null,
  markup_type text not null check (markup_type in ('none', 'percent', 'fixed')),
  markup_value numeric(10, 2) not null default 0,
  is_active boolean not null default false,
  sync_method text not null default 'manual' check (sync_method in ('manual', 'api')),
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.ota_channels is
  'Phase 72 OTA channels used to derive manual sync tasks from base room prices.';

insert into public.ota_channels (code, name_en, markup_type, markup_value, is_active, sync_method) values
  ('BOOKING', 'Booking.com', 'percent', 15.00, true, 'manual')
on conflict (code) do nothing;

create table if not exists public.ota_rate_sync_tasks (
  id uuid primary key default gen_random_uuid(),
  channel_code text not null references public.ota_channels(code),
  room_type_id bigint not null references public.room_types(id) on delete cascade,
  stay_date date not null,
  old_price numeric(10, 2),
  new_price numeric(10, 2) not null,
  calculated_ota_price numeric(10, 2) not null,
  markup_snapshot jsonb not null,
  status text not null default 'pending'
    check (status in ('pending', 'synced', 'superseded', 'skipped')),
  superseded_by uuid references public.ota_rate_sync_tasks(id) on delete set null,
  reason text,
  created_at timestamptz not null default timezone('utc', now()),
  created_by uuid references auth.users(id),
  acked_at timestamptz,
  acked_by uuid references auth.users(id),
  staff_note text
);

comment on table public.ota_rate_sync_tasks is
  'Phase 72 manual OTA sync queue. created_by may be NULL when inserted by DB trigger.';

create index if not exists idx_ota_tasks_pending
  on public.ota_rate_sync_tasks(channel_code, status, stay_date)
  where status = 'pending';

create index if not exists idx_ota_tasks_stale
  on public.ota_rate_sync_tasks(created_at)
  where status = 'pending';

create index if not exists idx_ota_tasks_key_status
  on public.ota_rate_sync_tasks(channel_code, room_type_id, stay_date, status, created_at desc);

alter table public.ota_channels enable row level security;
alter table public.ota_rate_sync_tasks enable row level security;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604220003_phase72_ota_sync_trigger.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 72 · Migration 003 — Rate Template → OTA Sync Trigger
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P1 — idempotence + supersede correctness)
-- Depends on: 001, 002
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- Agent B creates: fn_rate_template_ota_sync() + AFTER INSERT/UPDATE trigger.
-- See WORK_ASSIGNMENT_PHASE72.md §5.3 for reference implementation.
--
-- P1 invariants Lead will verify:
--   1. Re-running same UPDATE (price unchanged) MUST NOT insert a new task.
--   2. Prior pending tasks for (channel, room_type, stay_date) MUST be
--      marked 'superseded' with superseded_by FK pointing to the new task.
--   3. Trigger must cover ALL active manual channels (loop over
--      ota_channels WHERE is_active AND sync_method='manual').
-- ============================================================================

-- Agent B: implement full migration below this line.

create or replace function public.fn_rate_template_ota_sync()
returns trigger
language plpgsql
as $$
declare
  v_type_id bigint;
  v_channel record;
  v_old_price numeric(10, 2);
  v_calc numeric(10, 2);
  v_new_task_id uuid;
  v_same_pending_id uuid;
  v_matching_synced_id uuid;
  v_pending_ids uuid[];
begin
  select r.room_type_id
    into v_type_id
  from public.rooms r
  where r.id = new.room_id;

  if v_type_id is null then
    return new;
  end if;

  v_old_price := case when tg_op = 'UPDATE' then old.price else null end;

  if tg_op = 'UPDATE' and v_old_price is not distinct from new.price then
    return new;
  end if;

  for v_channel in
    select code, markup_type, markup_value
    from public.ota_channels
    where is_active = true
      and sync_method = 'manual'
  loop
    v_calc := round(
      case v_channel.markup_type
        when 'percent' then new.price * (1 + (v_channel.markup_value / 100.0))
        when 'fixed' then new.price + v_channel.markup_value
        else new.price
      end,
      2
    );

    select t.id
      into v_same_pending_id
    from public.ota_rate_sync_tasks t
    where t.channel_code = v_channel.code
      and t.room_type_id = v_type_id
      and t.stay_date = new.stay_date
      and t.status = 'pending'
      and t.new_price is not distinct from new.price
      and t.calculated_ota_price is not distinct from v_calc
    order by t.created_at desc
    limit 1;

    if v_same_pending_id is not null then
      continue;
    end if;

    select array_agg(t.id order by t.created_at)
      into v_pending_ids
    from public.ota_rate_sync_tasks t
    where t.channel_code = v_channel.code
      and t.room_type_id = v_type_id
      and t.stay_date = new.stay_date
      and t.status = 'pending';

    select t.id
      into v_matching_synced_id
    from public.ota_rate_sync_tasks t
    where t.channel_code = v_channel.code
      and t.room_type_id = v_type_id
      and t.stay_date = new.stay_date
      and t.status = 'synced'
      and t.new_price is not distinct from new.price
      and t.calculated_ota_price is not distinct from v_calc
    order by t.acked_at desc nulls last, t.created_at desc
    limit 1;

    if v_matching_synced_id is not null then
      if coalesce(array_length(v_pending_ids, 1), 0) > 0 then
        update public.ota_rate_sync_tasks
           set status = 'superseded',
               superseded_by = v_matching_synced_id
         where id = any(v_pending_ids);
      end if;
      continue;
    end if;

    insert into public.ota_rate_sync_tasks (
      channel_code,
      room_type_id,
      stay_date,
      old_price,
      new_price,
      calculated_ota_price,
      markup_snapshot,
      status,
      reason,
      created_by
    )
    values (
      v_channel.code,
      v_type_id,
      new.stay_date,
      v_old_price,
      new.price,
      v_calc,
      jsonb_build_object('type', v_channel.markup_type, 'value', v_channel.markup_value),
      'pending',
      case when tg_op = 'INSERT' then 'initial' else 'update' end,
      new.updated_by
    )
    returning id into v_new_task_id;

    if coalesce(array_length(v_pending_ids, 1), 0) > 0 then
      update public.ota_rate_sync_tasks
         set status = 'superseded',
             superseded_by = v_new_task_id
       where id = any(v_pending_ids);
    end if;
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_rate_template_ota_sync on public.rate_templates;

create trigger trg_rate_template_ota_sync
  after insert or update of price
  on public.rate_templates
  for each row
  execute function public.fn_rate_template_ota_sync();



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604220004_phase72_telegram_config.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 72 · Migration 004 — Telegram Webhook Config + Subscriptions
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P1 — schema sanity, P3 — index coverage)
-- Depends on: 001 (app_settings)
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- Agent B creates:
--   - telegram_webhook_events (raw update log for debugging + dedupe)
--   - telegram_alert_subscriptions (chat_id → role mapping)
-- See WORK_ASSIGNMENT_PHASE72.md §5.4 for DDL reference.
-- ============================================================================

-- Agent B: implement full migration below this line.

create table if not exists public.telegram_webhook_events (
  id bigserial primary key,
  update_id bigint not null unique,
  raw_payload jsonb not null,
  received_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.telegram_alert_subscriptions (
  chat_id bigint primary key,
  role text not null check (role in ('admin', 'fo', 'manager')),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.telegram_webhook_events is
  'Phase 72 raw Telegram updates for debugging, dedupe, and bot setup verification.';

comment on table public.telegram_alert_subscriptions is
  'Phase 72 Telegram recipients for OTA sync alerts.';

alter table public.telegram_webhook_events enable row level security;
alter table public.telegram_alert_subscriptions enable row level security;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604220005_phase72_rate_grid_occ_rpc.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 72 · Migration 005 — get_rate_grid_with_occ RPC
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P1 — return shape must match RateGridResponseV2 exactly)
-- Depends on: 001, 20260219_000001_init_core.sql (rate_templates, rooms,
--             room_types, reservations)
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- Agent B creates:
--   get_rate_grid_with_occ(p_start DATE, p_end DATE) RETURNS JSONB
--
-- Response contract (see src/lib/rates/types.ts → RateGridResponseV2):
-- {
--   success: true,
--   start_date, end_date, days: [...],
--   room_types: [{ type_id, type_name, type_code, rooms: [{room_id, room_number, rates:{date:price}}]}],
--   occupancy: {
--     per_room_type: { [type_id]: { [date]: { booked, total, pct } } },
--     hotel_wide:    { [date]: { booked, total, pct } }
--   }
-- }
--
-- P1 invariants Lead will verify:
--   1. Closed rooms excluded from `total` (status != 'closed').
--   2. Cancelled/no_show reservations excluded from `booked`.
--   3. Date-range inclusive on both ends; `days` array length = end-start+1.
--   4. pct rounded to 1 decimal; never NaN (guard total=0 → pct=0).
-- ============================================================================

-- Agent B: implement full migration below this line.

create or replace function public.get_rate_grid_with_occ(p_start date, p_end date)
returns jsonb
language plpgsql
stable
as $$
declare
  v_result jsonb;
begin
  if p_start is null or p_end is null or p_end < p_start then
    raise exception 'Invalid date range for get_rate_grid_with_occ(% , %)', p_start, p_end;
  end if;

  with days as (
    select generate_series(p_start, p_end, interval '1 day')::date as stay_date
  ),
  eligible_rooms as (
    select
      r.id,
      r.room_number,
      r.room_type_id,
      rt.name_en,
      rt.code,
      coalesce(rt.sort_order, 0) as type_sort_order
    from public.rooms r
    join public.room_types rt on rt.id = r.room_type_id
    where coalesce(r.is_sellable, false) = true
      and coalesce(r.is_dayuse, false) = false
  ),
  room_types_in_scope as (
    select distinct
      er.room_type_id,
      er.name_en,
      er.code,
      er.type_sort_order
    from eligible_rooms er
  ),
  room_rates as (
    select
      er.room_type_id,
      er.name_en,
      er.code,
      er.type_sort_order,
      er.id as room_id,
      er.room_number,
      d.stay_date,
      rt.price
    from eligible_rooms er
    cross join days d
    left join public.rate_templates rt
      on rt.room_id = er.id
     and rt.stay_date = d.stay_date
  ),
  room_rate_json as (
    select
      rr.room_type_id,
      rr.name_en,
      rr.code,
      rr.type_sort_order,
      rr.room_id,
      rr.room_number,
      jsonb_object_agg(
        rr.stay_date::text,
        to_jsonb(case when rr.price is null then null else round(rr.price, 2) end)
        order by rr.stay_date
      ) as rates_json
    from room_rates rr
    group by rr.room_type_id, rr.name_en, rr.code, rr.type_sort_order, rr.room_id, rr.room_number
  ),
  room_type_json as (
    select
      rj.room_type_id,
      rj.name_en,
      rj.code,
      rj.type_sort_order,
      jsonb_agg(
        jsonb_build_object(
          'room_id', rj.room_id::text,
          'room_number', rj.room_number,
          'rates', rj.rates_json
        )
        order by rj.room_number
      ) as rooms_json
    from room_rate_json rj
    group by rj.room_type_id, rj.name_en, rj.code, rj.type_sort_order
  ),
  room_count as (
    select er.room_type_id, count(*)::int as total
    from eligible_rooms er
    group by er.room_type_id
  ),
  booked as (
    select
      er.room_type_id,
      d.stay_date,
      count(distinct rn.room_id)::int as booked
    from days d
    cross join room_types_in_scope er
    left join public.reservation_nights rn
      on rn.stay_date = d.stay_date
     and rn.cancelled_at is null
    left join public.rooms booked_room
      on booked_room.id = rn.room_id
     and booked_room.room_type_id = er.room_type_id
     and coalesce(booked_room.is_sellable, false) = true
     and coalesce(booked_room.is_dayuse, false) = false
    left join public.reservations res
      on res.id = rn.reservation_id
     and res.status not in ('cancelled', 'no_show')
    where booked_room.id is not null
      and res.id is not null
    group by er.room_type_id, d.stay_date
  ),
  occ_type as (
    select
      rtis.room_type_id,
      d.stay_date,
      coalesce(b.booked, 0)::int as booked,
      coalesce(rc.total, 0)::int as total,
      case
        when coalesce(rc.total, 0) > 0 then round((coalesce(b.booked, 0)::numeric * 100.0) / rc.total::numeric, 1)
        else 0
      end as pct
    from room_types_in_scope rtis
    cross join days d
    left join room_count rc on rc.room_type_id = rtis.room_type_id
    left join booked b
      on b.room_type_id = rtis.room_type_id
     and b.stay_date = d.stay_date
  ),
  occ_hotel as (
    select
      ot.stay_date,
      sum(ot.booked)::int as booked_total,
      sum(ot.total)::int as room_total,
      case
        when sum(ot.total) > 0 then round((sum(ot.booked)::numeric * 100.0) / sum(ot.total)::numeric, 1)
        else 0
      end as pct
    from occ_type ot
    group by ot.stay_date
  )
  select jsonb_build_object(
    'success', true,
    'start_date', p_start::text,
    'end_date', p_end::text,
    'days', coalesce(
      (select jsonb_agg(d.stay_date::text order by d.stay_date) from days d),
      '[]'::jsonb
    ),
    'room_types', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'type_id', rtj.room_type_id::text,
            'type_name', rtj.name_en,
            'type_code', rtj.code,
            'rooms', rtj.rooms_json
          )
          order by rtj.type_sort_order, rtj.name_en, rtj.room_type_id
        )
        from room_type_json rtj
      ),
      '[]'::jsonb
    ),
    'occupancy', jsonb_build_object(
      'per_room_type', coalesce(
        (
          select jsonb_object_agg(
            otx.room_type_id::text,
            otx.payload
          )
          from (
            select
              ot.room_type_id,
              jsonb_object_agg(
                ot.stay_date::text,
                jsonb_build_object(
                  'booked', ot.booked,
                  'total', ot.total,
                  'pct', ot.pct,
                  'tier',
                    case
                      when ot.pct < 30 then 'low'
                      when ot.pct < 60 then 'normal'
                      when ot.pct < 85 then 'high'
                      else 'peak'
                    end
                )
                order by ot.stay_date
              ) as payload
            from occ_type ot
            group by ot.room_type_id
          ) otx
        ),
        '{}'::jsonb
      ),
      'hotel_wide', coalesce(
        (
          select jsonb_object_agg(
            oh.stay_date::text,
            jsonb_build_object(
              'booked', oh.booked_total,
              'total', oh.room_total,
              'pct', oh.pct,
              'tier',
                case
                  when oh.pct < 30 then 'low'
                  when oh.pct < 60 then 'normal'
                  when oh.pct < 85 then 'high'
                  else 'peak'
                end
            )
            order by oh.stay_date
          )
          from occ_hotel oh
        ),
        '{}'::jsonb
      )
    )
  )
  into v_result;

  return v_result;
end;
$$;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604230001_phase73_rule_groups_and_tiers.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 73 · Migration 001 — Rule Groups + Members + Tiers
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P1 — FK integrity, priority unique? NO, CHECK constraints)
-- Depends on: 20260219_000001_init_core.sql (room_types), auth schema
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- See WORK_ASSIGNMENT_PHASE73.md §5.1 for DDL reference.
--
-- Tables:
--   - rate_rule_groups        (priority, trigger_scope, mode, effective window)
--   - rate_rule_group_members (per-member action_type + action_value + rounding — B1/B2/B4)
--   - rate_rule_tiers         (threshold ladder — B3)
--
-- Invariants Lead will verify (P1):
--   1. trigger_scope CHECK covers 3 values exactly.
--   2. mode CHECK covers 2 values exactly.
--   3. action_type CHECK covers 4 values (percent/fixed_thb/step/override).
--   4. rounding CHECK covers 4 values (none/nearest_10/nearest_50/nearest_100).
--   5. effective_to >= effective_from when both set.
--   6. RLS enabled on all 3 tables with admin-write / supervisor+admin-read pattern.
-- ============================================================================

-- Agent B: implement full migration below this line.

create table if not exists public.rate_rule_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  priority int not null default 100,
  trigger_scope text not null
    check (trigger_scope in ('hotel_wide', 'group_aggregate', 'per_room_type')),
  mode text not null
    check (mode in ('suggest_only', 'auto_apply')),
  is_active boolean not null default true,
  effective_from date,
  effective_to date,
  applies_to_dow int[],
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid references auth.users(id),
  check (effective_to is null or effective_from is null or effective_to >= effective_from),
  check (
    applies_to_dow is null
    or (
      coalesce(array_length(applies_to_dow, 1), 0) > 0
      and applies_to_dow <@ array[0, 1, 2, 3, 4, 5, 6]::int[]
    )
  )
);

comment on table public.rate_rule_groups is
  'Phase 73 dynamic rate rule groups. Each group has a trigger scope, mode, and threshold tiers.';

create table if not exists public.rate_rule_group_members (
  group_id uuid not null references public.rate_rule_groups(id) on delete cascade,
  room_type_id bigint not null references public.room_types(id) on delete cascade,
  action_type text not null
    check (action_type in ('percent', 'fixed_thb', 'step', 'override')),
  action_value numeric(10, 2) not null,
  rounding text not null default 'nearest_10'
    check (rounding in ('none', 'nearest_10', 'nearest_50', 'nearest_100')),
  primary key (group_id, room_type_id)
);

comment on table public.rate_rule_group_members is
  'Phase 73 per-room-type pricing adjustment rules within a dynamic rate rule group.';

create table if not exists public.rate_rule_tiers (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.rate_rule_groups(id) on delete cascade,
  trigger_metric text not null
    check (trigger_metric in ('occ_percent', 'occ_rooms_booked')),
  trigger_threshold numeric(10, 2) not null,
  tier_order int not null default 1,
  unique (group_id, tier_order)
);

comment on table public.rate_rule_tiers is
  'Phase 73 threshold ladder for a dynamic rate rule group. Highest matching tier wins.';

create index if not exists idx_rule_groups_active
  on public.rate_rule_groups(is_active, priority)
  where is_active;

create index if not exists idx_rule_tiers_by_group
  on public.rate_rule_tiers(group_id, trigger_threshold desc, tier_order asc);

drop trigger if exists trg_rate_rule_groups_updated_at on public.rate_rule_groups;
create trigger trg_rate_rule_groups_updated_at
  before update on public.rate_rule_groups
  for each row execute function public.set_updated_at();

alter table public.rate_rule_groups enable row level security;
alter table public.rate_rule_group_members enable row level security;
alter table public.rate_rule_tiers enable row level security;

drop policy if exists rrg_read on public.rate_rule_groups;
create policy rrg_read on public.rate_rule_groups
  for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  ));

drop policy if exists rrg_write on public.rate_rule_groups;
create policy rrg_write on public.rate_rule_groups
  for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ));

drop policy if exists rrgm_read on public.rate_rule_group_members;
create policy rrgm_read on public.rate_rule_group_members
  for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  ));

drop policy if exists rrgm_write on public.rate_rule_group_members;
create policy rrgm_write on public.rate_rule_group_members
  for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ));

drop policy if exists rrt_read on public.rate_rule_tiers;
create policy rrt_read on public.rate_rule_tiers
  for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  ));

drop policy if exists rrt_write on public.rate_rule_tiers;
create policy rrt_write on public.rate_rule_tiers
  for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ));



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604230002_phase73_dynamic_preview_and_applied_log.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 73 · Migration 002 — Dynamic Preview + Applied Log
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P1)
-- Depends on: 001 (rate_rule_groups, rate_rule_tiers), init_core (room_types)
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- See WORK_ASSIGNMENT_PHASE73.md §5.2 for DDL reference.
--
-- Tables:
--   - rate_dynamic_preview       (suggestion queue + applied audit — unified)
--   - rate_dynamic_applied_log   (undo window tracking — B13)
--
-- Invariants Lead will verify (P1):
--   1. status CHECK covers 5 values (suggested/applied/rejected/superseded/expired).
--   2. direction CHECK covers 3 values (up/down/same).
--   3. requires_confirmation correctly forced true when direction='down' (B12)
--      — enforced by evaluator logic, also add a CHECK constraint here as
--      defense-in-depth:
--        CHECK (direction <> 'down' OR requires_confirmation = true)
--   4. superseded_by is self-FK (rate_dynamic_preview.id). (B21)
--   5. apply_method CHECK covers 3 values (auto/confirmed/manual_run).
--   6. affected_room_ids[] NOT NULL and non-empty.
--   7. All RLS enabled; admin/supervisor read, admin-only write (API-mediated).
--
-- Indexes required:
--   - idx_preview_pending ON (status, stay_date) WHERE status='suggested'
--   - idx_preview_by_date ON (stay_date, room_type_id)
--   - idx_preview_eval_run ON (eval_run_id)
--   - idx_applied_log_undoable ON (reversible_until) WHERE undone_at IS NULL
--   - idx_applied_log_recent ON (applied_at DESC)
-- ============================================================================

-- Agent B: implement full migration below this line.

create table if not exists public.rate_dynamic_preview (
  id uuid primary key default gen_random_uuid(),
  stay_date date not null,
  room_type_id bigint not null references public.room_types(id) on delete cascade,
  base_price numeric(10, 2) not null,
  suggested_price numeric(10, 2) not null,
  direction text not null
    check (direction in ('up', 'down', 'same')),
  requires_confirmation boolean not null default false,
  clamped_to_floor boolean not null default false,
  clamped_to_max boolean not null default false,
  direction_override boolean not null default false,
  applied_rule_group_id uuid not null references public.rate_rule_groups(id) on delete cascade,
  applied_tier_id uuid not null references public.rate_rule_tiers(id) on delete cascade,
  status text not null default 'suggested'
    check (status in ('suggested', 'applied', 'rejected', 'superseded', 'expired')),
  superseded_by uuid references public.rate_dynamic_preview(id) on delete set null,
  eval_run_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  actioned_at timestamptz,
  actioned_by uuid references auth.users(id),
  reject_reason text,
  check (direction <> 'down' or requires_confirmation = true)
);

comment on table public.rate_dynamic_preview is
  'Phase 73 preview queue plus audit trail for dynamic rule evaluations.';

create index if not exists idx_preview_pending
  on public.rate_dynamic_preview(status, stay_date)
  where status = 'suggested';

create index if not exists idx_preview_by_date
  on public.rate_dynamic_preview(stay_date, room_type_id);

create index if not exists idx_preview_eval_run
  on public.rate_dynamic_preview(eval_run_id);

create table if not exists public.rate_dynamic_applied_log (
  id uuid primary key default gen_random_uuid(),
  preview_id uuid references public.rate_dynamic_preview(id) on delete set null,
  stay_date date not null,
  room_type_id bigint not null references public.room_types(id),
  previous_price numeric(10, 2) not null,
  new_price numeric(10, 2) not null,
  applied_at timestamptz not null default timezone('utc', now()),
  applied_by uuid references auth.users(id),
  apply_method text not null
    check (apply_method in ('auto', 'confirmed', 'manual_run')),
  reversible_until timestamptz not null,
  undone_at timestamptz,
  undone_by uuid references auth.users(id),
  affected_room_ids uuid[] not null,
  check (coalesce(array_length(affected_room_ids, 1), 0) > 0)
);

comment on table public.rate_dynamic_applied_log is
  'Phase 73 apply audit log with undo window and fixed room-id snapshot.';

create index if not exists idx_applied_log_undoable
  on public.rate_dynamic_applied_log(reversible_until)
  where undone_at is null;

create index if not exists idx_applied_log_recent
  on public.rate_dynamic_applied_log(applied_at desc);

alter table public.rate_dynamic_preview enable row level security;
alter table public.rate_dynamic_applied_log enable row level security;

drop policy if exists rdp_read on public.rate_dynamic_preview;
create policy rdp_read on public.rate_dynamic_preview
  for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  ));

drop policy if exists rdp_write on public.rate_dynamic_preview;
create policy rdp_write on public.rate_dynamic_preview
  for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ));

drop policy if exists rdal_read on public.rate_dynamic_applied_log;
create policy rdal_read on public.rate_dynamic_applied_log
  for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin', 'supervisor')
  ));

drop policy if exists rdal_write on public.rate_dynamic_applied_log;
create policy rdal_write on public.rate_dynamic_applied_log
  for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role = 'admin'
  ));



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604230003_phase73_dynamic_settings_keys.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 73 · Migration 003 — Dynamic Engine app_settings Seed
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P3 — key names + defaults)
-- Depends on: Phase 72 Migration 001 (app_settings table exists)
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- See WORK_ASSIGNMENT_PHASE73.md §5.3 for seed reference.
--
-- Keys to insert (ON CONFLICT DO NOTHING):
--   rate.dynamic_max_multiplier            → 1.5
--   rate.dynamic_eval_window_days          → 60
--   rate.dynamic_undo_window_minutes       → 60
--   rate.dynamic_suggestion_stale_minutes  → 120
--
-- Note: Changing these via /pms/setup/rates/admin UI writes directly to
-- app_settings. The pg_cron schedule is NOT parameterised by these
-- (B15 — schedule is a migration-time decision).
-- ============================================================================

-- Agent B: implement full migration below this line.

insert into public.app_settings (key, value_json, description)
values
  (
    'rate.dynamic_max_multiplier',
    '1.5'::jsonb,
    'Max multiple of current base price a dynamic suggestion may output. Hard cap enforced by evaluator.'
  ),
  (
    'rate.dynamic_eval_window_days',
    '60'::jsonb,
    'Default look-ahead window in days for scheduled evaluations. Manual run may override.'
  ),
  (
    'rate.dynamic_undo_window_minutes',
    '60'::jsonb,
    'Minutes after apply during which the operation may be undone.'
  ),
  (
    'rate.dynamic_suggestion_stale_minutes',
    '120'::jsonb,
    'Minutes a suggested row may sit before Telegram alerts admin.'
  )
on conflict (key) do nothing;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604230004_phase73_evaluate_dynamic_rates_rpc.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 73 · Migration 004 — evaluate_dynamic_rates RPC
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P1 — algorithm correctness is the highest-stakes gate)
-- Depends on: 001, 002, 003, init_core (rate_templates, rooms, reservation_nights)
--             Phase 72 Migration 001 (room_types.min_rate_floor)
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- See WORK_ASSIGNMENT_PHASE73.md §5.4 + §8 (pseudocode) for reference.
--
-- Function signature:
--   public.evaluate_dynamic_rates(p_start DATE, p_end DATE) RETURNS JSONB
--   LANGUAGE plpgsql
--   SECURITY DEFINER
--   SET search_path = public, pg_temp                                 -- B20
--
-- Helper functions (same SECURITY DEFINER + search_path pattern):
--   - fn_round_price(p_price NUMERIC, p_mode TEXT) RETURNS NUMERIC
--   - fn_apply_action(p_base NUMERIC, p_action_type TEXT, p_action_value NUMERIC)
--   - fn_compute_group_occ(p_group_id UUID, p_stay_date DATE) RETURNS NUMERIC
--
-- Return JSONB shape (matches EvaluateResponse in dynamic-types.ts):
--   {
--     success: true,
--     eval_run_id: uuid,
--     stats: {
--       evaluated_dates, groups_fired, suggestions, applied,
--       no_op_count,           -- B22
--       clamped_floor, clamped_max
--     }
--   }
--
-- P1 invariants Lead will verify:
--   1. Idempotent re-run (B16): supersedes prior 'suggested' in range;
--      does NOT touch 'applied' or 'rejected'.
--   2. Direction asymmetry (B12): price-down rows NEVER auto-apply, even
--      when rule.mode='auto_apply'. They enter queue with
--      requires_confirmation=true AND direction_override=true.
--   3. Clamp order: max first, floor second (floor wins when both would fire).
--   4. No-op skip (B22): rows where suggested_price == base_price after
--      rounding+clamp are NOT inserted; stats.no_op_count++ instead.
--   5. Group conflict (B21): within same eval_run_id, higher-priority group
--      writes new row; lower-priority group's prior row in same eval marked
--      status='superseded', superseded_by=<winner id>.
--   6. SECURITY DEFINER with explicit search_path (B20). REVOKE from public
--      on helpers; GRANT EXECUTE on evaluate_dynamic_rates to authenticated
--      + service_role.
--   7. auto_apply path writes rate_templates; Phase 72 trigger auto-generates
--      ota_rate_sync_tasks — do NOT manually insert OTA tasks here.
--   8. applied_log row's affected_room_ids[] captured at apply time (not
--      re-computed on undo) so room reassignment doesn't break undo target.
-- ============================================================================

-- Agent B: implement full migration below this line.

create or replace function public.fn_round_price(p_price numeric, p_mode text)
returns numeric
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  case coalesce(p_mode, 'nearest_10')
    when 'nearest_100' then
      return round(p_price / 100.0) * 100;
    when 'nearest_50' then
      return round(p_price / 50.0) * 50;
    when 'nearest_10' then
      return round(p_price / 10.0) * 10;
    else
      return round(p_price, 2);
  end case;
end;
$$;

create or replace function public.fn_apply_action(
  p_base numeric,
  p_action_type text,
  p_action_value numeric
)
returns numeric
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  case p_action_type
    when 'percent' then
      return round(p_base * (1 + (coalesce(p_action_value, 0) / 100.0)), 2);
    when 'fixed_thb' then
      return round(p_base + coalesce(p_action_value, 0), 2);
    when 'step' then
      return round(p_base + coalesce(p_action_value, 0), 2);
    when 'override' then
      return round(coalesce(p_action_value, p_base), 2);
    else
      return round(p_base, 2);
  end case;
end;
$$;

create or replace function public.fn_compute_group_occ(
  p_group_id uuid,
  p_stay_date date,
  p_room_type_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_scope text;
  v_total int := 0;
  v_booked int := 0;
begin
  select trigger_scope
    into v_scope
  from public.rate_rule_groups
  where id = p_group_id;

  if v_scope is null then
    return jsonb_build_object('booked', 0, 'total', 0, 'pct', 0);
  end if;

  with scope_rooms as (
    select r.id
    from public.rooms r
    where r.is_sellable = true
      and coalesce(r.is_dayuse, false) = false
      and (
        v_scope = 'hotel_wide'
        or (
          v_scope = 'group_aggregate'
          and exists (
            select 1
            from public.rate_rule_group_members gm
            where gm.group_id = p_group_id
              and gm.room_type_id = r.room_type_id
          )
        )
        or (
          v_scope = 'per_room_type'
          and p_room_type_id is not null
          and r.room_type_id = p_room_type_id
        )
      )
  )
  select
    count(*)::int,
    coalesce(count(rn.room_id), 0)::int
  into v_total, v_booked
  from scope_rooms sr
  left join public.reservation_nights rn
    on rn.room_id = sr.id
   and rn.stay_date = p_stay_date
   and rn.cancelled_at is null
  left join public.reservations res
    on res.id = rn.reservation_id
   and res.status not in ('cancelled', 'no_show');

  return jsonb_build_object(
    'booked', coalesce(v_booked, 0),
    'total', coalesce(v_total, 0),
    'pct', case
      when coalesce(v_total, 0) > 0 then round((coalesce(v_booked, 0)::numeric * 100.0) / v_total, 2)
      else 0
    end
  );
end;
$$;

create or replace function public.evaluate_dynamic_rates(p_start date, p_end date)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_eval_run_id uuid := gen_random_uuid();
  v_day date;
  v_group record;
  v_member record;
  v_tier record;
  v_occ jsonb;
  v_base numeric(10, 2);
  v_raw_price numeric(10, 2);
  v_next_price numeric(10, 2);
  v_floor numeric(10, 2);
  v_max numeric(10, 2);
  v_direction text;
  v_requires_confirmation boolean;
  v_direction_override boolean;
  v_candidate_id uuid;
  v_now timestamptz;
  v_groups_fired int := 0;
  v_suggestions int := 0;
  v_applied int := 0;
  v_no_op_count int := 0;
  v_clamped_floor int := 0;
  v_clamped_max int := 0;
  v_evaluated_dates int := 0;
  v_group_counted boolean;
  v_room_ids uuid[];
  v_max_multiplier numeric := 1.5;
  v_undo_window_minutes int := 60;
  v_status text;
  v_existing_winner_id uuid;
  v_apply_row record;
begin
  if p_start is null or p_end is null or p_end < p_start then
    raise exception 'Invalid date range.';
  end if;

  select coalesce((value_json #>> '{}')::numeric, 1.5)
    into v_max_multiplier
  from public.app_settings
  where key = 'rate.dynamic_max_multiplier';

  select coalesce((value_json #>> '{}')::int, 60)
    into v_undo_window_minutes
  from public.app_settings
  where key = 'rate.dynamic_undo_window_minutes';

  update public.rate_dynamic_preview
     set status = 'superseded'
   where stay_date between p_start and p_end
     and status = 'suggested';

  drop table if exists tmp_dynamic_eval_candidates;

  create temporary table tmp_dynamic_eval_candidates (
    id uuid primary key,
    stay_date date not null,
    room_type_id bigint not null,
    base_price numeric(10, 2) not null,
    suggested_price numeric(10, 2) not null,
    direction text not null,
    requires_confirmation boolean not null default false,
    clamped_to_floor boolean not null default false,
    clamped_to_max boolean not null default false,
    direction_override boolean not null default false,
    applied_rule_group_id uuid not null,
    applied_tier_id uuid not null,
    candidate_status text not null check (candidate_status in ('suggested', 'applied', 'superseded')),
    superseded_by uuid,
    eval_run_id uuid not null,
    created_at timestamptz not null default timezone('utc', now()),
    affected_room_ids uuid[] not null
  ) on commit drop;

  for v_day in
    select generate_series(p_start, p_end, interval '1 day')::date
  loop
    v_evaluated_dates := v_evaluated_dates + 1;

    for v_group in
      select *
      from public.rate_rule_groups
      where is_active = true
        and (effective_from is null or effective_from <= v_day)
        and (effective_to is null or effective_to >= v_day)
        and (
          applies_to_dow is null
          or extract(dow from v_day)::int = any(applies_to_dow)
        )
      order by priority asc, created_at asc, id asc
    loop
      v_group_counted := false;

      if v_group.trigger_scope = 'per_room_type' then
        for v_member in
          select gm.*, rt.min_rate_floor
          from public.rate_rule_group_members gm
          join public.room_types rt on rt.id = gm.room_type_id
          where gm.group_id = v_group.id
          order by gm.room_type_id asc
        loop
          v_occ := public.fn_compute_group_occ(v_group.id, v_day, v_member.room_type_id);

          select t.*
            into v_tier
          from public.rate_rule_tiers t
          where t.group_id = v_group.id
            and (
              (t.trigger_metric = 'occ_percent' and coalesce((v_occ ->> 'pct')::numeric, 0) >= t.trigger_threshold)
              or
              (t.trigger_metric = 'occ_rooms_booked' and coalesce((v_occ ->> 'booked')::numeric, 0) >= t.trigger_threshold)
            )
          order by t.trigger_threshold desc, t.tier_order asc
          limit 1;

          if v_tier.id is null then
            continue;
          end if;

          if not v_group_counted then
            v_groups_fired := v_groups_fired + 1;
            v_group_counted := true;
          end if;

          select array_agg(r.id order by r.room_number asc, r.id asc)
            into v_room_ids
          from public.rooms r
          where r.room_type_id = v_member.room_type_id
            and r.is_sellable = true
            and coalesce(r.is_dayuse, false) = false;

          if coalesce(array_length(v_room_ids, 1), 0) = 0 then
            continue;
          end if;

          select min(rt.price)
            into v_base
          from public.rate_templates rt
          where rt.stay_date = v_day
            and rt.room_id = any(v_room_ids);

          if v_base is null then
            continue;
          end if;

          v_raw_price := public.fn_apply_action(v_base, v_member.action_type, v_member.action_value);
          if v_member.action_type <> 'step' then
            v_next_price := public.fn_round_price(v_raw_price, v_member.rounding);
          else
            v_next_price := round(v_raw_price, 2);
          end if;

          v_max := round(v_base * coalesce(v_max_multiplier, 1.5), 2);
          if v_next_price > v_max then
            v_next_price := public.fn_round_price(v_max, v_member.rounding);
            v_clamped_max := v_clamped_max + 1;
          end if;

          v_floor := v_member.min_rate_floor;
          if v_floor is not null and v_next_price < v_floor then
            v_next_price := round(v_floor, 2);
            v_clamped_floor := v_clamped_floor + 1;
          end if;

          v_direction := case
            when v_next_price > v_base then 'up'
            when v_next_price < v_base then 'down'
            else 'same'
          end;

          if v_direction = 'same' then
            v_no_op_count := v_no_op_count + 1;
            continue;
          end if;

          v_requires_confirmation := (v_direction = 'down');
          v_direction_override := (v_direction = 'down' and v_group.mode = 'auto_apply');
          v_status := case
            when v_group.mode = 'auto_apply' and v_direction = 'up' then 'applied'
            else 'suggested'
          end;

          v_candidate_id := gen_random_uuid();

          update tmp_dynamic_eval_candidates
             set candidate_status = 'superseded',
                 superseded_by = v_candidate_id
           where stay_date = v_day
             and room_type_id = v_member.room_type_id
             and superseded_by is null;

          insert into tmp_dynamic_eval_candidates (
            id,
            stay_date,
            room_type_id,
            base_price,
            suggested_price,
            direction,
            requires_confirmation,
            clamped_to_floor,
            clamped_to_max,
            direction_override,
            applied_rule_group_id,
            applied_tier_id,
            candidate_status,
            eval_run_id,
            affected_room_ids
          )
          values (
            v_candidate_id,
            v_day,
            v_member.room_type_id,
            round(v_base, 2),
            round(v_next_price, 2),
            v_direction,
            v_requires_confirmation,
            (v_floor is not null and v_next_price = round(v_floor, 2)),
            (v_next_price = public.fn_round_price(v_max, v_member.rounding) and round(v_base * coalesce(v_max_multiplier, 1.5), 2) < v_raw_price),
            v_direction_override,
            v_group.id,
            v_tier.id,
            v_status,
            v_eval_run_id,
            v_room_ids
          );
        end loop;
      else
        v_occ := public.fn_compute_group_occ(v_group.id, v_day, null);

        select t.*
          into v_tier
        from public.rate_rule_tiers t
        where t.group_id = v_group.id
          and (
            (t.trigger_metric = 'occ_percent' and coalesce((v_occ ->> 'pct')::numeric, 0) >= t.trigger_threshold)
            or
            (t.trigger_metric = 'occ_rooms_booked' and coalesce((v_occ ->> 'booked')::numeric, 0) >= t.trigger_threshold)
          )
        order by t.trigger_threshold desc, t.tier_order asc
        limit 1;

        if v_tier.id is null then
          continue;
        end if;

        v_groups_fired := v_groups_fired + 1;

        for v_member in
          select gm.*, rt.min_rate_floor
          from public.rate_rule_group_members gm
          join public.room_types rt on rt.id = gm.room_type_id
          where gm.group_id = v_group.id
          order by gm.room_type_id asc
        loop
          select array_agg(r.id order by r.room_number asc, r.id asc)
            into v_room_ids
          from public.rooms r
          where r.room_type_id = v_member.room_type_id
            and r.is_sellable = true
            and coalesce(r.is_dayuse, false) = false;

          if coalesce(array_length(v_room_ids, 1), 0) = 0 then
            continue;
          end if;

          select min(rt.price)
            into v_base
          from public.rate_templates rt
          where rt.stay_date = v_day
            and rt.room_id = any(v_room_ids);

          if v_base is null then
            continue;
          end if;

          v_raw_price := public.fn_apply_action(v_base, v_member.action_type, v_member.action_value);
          if v_member.action_type <> 'step' then
            v_next_price := public.fn_round_price(v_raw_price, v_member.rounding);
          else
            v_next_price := round(v_raw_price, 2);
          end if;

          v_max := round(v_base * coalesce(v_max_multiplier, 1.5), 2);
          if v_next_price > v_max then
            v_next_price := public.fn_round_price(v_max, v_member.rounding);
            v_clamped_max := v_clamped_max + 1;
          end if;

          v_floor := v_member.min_rate_floor;
          if v_floor is not null and v_next_price < v_floor then
            v_next_price := round(v_floor, 2);
            v_clamped_floor := v_clamped_floor + 1;
          end if;

          v_direction := case
            when v_next_price > v_base then 'up'
            when v_next_price < v_base then 'down'
            else 'same'
          end;

          if v_direction = 'same' then
            v_no_op_count := v_no_op_count + 1;
            continue;
          end if;

          v_requires_confirmation := (v_direction = 'down');
          v_direction_override := (v_direction = 'down' and v_group.mode = 'auto_apply');
          v_status := case
            when v_group.mode = 'auto_apply' and v_direction = 'up' then 'applied'
            else 'suggested'
          end;

          v_candidate_id := gen_random_uuid();

          update tmp_dynamic_eval_candidates
             set candidate_status = 'superseded',
                 superseded_by = v_candidate_id
           where stay_date = v_day
             and room_type_id = v_member.room_type_id
             and superseded_by is null;

          insert into tmp_dynamic_eval_candidates (
            id,
            stay_date,
            room_type_id,
            base_price,
            suggested_price,
            direction,
            requires_confirmation,
            clamped_to_floor,
            clamped_to_max,
            direction_override,
            applied_rule_group_id,
            applied_tier_id,
            candidate_status,
            eval_run_id,
            affected_room_ids
          )
          values (
            v_candidate_id,
            v_day,
            v_member.room_type_id,
            round(v_base, 2),
            round(v_next_price, 2),
            v_direction,
            v_requires_confirmation,
            (v_floor is not null and v_next_price = round(v_floor, 2)),
            (v_next_price = public.fn_round_price(v_max, v_member.rounding) and round(v_base * coalesce(v_max_multiplier, 1.5), 2) < v_raw_price),
            v_direction_override,
            v_group.id,
            v_tier.id,
            v_status,
            v_eval_run_id,
            v_room_ids
          );
        end loop;
      end if;
    end loop;
  end loop;

  insert into public.rate_dynamic_preview (
    id,
    stay_date,
    room_type_id,
    base_price,
    suggested_price,
    direction,
    requires_confirmation,
    clamped_to_floor,
    clamped_to_max,
    direction_override,
    applied_rule_group_id,
    applied_tier_id,
    status,
    eval_run_id,
    created_at,
    actioned_at,
    actioned_by,
    reject_reason
  )
  select
    c.id,
    c.stay_date,
    c.room_type_id,
    c.base_price,
    c.suggested_price,
    c.direction,
    c.requires_confirmation,
    c.clamped_to_floor,
    c.clamped_to_max,
    c.direction_override,
    c.applied_rule_group_id,
    c.applied_tier_id,
    case
      when c.superseded_by is not null then 'superseded'
      else c.candidate_status
    end,
    c.eval_run_id,
    c.created_at,
    case
      when c.superseded_by is null and c.candidate_status = 'applied' then timezone('utc', now())
      else null
    end,
    null,
    null
  from tmp_dynamic_eval_candidates c;

  update public.rate_dynamic_preview p
     set superseded_by = c.superseded_by
    from tmp_dynamic_eval_candidates c
   where p.id = c.id
     and c.superseded_by is not null;

  select
    count(*) filter (where superseded_by is null and candidate_status = 'suggested'),
    count(*) filter (where superseded_by is null and candidate_status = 'applied')
    into v_suggestions, v_applied
  from tmp_dynamic_eval_candidates;

  for v_apply_row in
    select *
    from tmp_dynamic_eval_candidates
    where superseded_by is null
      and candidate_status = 'applied'
    order by stay_date asc, room_type_id asc
  loop
    v_now := timezone('utc', now());

    insert into public.rate_templates (
      stay_date,
      room_id,
      price,
      updated_by,
      updated_at
    )
    select
      v_apply_row.stay_date,
      room_id,
      v_apply_row.suggested_price,
      null,
      v_now
    from unnest(v_apply_row.affected_room_ids) as room_id
    on conflict (stay_date, room_id)
    do update
      set price = excluded.price,
          updated_by = excluded.updated_by,
          updated_at = excluded.updated_at;

    insert into public.rate_dynamic_applied_log (
      preview_id,
      stay_date,
      room_type_id,
      previous_price,
      new_price,
      applied_at,
      applied_by,
      apply_method,
      reversible_until,
      affected_room_ids
    )
    values (
      v_apply_row.id,
      v_apply_row.stay_date,
      v_apply_row.room_type_id,
      v_apply_row.base_price,
      v_apply_row.suggested_price,
      v_now,
      null,
      'auto',
      v_now + make_interval(mins => v_undo_window_minutes),
      v_apply_row.affected_room_ids
    );
  end loop;

  return jsonb_build_object(
    'success', true,
    'eval_run_id', v_eval_run_id,
    'stats', jsonb_build_object(
      'evaluated_dates', v_evaluated_dates,
      'groups_fired', v_groups_fired,
      'suggestions', coalesce(v_suggestions, 0),
      'applied', coalesce(v_applied, 0),
      'no_op_count', coalesce(v_no_op_count, 0),
      'clamped_floor', coalesce(v_clamped_floor, 0),
      'clamped_max', coalesce(v_clamped_max, 0)
    )
  );
end;
$$;

revoke execute on function public.fn_round_price(numeric, text) from public;
revoke execute on function public.fn_apply_action(numeric, text, numeric) from public;
revoke execute on function public.fn_compute_group_occ(uuid, date, bigint) from public;
revoke execute on function public.evaluate_dynamic_rates(date, date) from public;

grant execute on function public.fn_round_price(numeric, text) to service_role;
grant execute on function public.fn_apply_action(numeric, text, numeric) to service_role;
grant execute on function public.fn_compute_group_occ(uuid, date, bigint) to service_role;
grant execute on function public.evaluate_dynamic_rates(date, date) to authenticated, service_role;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604230005_phase73_pg_cron_schedule.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- ============================================================================
-- Phase 73 · Migration 005 — pg_cron Schedule for Dynamic Rate Evaluation
-- ============================================================================
-- Owner: Agent B
-- Reviewer: Lead (P1 — schedule correctness, idempotence, tz correctness)
-- Depends on: 004 (evaluate_dynamic_rates function exists), Phase 72
--             app_settings (for dynamic_eval_window_days lookup)
--
-- LAYER 0 SKELETON — DO NOT APPLY UNTIL AGENT B FILLS BODY.
-- See WORK_ASSIGNMENT_PHASE73.md §5.5 for reference SQL.
--
-- Job:
--   jobname = 'phase73_dynamic_rate_eval'
--   cron    = '0 2 * * *'          -- 02:00 UTC = 09:00 Asia/Bangkok (B14)
--   command = SELECT public.evaluate_dynamic_rates(
--               CURRENT_DATE,
--               CURRENT_DATE + <app_settings.rate.dynamic_eval_window_days>::INT
--             );
--
-- Migration must:
--   1. CREATE EXTENSION IF NOT EXISTS pg_cron;
--   2. Unschedule any prior job named 'phase73_dynamic_rate_eval' (idempotent).
--   3. Schedule fresh via cron.schedule(...).
--
-- P1 invariants Lead will verify:
--   1. Migration is re-runnable (unschedule-then-schedule pattern).
--   2. Job command reads window from app_settings at runtime (not baked at
--      migration time) so admin edits take effect next run without a new
--      migration — even though schedule time itself is migration-locked (B15).
--   3. Supabase target tier supports pg_cron (Lead verifies on staging before
--      prod). If extension unavailable, Agent B raises to Lead — fallback:
--      Vercel Cron hitting /api/dynamic-rules/eval. This migration's failure
--      must NOT block prior Phase 73 migrations from running.
-- ============================================================================

-- Agent B: implement full migration below this line.

do $$
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      raise notice 'Phase 73: pg_cron extension unavailable (%). Skipping dynamic rate schedule migration.', sqlerrm;
      return;
  end;

  begin
    if exists (select 1 from pg_extension where extname = 'pg_cron') then
      if exists (select 1 from cron.job where jobname = 'phase73_dynamic_rate_eval') then
        perform cron.unschedule(jobid)
        from cron.job
        where jobname = 'phase73_dynamic_rate_eval';
      end if;

      perform cron.schedule(
        'phase73_dynamic_rate_eval',
        '0 2 * * *',
        $job$
        select public.evaluate_dynamic_rates(
          current_date,
          current_date + coalesce(
            (
              select (value_json #>> '{}')::int
              from public.app_settings
              where key = 'rate.dynamic_eval_window_days'
            ),
            60
          )
        );
        $job$
      );

      execute $comment$
        comment on extension pg_cron is
        'Phase 73 scheduler for dynamic rate evaluation. Job: phase73_dynamic_rate_eval @ 02:00 UTC daily.';
      $comment$;
    end if;
  exception
    when others then
      raise notice 'Phase 73: unable to schedule pg_cron job (%). Dynamic rate schedule skipped.', sqlerrm;
  end;
end;
$$;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240001_phase74_alert_rules.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 74 — Alert Rules (pre-payment rule engine)
-- File 1/6. Creates alert_rules table, enums, RLS, and the overlap validator
-- used by BEFORE INSERT/UPDATE trigger to prevent conflicting active rules.
--
-- Amendment #1 references:
--   A2: trigger/scope mapping
--   A3: this file uses 2026-04-24 date prefix
--
-- Safe to re-run on fresh DB (idempotent via IF NOT EXISTS).

-- 1) Enums ------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE public.alert_rule_trigger AS ENUM ('all_year', 'date_range');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.alert_rule_scope AS ENUM ('all', 'individual', 'group');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2) Table ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.alert_rules (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL CHECK (length(trim(name)) > 0),
  is_active    boolean NOT NULL DEFAULT true,
  trigger_mode public.alert_rule_trigger NOT NULL,
  date_start   date,
  date_end     date,
  occ_threshold numeric(5, 2) NOT NULL DEFAULT 0 CHECK (occ_threshold >= 0 AND occ_threshold <= 100),
  scope        public.alert_rule_scope NOT NULL DEFAULT 'all',
  created_at   timestamptz NOT NULL DEFAULT timezone('utc', now()),
  created_by   uuid REFERENCES public.profiles(user_id),
  updated_at   timestamptz NOT NULL DEFAULT timezone('utc', now()),

  -- Shape consistency: all_year must have null dates; date_range must have both
  CONSTRAINT alert_rules_trigger_dates_shape CHECK (
    (trigger_mode = 'all_year' AND date_start IS NULL AND date_end IS NULL)
    OR
    (trigger_mode = 'date_range' AND date_start IS NOT NULL AND date_end IS NOT NULL AND date_end >= date_start)
  )
);

CREATE INDEX IF NOT EXISTS idx_alert_rules_active
  ON public.alert_rules (is_active)
  WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_alert_rules_range
  ON public.alert_rules (date_start, date_end)
  WHERE is_active = true AND trigger_mode = 'date_range';

-- 3) updated_at auto-touch --------------------------------------------------
CREATE OR REPLACE FUNCTION public.tg_alert_rules_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS alert_rules_set_updated_at ON public.alert_rules;
CREATE TRIGGER alert_rules_set_updated_at
  BEFORE UPDATE ON public.alert_rules
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_alert_rules_set_updated_at();

-- 4) Overlap validator ------------------------------------------------------
-- Rule: among all_active_rules, no two may share any day. An all_year rule
-- overlaps with every other active rule. A date_range rule overlaps with
-- another date_range rule whose [start,end] intersects.
--
-- Returns: jsonb with { ok: boolean, conflicts: [{id,name,date_start,date_end}] }

CREATE OR REPLACE FUNCTION public.alert_rules_check_overlap(
  p_rule_id uuid,
  p_trigger public.alert_rule_trigger,
  p_start date,
  p_end date,
  p_is_active boolean
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_conflicts jsonb;
BEGIN
  -- Inactive rule can never conflict
  IF NOT p_is_active THEN
    RETURN jsonb_build_object('ok', true, 'conflicts', '[]'::jsonb);
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', r.id,
    'name', r.name,
    'date_start', r.date_start,
    'date_end', r.date_end
  )), '[]'::jsonb)
  INTO v_conflicts
  FROM public.alert_rules r
  WHERE r.is_active = true
    AND (p_rule_id IS NULL OR r.id <> p_rule_id)
    AND (
      -- Any active rule conflicts with a new all_year rule
      p_trigger = 'all_year'
      -- Any active all_year rule conflicts with a new date_range rule
      OR r.trigger_mode = 'all_year'
      -- Two date_range rules overlap if [a_start, a_end] ∩ [b_start, b_end] ≠ ∅
      OR (
        p_trigger = 'date_range'
        AND r.trigger_mode = 'date_range'
        AND p_start IS NOT NULL AND p_end IS NOT NULL
        AND r.date_start <= p_end
        AND r.date_end >= p_start
      )
    );

  RETURN jsonb_build_object(
    'ok', jsonb_array_length(v_conflicts) = 0,
    'conflicts', v_conflicts
  );
END;
$$;

-- 5) Enforcement trigger: BEFORE INSERT/UPDATE blocks if overlap exists
CREATE OR REPLACE FUNCTION public.tg_alert_rules_enforce_overlap()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := public.alert_rules_check_overlap(
    CASE WHEN TG_OP = 'UPDATE' THEN NEW.id ELSE NULL END,
    NEW.trigger_mode,
    NEW.date_start,
    NEW.date_end,
    NEW.is_active
  );

  IF (v_result ->> 'ok')::boolean = false THEN
    RAISE EXCEPTION 'Alert rule overlaps with existing active rule(s): %', v_result -> 'conflicts'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS alert_rules_enforce_overlap ON public.alert_rules;
CREATE TRIGGER alert_rules_enforce_overlap
  BEFORE INSERT OR UPDATE OF is_active, trigger_mode, date_start, date_end
  ON public.alert_rules
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_alert_rules_enforce_overlap();

-- 6) RLS --------------------------------------------------------------------
ALTER TABLE public.alert_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "alert_rules_read_authenticated" ON public.alert_rules;
CREATE POLICY "alert_rules_read_authenticated"
  ON public.alert_rules FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "alert_rules_write_authenticated" ON public.alert_rules;
CREATE POLICY "alert_rules_write_authenticated"
  ON public.alert_rules FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 7) Grants for exposed RPC
GRANT EXECUTE ON FUNCTION public.alert_rules_check_overlap(uuid, public.alert_rule_trigger, date, date, boolean)
  TO authenticated;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240002_phase74_booking_alarms.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 74 — Booking Alarms (custom per-booking alarm definitions)
-- File 2/6. Immutable alarm definitions; snooze/clear lives in alert_daily_state.

-- 1) Enum -------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE public.booking_alarm_status AS ENUM (
    'active',
    'completed',
    'deleted',
    'auto_cancelled_due_in'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2) Table ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.booking_alarms (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id  uuid NOT NULL REFERENCES public.reservations(id) ON DELETE CASCADE,
  alarm_date      date NOT NULL,
  note            text NOT NULL CHECK (length(trim(note)) >= 5),
  status          public.booking_alarm_status NOT NULL DEFAULT 'active',

  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  created_by      uuid REFERENCES public.profiles(user_id),

  completed_at    timestamptz,
  completed_by    uuid REFERENCES public.profiles(user_id),
  completion_note text,

  deleted_at      timestamptz,
  deleted_by      uuid REFERENCES public.profiles(user_id)
);

-- 3) Indexes ----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_booking_alarms_res
  ON public.booking_alarms (reservation_id);

CREATE INDEX IF NOT EXISTS idx_booking_alarms_date
  ON public.booking_alarms (alarm_date)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_booking_alarms_status
  ON public.booking_alarms (status);

-- 4) Validation: alarm_date must precede reservation check_in_date ---------
-- Applied on INSERT + UPDATE of alarm_date. We fetch check_in_date from
-- reservations and compare; if alarm_date >= check_in_date, reject.

CREATE OR REPLACE FUNCTION public.tg_booking_alarms_validate_date()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_checkin_date date;
BEGIN
  SELECT checkin_date INTO v_checkin_date
  FROM public.reservations
  WHERE id = NEW.reservation_id;

  IF v_checkin_date IS NULL THEN
    RAISE EXCEPTION 'reservation % not found or has no checkin_date', NEW.reservation_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  IF NEW.alarm_date >= v_checkin_date THEN
    RAISE EXCEPTION 'alarm_date (%) must be before reservation checkin_date (%)', NEW.alarm_date, v_checkin_date
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS booking_alarms_validate_date ON public.booking_alarms;
CREATE TRIGGER booking_alarms_validate_date
  BEFORE INSERT OR UPDATE OF alarm_date, reservation_id
  ON public.booking_alarms
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_booking_alarms_validate_date();

-- 5) Lifecycle consistency (best-effort; admin corrections may bypass) -----
ALTER TABLE public.booking_alarms
  DROP CONSTRAINT IF EXISTS booking_alarms_lifecycle_consistency;

ALTER TABLE public.booking_alarms
  ADD CONSTRAINT booking_alarms_lifecycle_consistency CHECK (
    (status = 'completed' AND completed_at IS NOT NULL AND length(trim(coalesce(completion_note, ''))) > 0)
    OR
    (status = 'deleted' AND deleted_at IS NOT NULL)
    OR
    (status IN ('active', 'auto_cancelled_due_in'))
  );

-- 6) RLS --------------------------------------------------------------------
ALTER TABLE public.booking_alarms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "booking_alarms_read_authenticated" ON public.booking_alarms;
CREATE POLICY "booking_alarms_read_authenticated"
  ON public.booking_alarms FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "booking_alarms_write_authenticated" ON public.booking_alarms;
CREATE POLICY "booking_alarms_write_authenticated"
  ON public.booking_alarms FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240003_phase74_alert_daily_state.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 74 — Alert Daily State + reservations.is_thai_manual
-- File 3/6. Per-day alert instances (snooze/clear state) + Thai manual flag.
--
-- Amendment #1 A4: adds reservations.is_thai_manual (default false)
-- Amendment #1 A2: Thai detection priority chain — is_thai_manual is first.

-- 1) Enum -------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE public.alert_type AS ENUM ('prepayment', 'custom');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE public.alert_status AS ENUM (
    'pending',
    'snoozed',
    'cleared_auto',
    'cleared_manual',
    'cleared_admin_override',
    'auto_cancelled_due_in'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2) reservations.is_thai_manual -------------------------------------------
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS is_thai_manual boolean NOT NULL DEFAULT false;

-- 3) alert_daily_state table -----------------------------------------------
-- One row per (alert_date, reservation_id, alert_type, source_id)
-- source_id references either alert_rules.id (for prepayment) or
-- booking_alarms.id (for custom). Not FK-enforced so orphans from rule
-- inactivation don't cascade-destroy history.

CREATE TABLE IF NOT EXISTS public.alert_daily_state (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_date     date NOT NULL,
  reservation_id uuid NOT NULL REFERENCES public.reservations(id) ON DELETE CASCADE,
  alert_type     public.alert_type NOT NULL,
  source_id      uuid NOT NULL,
  status         public.alert_status NOT NULL DEFAULT 'pending',

  snoozed_from   date,
  snooze_note    text,

  cleared_at     timestamptz,
  cleared_by     uuid REFERENCES public.profiles(user_id),
  clear_note     text,

  created_at     timestamptz NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT alert_daily_state_uniq_instance UNIQUE (alert_date, reservation_id, alert_type, source_id)
);

-- 4) Indexes ----------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_alert_daily_state_date
  ON public.alert_daily_state (alert_date);

CREATE INDEX IF NOT EXISTS idx_alert_daily_state_res
  ON public.alert_daily_state (reservation_id);

CREATE INDEX IF NOT EXISTS idx_alert_daily_state_status
  ON public.alert_daily_state (alert_date, status)
  WHERE status IN ('pending', 'snoozed');

CREATE INDEX IF NOT EXISTS idx_alert_daily_state_type
  ON public.alert_daily_state (alert_date, alert_type);

-- 5) Admin force-clear marker on reservations ------------------------------
-- Per Amendment §2.4 / H-rule: once admin force-clears prepayment alert for
-- a booking, no regen. We persist this as a column so future materialize
-- calls can skip the reservation.

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS prepayment_admin_cleared_at timestamptz;

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS prepayment_admin_cleared_by uuid REFERENCES public.profiles(user_id);

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS prepayment_admin_cleared_note text;

-- 6) RLS --------------------------------------------------------------------
ALTER TABLE public.alert_daily_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "alert_daily_state_read_authenticated" ON public.alert_daily_state;
CREATE POLICY "alert_daily_state_read_authenticated"
  ON public.alert_daily_state FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "alert_daily_state_write_authenticated" ON public.alert_daily_state;
CREATE POLICY "alert_daily_state_write_authenticated"
  ON public.alert_daily_state FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240004_phase74_alert_job_log.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 74 — Alert Job Log
-- File 4/6. Records every Finish Alarm Job execution; one row per business
-- date. Audit trail JSONB captures per-action history for the day.

CREATE TABLE IF NOT EXISTS public.alert_job_log (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_date          date NOT NULL UNIQUE,
  total_alerts      integer NOT NULL DEFAULT 0,
  cleared_count     integer NOT NULL DEFAULT 0,
  snoozed_count     integer NOT NULL DEFAULT 0,

  finished_at       timestamptz NOT NULL DEFAULT timezone('utc', now()),
  finished_by       uuid REFERENCES public.profiles(user_id),

  telegram_sent_at  timestamptz,
  telegram_message  text,
  telegram_error    text,

  audit_trail       jsonb NOT NULL DEFAULT '[]'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_alert_job_log_date
  ON public.alert_job_log (job_date DESC);

-- RLS
ALTER TABLE public.alert_job_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "alert_job_log_read_authenticated" ON public.alert_job_log;
CREATE POLICY "alert_job_log_read_authenticated"
  ON public.alert_job_log FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "alert_job_log_write_authenticated" ON public.alert_job_log;
CREATE POLICY "alert_job_log_write_authenticated"
  ON public.alert_job_log FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240005_phase74_alert_settings_seed.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 74 — Alert Settings Seed
-- File 5/6. Adds 3 app_settings rows consumed by Phase 74.
-- telegram.admin_chat_id is NOT seeded here (already seeded in Phase 72).

INSERT INTO public.app_settings (key, value_json, description) VALUES
  (
    'alert.start_time',
    '"07:30"'::jsonb,
    'Phase 74: Time of day (Bangkok) when pending alerts begin escalating. Re-triggered per snooze_minutes interval until Finish Alarm Job is clicked.'
  ),
  (
    'alert.snooze_minutes',
    '60'::jsonb,
    'Phase 74: Minutes between re-triggers of the pending-alerts banner on operational pages after a snooze. Default 60.'
  ),
  (
    'alert.prepayment_lead_days',
    '7'::jsonb,
    'Phase 74: Number of days ahead to scan for eligible Thai-customer pre-payment alerts. Default 7.'
  )
ON CONFLICT (key) DO NOTHING;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240006_phase74_alert_rpcs.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 74 — Alert RPC Bundle
-- File 6/6. Eligibility helpers + materialize + auto-clear + finish-job +
-- night audit integration + admin force-clear.
--
-- All RPCs accept business_date explicitly (never CURRENT_DATE) per
-- Amendment #1 A2. Table names: folio_payments (not booking_payments),
-- checkin_date (not check_in_date).

-- ============================================================================
-- 1) Helpers
-- ============================================================================

-- 1a) fn_alert_get_business_date — read hotel_settings singleton
CREATE OR REPLACE FUNCTION public.fn_alert_get_business_date()
RETURNS date
LANGUAGE sql
STABLE
AS $$
  SELECT business_date FROM public.hotel_settings WHERE id = 1
$$;

-- 1b) fn_alert_is_thai_customer — priority chain per Amendment #1 A2
CREATE OR REPLACE FUNCTION public.fn_alert_is_thai_customer(p_reservation_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_res record;
  v_gp record;
BEGIN
  SELECT id, guest_profile_id, guest_name, is_thai_manual
    INTO v_res
  FROM public.reservations
  WHERE id = p_reservation_id;

  IF NOT FOUND THEN RETURN false; END IF;

  -- (1) manual override
  IF coalesce(v_res.is_thai_manual, false) THEN RETURN true; END IF;

  IF v_res.guest_profile_id IS NOT NULL THEN
    SELECT nationality_code, nationality, first_name, last_name
      INTO v_gp
    FROM public.guest_profiles
    WHERE id = v_res.guest_profile_id;

    -- (2) nationality_code = TH
    IF v_gp.nationality_code = 'TH' THEN RETURN true; END IF;

    -- (3) nationality free-text
    IF v_gp.nationality IS NOT NULL
       AND lower(trim(v_gp.nationality)) IN ('thai', 'ไทย') THEN
      RETURN true;
    END IF;

    -- (4) name regex (Thai Unicode)
    IF coalesce(v_gp.first_name, '') ~ '[\u0E00-\u0E7F]'
       OR coalesce(v_gp.last_name, '') ~ '[\u0E00-\u0E7F]' THEN
      RETURN true;
    END IF;
  END IF;

  RETURN false;
END;
$$;

-- 1c) fn_alert_reservation_payment_sum — canonical total_paid source
-- Only tx_type='payment', excludes is_record_only. Per Amendment #1 A2.
CREATE OR REPLACE FUNCTION public.fn_alert_reservation_payment_sum(p_reservation_id uuid)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(sum(amount), 0)
  FROM public.folio_payments
  WHERE reservation_id = p_reservation_id
    AND tx_type = 'payment'
    AND coalesce(is_record_only, false) = false
$$;

-- 1d) fn_alert_occ_for_date — occupancy percentage for a stay date
-- Uses active reservation_nights vs hotel_settings.sellable_rooms.
CREATE OR REPLACE FUNCTION public.fn_alert_occ_for_date(p_date date)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_sellable int;
  v_occupied int;
BEGIN
  SELECT sellable_rooms INTO v_sellable FROM public.hotel_settings WHERE id = 1;
  IF coalesce(v_sellable, 0) <= 0 THEN RETURN 0; END IF;

  SELECT count(*) INTO v_occupied
  FROM public.reservation_nights rn
  WHERE rn.stay_date = p_date
    AND rn.cancelled_at IS NULL;

  RETURN round((v_occupied::numeric / v_sellable::numeric) * 100, 2);
END;
$$;

-- ============================================================================
-- 2) alert_materialize_daily — idempotent writer of daily state rows
-- ============================================================================
-- For p_date, creates pending alert_daily_state rows for:
--   - Each active alert_rule × eligible Thai reservation with total_paid=0
--   - Each active booking_alarm with alarm_date = p_date
-- ON CONFLICT DO NOTHING (safe to re-run).
-- Skips reservations with prepayment_admin_cleared_at IS NOT NULL.

CREATE OR REPLACE FUNCTION public.alert_materialize_daily(p_date date)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_lead_days int;
  v_inserted int := 0;
  v_rule record;
  v_res record;
  v_occ numeric;
BEGIN
  SELECT (value_json)::text::int INTO v_lead_days
  FROM public.app_settings WHERE key = 'alert.prepayment_lead_days';
  v_lead_days := coalesce(v_lead_days, 7);

  -- --- Pre-payment alerts ---
  FOR v_rule IN
    SELECT id, trigger_mode, date_start, date_end, occ_threshold, scope
    FROM public.alert_rules
    WHERE is_active = true
  LOOP
    FOR v_res IN
      SELECT r.id, r.checkin_date, r.booking_group_id
      FROM public.reservations r
      WHERE r.status = 'active'
        AND r.checkin_date > p_date
        AND r.checkin_date <= p_date + v_lead_days
        AND r.prepayment_admin_cleared_at IS NULL
        AND (
          v_rule.trigger_mode = 'all_year'
          OR (v_rule.trigger_mode = 'date_range' AND r.checkin_date >= v_rule.date_start AND r.checkin_date <= v_rule.date_end)
        )
        AND (
          v_rule.scope = 'all'
          OR (v_rule.scope = 'individual' AND r.booking_group_id IS NULL)
          OR (v_rule.scope = 'group' AND r.booking_group_id IS NOT NULL)
        )
    LOOP
      -- Thai?
      IF NOT public.fn_alert_is_thai_customer(v_res.id) THEN CONTINUE; END IF;

      -- total_paid = 0?
      IF public.fn_alert_reservation_payment_sum(v_res.id) > 0 THEN CONTINUE; END IF;

      -- OCC threshold (evaluated on checkin_date per Amendment #1 business rule)
      IF coalesce(v_rule.occ_threshold, 0) > 0 THEN
        v_occ := public.fn_alert_occ_for_date(v_res.checkin_date);
        IF v_occ < v_rule.occ_threshold THEN CONTINUE; END IF;
      END IF;

      INSERT INTO public.alert_daily_state
        (alert_date, reservation_id, alert_type, source_id, status)
      VALUES
        (p_date, v_res.id, 'prepayment', v_rule.id, 'pending')
      ON CONFLICT (alert_date, reservation_id, alert_type, source_id) DO NOTHING;

      IF FOUND THEN v_inserted := v_inserted + 1; END IF;
    END LOOP;
  END LOOP;

  -- --- Custom alarms ---
  -- Per Amendment §2.5: alarm on check_in_date → auto_cancelled_due_in; else pending
  FOR v_res IN
    SELECT a.id AS alarm_id, a.reservation_id, r.checkin_date
    FROM public.booking_alarms a
    JOIN public.reservations r ON r.id = a.reservation_id
    WHERE a.alarm_date = p_date
      AND a.status = 'active'
      AND r.status = 'active'
  LOOP
    INSERT INTO public.alert_daily_state
      (alert_date, reservation_id, alert_type, source_id, status)
    VALUES (
      p_date,
      v_res.reservation_id,
      'custom',
      v_res.alarm_id,
      CASE WHEN v_res.checkin_date = p_date THEN 'auto_cancelled_due_in'::public.alert_status
           ELSE 'pending'::public.alert_status END
    )
    ON CONFLICT (alert_date, reservation_id, alert_type, source_id) DO NOTHING;

    IF FOUND THEN v_inserted := v_inserted + 1; END IF;
  END LOOP;

  RETURN v_inserted;
END;
$$;

-- ============================================================================
-- 3) alert_project_daily_counts — read-only projection for /api/alerts/range
-- ============================================================================
-- Returns projected counts without writing rows. Picker uses this for days
-- the user hasn't clicked into yet.

CREATE OR REPLACE FUNCTION public.alert_project_daily_counts(p_date date)
RETURNS TABLE (alert_type text, pending_count int)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_lead_days int;
  v_prepay int := 0;
  v_custom int := 0;
  v_rule record;
  v_res record;
  v_occ numeric;
BEGIN
  SELECT (value_json)::text::int INTO v_lead_days
  FROM public.app_settings WHERE key = 'alert.prepayment_lead_days';
  v_lead_days := coalesce(v_lead_days, 7);

  -- Pre-payment count
  FOR v_rule IN
    SELECT id, trigger_mode, date_start, date_end, occ_threshold, scope
    FROM public.alert_rules
    WHERE is_active = true
  LOOP
    FOR v_res IN
      SELECT r.id, r.checkin_date, r.booking_group_id
      FROM public.reservations r
      WHERE r.status = 'active'
        AND r.checkin_date > p_date
        AND r.checkin_date <= p_date + v_lead_days
        AND r.prepayment_admin_cleared_at IS NULL
        AND (
          v_rule.trigger_mode = 'all_year'
          OR (v_rule.trigger_mode = 'date_range' AND r.checkin_date >= v_rule.date_start AND r.checkin_date <= v_rule.date_end)
        )
        AND (
          v_rule.scope = 'all'
          OR (v_rule.scope = 'individual' AND r.booking_group_id IS NULL)
          OR (v_rule.scope = 'group' AND r.booking_group_id IS NOT NULL)
        )
    LOOP
      IF NOT public.fn_alert_is_thai_customer(v_res.id) THEN CONTINUE; END IF;
      IF public.fn_alert_reservation_payment_sum(v_res.id) > 0 THEN CONTINUE; END IF;
      IF coalesce(v_rule.occ_threshold, 0) > 0 THEN
        v_occ := public.fn_alert_occ_for_date(v_res.checkin_date);
        IF v_occ < v_rule.occ_threshold THEN CONTINUE; END IF;
      END IF;
      v_prepay := v_prepay + 1;
    END LOOP;
  END LOOP;

  -- Custom count (exclude due-in-day because those auto-cancel)
  SELECT count(*) INTO v_custom
  FROM public.booking_alarms a
  JOIN public.reservations r ON r.id = a.reservation_id
  WHERE a.alarm_date = p_date
    AND a.status = 'active'
    AND r.status = 'active'
    AND r.checkin_date <> p_date;

  RETURN QUERY VALUES ('prepayment', v_prepay), ('custom', v_custom);
END;
$$;

-- ============================================================================
-- 4) alert_auto_clear_by_payment — hook called from payment POST route
-- ============================================================================
CREATE OR REPLACE FUNCTION public.alert_auto_clear_by_payment(p_booking_id uuid)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_business_date date;
  v_updated int;
BEGIN
  v_business_date := public.fn_alert_get_business_date();

  UPDATE public.alert_daily_state
     SET status = 'cleared_auto',
         cleared_at = timezone('utc', now()),
         clear_note = 'Auto-cleared: payment received'
   WHERE reservation_id = p_booking_id
     AND alert_type = 'prepayment'
     AND alert_date = v_business_date
     AND status IN ('pending', 'snoozed');

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated;
END;
$$;

-- ============================================================================
-- 5) alert_night_audit_bulk_snooze — migrate pending to next business date
-- ============================================================================
-- Called from Night Audit alert_check gate when FO opts to bulk-snooze.
-- Also: any custom alarm whose alarm_date = p_business_date AND
-- the reservation's checkin_date = p_next_date is marked auto_cancelled_due_in
-- (per Amendment §2.5: due-in custom alarms don't snooze).

CREATE OR REPLACE FUNCTION public.alert_night_audit_bulk_snooze(
  p_business_date date,
  p_next_date date,
  p_note text,
  p_user uuid
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_row record;
  v_migrated int := 0;
  v_will_be_due_in boolean;
BEGIN
  IF length(trim(coalesce(p_note, ''))) = 0 THEN
    RAISE EXCEPTION 'bulk snooze note is required'
      USING ERRCODE = 'check_violation';
  END IF;

  FOR v_row IN
    SELECT ads.*, r.checkin_date
    FROM public.alert_daily_state ads
    JOIN public.reservations r ON r.id = ads.reservation_id
    WHERE ads.alert_date = p_business_date
      AND ads.status IN ('pending', 'snoozed')
  LOOP
    -- Close today's instance as snoozed
    UPDATE public.alert_daily_state
       SET status = 'snoozed',
           snooze_note = p_note,
           cleared_at = timezone('utc', now()),
           cleared_by = p_user,
           clear_note = 'Night Audit bulk-snooze: ' || p_note
     WHERE id = v_row.id;

    -- Decide next-day status
    v_will_be_due_in := (
      v_row.alert_type = 'custom'
      AND v_row.checkin_date = p_next_date
    );

    INSERT INTO public.alert_daily_state
      (alert_date, reservation_id, alert_type, source_id, status, snoozed_from, snooze_note)
    VALUES (
      p_next_date,
      v_row.reservation_id,
      v_row.alert_type,
      v_row.source_id,
      CASE WHEN v_will_be_due_in
           THEN 'auto_cancelled_due_in'::public.alert_status
           ELSE 'pending'::public.alert_status END,
      p_business_date,
      p_note
    )
    ON CONFLICT (alert_date, reservation_id, alert_type, source_id) DO NOTHING;

    v_migrated := v_migrated + 1;
  END LOOP;

  RETURN v_migrated;
END;
$$;

-- ============================================================================
-- 6) alert_admin_force_clear — admin-only, suppresses future regen
-- ============================================================================
CREATE OR REPLACE FUNCTION public.alert_admin_force_clear(
  p_daily_state_id uuid,
  p_note text,
  p_user uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_row record;
  v_is_admin boolean;
BEGIN
  IF length(trim(coalesce(p_note, ''))) = 0 THEN
    RAISE EXCEPTION 'clear note is required for admin force-clear'
      USING ERRCODE = 'check_violation';
  END IF;

  -- Role check: profiles.role = 'admin'
  SELECT (role = 'admin') INTO v_is_admin
  FROM public.profiles
  WHERE user_id = p_user;

  IF NOT coalesce(v_is_admin, false) THEN
    RAISE EXCEPTION 'admin role required for force-clear'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  SELECT * INTO v_row FROM public.alert_daily_state WHERE id = p_daily_state_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'alert_daily_state % not found', p_daily_state_id
      USING ERRCODE = 'no_data_found';
  END IF;

  -- Mark this instance cleared
  UPDATE public.alert_daily_state
     SET status = 'cleared_admin_override',
         cleared_at = timezone('utc', now()),
         cleared_by = p_user,
         clear_note = p_note
   WHERE id = p_daily_state_id;

  -- Suppress regen on the reservation (only for prepayment type)
  IF v_row.alert_type = 'prepayment' THEN
    UPDATE public.reservations
       SET prepayment_admin_cleared_at = timezone('utc', now()),
           prepayment_admin_cleared_by = p_user,
           prepayment_admin_cleared_note = p_note
     WHERE id = v_row.reservation_id;
  END IF;

  RETURN jsonb_build_object(
    'daily_state_id', p_daily_state_id,
    'reservation_id', v_row.reservation_id,
    'alert_type', v_row.alert_type,
    'suppressed_future_regen', v_row.alert_type = 'prepayment'
  );
END;
$$;

-- ============================================================================
-- 7) alert_finish_job — writes job log, guards pending = 0
-- ============================================================================
-- Returns summary payload for the telegram helper to format.
-- Does NOT send telegram itself (edge/server concern).

CREATE OR REPLACE FUNCTION public.alert_finish_job(
  p_business_date date,
  p_user uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_total int;
  v_cleared int;
  v_snoozed int;
  v_pending int;
  v_prepayment_paid int;
  v_prepayment_snoozed int;
  v_prepayment_admin int;
  v_custom_done int;
  v_custom_snoozed int;
  v_id uuid;
BEGIN
  SELECT
    count(*),
    count(*) FILTER (WHERE status IN (
      'cleared_auto','cleared_manual','cleared_admin_override','auto_cancelled_due_in')),
    count(*) FILTER (WHERE status = 'snoozed'),
    count(*) FILTER (WHERE status = 'pending'),
    count(*) FILTER (WHERE alert_type = 'prepayment' AND status = 'cleared_auto'),
    count(*) FILTER (WHERE alert_type = 'prepayment' AND status = 'snoozed'),
    count(*) FILTER (WHERE alert_type = 'prepayment' AND status = 'cleared_admin_override'),
    count(*) FILTER (WHERE alert_type = 'custom' AND status = 'cleared_manual'),
    count(*) FILTER (WHERE alert_type = 'custom' AND status = 'snoozed')
  INTO
    v_total, v_cleared, v_snoozed, v_pending,
    v_prepayment_paid, v_prepayment_snoozed, v_prepayment_admin,
    v_custom_done, v_custom_snoozed
  FROM public.alert_daily_state
  WHERE alert_date = p_business_date;

  IF v_pending > 0 THEN
    RAISE EXCEPTION 'cannot finish alarm job: % pending alerts remain', v_pending
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO public.alert_job_log
    (job_date, total_alerts, cleared_count, snoozed_count, finished_by)
  VALUES
    (p_business_date, v_total, v_cleared, v_snoozed, p_user)
  ON CONFLICT (job_date) DO UPDATE
    SET total_alerts = EXCLUDED.total_alerts,
        cleared_count = EXCLUDED.cleared_count,
        snoozed_count = EXCLUDED.snoozed_count,
        finished_at = timezone('utc', now()),
        finished_by = EXCLUDED.finished_by
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'job_log_id', v_id,
    'job_date', p_business_date,
    'total', v_total,
    'cleared', v_cleared,
    'snoozed', v_snoozed,
    'prepayment', jsonb_build_object(
      'paid', v_prepayment_paid,
      'snoozed', v_prepayment_snoozed,
      'admin_override', v_prepayment_admin
    ),
    'custom', jsonb_build_object(
      'done', v_custom_done,
      'snoozed', v_custom_snoozed
    )
  );
END;
$$;

-- ============================================================================
-- 8) Grants
-- ============================================================================
GRANT EXECUTE ON FUNCTION public.fn_alert_get_business_date() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_alert_is_thai_customer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_alert_reservation_payment_sum(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_alert_occ_for_date(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.alert_materialize_daily(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.alert_project_daily_counts(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.alert_auto_clear_by_payment(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.alert_night_audit_bulk_snooze(date, date, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.alert_admin_force_clear(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.alert_finish_job(date, uuid) TO authenticated;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240007_phase75_owner_role.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

do $$
begin
  alter type public.user_role add value if not exists 'owner';
exception
  when duplicate_object then null;
end $$;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240008_phase74_alert_rls_hardening.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 74 follow-up: tighten direct browser writes for Alerts/Alarms tables.
--
-- Server API routes use the service-role Supabase client and still bypass RLS.
-- Authenticated browser clients may read these operational tables, but direct
-- writes must go through the Phase 74 API/RPC layer so role checks, audit fields,
-- and notification semantics cannot be bypassed.

-- alert_rules ---------------------------------------------------------------
ALTER TABLE public.alert_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "alert_rules_write_authenticated" ON public.alert_rules;
DROP POLICY IF EXISTS "alert_rules_read_authenticated" ON public.alert_rules;

CREATE POLICY "alert_rules_read_authenticated"
  ON public.alert_rules
  FOR SELECT
  TO authenticated
  USING (true);

-- booking_alarms ------------------------------------------------------------
ALTER TABLE public.booking_alarms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "booking_alarms_write_authenticated" ON public.booking_alarms;
DROP POLICY IF EXISTS "booking_alarms_read_authenticated" ON public.booking_alarms;

CREATE POLICY "booking_alarms_read_authenticated"
  ON public.booking_alarms
  FOR SELECT
  TO authenticated
  USING (true);

-- alert_daily_state ---------------------------------------------------------
ALTER TABLE public.alert_daily_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "alert_daily_state_write_authenticated" ON public.alert_daily_state;
DROP POLICY IF EXISTS "alert_daily_state_read_authenticated" ON public.alert_daily_state;

CREATE POLICY "alert_daily_state_read_authenticated"
  ON public.alert_daily_state
  FOR SELECT
  TO authenticated
  USING (true);

-- alert_job_log -------------------------------------------------------------
ALTER TABLE public.alert_job_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "alert_job_log_write_authenticated" ON public.alert_job_log;
DROP POLICY IF EXISTS "alert_job_log_read_authenticated" ON public.alert_job_log;

CREATE POLICY "alert_job_log_read_authenticated"
  ON public.alert_job_log
  FOR SELECT
  TO authenticated
  USING (true);



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240009_phase75_rls_baseline.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 75 · Batch 3 · RLS baseline on 11 no-RLS tables
-- Date: 2026-04-24
-- Owner: Lead (skeleton) + Agent B (body fill)
-- Risk: LOW — Agent A confirmed client-side reads go through API routes (service_role bypasses RLS).
--              Permissive SELECT policy for authenticated keeps any future anon-key path working too.
--
-- Pattern per table (MUST be idempotent):
--   ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;
--   DROP POLICY IF EXISTS <table>_authenticated_read ON public.<table>;
--   CREATE POLICY <table>_authenticated_read
--     ON public.<table>
--     FOR SELECT
--     TO authenticated
--     USING (true);
--
-- No INSERT/UPDATE/DELETE policies — writes remain service-role-only (existing behavior).
--
-- Rollback: run 202604240010_phase75_rls_rollback.sql (prepared but NOT applied).

BEGIN;

-- ============================================================================
-- 1. rate_plans
-- ============================================================================
ALTER TABLE public.rate_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rate_plans_authenticated_read ON public.rate_plans;
CREATE POLICY rate_plans_authenticated_read
  ON public.rate_plans
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 2. rate_plan_tiers
-- ============================================================================
ALTER TABLE public.rate_plan_tiers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rate_plan_tiers_authenticated_read ON public.rate_plan_tiers;
CREATE POLICY rate_plan_tiers_authenticated_read
  ON public.rate_plan_tiers
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 3. rate_plan_profiles
-- ============================================================================
ALTER TABLE public.rate_plan_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rate_plan_profiles_authenticated_read ON public.rate_plan_profiles;
CREATE POLICY rate_plan_profiles_authenticated_read
  ON public.rate_plan_profiles
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 4. booking_groups
-- ============================================================================
ALTER TABLE public.booking_groups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS booking_groups_authenticated_read ON public.booking_groups;
CREATE POLICY booking_groups_authenticated_read
  ON public.booking_groups
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 5. daily_plans
-- ============================================================================
ALTER TABLE public.daily_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS daily_plans_authenticated_read ON public.daily_plans;
CREATE POLICY daily_plans_authenticated_read
  ON public.daily_plans
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 6. checklist_templates
-- ============================================================================
ALTER TABLE public.checklist_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS checklist_templates_authenticated_read ON public.checklist_templates;
CREATE POLICY checklist_templates_authenticated_read
  ON public.checklist_templates
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 7. extra_task_templates
-- ============================================================================
ALTER TABLE public.extra_task_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS extra_task_templates_authenticated_read ON public.extra_task_templates;
CREATE POLICY extra_task_templates_authenticated_read
  ON public.extra_task_templates
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 8. extra_task_assignments
-- ============================================================================
ALTER TABLE public.extra_task_assignments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS extra_task_assignments_authenticated_read ON public.extra_task_assignments;
CREATE POLICY extra_task_assignments_authenticated_read
  ON public.extra_task_assignments
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 9. stock_items
-- ============================================================================
ALTER TABLE public.stock_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS stock_items_authenticated_read ON public.stock_items;
CREATE POLICY stock_items_authenticated_read
  ON public.stock_items
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 10. stock_transactions
-- ============================================================================
ALTER TABLE public.stock_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS stock_transactions_authenticated_read ON public.stock_transactions;
CREATE POLICY stock_transactions_authenticated_read
  ON public.stock_transactions
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- 11. maid_cart_items
-- ============================================================================
ALTER TABLE public.maid_cart_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS maid_cart_items_authenticated_read ON public.maid_cart_items;
CREATE POLICY maid_cart_items_authenticated_read
  ON public.maid_cart_items
  FOR SELECT
  TO authenticated
  USING (true);

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240011_phase75_legacy_stays_tighten.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 75 · Batch 4 · legacy_stays policy tightening
-- Date: 2026-04-24
-- Owner: Lead (skeleton) + Agent B (verify + apply)
--
-- Context: Agent B §2.1 found the policy `legacy_stays_service_role` (created in
--   20260329_phase51_guest_migration.sql:28) was missing a `TO service_role`
--   qualifier, making it effectively TO PUBLIC — any authenticated user with the
--   anon key would read all legacy stay rows.
--
-- Fix shape: DROP the broken policy. RLS stays ON with zero policies. Combined
-- with the fact that all legit readers use the service_role client in API
-- routes (which bypasses RLS entirely), the table becomes truly server-only.
--
-- Agent B MUST verify before applying:
--   1. grep `.from('legacy_stays')` — confirm every call site is a server API
--      route, never a browser client.
--   2. curl as non-service-role user after migration: expect zero rows.
--
-- Risk: LOW — the existing policy was broken; removing it matches documented intent.

BEGIN;

DROP POLICY IF EXISTS legacy_stays_service_role ON public.legacy_stays;
COMMENT ON TABLE public.legacy_stays IS
  'Historical pre-migration stay data. Service-role only (RLS ON with no policies).';

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604240012_phase75_rpc_execute_revoke.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 75 · Batch 5 · SECURITY DEFINER RPC EXECUTE revoke
-- Date: 2026-04-24
-- Owner: Lead (skeleton + signatures verified) + Agent B (body fill)
--
-- Context: Agent B §5 found SECURITY DEFINER RPCs with PUBLIC EXECUTE grants.
--   Any authenticated user can invoke these directly via `supabase.rpc(...)`
--   from the browser, bypassing API-route auth gates.
--
-- PRE-FLIGHT VERIFIED 2026-04-24 (Lead):
--   - grep of `.rpc('<fn>')` across src/ shows ALL 6 non-Phase-73 RPCs are
--     called ONLY from server files (lib/*.ts or api/**/route.ts) using
--     createServerSupabaseClient (service_role).
--   - Therefore REVOKE FROM authenticated is safe for these 6.
--
-- ⚠️ DEFERRED TO PHASE 76: `evaluate_dynamic_rates` (Phase 73 RPC)
--   Reason: called by pg_cron job (see 202604230005_phase73_pg_cron_schedule.sql:56-72).
--   Supabase pg_cron typically runs as postgres (superuser, bypasses grants),
--   but this is NOT verified on our tier and Phase 73 is DO NOT TOUCH list.
--   Staging test required before revoke. Separate Phase 76 migration.
--
-- Signatures below are LOCKED to exact source migration definitions.
-- Agent B: do not modify argument lists. Fill REVOKE/GRANT exactly as written.
--
-- Risk: LOW for these 6 (verified server-only). Rollback = GRANT EXECUTE TO authenticated.

BEGIN;

-- ============================================================================
-- 1. pos_create_order_v2  (Phase 29/54 — POS)
-- Source: 202603310001_phase54_business_date_pos_deposit_hotfix.sql:230
-- Sig: (text, jsonb, text, uuid, text, text, numeric)
-- Caller: src/app/api/pos/orders/route.ts:303 (server)
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.pos_create_order_v2(text, jsonb, text, uuid, text, text, numeric)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.pos_create_order_v2(text, jsonb, text, uuid, text, text, numeric)
  TO service_role;

-- ============================================================================
-- 2. pos_void_order_v2  (Phase 29/54 — POS)
-- Source: 202603310001_phase54_business_date_pos_deposit_hotfix.sql:650
-- Sig: (uuid, text, text)
-- Caller: src/app/api/pos/orders/[id]/void/route.ts:154 (server)
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.pos_void_order_v2(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.pos_void_order_v2(uuid, text, text)
  TO service_role;

-- ============================================================================
-- 3. stock_transfer  (Phase 10 — Inventory)
-- Source: 202603020001_phase10_pos_inventory.sql:125
-- Sig: (uuid, int, int, text, text)
-- Caller: src/app/api/stock/transfer/route.ts:53 (server)
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.stock_transfer(uuid, int, int, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.stock_transfer(uuid, int, int, text, text)
  TO service_role;

-- ============================================================================
-- 4. fo_prepare_daily_stock  (Phase 10 — FO)
-- Source: 202603020002_phase10_fo_prepare_flow.sql:64
-- Sig: (date, text, text, jsonb)
-- Caller: src/app/api/stock/fo-prepare/route.ts:199 (server)
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.fo_prepare_daily_stock(date, text, text, jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fo_prepare_daily_stock(date, text, text, jsonb)
  TO service_role;

-- ============================================================================
-- 5. fo_return_daily_stock  (Phase 10 — FO)
-- Source: 202603020002_phase10_fo_prepare_flow.sql:317
-- Sig: (uuid, text, text, jsonb, boolean, text)
-- Caller: no direct .rpc() found in src/ — called via stored proc chain only.
--         Safe to revoke.
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.fo_return_daily_stock(uuid, text, text, jsonb, boolean, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fo_return_daily_stock(uuid, text, text, jsonb, boolean, text)
  TO service_role;

-- ============================================================================
-- 6. fo_amenity_audit_submit  (Phase 65 — FO)
-- Source: 202604150001_phase65_stock_snapshot_amenity_audit.sql:433
-- Sig: (jsonb)
-- Caller: src/lib/fo-amenity-audit.ts:118 (server lib, uses createServerSupabaseClient)
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.fo_amenity_audit_submit(jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fo_amenity_audit_submit(jsonb)
  TO service_role;

-- ============================================================================
-- 7. evaluate_dynamic_rates  — ⚠️ DEFERRED to Phase 76
-- Source: 202604230004_phase73_evaluate_dynamic_rates_rpc.sql:174
-- Sig: (date, date)
-- Callers:
--   - src/lib/dynamic-rules/service.ts:918 (server lib, service_role) — safe
--   - pg_cron job in 202604230005_phase73_pg_cron_schedule.sql:56-72 — UNCERTAIN
--     (Supabase pg_cron role privileges not verified on our tier)
-- Decision 2026-04-24 (Lead): DEFER to Phase 76 with dedicated staging test.
-- Phase 73 is also on DO NOT TOUCH list (Inventory §5.3).
-- DO NOT UNCOMMENT.
-- ============================================================================

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604250001_phase76_rpc_execute_revoke_evaluate_dynamic_rates.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 76 · Batch 2 · evaluate_dynamic_rates EXECUTE revoke
-- Date: 2026-04-25
-- Owner: Lead (decision matrix + body) + Agent B (3-axis spike + cross-check)
--
-- Context: Picks up the deferred RPC #7 from Phase 75 mig 012 lines 96-106.
--   evaluate_dynamic_rates is SECURITY DEFINER with EXECUTE granted to
--   anon + authenticated. Any logged-in browser user could invoke it
--   directly via supabase.rpc(...), bypassing the API-route admin gate.
--
-- 3-AXIS SPIKE EVIDENCE (verified on staging 2026-04-25):
--
--   Axis 1 -- pg_cron callers (User staging SQL):
--     Job 'phase73_dynamic_rate_eval' (active, schedule '0 2 * * *')
--     runs as username=postgres. Calls public.evaluate_dynamic_rates(
--       current_date,
--       current_date + coalesce(app_settings.rate.dynamic_eval_window_days, 60)
--     ).
--     -> postgres MUST retain EXECUTE.
--
--   Axis 2 -- server route callers (Agent B trace):
--     Single caller: POST /api/dynamic-rules/eval (route.ts:24).
--     Guard: requireDynamicRulesAdminAccess (admin role only,
--       src/lib/dynamic-rules/service.ts:532-542).
--     Client: createServerSupabaseClient() = service_role.
--     UI trigger: ManualRunButton.tsx:16 calls server route via fetch
--       (NOT direct .rpc).
--     No browser-side .rpc("evaluate_dynamic_rates") found in src/.
--     -> service_role MUST retain EXECUTE.
--
--   Axis 3 -- current ACL (User staging SQL):
--     Function: public.evaluate_dynamic_rates(p_start date, p_end date)
--     SECURITY DEFINER: true
--     Current proacl: postgres=X/postgres, anon=X/postgres,
--       authenticated=X/postgres, service_role=X/postgres
--     -> anon + authenticated EXECUTE is the security gap (browser bypass
--        of admin gate via supabase.rpc()).
--
-- Decision matrix (per WORK_ASSIGNMENT_PHASE76.md §3.2):
--   cron=postgres + server callers exist
--   -> REVOKE EXECUTE FROM PUBLIC, anon, authenticated
--      GRANT  EXECUTE TO postgres, service_role
--
-- Auth-helper scan on POST /api/dynamic-rules/eval (per WA §3.3):
--   Sole gate: requireDynamicRulesAdminAccess. No double-auth, no
--   CRON_SECRET bypass, no skipRoleCheck-style fail-open.
--
-- Risk: LOW. postgres path = cron job (preserved). service_role path =
--   server route (preserved). Browser path (anon/authenticated direct
--   .rpc) = closed.
--
-- Rollback (emergency only):
--   GRANT EXECUTE ON FUNCTION public.evaluate_dynamic_rates(date, date)
--     TO authenticated, anon;

BEGIN;

-- ============================================================================
-- evaluate_dynamic_rates  (Phase 73 -- Dynamic rate engine)
-- Source: 202604230004_phase73_evaluate_dynamic_rates_rpc.sql:174
-- Sig: (date, date)
-- Callers (verified Phase 76 Batch 2 spike, 2026-04-25):
--   - src/lib/dynamic-rules/service.ts:914  (runDynamicEvaluation, service_role)
--   - pg_cron 'phase73_dynamic_rate_eval'   (postgres role, '0 2 * * *')
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.evaluate_dynamic_rates(date, date)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.evaluate_dynamic_rates(date, date)
  TO postgres, service_role;

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604280001_phase77_full_tax_invoice_yymm_sequence.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 77: full tax invoice number format IVYYMMXX.
-- Example: issue_date 2026-04-01, first invoice of month => IV260401.
CREATE OR REPLACE FUNCTION public.next_invoice_no(p_yy text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_raw text;
  v_yymm text;
  v_prefix text;
  v_last_seq bigint;
  v_next_seq bigint;
  v_width int;
BEGIN
  v_raw := COALESCE(NULLIF(trim(p_yy), ''), to_char(timezone('Asia/Bangkok', now())::date, 'YYMM'));

  IF v_raw ~ '^\d{4}-\d{2}-\d{2}$' THEN
    v_yymm := to_char(v_raw::date, 'YYMM');
  ELSIF v_raw ~ '^\d{4}$' THEN
    v_yymm := v_raw;
  ELSIF v_raw ~ '^\d{2}$' THEN
    v_yymm := v_raw || to_char(timezone('Asia/Bangkok', now())::date, 'MM');
  ELSE
    RAISE EXCEPTION 'next_invoice_no(p_yy) expects YY, YYMM, or YYYY-MM-DD, got: %', p_yy;
  END IF;

  v_prefix := 'IV' || v_yymm;

  SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_no FROM 7) AS bigint)), 0)
    INTO v_last_seq
  FROM public.invoices
  WHERE invoice_no LIKE v_prefix || '%'
    AND invoice_no ~ ('^' || v_prefix || '[0-9]+$');

  v_next_seq := v_last_seq + 1;
  v_width := GREATEST(2, LENGTH(v_next_seq::text));

  RETURN v_prefix || LPAD(v_next_seq::text, v_width, '0');
END;
$$;

COMMENT ON FUNCTION public.next_invoice_no(text)
  IS 'Phase 77: returns full tax invoice number IVYYMMXX, resetting sequence per issue month. Accepts YY, YYMM, or YYYY-MM-DD for backwards compatibility.';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202604290001_phase78_linen_daily_snapshots.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create table if not exists public.linen_daily_snapshots (
  id uuid primary key default gen_random_uuid(),
  business_date date not null unique,
  computed_at timestamptz not null default timezone('utc', now()),
  computed_by uuid references auth.users(id),
  recomputed_count int not null default 0 check (recomputed_count >= 0),
  recompute_reason text,
  total_sent_normal int not null default 0 check (total_sent_normal >= 0),
  total_sent_rewash int not null default 0 check (total_sent_rewash >= 0),
  total_sent_old_dayuse int not null default 0 check (total_sent_old_dayuse >= 0),
  total_received_normal int not null default 0 check (total_received_normal >= 0),
  total_received_rewash int not null default 0 check (total_received_rewash >= 0),
  total_received_pending int not null default 0 check (total_received_pending >= 0),
  total_received_old_dayuse int not null default 0 check (total_received_old_dayuse >= 0),
  total_balance_normal_today int not null default 0 check (total_balance_normal_today >= 0),
  total_balance_old_dayuse int not null default 0 check (total_balance_old_dayuse >= 0),
  total_balance_pending_old int not null default 0 check (total_balance_pending_old >= 0),
  total_balance_rewash int not null default 0 check (total_balance_rewash >= 0),
  total_balance_vendor int not null default 0 check (total_balance_vendor >= 0),
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.linen_daily_snapshot_items (
  id uuid primary key default gen_random_uuid(),
  snapshot_id uuid not null references public.linen_daily_snapshots(id) on delete cascade,
  business_date date not null,
  linen_item_id int not null references public.linen_items(id),
  item_number smallint,
  name_th text not null default '',
  sent_normal int not null default 0 check (sent_normal >= 0),
  sent_rewash int not null default 0 check (sent_rewash >= 0),
  sent_old_dayuse int not null default 0 check (sent_old_dayuse >= 0),
  received_normal int not null default 0 check (received_normal >= 0),
  received_rewash int not null default 0 check (received_rewash >= 0),
  received_pending int not null default 0 check (received_pending >= 0),
  received_old_dayuse int not null default 0 check (received_old_dayuse >= 0),
  balance_normal_today int not null default 0 check (balance_normal_today >= 0),
  balance_old_dayuse int not null default 0 check (balance_old_dayuse >= 0),
  balance_pending_old int not null default 0 check (balance_pending_old >= 0),
  balance_rewash int not null default 0 check (balance_rewash >= 0),
  balance_total int not null default 0 check (balance_total >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  unique (snapshot_id, linen_item_id),
  unique (business_date, linen_item_id)
);

create index if not exists idx_linen_daily_snapshots_date
  on public.linen_daily_snapshots (business_date desc);

create index if not exists idx_linen_daily_snapshot_items_date
  on public.linen_daily_snapshot_items (business_date, item_number);

drop trigger if exists trg_linen_daily_snapshots_updated_at on public.linen_daily_snapshots;
create trigger trg_linen_daily_snapshots_updated_at
before update on public.linen_daily_snapshots
for each row execute function public.set_updated_at();

alter table public.linen_daily_snapshots enable row level security;
alter table public.linen_daily_snapshot_items enable row level security;

drop policy if exists linen_daily_snapshots_auth on public.linen_daily_snapshots;
create policy linen_daily_snapshots_auth on public.linen_daily_snapshots
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists linen_daily_snapshot_items_auth on public.linen_daily_snapshot_items;
create policy linen_daily_snapshot_items_auth on public.linen_daily_snapshot_items
  for all to authenticated
  using (true)
  with check (true);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605010001_phase79_rr3_manual_rows.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create table if not exists public.rr3_row_overrides (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.monthly_audit_periods(id) on delete cascade,
  reservation_id uuid not null,
  guest_profile_id uuid not null,
  checkin_datetime text not null default '',
  room_number text not null default '',
  full_name text not null default '',
  nationality text not null default '',
  id_or_passport text not null default '',
  current_address text not null default '',
  occupation text not null default 'รับจ้าง',
  coming_from text not null default '',
  going_to text not null default 'ตัวอย่าง',
  checkout_datetime text not null default '',
  remarks text not null default '',
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (period_id, reservation_id, guest_profile_id)
);

create index if not exists idx_rr3_row_overrides_period
  on public.rr3_row_overrides(period_id, created_at);

drop trigger if exists trg_rr3_row_overrides_updated_at on public.rr3_row_overrides;
create trigger trg_rr3_row_overrides_updated_at
before update on public.rr3_row_overrides
for each row execute function public.set_updated_at();

alter table public.rr3_row_overrides enable row level security;

drop policy if exists rr3_row_overrides_select on public.rr3_row_overrides;
create policy rr3_row_overrides_select on public.rr3_row_overrides
  for select to authenticated using (true);

drop policy if exists rr3_row_overrides_insert on public.rr3_row_overrides;
create policy rr3_row_overrides_insert on public.rr3_row_overrides
  for insert to authenticated
  with check (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid() and p.role in ('admin', 'supervisor')
  ));

drop policy if exists rr3_row_overrides_update on public.rr3_row_overrides;
create policy rr3_row_overrides_update on public.rr3_row_overrides
  for update to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid() and p.role in ('admin', 'supervisor')
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid() and p.role in ('admin', 'supervisor')
  ));

drop policy if exists rr3_row_overrides_delete on public.rr3_row_overrides;
create policy rr3_row_overrides_delete on public.rr3_row_overrides
  for delete to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid() and p.role in ('admin', 'supervisor')
  ));

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605020002_shift_logout_reminders.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

alter table public.hotel_settings
  add column if not exists shift_logout_reminder_times text[] not null default array['07:00', '15:00', '23:00'],
  add column if not exists shift_logout_snooze_min integer not null default 15,
  add column if not exists shift_logout_snooze_enabled boolean not null default true;

alter table public.hotel_settings
  drop constraint if exists hotel_settings_shift_logout_snooze_min_check;

alter table public.hotel_settings
  add constraint hotel_settings_shift_logout_snooze_min_check
  check (shift_logout_snooze_min between 1 and 1440);

alter table public.hotel_settings
  drop constraint if exists hotel_settings_shift_logout_reminder_times_check;

alter table public.hotel_settings
  add constraint hotel_settings_shift_logout_reminder_times_check
  check (
    array_length(shift_logout_reminder_times, 1) between 1 and 6
    and shift_logout_reminder_times <@ array[
      '00:00','00:30','01:00','01:30','02:00','02:30','03:00','03:30',
      '04:00','04:30','05:00','05:30','06:00','06:30','07:00','07:30',
      '08:00','08:30','09:00','09:30','10:00','10:30','11:00','11:30',
      '12:00','12:30','13:00','13:30','14:00','14:30','15:00','15:30',
      '16:00','16:30','17:00','17:30','18:00','18:30','19:00','19:30',
      '20:00','20:30','21:00','21:30','22:00','22:30','23:00','23:30'
    ]::text[]
  );

notify pgrst, 'reload schema';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605030001_phase80_tha_alert_detection.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Phase 80 — Thai prepayment alert detection accepts ISO alpha-3 nationality.
--
-- Context:
-- Some Thai guests have English names and guest_profiles.nationality_code = 'THA'.
-- Phase 74 only matched nationality_code = 'TH', so prepayment alerts could be
-- missed unless the name contained Thai text or reservations.is_thai_manual was set.

CREATE OR REPLACE FUNCTION public.fn_alert_is_thai_customer(p_reservation_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_res record;
  v_gp record;
BEGIN
  SELECT id, guest_profile_id, guest_name, is_thai_manual
    INTO v_res
  FROM public.reservations
  WHERE id = p_reservation_id;

  IF NOT FOUND THEN RETURN false; END IF;

  -- (1) manual override
  IF coalesce(v_res.is_thai_manual, false) THEN RETURN true; END IF;

  IF v_res.guest_profile_id IS NOT NULL THEN
    SELECT nationality_code, nationality, first_name, last_name
      INTO v_gp
    FROM public.guest_profiles
    WHERE id = v_res.guest_profile_id;

    -- (2) nationality_code = TH / THA
    IF upper(trim(coalesce(v_gp.nationality_code, ''))) IN ('TH', 'THA') THEN
      RETURN true;
    END IF;

    -- (3) nationality free-text
    IF lower(trim(coalesce(v_gp.nationality, ''))) IN ('thai', 'thailand', 'ไทย', 'ประเทศไทย') THEN
      RETURN true;
    END IF;

    -- (4) profile name regex (Thai Unicode)
    IF coalesce(v_gp.first_name, '') ~ '[\u0E00-\u0E7F]'
       OR coalesce(v_gp.last_name, '') ~ '[\u0E00-\u0E7F]' THEN
      RETURN true;
    END IF;
  END IF;

  -- (5) reservation guest_name fallback for bookings without a linked profile.
  IF coalesce(v_res.guest_name, '') ~ '[\u0E00-\u0E7F]' THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_alert_is_thai_customer(uuid) TO authenticated;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605040001_phase_logbook_l1.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- ============================================================
-- Phase Logbook L1 -- time window + close + shared shift log
-- ============================================================

alter table public.logbook_notes
  add column if not exists start_at timestamptz,
  add column if not exists end_at timestamptz,
  add column if not exists closed_at timestamptz,
  add column if not exists closed_by uuid references public.staff(id) on delete set null;

update public.logbook_notes
set start_at = created_at,
    end_at = (date_trunc('day', created_at at time zone 'Asia/Bangkok')
              + interval '8 days' - interval '1 second')
              at time zone 'Asia/Bangkok'
where start_at is null;

alter table public.logbook_notes
  alter column start_at set not null,
  alter column start_at set default timezone('utc', now());

create index if not exists idx_logbook_notes_start_at
  on public.logbook_notes (start_at);

create index if not exists idx_logbook_notes_end_at
  on public.logbook_notes (end_at);

create index if not exists idx_logbook_notes_active_window
  on public.logbook_notes (start_at, end_at)
  where archived_at is null and closed_at is null;

create index if not exists idx_logbook_notes_closed_at
  on public.logbook_notes (closed_at);

create table if not exists public.shift_log_entries (
  id uuid primary key default gen_random_uuid(),
  log_date date not null,
  hour_slot int not null check (hour_slot between 0 and 23),
  body text not null default '',
  body_rich jsonb,
  created_by uuid not null references public.staff(id) on delete restrict,
  updated_by uuid references public.staff(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (log_date, hour_slot)
);

create index if not exists idx_shift_log_entries_log_date
  on public.shift_log_entries (log_date desc);

drop trigger if exists trg_shift_log_entries_updated_at on public.shift_log_entries;
create trigger trg_shift_log_entries_updated_at
before update on public.shift_log_entries
for each row execute function public.set_updated_at();

alter table public.shift_log_entries enable row level security;

drop policy if exists shift_log_entries_select_authenticated on public.shift_log_entries;
create policy shift_log_entries_select_authenticated
on public.shift_log_entries for select to authenticated using (true);

drop policy if exists shift_log_entries_insert_authenticated_staff on public.shift_log_entries;
drop policy if exists shift_log_entries_insert_self on public.shift_log_entries;
create policy shift_log_entries_insert_authenticated_staff
on public.shift_log_entries for insert to authenticated
with check (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

drop policy if exists shift_log_entries_update_authenticated_staff on public.shift_log_entries;
drop policy if exists shift_log_entries_update_owner_or_admin on public.shift_log_entries;
create policy shift_log_entries_update_authenticated_staff
on public.shift_log_entries for update to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
)
with check (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

drop policy if exists shift_log_entries_delete_authenticated_staff on public.shift_log_entries;
drop policy if exists shift_log_entries_delete_owner_or_admin on public.shift_log_entries;
create policy shift_log_entries_delete_authenticated_staff
on public.shift_log_entries for delete to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605040002_logbook_shared_staff_rls.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Logbook is a shared hotel surface: any active authenticated staff member
-- can edit, close, archive, restore, link, mention, or delete notes.

drop policy if exists logbook_notes_insert_self on public.logbook_notes;
drop policy if exists logbook_notes_update_owner_or_admin on public.logbook_notes;
drop policy if exists logbook_notes_delete_owner_or_admin on public.logbook_notes;
drop policy if exists logbook_notes_insert_authenticated_staff on public.logbook_notes;
drop policy if exists logbook_notes_update_authenticated_staff on public.logbook_notes;
drop policy if exists logbook_notes_delete_authenticated_staff on public.logbook_notes;

create policy logbook_notes_insert_authenticated_staff
on public.logbook_notes
for insert
to authenticated
with check (
  created_by = auth.uid()
  and
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

create policy logbook_notes_update_authenticated_staff
on public.logbook_notes
for update
to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
)
with check (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

create policy logbook_notes_delete_authenticated_staff
on public.logbook_notes
for delete
to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

drop policy if exists logbook_note_links_insert_manage_note on public.logbook_note_links;
drop policy if exists logbook_note_links_delete_manage_note on public.logbook_note_links;
drop policy if exists logbook_note_links_insert_authenticated_staff on public.logbook_note_links;
drop policy if exists logbook_note_links_delete_authenticated_staff on public.logbook_note_links;

create policy logbook_note_links_insert_authenticated_staff
on public.logbook_note_links
for insert
to authenticated
with check (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

create policy logbook_note_links_delete_authenticated_staff
on public.logbook_note_links
for delete
to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

drop policy if exists logbook_note_mentions_insert_manage_note on public.logbook_note_mentions;
drop policy if exists logbook_note_mentions_update_manage_note on public.logbook_note_mentions;
drop policy if exists logbook_note_mentions_delete_manage_note on public.logbook_note_mentions;
drop policy if exists logbook_note_mentions_insert_authenticated_staff on public.logbook_note_mentions;
drop policy if exists logbook_note_mentions_update_authenticated_staff on public.logbook_note_mentions;
drop policy if exists logbook_note_mentions_delete_authenticated_staff on public.logbook_note_mentions;

create policy logbook_note_mentions_insert_authenticated_staff
on public.logbook_note_mentions
for insert
to authenticated
with check (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

create policy logbook_note_mentions_update_authenticated_staff
on public.logbook_note_mentions
for update
to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
)
with check (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

create policy logbook_note_mentions_delete_authenticated_staff
on public.logbook_note_mentions
for delete
to authenticated
using (
  exists (
    select 1
    from public.staff s
    where s.id = auth.uid()
      and coalesce(s.is_active, true) = true
  )
);

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605040003_logbook_closed_status_sync.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Keep legacy status aligned with the close marker for existing Logbook rows.
-- UI uses closed_at/archived_at as the source of truth, but status should not
-- continue to show "open" for notes that staff already closed.

update public.logbook_notes
set status = 'resolved'
where closed_at is not null
  and status <> 'resolved';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605080001_tax_invoice_remark.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS remark text;

COMMENT ON COLUMN public.invoices.remark IS
  'Customer-facing remark printed in the full tax invoice remark box.';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605080002_sync_deposit_snapshot_from_folio.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create or replace function public.sync_reservation_deposit_snapshot_from_folio(
  p_reservation_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total numeric(10,2);
  v_snapshot_note text;
  v_last_paid_at timestamptz;
begin
  if p_reservation_id is null then
    return;
  end if;

  with method_totals as (
    select
      public.normalize_deposit_method_text(coalesce(fp.method::text, 'cash')) as method,
      round(
        sum(
          case
            when fp.tx_type = 'deposit' then fp.amount
            when fp.tx_type = 'refund' then -fp.amount
            else 0
          end
        )::numeric,
        2
      ) as amount
    from public.folio_payments fp
    where fp.reservation_id = p_reservation_id
      and coalesce(fp.revenue_category, '') = 'deposit'
      and coalesce(fp.is_record_only, false) = false
    group by public.normalize_deposit_method_text(coalesce(fp.method::text, 'cash'))
  ),
  active_lines as (
    select method, amount
    from method_totals
    where amount > 0
  )
  select coalesce(round(sum(amount)::numeric, 2), 0)
  into v_total
  from active_lines;

  select max(fp.paid_at)
  into v_last_paid_at
  from public.folio_payments fp
  where fp.reservation_id = p_reservation_id
    and coalesce(fp.revenue_category, '') = 'deposit'
    and fp.tx_type = 'deposit'
    and coalesce(fp.is_record_only, false) = false;

  with method_totals as (
    select
      public.normalize_deposit_method_text(coalesce(fp.method::text, 'cash')) as method,
      round(
        sum(
          case
            when fp.tx_type = 'deposit' then fp.amount
            when fp.tx_type = 'refund' then -fp.amount
            else 0
          end
        )::numeric,
        2
      ) as amount
    from public.folio_payments fp
    where fp.reservation_id = p_reservation_id
      and coalesce(fp.revenue_category, '') = 'deposit'
      and coalesce(fp.is_record_only, false) = false
    group by public.normalize_deposit_method_text(coalesce(fp.method::text, 'cash'))
  ),
  active_lines as (
    select method, amount
    from method_totals
    where amount > 0
  )
  select
    case
      when coalesce(v_total, 0) <= 0 then null
      else jsonb_build_object(
        'lines',
        coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'method', method,
                'amount', amount
              )
              order by method
            )
            from active_lines
          ),
          '[]'::jsonb
        )
      )::text
    end
  into v_snapshot_note;

  update public.reservations
  set deposit_amount = coalesce(v_total, 0),
      deposit_paid_at = case when coalesce(v_total, 0) > 0 then v_last_paid_at else null end,
      deposit_note = v_snapshot_note,
      updated_at = timezone('utc', now())
  where id = p_reservation_id;
end;
$$;

create or replace function public.folio_payments_sync_deposit_snapshot_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation_id uuid;
  v_should_sync boolean := false;
begin
  if tg_op = 'INSERT' then
    v_reservation_id := new.reservation_id;
    v_should_sync :=
      new.reservation_id is not null
      and coalesce(new.revenue_category, '') = 'deposit'
      and coalesce(new.is_record_only, false) = false;
  elsif tg_op = 'UPDATE' then
    v_reservation_id := coalesce(new.reservation_id, old.reservation_id);
    v_should_sync :=
      (
        new.reservation_id is not null
        and coalesce(new.revenue_category, '') = 'deposit'
        and coalesce(new.is_record_only, false) = false
      )
      or (
        old.reservation_id is not null
        and coalesce(old.revenue_category, '') = 'deposit'
        and coalesce(old.is_record_only, false) = false
      );
  elsif tg_op = 'DELETE' then
    v_reservation_id := old.reservation_id;
    v_should_sync :=
      old.reservation_id is not null
      and coalesce(old.revenue_category, '') = 'deposit'
      and coalesce(old.is_record_only, false) = false;
  end if;

  if v_should_sync then
    perform public.sync_reservation_deposit_snapshot_from_folio(v_reservation_id);
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists folio_payments_sync_deposit_snapshot
  on public.folio_payments;

create trigger folio_payments_sync_deposit_snapshot
after insert or update or delete on public.folio_payments
for each row
execute function public.folio_payments_sync_deposit_snapshot_trigger();

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605110001_tax_invoice_coverage_split.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Tax invoice coverage/split hotfix.
-- Adds metadata for Admin-managed prepayment/balance invoices and removes the
-- one-issued-invoice-per-reservation database constraint in favor of API guards.

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS invoice_kind text NOT NULL DEFAULT 'standard',
  ADD COLUMN IF NOT EXISTS split_group_id uuid,
  ADD COLUMN IF NOT EXISTS coverage_amount numeric(12,2),
  ADD COLUMN IF NOT EXISTS coverage_note text,
  ADD COLUMN IF NOT EXISTS manual_issue_date_reason text;

DO $$
BEGIN
  ALTER TABLE public.invoices
    ADD CONSTRAINT invoices_invoice_kind_check
    CHECK (invoice_kind IN ('standard', 'prepayment', 'balance'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

UPDATE public.invoices
SET
  invoice_kind = COALESCE(NULLIF(invoice_kind, ''), 'standard'),
  coverage_amount = COALESCE(coverage_amount, grand_total)
WHERE invoice_kind IS NULL
   OR invoice_kind = ''
   OR coverage_amount IS NULL;

DROP INDEX IF EXISTS public.idx_invoices_reservation_issued_unique;

CREATE INDEX IF NOT EXISTS idx_invoices_reservation_status_kind
  ON public.invoices(reservation_id, status, invoice_kind);

CREATE INDEX IF NOT EXISTS idx_invoices_split_group
  ON public.invoices(split_group_id)
  WHERE split_group_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_invoices_invoice_kind
  ON public.invoices(invoice_kind);

COMMENT ON COLUMN public.invoices.invoice_kind IS
  'Tax invoice type: standard full-coverage invoice, prepayment split, or balance split.';
COMMENT ON COLUMN public.invoices.split_group_id IS
  'Groups the Admin-created prepayment and balance invoices for the same stay coverage.';
COMMENT ON COLUMN public.invoices.coverage_amount IS
  'VAT-inclusive amount covered/printed by this invoice after booking discounts.';
COMMENT ON COLUMN public.invoices.coverage_note IS
  'Short printed/internal note for coverage-based invoices.';
COMMENT ON COLUMN public.invoices.manual_issue_date_reason IS
  'Admin audit note when a split invoice is issued using a manually selected issue date.';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 202605190001_hotfix_abbreviated_invoice_sequence.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Hotfix: abbreviated invoice numbers must run continuously by actual issued rows.
--
-- Room OTA:          YYMM + monthly sequence       e.g. 690401, 690402
-- Room Walk-in/Dir:  W + YYMM + monthly sequence   e.g. W690401, W690402
-- POS:               D + YYMM + monthly sequence   e.g. D690401, D690402
-- Day Use remains monthly: DY + YY + MM            e.g. DY6904

BEGIN;

CREATE OR REPLACE FUNCTION public.next_abbreviated_invoice_no(
  p_date date,
  p_channel_group text DEFAULT NULL,
  p_source_type public.abbreviated_source_type DEFAULT 'room'
) RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_group text;
  v_source public.abbreviated_source_type;
  v_be_year int;
  v_yy text;
  v_prefix text;
  v_month_prefix text;
  v_sequence int;
  v_no text;
BEGIN
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'next_abbreviated_invoice_no expects p_date';
  END IF;

  v_source := COALESCE(p_source_type, 'room');
  v_group := lower(nullif(trim(coalesce(p_channel_group, '')), ''));
  v_be_year := extract(year from p_date)::int + 543;
  v_yy := lpad((v_be_year % 100)::text, 2, '0');

  IF v_source = 'room' THEN
    IF v_group NOT IN ('ota', 'walkin_direct') THEN
      RAISE EXCEPTION 'room abbreviated invoice expects channel_group ota or walkin_direct, got: %', p_channel_group;
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('hotfix-abbr-no:room:' || v_group || ':' || to_char(p_date, 'YYYY-MM')));

    v_prefix := CASE WHEN v_group = 'walkin_direct' THEN 'W' ELSE '' END;
    v_month_prefix := v_prefix || v_yy || to_char(p_date, 'MM');

    IF EXISTS (
      SELECT 1
      FROM public.abbreviated_tax_invoice i
      WHERE i.source_type = 'room'
        AND i.issue_date = p_date
        AND i.channel_group = v_group
        AND i.status <> 'cancelled'
    ) THEN
      RAISE EXCEPTION 'Active room abbreviated invoice already exists for % / %', p_date, v_group
        USING ERRCODE = '23505';
    END IF;
  ELSIF v_source = 'dayuse' THEN
    IF v_group IS NOT NULL THEN
      RAISE EXCEPTION 'dayuse abbreviated invoice expects NULL channel_group, got: %', p_channel_group;
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('hotfix-abbr-no:dayuse:' || to_char(p_date, 'YYYY-MM')));

    v_no := 'DY' || v_yy || to_char(p_date, 'MM');

    IF EXISTS (
      SELECT 1
      FROM public.abbreviated_tax_invoice i
      WHERE i.source_type = 'dayuse'
        AND i.issue_date = p_date
        AND i.status <> 'cancelled'
    ) THEN
      RAISE EXCEPTION 'Active dayuse abbreviated invoice already exists for %', p_date
        USING ERRCODE = '23505';
    END IF;
  ELSIF v_source = 'pos' THEN
    IF v_group IS NOT NULL THEN
      RAISE EXCEPTION 'pos abbreviated invoice expects NULL channel_group, got: %', p_channel_group;
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('hotfix-abbr-no:pos:' || to_char(p_date, 'YYYY-MM')));

    v_month_prefix := 'D' || v_yy || to_char(p_date, 'MM');

    IF EXISTS (
      SELECT 1
      FROM public.abbreviated_tax_invoice i
      WHERE i.source_type = 'pos'
        AND i.issue_date = p_date
        AND i.status <> 'cancelled'
    ) THEN
      RAISE EXCEPTION 'Active pos abbreviated invoice already exists for %', p_date
        USING ERRCODE = '23505';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported abbreviated invoice source_type: %', p_source_type;
  END IF;

  IF v_source IN ('room', 'pos') THEN
    v_sequence := 1;
    LOOP
      v_no := v_month_prefix || lpad(v_sequence::text, 2, '0');
      EXIT WHEN NOT EXISTS (
        SELECT 1
        FROM public.abbreviated_tax_invoice i
        WHERE i.invoice_no = v_no
          AND i.status <> 'cancelled'
      );
      v_sequence := v_sequence + 1;
      IF v_sequence > 9999 THEN
        RAISE EXCEPTION 'Could not allocate abbreviated invoice number for prefix %', v_month_prefix;
      END IF;
    END LOOP;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.abbreviated_tax_invoice i
    WHERE i.invoice_no = v_no
      AND i.status <> 'cancelled'
  ) THEN
    RAISE EXCEPTION 'Active abbreviated invoice number already exists: %', v_no
      USING ERRCODE = '23505';
  END IF;

  RETURN v_no;
END;
$$;

COMMENT ON FUNCTION public.next_abbreviated_invoice_no(date, text, public.abbreviated_source_type)
  IS 'Hotfix: returns continuous monthly abbreviated invoice numbers by active issued rows. room => YYMMNN/WYYMMNN, dayuse => DYYYMM, pos => DYYMMNN.';

COMMIT;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260508165658_deposit_snapshot_payment_movements.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create or replace function public.sync_reservation_deposit_snapshot_from_folio(
  p_reservation_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total numeric(10,2);
  v_snapshot_note text;
  v_last_paid_at timestamptz;
begin
  if p_reservation_id is null then
    return;
  end if;

  with method_totals as (
    select
      public.normalize_deposit_method_text(coalesce(fp.method::text, 'cash')) as method,
      round(
        sum(
          case
            when fp.tx_type = 'deposit' then fp.amount
            when fp.tx_type = 'payment' then fp.amount
            when fp.tx_type = 'refund' then -fp.amount
            else 0
          end
        )::numeric,
        2
      ) as amount
    from public.folio_payments fp
    where fp.reservation_id = p_reservation_id
      and coalesce(fp.revenue_category, '') = 'deposit'
      and coalesce(fp.is_record_only, false) = false
    group by public.normalize_deposit_method_text(coalesce(fp.method::text, 'cash'))
  ),
  active_lines as (
    select method, amount
    from method_totals
    where amount > 0
  )
  select coalesce(round(sum(amount)::numeric, 2), 0)
  into v_total
  from active_lines;

  select max(fp.paid_at)
  into v_last_paid_at
  from public.folio_payments fp
  where fp.reservation_id = p_reservation_id
    and coalesce(fp.revenue_category, '') = 'deposit'
    and fp.tx_type in ('deposit', 'payment')
    and coalesce(fp.is_record_only, false) = false;

  with method_totals as (
    select
      public.normalize_deposit_method_text(coalesce(fp.method::text, 'cash')) as method,
      round(
        sum(
          case
            when fp.tx_type = 'deposit' then fp.amount
            when fp.tx_type = 'payment' then fp.amount
            when fp.tx_type = 'refund' then -fp.amount
            else 0
          end
        )::numeric,
        2
      ) as amount
    from public.folio_payments fp
    where fp.reservation_id = p_reservation_id
      and coalesce(fp.revenue_category, '') = 'deposit'
      and coalesce(fp.is_record_only, false) = false
    group by public.normalize_deposit_method_text(coalesce(fp.method::text, 'cash'))
  ),
  active_lines as (
    select method, amount
    from method_totals
    where amount > 0
  )
  select
    case
      when coalesce(v_total, 0) <= 0 then null
      else jsonb_build_object(
        'lines',
        coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'method', method,
                'amount', amount
              )
              order by method
            )
            from active_lines
          ),
          '[]'::jsonb
        )
      )::text
    end
  into v_snapshot_note;

  update public.reservations
  set deposit_amount = coalesce(v_total, 0),
      deposit_paid_at = case when coalesce(v_total, 0) > 0 then v_last_paid_at else null end,
      deposit_note = v_snapshot_note,
      updated_at = timezone('utc', now())
  where id = p_reservation_id;
end;
$$;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260509080105_urgent_overlay_setting.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

alter table public.hotel_settings
  add column if not exists urgent_overlay_enabled boolean not null default false;

notify pgrst, 'reload schema';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260512100944_manual_transfer_detail_single_room.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Manual Transfer Detail, single-room v1.
-- Keeps folio_payments as the accounting source while storing bank transfer
-- metadata in transfer_events for audit comparison.

create table if not exists public.transfer_events (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'manual',
  paid_date date not null,
  sender_name text null,
  transfer_at timestamptz null,
  amount numeric(12,2) not null,
  bank_ref text null,
  scb_transaction_id uuid null references public.scb_payment_transactions(id) on delete set null,
  note text null,
  recorded_by uuid null references public.profiles(user_id),
  recorded_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.transfer_events
  add column if not exists source text not null default 'manual',
  add column if not exists paid_date date not null default current_date,
  add column if not exists sender_name text null,
  add column if not exists transfer_at timestamptz null,
  add column if not exists amount numeric(12,2) not null default 0,
  add column if not exists bank_ref text null,
  add column if not exists note text null,
  add column if not exists recorded_by uuid null references public.profiles(user_id),
  add column if not exists recorded_at timestamptz not null default timezone('utc', now()),
  add column if not exists created_at timestamptz not null default timezone('utc', now());

do $$
begin
  alter table public.transfer_events
    add constraint transfer_events_source_check
    check (source in ('manual', 'ocr', 'scb_webhook'));
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table public.transfer_events
    add constraint transfer_events_amount_check
    check (amount > 0);
exception
  when duplicate_object then null;
end $$;

create index if not exists idx_transfer_events_paid_date
  on public.transfer_events (paid_date);

create index if not exists idx_transfer_events_transfer_at
  on public.transfer_events (transfer_at desc nulls last);

create index if not exists idx_transfer_events_recorded_at
  on public.transfer_events (recorded_at desc);

create index if not exists idx_transfer_events_source
  on public.transfer_events (source);

alter table public.folio_payments
  add column if not exists transfer_event_id uuid null;

do $$
begin
  alter table public.folio_payments
    add constraint folio_payments_transfer_event_id_fkey
    foreign key (transfer_event_id)
    references public.transfer_events(id)
    on delete set null;
exception
  when duplicate_object then null;
end $$;

create index if not exists idx_folio_payments_transfer_event
  on public.folio_payments (transfer_event_id);

alter table public.transfer_events enable row level security;

drop policy if exists transfer_events_select_staff on public.transfer_events;
create policy transfer_events_select_staff on public.transfer_events
for select to authenticated
using (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]));

drop policy if exists transfer_events_insert_staff on public.transfer_events;
create policy transfer_events_insert_staff on public.transfer_events
for insert to authenticated
with check (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]));

drop function if exists public.create_manual_transfer_payment(
  uuid,
  public.payment_tx_type,
  public.payment_method_type,
  numeric,
  text,
  text,
  text,
  boolean,
  date,
  timestamptz,
  uuid,
  numeric,
  text,
  text,
  timestamptz,
  text
);

create function public.create_manual_transfer_payment(
  p_reservation_id uuid,
  p_tx_type public.payment_tx_type,
  p_method public.payment_method_type,
  p_folio_amount numeric,
  p_folio_note text,
  p_revenue_category text,
  p_cashier_name text,
  p_is_record_only boolean,
  p_paid_date date,
  p_paid_at timestamptz,
  p_recorded_by uuid,
  p_actual_amount numeric,
  p_sender_name text,
  p_bank_ref text,
  p_transfer_at timestamptz,
  p_transfer_note text
)
returns table(payment_id uuid, transfer_event_id uuid)
language plpgsql
as $$
declare
  v_payment_id uuid;
  v_transfer_event_id uuid;
begin
  if p_method <> 'transfer'::public.payment_method_type then
    raise exception 'manual transfer detail can only be used with transfer method';
  end if;

  if p_actual_amount is null or p_actual_amount <= 0 then
    raise exception 'transfer actual amount must be > 0';
  end if;

  if p_transfer_at is null then
    raise exception 'transfer_at is required';
  end if;

  if p_transfer_at > now() then
    raise exception 'transfer_at cannot be in the future';
  end if;

  insert into public.transfer_events (
    source,
    paid_date,
    sender_name,
    transfer_at,
    amount,
    bank_ref,
    note,
    recorded_by,
    recorded_at
  )
  values (
    'manual',
    p_paid_date,
    nullif(btrim(p_sender_name), ''),
    p_transfer_at,
    p_actual_amount,
    nullif(btrim(p_bank_ref), ''),
    nullif(btrim(p_transfer_note), ''),
    p_recorded_by,
    timezone('utc', now())
  )
  returning id into v_transfer_event_id;

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    revenue_category,
    cashier_name,
    is_record_only,
    paid_date,
    paid_at,
    recorded_by,
    transfer_event_id
  )
  values (
    p_reservation_id,
    p_tx_type,
    p_method,
    p_folio_amount,
    nullif(btrim(p_folio_note), ''),
    p_revenue_category,
    p_cashier_name,
    coalesce(p_is_record_only, false),
    p_paid_date,
    p_paid_at,
    p_recorded_by,
    v_transfer_event_id
  )
  returning id into v_payment_id;

  return query select v_payment_id, v_transfer_event_id;
end;
$$;

grant execute on function public.create_manual_transfer_payment(
  uuid,
  public.payment_tx_type,
  public.payment_method_type,
  numeric,
  text,
  text,
  text,
  boolean,
  date,
  timestamptz,
  uuid,
  numeric,
  text,
  text,
  timestamptz,
  text
) to authenticated, service_role;

comment on table public.transfer_events is
  'Structured bank transfer metadata used for manual Transfer Audit. Accounting still lives in folio_payments.';
comment on column public.transfer_events.source is
  'manual for staff-entered transfers; ocr/scb_webhook reserved for future automation.';
comment on column public.transfer_events.amount is
  'Actual bank transfer amount before any future allocation/split.';
comment on column public.transfer_events.transfer_at is
  'Customer-side bank transfer timestamp.';
comment on column public.folio_payments.transfer_event_id is
  'Nullable link to structured transfer_events. Null transfer rows are legacy free-text entries.';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260512124806_transfer_audit_grouping_v1.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Transfer Audit Grouping v1.
-- Transfer Audit is an evidence/grouping layer only. Money remains in
-- folio_payments; transfer_events.amount is locked to linked folio rows.

alter table public.transfer_events
  add column if not exists status text not null default 'active',
  add column if not exists archived_at timestamptz null,
  add column if not exists archived_by uuid null references public.profiles(user_id),
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.transfer_events
  drop constraint if exists transfer_events_status_check;

alter table public.transfer_events
  add constraint transfer_events_status_check
  check (status in ('active', 'archived'));

create index if not exists idx_transfer_events_status_recorded
  on public.transfer_events (status, recorded_at desc);

alter table public.folio_payments
  add column if not exists transfer_audit_original_note text null;

create index if not exists idx_folio_payments_transfer_unlinked
  on public.folio_payments (paid_date, paid_at desc)
  where method = 'transfer'::public.payment_method_type
    and transfer_event_id is null;

drop policy if exists transfer_events_update_staff on public.transfer_events;
create policy transfer_events_update_staff on public.transfer_events
for update to authenticated
using (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]))
with check (public.has_any_role(array['admin', 'frontdesk', 'supervisor']::public.user_role[]));

-- Backfill active status and lock any existing event amount to linked folio rows.
update public.transfer_events
set status = coalesce(nullif(status, ''), 'active'),
    updated_at = timezone('utc', now())
where status is null or status = '';

update public.transfer_events te
set amount = grouped.total_amount,
    updated_at = timezone('utc', now())
from (
  select transfer_event_id, sum(amount)::numeric(12,2) as total_amount
  from public.folio_payments
  where transfer_event_id is not null
  group by transfer_event_id
) grouped
where te.id = grouped.transfer_event_id;

drop function if exists public.create_manual_transfer_payment(
  uuid,
  public.payment_tx_type,
  public.payment_method_type,
  numeric,
  text,
  text,
  text,
  boolean,
  date,
  timestamptz,
  uuid,
  numeric,
  text,
  text,
  timestamptz,
  text
);

create function public.create_manual_transfer_payment(
  p_reservation_id uuid,
  p_tx_type public.payment_tx_type,
  p_method public.payment_method_type,
  p_folio_amount numeric,
  p_folio_note text,
  p_revenue_category text,
  p_cashier_name text,
  p_is_record_only boolean,
  p_paid_date date,
  p_paid_at timestamptz,
  p_recorded_by uuid,
  p_actual_amount numeric,
  p_sender_name text,
  p_bank_ref text,
  p_transfer_at timestamptz,
  p_transfer_note text
)
returns table(payment_id uuid, transfer_event_id uuid)
language plpgsql
as $$
declare
  v_payment_id uuid;
  v_transfer_event_id uuid;
begin
  if p_method <> 'transfer'::public.payment_method_type then
    raise exception 'manual transfer detail can only be used with transfer method';
  end if;

  if p_folio_amount is null or p_folio_amount <= 0 then
    raise exception 'folio payment amount must be > 0';
  end if;

  if p_actual_amount is null or p_actual_amount <= 0 then
    raise exception 'transfer actual amount must be > 0';
  end if;

  if p_transfer_at is null then
    raise exception 'transfer_at is required';
  end if;

  if p_transfer_at > now() then
    raise exception 'transfer_at cannot be in the future';
  end if;

  insert into public.transfer_events (
    source,
    status,
    paid_date,
    sender_name,
    transfer_at,
    amount,
    bank_ref,
    note,
    recorded_by,
    recorded_at,
    updated_at
  )
  values (
    'manual',
    'active',
    p_paid_date,
    nullif(btrim(p_sender_name), ''),
    p_transfer_at,
    p_folio_amount,
    nullif(btrim(p_bank_ref), ''),
    nullif(btrim(p_transfer_note), ''),
    p_recorded_by,
    timezone('utc', now()),
    timezone('utc', now())
  )
  returning id into v_transfer_event_id;

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    revenue_category,
    cashier_name,
    is_record_only,
    paid_date,
    paid_at,
    recorded_by,
    transfer_event_id
  )
  values (
    p_reservation_id,
    p_tx_type,
    p_method,
    p_folio_amount,
    nullif(btrim(p_folio_note), ''),
    p_revenue_category,
    p_cashier_name,
    coalesce(p_is_record_only, false),
    p_paid_date,
    p_paid_at,
    p_recorded_by,
    v_transfer_event_id
  )
  returning id into v_payment_id;

  return query select v_payment_id, v_transfer_event_id;
end;
$$;

grant execute on function public.create_manual_transfer_payment(
  uuid,
  public.payment_tx_type,
  public.payment_method_type,
  numeric,
  text,
  text,
  text,
  boolean,
  date,
  timestamptz,
  uuid,
  numeric,
  text,
  text,
  timestamptz,
  text
) to authenticated, service_role;

comment on column public.transfer_events.status is
  'active or archived. Archived groups keep evidence history but unlink folio rows.';
comment on column public.transfer_events.amount is
  'Locked audit group amount, always computed from linked folio_payments rows.';
comment on column public.folio_payments.transfer_audit_original_note is
  'Original folio note before Transfer Audit auto-sync; restored when unlinked.';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260513073516_transfer_deposit_split_exact_match.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

-- Exact-match Transfer Detail split:
-- one manual transfer event creates a room payment row and a deposit row.
-- The API still owns the decision; this RPC keeps the DB insert atomic.

drop function if exists public.create_manual_transfer_payment_with_deposit_split(
  uuid,
  numeric,
  numeric,
  text,
  text,
  date,
  timestamptz,
  uuid,
  numeric,
  text,
  text,
  timestamptz,
  text
);

create function public.create_manual_transfer_payment_with_deposit_split(
  p_reservation_id uuid,
  p_folio_amount numeric,
  p_deposit_amount numeric,
  p_folio_note text,
  p_cashier_name text,
  p_paid_date date,
  p_paid_at timestamptz,
  p_recorded_by uuid,
  p_actual_amount numeric,
  p_sender_name text,
  p_bank_ref text,
  p_transfer_at timestamptz,
  p_transfer_note text
)
returns table(payment_id uuid, deposit_payment_id uuid, transfer_event_id uuid)
language plpgsql
as $$
declare
  v_payment_id uuid;
  v_deposit_payment_id uuid;
  v_transfer_event_id uuid;
  v_folio_amount numeric(12,2) := round(coalesce(p_folio_amount, 0)::numeric, 2);
  v_deposit_amount numeric(12,2) := round(coalesce(p_deposit_amount, 0)::numeric, 2);
  v_actual_amount numeric(12,2) := round(coalesce(p_actual_amount, 0)::numeric, 2);
begin
  if p_reservation_id is null then
    raise exception 'reservation_id is required';
  end if;

  if v_folio_amount <= 0 then
    raise exception 'folio payment amount must be > 0';
  end if;

  if v_deposit_amount <= 0 then
    raise exception 'deposit amount must be > 0';
  end if;

  if v_actual_amount <= 0 then
    raise exception 'transfer actual amount must be > 0';
  end if;

  if v_actual_amount <> round((v_folio_amount + v_deposit_amount)::numeric, 2) then
    raise exception 'actual transfer amount must equal folio payment plus deposit';
  end if;

  if p_transfer_at is null then
    raise exception 'transfer_at is required';
  end if;

  if p_transfer_at > now() then
    raise exception 'transfer_at cannot be in the future';
  end if;

  insert into public.transfer_events (
    source,
    status,
    paid_date,
    sender_name,
    transfer_at,
    amount,
    bank_ref,
    note,
    recorded_by,
    recorded_at,
    updated_at
  )
  values (
    'manual',
    'active',
    p_paid_date,
    nullif(btrim(p_sender_name), ''),
    p_transfer_at,
    v_actual_amount,
    nullif(btrim(p_bank_ref), ''),
    nullif(btrim(p_transfer_note), ''),
    p_recorded_by,
    timezone('utc', now()),
    timezone('utc', now())
  )
  returning id into v_transfer_event_id;

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    revenue_category,
    cashier_name,
    is_record_only,
    paid_date,
    paid_at,
    recorded_by,
    transfer_event_id
  )
  values (
    p_reservation_id,
    'payment'::public.payment_tx_type,
    'transfer'::public.payment_method_type,
    v_folio_amount,
    nullif(btrim(p_folio_note), ''),
    'room_revenue',
    coalesce(nullif(btrim(p_cashier_name), ''), 'FO'),
    false,
    p_paid_date,
    p_paid_at,
    p_recorded_by,
    v_transfer_event_id
  )
  returning id into v_payment_id;

  insert into public.folio_payments (
    reservation_id,
    tx_type,
    method,
    amount,
    note,
    revenue_category,
    cashier_name,
    is_record_only,
    paid_date,
    paid_at,
    recorded_by,
    transfer_event_id
  )
  values (
    p_reservation_id,
    'deposit'::public.payment_tx_type,
    'transfer'::public.payment_method_type,
    v_deposit_amount,
    nullif(btrim(p_folio_note), ''),
    'deposit',
    coalesce(nullif(btrim(p_cashier_name), ''), 'FO'),
    false,
    p_paid_date,
    p_paid_at,
    p_recorded_by,
    v_transfer_event_id
  )
  returning id into v_deposit_payment_id;

  return query select v_payment_id, v_deposit_payment_id, v_transfer_event_id;
end;
$$;

grant execute on function public.create_manual_transfer_payment_with_deposit_split(
  uuid,
  numeric,
  numeric,
  text,
  text,
  date,
  timestamptz,
  uuid,
  numeric,
  text,
  text,
  timestamptz,
  text
) to authenticated, service_role;

comment on function public.create_manual_transfer_payment_with_deposit_split(
  uuid,
  numeric,
  numeric,
  text,
  text,
  date,
  timestamptz,
  uuid,
  numeric,
  text,
  text,
  timestamptz,
  text
) is
  'Creates one manual transfer event and links exact-match room payment + deposit folio rows atomically.';



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260531020615_linen_monthly_vendor_statement.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

-- Monthly vendor statements use a separate token scope from per-batch vendor flows.
-- Expiry is controlled by API code at the next Bangkok month boundary.
create table if not exists public.laundry_monthly_vendor_tokens (
  id uuid primary key default gen_random_uuid(),
  year smallint not null check (year between 2020 and 2100),
  month smallint not null check (month between 1 and 12),
  token uuid not null default gen_random_uuid() unique,
  vendor_name text,
  expires_at timestamptz not null,
  revoked boolean not null default false,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_laundry_monthly_vendor_tokens_token
  on public.laundry_monthly_vendor_tokens (token);

create index if not exists idx_laundry_monthly_vendor_tokens_period
  on public.laundry_monthly_vendor_tokens (year, month, created_at desc);

create unique index if not exists idx_laundry_monthly_vendor_tokens_one_active_period
  on public.laundry_monthly_vendor_tokens (year, month)
  where revoked = false;

drop trigger if exists trg_laundry_monthly_vendor_tokens_updated_at on public.laundry_monthly_vendor_tokens;
create trigger trg_laundry_monthly_vendor_tokens_updated_at
before update on public.laundry_monthly_vendor_tokens
for each row execute function public.set_updated_at();

alter table public.laundry_monthly_vendor_tokens enable row level security;

drop policy if exists laundry_monthly_vendor_tokens_auth on public.laundry_monthly_vendor_tokens;
create policy laundry_monthly_vendor_tokens_auth on public.laundry_monthly_vendor_tokens
  for all to authenticated
  using (true)
  with check (true);

drop policy if exists laundry_monthly_vendor_tokens_service_role on public.laundry_monthly_vendor_tokens;
create policy laundry_monthly_vendor_tokens_service_role on public.laundry_monthly_vendor_tokens
  for all to service_role
  using (true)
  with check (true);

grant select, insert, update, delete on public.laundry_monthly_vendor_tokens to authenticated, service_role;

-- Monthly summary billing is N + O. Rewash is stored separately and remains ฿0.
create or replace function public.fn_linen_monthly_summary(p_year int, p_month int)
returns table (
  linen_item_id int,
  item_number smallint,
  name_th text,
  name_en text,
  rate numeric,
  qty_sent bigint,
  qty_returned bigint,
  qty_pending bigint,
  qty_extra bigint,
  qty_dayuse bigint,
  total_baht numeric
)
language sql
stable
as $$
  with bounds as (
    select make_date(p_year, p_month, 1) as start_date,
           (make_date(p_year, p_month, 1) + interval '1 month')::date as end_date
  ),
  item_agg as (
    select
      i.linen_item_id,
      sum(case when i.is_dayuse is false then i.sent_by_hotel else 0 end)::bigint as qty_sent,
      sum(case when i.is_dayuse is false then i.received_back else 0 end)::bigint as qty_returned,
      sum(case when i.is_dayuse is false and li.item_number in (1, 2)
          then greatest(i.sent_by_hotel - i.estimated_qty, 0)
          else 0 end)::bigint as qty_extra,
      sum(case when i.is_dayuse is true then i.sent_by_hotel else 0 end)::bigint as qty_dayuse
    from public.laundry_batches b
    join public.laundry_batch_items i on i.batch_id = b.id
    join public.linen_items li on li.id = i.linen_item_id
    cross join bounds
    where b.business_date >= bounds.start_date
      and b.business_date < bounds.end_date
    group by i.linen_item_id
  )
  select
    li.id as linen_item_id,
    li.item_number,
    li.name_th,
    li.name_en,
    public.fn_linen_rate(li.id, bounds.start_date) as rate,
    coalesce(a.qty_sent, 0) as qty_sent,
    coalesce(a.qty_returned, 0) as qty_returned,
    greatest(coalesce(a.qty_sent, 0) - coalesce(a.qty_returned, 0), 0) as qty_pending,
    coalesce(a.qty_extra, 0) as qty_extra,
    coalesce(a.qty_dayuse, 0) as qty_dayuse,
    (
      public.fn_linen_rate(li.id, bounds.start_date)
      * (coalesce(a.qty_sent, 0) + coalesce(a.qty_dayuse, 0))
    )::numeric(12, 2) as total_baht
  from public.linen_items li
  cross join bounds
  left join item_agg a on a.linen_item_id = li.id
  order by li.item_number;
$$;

grant execute on function public.fn_linen_monthly_summary(int, int) to authenticated, service_role;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260531125620_ui_event_log_archive_runs.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create table if not exists public.ui_event_log_archive_runs (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'started'
    check (status in ('started', 'succeeded', 'failed')),
  archive_cutoff_at timestamptz not null,
  retention_policy jsonb not null default '{}'::jsonb,
  r2_keys text[] not null default '{}'::text[],
  sha256_by_key jsonb not null default '{}'::jsonb,
  row_count integer not null default 0,
  archived_count integer not null default 0,
  deleted_count integer not null default 0,
  event_counts jsonb not null default '{}'::jsonb,
  category_counts jsonb not null default '{}'::jsonb,
  error_message text,
  started_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.ui_event_log_archive_runs enable row level security;

alter table public.ui_event_logs
  add column if not exists archived_at timestamptz,
  add column if not exists archive_run_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'ui_event_logs_archive_run_id_fkey'
  ) then
    alter table public.ui_event_logs
      add constraint ui_event_logs_archive_run_id_fkey
      foreign key (archive_run_id)
      references public.ui_event_log_archive_runs (id)
      on delete set null;
  end if;
end $$;

create index if not exists idx_ui_event_log_archive_runs_created
  on public.ui_event_log_archive_runs (created_at desc);

create index if not exists idx_ui_event_logs_archive_pending
  on public.ui_event_logs (created_at asc)
  where archived_at is null;

create index if not exists idx_ui_event_logs_archived_cleanup
  on public.ui_event_logs (created_at asc)
  where archived_at is not null;

commit;



-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- MIGRATION: 20260531134927_ui_event_log_supabase_cron.sql
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

begin;

create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists supabase_vault with schema vault;

-- Supabase Cron is the scheduler of record for Activity Log archives.
-- Required Vault secrets before the job runs:
--   hotel_pms_app_base_url       = https://<current app host>
--   hotel_pms_cron_backup_secret = same value as CRON_BACKUP_SECRET on the app host

create or replace function public.invoke_ui_event_log_archive()
returns bigint
language plpgsql
security definer
set search_path = public, extensions, net, vault
as $$
declare
  app_base_url text;
  cron_secret text;
  request_id bigint;
begin
  select decrypted_secret
  into app_base_url
  from vault.decrypted_secrets
  where name = 'hotel_pms_app_base_url'
  limit 1;

  select decrypted_secret
  into cron_secret
  from vault.decrypted_secrets
  where name = 'hotel_pms_cron_backup_secret'
  limit 1;

  if nullif(trim(app_base_url), '') is null then
    raise exception 'Missing Vault secret: hotel_pms_app_base_url';
  end if;

  if nullif(trim(cron_secret), '') is null then
    raise exception 'Missing Vault secret: hotel_pms_cron_backup_secret';
  end if;

  select net.http_post(
    url := rtrim(app_base_url, '/') || '/api/cron/ui-event-log-archive',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || cron_secret
    ),
    body := jsonb_build_object(
      'source', 'supabase_cron',
      'job', 'ui_event_log_archive',
      'requested_at', timezone('utc', now())
    ),
    timeout_milliseconds := 30000
  )
  into request_id;

  return request_id;
end;
$$;

revoke all on function public.invoke_ui_event_log_archive() from public;
grant execute on function public.invoke_ui_event_log_archive() to postgres;
grant execute on function public.invoke_ui_event_log_archive() to service_role;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'ui_event_log_archive_http') then
    perform cron.unschedule(jobid)
    from cron.job
    where jobname = 'ui_event_log_archive_http';
  end if;

  perform cron.schedule(
    'ui_event_log_archive_http',
    '0 20 * * *',
    'select public.invoke_ui_event_log_archive();'
  );
exception
  when others then
    raise notice 'Unable to schedule ui_event_log_archive_http (%). Configure Supabase Cron manually after this migration.', sqlerrm;
end $$;

commit;


