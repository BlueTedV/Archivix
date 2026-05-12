-- ArchivIX — collections_setup.sql
-- Run this in the Supabase SQL editor.
-- Creates the collections and collection_items tables with RLS policies.

create extension if not exists pgcrypto;

-- ─── Collections ─────────────────────────────────────────────────────────────

create table if not exists public.collections (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  description text,
  is_public   boolean not null default false,
  created_at  timestamptz not null default timezone('utc', now()),
  updated_at  timestamptz not null default timezone('utc', now()),

  constraint collections_name_length check (
    char_length(btrim(name)) >= 1 and char_length(name) <= 80
  ),
  constraint collections_description_length check (
    description is null or char_length(description) <= 300
  )
);

create index if not exists idx_collections_user_id
  on public.collections (user_id, created_at desc);

-- ─── Collection items ─────────────────────────────────────────────────────────

create table if not exists public.collection_items (
  id              uuid primary key default gen_random_uuid(),
  collection_id   uuid not null references public.collections(id) on delete cascade,
  content_type    text not null,
  content_id      uuid not null,
  added_at        timestamptz not null default timezone('utc', now()),

  constraint collection_items_content_type_check check (
    content_type in ('paper', 'post')
  ),
  -- A piece of content can only appear once per collection.
  constraint collection_items_unique unique (collection_id, content_type, content_id)
);

create index if not exists idx_collection_items_collection_id
  on public.collection_items (collection_id, added_at desc);

create index if not exists idx_collection_items_content
  on public.collection_items (content_type, content_id);

-- ─── updated_at trigger ───────────────────────────────────────────────────────

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_collections_updated_at on public.collections;
create trigger set_collections_updated_at
before update on public.collections
for each row
execute function public.set_updated_at();

-- ─── RLS — collections ───────────────────────────────────────────────────────

alter table public.collections enable row level security;

-- Public collections are visible to everyone; private ones only to their owner.
drop policy if exists "collections_read_visible" on public.collections;
create policy "collections_read_visible"
on public.collections
for select
using (
  is_public = true
  or auth.uid() = user_id
);

drop policy if exists "collections_insert_own" on public.collections;
create policy "collections_insert_own"
on public.collections
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "collections_update_own" on public.collections;
create policy "collections_update_own"
on public.collections
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "collections_delete_own" on public.collections;
create policy "collections_delete_own"
on public.collections
for delete
to authenticated
using (auth.uid() = user_id);

-- ─── RLS — collection_items ──────────────────────────────────────────────────

alter table public.collection_items enable row level security;

-- Items are visible if the parent collection is visible.
drop policy if exists "collection_items_read_visible" on public.collection_items;
create policy "collection_items_read_visible"
on public.collection_items
for select
using (
  exists (
    select 1
    from public.collections c
    where c.id = collection_items.collection_id
      and (c.is_public = true or c.user_id = auth.uid())
  )
);

-- Only the collection owner can add items.
drop policy if exists "collection_items_insert_owner" on public.collection_items;
create policy "collection_items_insert_owner"
on public.collection_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.collections c
    where c.id = collection_id
      and c.user_id = auth.uid()
  )
);

-- Only the collection owner can remove items.
drop policy if exists "collection_items_delete_owner" on public.collection_items;
create policy "collection_items_delete_owner"
on public.collection_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.collections c
    where c.id = collection_items.collection_id
      and c.user_id = auth.uid()
  )
);
