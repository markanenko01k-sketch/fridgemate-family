-- FridgeMate Family: execute all in Supabase SQL Editor
create extension if not exists pgcrypto;
create table if not exists public.households(id uuid primary key default gen_random_uuid(),invite_code_hash text not null unique,created_at timestamptz not null default now());
create table if not exists public.family_members(user_id uuid primary key references auth.users(id) on delete cascade,household_id uuid not null references public.households(id) on delete cascade,name text not null check(char_length(name) between 1 and 50),role text not null default 'member' check(role in('owner','member')),created_at timestamptz not null default now());
create index if not exists family_members_household_idx on public.family_members(household_id);
create table if not exists public.family_items(id uuid primary key default gen_random_uuid(),household_id uuid not null references public.households(id) on delete cascade,section text not null check(section in('fridge','pantry','shopping')),name text not null check(char_length(name) between 1 and 160),qty numeric(12,3) not null default 1 check(qty>=0),unit text not null default 'шт.',category text not null default 'Інше',price numeric(12,2) not null default 0 check(price>=0),min_qty numeric(12,3) not null default 0 check(min_qty>=0),expiry_date date,target text not null default 'none' check(target in('fridge','pantry','none')),bought boolean not null default false,added_by uuid references auth.users(id) on delete set null,created_at timestamptz not null default now());
create index if not exists family_items_hh_section_idx on public.family_items(household_id,section);
create or replace function public.is_family_member(h uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from public.family_members where household_id=h and user_id=auth.uid());$$;
alter table public.households enable row level security;alter table public.family_members enable row level security;alter table public.family_items enable row level security;
drop policy if exists household_read on public.households;create policy household_read on public.households for select using(public.is_family_member(id));
drop policy if exists members_read on public.family_members;create policy members_read on public.family_members for select using(public.is_family_member(household_id));
drop policy if exists items_read on public.family_items;create policy items_read on public.family_items for select using(public.is_family_member(household_id));
drop policy if exists items_insert on public.family_items;create policy items_insert on public.family_items for insert with check(public.is_family_member(household_id) and added_by=auth.uid());
drop policy if exists items_update on public.family_items;create policy items_update on public.family_items for update using(public.is_family_member(household_id)) with check(public.is_family_member(household_id));
drop policy if exists items_delete on public.family_items;create policy items_delete on public.family_items for delete using(public.is_family_member(household_id));
create or replace function public.create_family(p_name text) returns text language plpgsql security definer set search_path=public as $$
declare c text; h uuid; u uuid:=auth.uid();
begin
 if u is null then raise exception 'Потрібна авторизація';end if;
 if exists(select 1 from public.family_members where user_id=u) then raise exception 'Цей користувач уже в сім’ї';end if;
 if p_name is null or length(trim(p_name))=0 then raise exception 'Вкажи ім’я';end if;
 c:=upper(substr(encode(gen_random_bytes(6),'hex'),1,8));
 insert into public.households(invite_code_hash) values(encode(digest(c,'sha256'),'hex')) returning id into h;
 insert into public.family_members(user_id,household_id,name,role) values(u,h,trim(p_name),'owner');return c;
end;$$;
create or replace function public.join_family(p_code text,p_name text) returns uuid language plpgsql security definer set search_path=public as $$
declare h uuid;u uuid:=auth.uid();n int;
begin
 if u is null then raise exception 'Потрібна авторизація';end if;
 if p_name is null or length(trim(p_name))=0 then raise exception 'Вкажи ім’я';end if;
 if exists(select 1 from public.family_members where user_id=u) then raise exception 'Цей користувач уже входить до сім’ї';end if;
 select id into h from public.households where invite_code_hash=encode(digest(upper(trim(p_code)),'sha256'),'hex') for update;
 if h is null then raise exception 'Неправильний код';end if;
 select count(*) into n from public.family_members where household_id=h;
 if n>=2 then raise exception 'У сім’ї вже два учасники';end if;
 insert into public.family_members(user_id,household_id,name,role) values(u,h,trim(p_name),'member');return h;
end;$$;
grant execute on function public.create_family(text) to anon,authenticated;
grant execute on function public.join_family(text,text) to anon,authenticated;
grant execute on function public.is_family_member(uuid) to anon,authenticated;
grant select on public.households,public.family_members to authenticated;
grant select,insert,update,delete on public.family_items to authenticated;
do $$begin alter publication supabase_realtime add table public.family_items;exception when duplicate_object then null;when undefined_object then null;end$$;
-- Supabase Dashboard: Authentication -> Providers -> enable Anonymous Sign-Ins.
