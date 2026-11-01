-- FridgeMate Family 4.0 migration
-- Run this in Supabase SQL Editor while logged in as project owner.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
do $$ declare ext_schema text; begin
  select n.nspname into ext_schema from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname='pgcrypto';
  if ext_schema is distinct from 'extensions' then alter extension pgcrypto set schema extensions; end if;
end $$;

-- Shared household preferences and budget.
create table if not exists public.household_settings (
  household_id uuid primary key references public.households(id) on delete cascade,
  budget_limit numeric(12,2) not null default 0 check (budget_limit >= 0),
  updated_at timestamptz not null default now()
);

alter table public.family_items
  add column if not exists bought_by uuid references auth.users(id) on delete set null,
  add column if not exists bought_at timestamptz;

-- Persist the current invitation code so the owner can retrieve it after reload.
alter table public.households add column if not exists invite_code text;

create table if not exists public.family_meals (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  meal_date date not null default current_date,
  meal_type text not null check (meal_type in ('Сніданок','Обід','Вечеря')),
  recipe_name text not null check (char_length(recipe_name) between 1 and 160),
  created_at timestamptz not null default now()
);
create index if not exists family_meals_household_date_idx on public.family_meals(household_id, meal_date);

alter table public.household_settings enable row level security;
alter table public.family_meals enable row level security;

drop policy if exists household_settings_select on public.household_settings;
create policy household_settings_select on public.household_settings for select using (public.is_family_member(household_id));
drop policy if exists household_settings_insert on public.household_settings;
create policy household_settings_insert on public.household_settings for insert with check (public.is_family_member(household_id));
drop policy if exists household_settings_update on public.household_settings;
create policy household_settings_update on public.household_settings for update using (public.is_family_member(household_id)) with check (public.is_family_member(household_id));
drop policy if exists family_meals_select on public.family_meals;
create policy family_meals_select on public.family_meals for select using (public.is_family_member(household_id));
drop policy if exists family_meals_insert on public.family_meals;
create policy family_meals_insert on public.family_meals for insert with check (public.is_family_member(household_id) and created_by = auth.uid());
drop policy if exists family_meals_delete on public.family_meals;
create policy family_meals_delete on public.family_meals for delete using (public.is_family_member(household_id));

grant select, insert, update on public.household_settings to authenticated;
grant select, insert, delete on public.family_meals to authenticated;
grant select on public.households to authenticated;
grant select, insert, update, delete on public.family_items to authenticated;

-- Always resolve pgcrypto functions in the extensions schema.
create or replace function public.create_family(p_name text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare c text; h uuid; u uuid := auth.uid();
begin
  if u is null then raise exception 'Потрібна авторизація'; end if;
  if exists(select 1 from public.family_members where user_id = u) then raise exception 'Цей користувач уже в сім’ї'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'Вкажи ім’я'; end if;
  c := upper(substr(encode(extensions.gen_random_bytes(6),'hex'),1,8));
  insert into public.households(invite_code_hash, invite_code)
  values(encode(extensions.digest(c,'sha256'),'hex'), c) returning id into h;
  insert into public.family_members(user_id,household_id,name,role) values(u,h,trim(p_name),'owner');
  insert into public.household_settings(household_id,budget_limit) values(h,0) on conflict do nothing;
  return c;
end; $$;

create or replace function public.join_family(p_code text,p_name text)
returns uuid language plpgsql security definer set search_path = public, extensions as $$
declare h uuid; u uuid := auth.uid(); n int;
begin
  if u is null then raise exception 'Потрібна авторизація'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'Вкажи ім’я'; end if;
  if exists(select 1 from public.family_members where user_id = u) then raise exception 'Цей користувач уже входить до сім’ї'; end if;
  select id into h from public.households where invite_code_hash = encode(extensions.digest(upper(trim(p_code)),'sha256'),'hex') for update;
  if h is null then raise exception 'Неправильний код'; end if;
  select count(*) into n from public.family_members where household_id = h;
  if n >= 2 then raise exception 'У сім’ї вже два учасники'; end if;
  insert into public.family_members(user_id,household_id,name,role) values(u,h,trim(p_name),'member');
  insert into public.household_settings(household_id,budget_limit) values(h,0) on conflict do nothing;
  return h;
end; $$;

create or replace function public.get_family_invite_code()
returns text language plpgsql security definer set search_path = public, extensions as $$
declare h uuid; c text;
begin
  select household_id into h from public.family_members where user_id = auth.uid();
  if h is null then raise exception 'Ти не входиш до сім’ї'; end if;
  select invite_code into c from public.households where id = h;
  if c is null then
    c := upper(substr(encode(extensions.gen_random_bytes(6),'hex'),1,8));
    update public.households set invite_code = c, invite_code_hash = encode(extensions.digest(c,'sha256'),'hex') where id = h;
  end if;
  return c;
end; $$;

create or replace function public.rotate_family_invite_code()
returns text language plpgsql security definer set search_path = public, extensions as $$
declare h uuid; c text;
begin
  select household_id into h from public.family_members where user_id = auth.uid() and role = 'owner';
  if h is null then raise exception 'Лише власник може змінити код'; end if;
  c := upper(substr(encode(extensions.gen_random_bytes(6),'hex'),1,8));
  update public.households set invite_code = c, invite_code_hash = encode(extensions.digest(c,'sha256'),'hex') where id = h;
  return c;
end; $$;

grant execute on function public.create_family(text) to anon, authenticated;
grant execute on function public.join_family(text,text) to anon, authenticated;
grant execute on function public.get_family_invite_code() to authenticated;
grant execute on function public.rotate_family_invite_code() to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.household_settings;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.family_meals;
exception when duplicate_object then null; when undefined_object then null; end $$;

-- Keep the existing two-member family and all existing inventory rows intact.
