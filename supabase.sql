--0)Extensions
-- UUID/加密工具（可选，但常用）
create extension if not exists "pgcrypto";
-- 地理能力
create extension if not exists postgis;

--1) 类型 & 枚举
do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type user_role as enum ('passenger', 'driver');
  end if;

  if not exists (select 1 from pg_type where typname = 'order_status') then
    create type order_status as enum (
      'requested',
      'accepted',
      'arrived',
      'started',
      'completed',
      'cancelled'
    );
  end if;
end $$;

--2) 表结构
--2.1 profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null,
  name text,
  phone text,
  driver_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles(role);

--自动创建 profile
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role)
  values (new.id, 'passenger')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- 2.2 drivers（司机实时点位/在线状态)
create table if not exists public.drivers (
  id uuid primary key references public.profiles(id) on delete cascade,
  is_online boolean not null default false,

  current_lat double precision,
  current_lng double precision,

  -- 用 generated column 生成 geography 点，方便距离计算 + 索引
  current_geog geography(Point, 4326)
    generated always as (
      case
        when current_lat is null or current_lng is null then null
        else ST_SetSRID(ST_MakePoint(current_lng, current_lat), 4326)::geography
      end
    ) stored,

  updated_at timestamptz not null default now()
);

create index if not exists drivers_online_idx on public.drivers(is_online);
create index if not exists drivers_geog_gist_idx on public.drivers using gist(current_geog);

--2.3 orders（订单）
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),

  passenger_id uuid not null references public.profiles(id),
  driver_id uuid references public.profiles(id),

  pickup_lat double precision not null,
  pickup_lng double precision not null,
  dropoff_lat double precision,
  dropoff_lng double precision,

  pickup_geog geography(Point, 4326)
    generated always as (
      ST_SetSRID(ST_MakePoint(pickup_lng, pickup_lat), 4326)::geography
    ) stored,

  dropoff_geog geography(Point, 4326)
    generated always as (
      case
        when dropoff_lat is null or dropoff_lng is null then null
        else ST_SetSRID(ST_MakePoint(dropoff_lng, dropoff_lat), 4326)::geography
      end
    ) stored,

  status order_status not null default 'requested',

  price_estimate numeric(10,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists orders_passenger_idx on public.orders(passenger_id);
create index if not exists orders_driver_idx on public.orders(driver_id);
create index if not exists orders_status_idx on public.orders(status);
create index if not exists orders_pickup_gist_idx on public.orders using gist(pickup_geog);

--2.4 order_locations（司机轨迹历史，可选但强烈推荐)
create table if not exists public.order_locations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete cascade,

  lat double precision not null,
  lng double precision not null,

  geog geography(Point, 4326)
    generated always as (
      ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography
    ) stored,

  recorded_at timestamptz not null default now()
);

create index if not exists order_locations_order_idx on public.order_locations(order_id);
create index if not exists order_locations_driver_idx on public.order_locations(driver_id);
create index if not exists order_locations_geog_gist_idx on public.order_locations using gist(geog);

--3) updated_at 自动刷新
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_drivers_updated_at on public.drivers;
create trigger trg_drivers_updated_at
before update on public.drivers
for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at
before update on public.orders
for each row execute procedure public.touch_updated_at();

--4) RLS
--先统一开启：
alter table public.profiles enable row level security;
alter table public.drivers enable row level security;
alter table public.orders enable row level security;
alter table public.order_locations enable row level security;

--4.1 profiles 策略
-- 自己看自己
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

-- 自己改自己
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- 允许自己插入自己（如果你不用 auth trigger 可保留）
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

--4.2 drivers 策略
-- 司机可读自己的司机行
create policy "drivers_select_own"
on public.drivers
for select
to authenticated
using (id = auth.uid());

-- 乘客可读在线司机（只读）
create policy "drivers_select_online"
on public.drivers
for select
to authenticated
using (is_online = true);

-- 司机可插入自己的 drivers 记录
create policy "drivers_insert_own"
on public.drivers
for insert
to authenticated
with check (id = auth.uid());

-- 司机只能更新自己的在线/位置
create policy "drivers_update_own"
on public.drivers
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

--4.3 orders 策略
-- 乘客读自己的订单
create policy "orders_select_passenger_own"
on public.orders
for select
to authenticated
using (passenger_id = auth.uid());

-- 司机读自己接的订单
create policy "orders_select_driver_own"
on public.orders
for select
to authenticated
using (driver_id = auth.uid());

-- 乘客创建订单
create policy "orders_insert_passenger"
on public.orders
for insert
to authenticated
with check (passenger_id = auth.uid());

-- 乘客更新自己订单（通常仅允许取消/改目的地等）
create policy "orders_update_passenger_own"
on public.orders
for update
to authenticated
using (passenger_id = auth.uid())
with check (passenger_id = auth.uid());

-- 司机更新自己接到的订单
create policy "orders_update_driver_own"
on public.orders
for update
to authenticated
using (driver_id = auth.uid())
with check (driver_id = auth.uid());

--实战建议：
--不要让客户端直接随便 update status。
--状态流用 RPC 控制更安全（下面我给你做了）。

--4.4 order_locations 策略
-- 司机写自己的轨迹
create policy "order_locations_insert_driver_own"
on public.order_locations
for insert
to authenticated
with check (driver_id = auth.uid());

-- 司机读取自己轨迹
create policy "order_locations_select_driver_own"
on public.order_locations
for select
to authenticated
using (driver_id = auth.uid());

-- 乘客读取自己订单的轨迹
create policy "order_locations_select_passenger_order"
on public.order_locations
for select
to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = order_id
      and o.passenger_id = auth.uid()
  )
);

--5) 核心 RPC

--这些 RPC 是你 iOS MVP 的“发动机”。
--重点：距离字段直接由数据库算好返回。

create or replace function public.list_nearby_online_drivers(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision default 5,
  p_limit int default 50
)
returns table (
  driver_id uuid,
  name text,
  is_online boolean,
  current_lat double precision,
  current_lng double precision,
  distance_km double precision
)
language sql
stable
as $$
  with me as (
    select ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography as g
  )
  select
    d.id as driver_id,
    p.name,
    d.is_online,
    d.current_lat,
    d.current_lng,
    round((ST_Distance(d.current_geog, me.g) / 1000.0)::numeric, 3)::double precision as distance_km
  from public.drivers d
  join public.profiles p on p.id = d.id
  cross join me
  where d.is_online = true
    and d.current_geog is not null
    and ST_DWithin(d.current_geog, me.g, p_radius_km * 1000.0)
  order by ST_Distance(d.current_geog, me.g)
  limit p_limit;
$$;

--5.2 司机：获取附近可接订单（带距离）
create or replace function public.list_nearby_open_orders(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision default 5,
  p_limit int default 50
)
returns table (
  order_id uuid,
  passenger_id uuid,
  pickup_lat double precision,
  pickup_lng double precision,
  dropoff_lat double precision,
  dropoff_lng double precision,
  status order_status,
  distance_km double precision,
  created_at timestamptz
)
language sql
stable
as $$
  with me as (
    select ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography as g
  )
  select
    o.id as order_id,
    o.passenger_id,
    o.pickup_lat, o.pickup_lng,
    o.dropoff_lat, o.dropoff_lng,
    o.status,
    round((ST_Distance(o.pickup_geog, me.g) / 1000.0)::numeric, 3)::double precision as distance_km,
    o.created_at
  from public.orders o
  cross join me
  where o.status = 'requested'
    and o.driver_id is null
    and ST_DWithin(o.pickup_geog, me.g, p_radius_km * 1000.0)
  order by ST_Distance(o.pickup_geog, me.g), o.created_at desc
  limit p_limit;
$$;

--5.3 司机：上报位置/在线状态（upsert）
create or replace function public.upsert_my_driver_state(
  p_is_online boolean,
  p_lat double precision,
  p_lng double precision
)
returns public.drivers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role user_role;
  v_row public.drivers;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'driver' then
    raise exception 'only driver can update driver state';
  end if;

  insert into public.drivers (id, is_online, current_lat, current_lng)
  values (v_uid, p_is_online, p_lat, p_lng)
  on conflict (id)
  do update set
    is_online = excluded.is_online,
    current_lat = excluded.current_lat,
    current_lng = excluded.current_lng,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.upsert_my_driver_state(boolean, double precision, double precision) to authenticated;

--5.4 司机：接单（原子化防抢单）
create or replace function public.accept_order(
  p_order_id uuid
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role user_role;
  v_order public.orders;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'driver' then
    raise exception 'only driver can accept orders';
  end if;

  -- 锁行，避免并发抢单
  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.status <> 'requested' or v_order.driver_id is not null then
    raise exception 'order not available';
  end if;

  update public.orders
  set driver_id = v_uid,
      status = 'accepted',
      updated_at = now()
  where id = p_order_id
  returning * into v_order;

  return v_order;
end;
$$;

grant execute on function public.accept_order(uuid) to authenticated;

--5.5 司机/乘客：推进订单状态（受控状态机）
--你可以做一个通用的状态推进 RPC，但要严格判断身份与合法状态跳转。
create or replace function public.set_order_status(
  p_order_id uuid,
  p_new_status order_status
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role user_role;
  v_order public.orders;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select role into v_role from public.profiles where id = v_uid;

  select * into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  -- 权限判断
  if v_role = 'passenger' and v_order.passenger_id <> v_uid then
    raise exception 'passenger cannot modify others order';
  end if;

  if v_role = 'driver' and v_order.driver_id <> v_uid then
    raise exception 'driver cannot modify unassigned order';
  end if;

  -- 合法状态机（可按你业务微调）
  if v_order.status = 'requested' and p_new_status not in ('cancelled') and v_role <> 'driver' then
    raise exception 'only driver can move requested -> accepted';
  end if;

  if v_order.status = 'requested' and p_new_status = 'accepted' and v_role <> 'driver' then
    raise exception 'only driver can accept';
  end if;

  if v_order.status = 'accepted' and p_new_status not in ('arrived','cancelled') then
    raise exception 'invalid transition';
  end if;

  if v_order.status = 'arrived' and p_new_status not in ('started','cancelled') then
    raise exception 'invalid transition';
  end if;

  if v_order.status = 'started' and p_new_status not in ('completed') then
    raise exception 'invalid transition';
  end if;

  if v_order.status in ('completed','cancelled') then
    raise exception 'final state cannot change';
  end if;

  update public.orders
  set status = p_new_status,
      updated_at = now()
  where id = p_order_id
  returning * into v_order;

  return v_order;
end;
$$;

grant execute on function public.set_order_status(uuid, order_status) to authenticated;

--5.6 司机：写轨迹点（可选）
create or replace function public.append_my_order_location(
  p_order_id uuid,
  p_lat double precision,
  p_lng double precision
)
returns public.order_locations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_order public.orders;
  v_row public.order_locations;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.driver_id <> v_uid then
    raise exception 'only assigned driver can write locations';
  end if;

  insert into public.order_locations(order_id, driver_id, lat, lng)
  values (p_order_id, v_uid, p_lat, p_lng)
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.append_my_order_location(uuid, double precision, double precision) to authenticated;

-- 6) 你 iOS 侧对接时的最关键调用清单
-- 乘客首页附近司机：
-- list_nearby_online_drivers(lat, lng, radius_km, limit)
-- 司机首页附近可接单：
-- list_nearby_open_orders(lat, lng, radius_km, limit)
-- 司机上线 & 位置心跳：
-- upsert_my_driver_state(is_online, lat, lng)
-- 司机接单：
-- accept_order(order_id)
-- 状态推进：
-- set_order_status(order_id, new_status)
-- 轨迹（如果启用）：
-- append_my_order_location(order_id, lat, lng)

-- 7) 小提醒（避免后期安全返工）
-- 客户端不要直接 update orders.status
-- 只调用 accept_order / set_order_status。
-- 你要做“只展示 5km 内司机/订单”，
-- UI 侧不要自己算距离，
-- 就用 RPC 返回的 distance_km。
-- Realtime 订阅建议：
-- 乘客端：按 orders 里自己的订单过滤
-- 司机端：可以先“RPC 轮询”，后面再做实时推送

--司机读取未被接单的 requested 订单
--司机只能看到自己在线时的接单池：

create policy "orders_select_open_for_drivers_online"
on public.orders
for select
to authenticated
using (
  status = 'requested'
  and driver_id is null
  and exists (
    select 1
    from public.drivers d
    where d.id = auth.uid()
      and d.is_online = true
  )
);
