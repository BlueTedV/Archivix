-- ArchivIX — follows_setup.sql
-- Run this in the Supabase SQL editor.
-- Creates the user-follows-user table with RLS policies.

create extension if not exists pgcrypto;

-- ─── Table ───────────────────────────────────────────────────────────────────

create table if not exists public.user_follows (
  id          uuid primary key default gen_random_uuid(),
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default timezone('utc', now()),

  -- A user cannot follow the same person twice.
  constraint user_follows_unique unique (follower_id, following_id),
  -- A user cannot follow themselves.
  constraint user_follows_no_self_follow check (follower_id <> following_id)
);

-- ─── Indexes ─────────────────────────────────────────────────────────────────

create index if not exists idx_user_follows_follower_id
  on public.user_follows (follower_id);

create index if not exists idx_user_follows_following_id
  on public.user_follows (following_id);

-- ─── RLS ─────────────────────────────────────────────────────────────────────

alter table public.user_follows enable row level security;

-- Anyone can see who follows whom (public social graph).
drop policy if exists "user_follows_read_all" on public.user_follows;
create policy "user_follows_read_all"
on public.user_follows
for select
using (true);

-- Authenticated users can follow others.
drop policy if exists "user_follows_insert_own" on public.user_follows;
create policy "user_follows_insert_own"
on public.user_follows
for insert
to authenticated
with check (auth.uid() = follower_id);

-- Users can only unfollow (delete) their own follow rows.
drop policy if exists "user_follows_delete_own" on public.user_follows;
create policy "user_follows_delete_own"
on public.user_follows
for delete
to authenticated
using (auth.uid() = follower_id);

-- ─── Helper functions ─────────────────────────────────────────────────────────

-- Returns the follower count for a given user.
create or replace function public.get_follower_count(target_user_id uuid)
returns bigint
language sql
stable
set search_path = public
as $$
  select count(*) from public.user_follows where following_id = target_user_id;
$$;

-- Returns the following count for a given user.
create or replace function public.get_following_count(target_user_id uuid)
returns bigint
language sql
stable
set search_path = public
as $$
  select count(*) from public.user_follows where follower_id = target_user_id;
$$;

grant execute on function public.get_follower_count(uuid) to anon, authenticated;
grant execute on function public.get_following_count(uuid) to anon, authenticated;
