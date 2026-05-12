-- Adds nested comment replies and per-comment like/dislike reactions.
-- Run this in the Supabase SQL editor for existing Archivix projects.

alter table public.paper_comments
  add column if not exists parent_comment_id uuid;

do $$
begin
  alter table public.paper_comments
    add constraint paper_comments_parent_comment_id_fkey
    foreign key (parent_comment_id)
    references public.paper_comments(id)
    on delete cascade;
exception
  when duplicate_object then null;
end $$;

create index if not exists paper_comments_parent_comment_id_idx
  on public.paper_comments(parent_comment_id);

create index if not exists paper_comments_paper_parent_created_idx
  on public.paper_comments(paper_id, parent_comment_id, created_at);

create index if not exists paper_comments_post_parent_created_idx
  on public.paper_comments(post_id, parent_comment_id, created_at);

create table if not exists public.comment_reactions (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null
    references public.paper_comments(id)
    on delete cascade,
  user_id uuid not null
    references auth.users(id)
    on delete cascade,
  reaction_value smallint not null
    check (reaction_value in (-1, 1)),
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now()),
  unique (comment_id, user_id)
);

create index if not exists comment_reactions_comment_id_idx
  on public.comment_reactions(comment_id);

create index if not exists comment_reactions_user_id_idx
  on public.comment_reactions(user_id);

alter table public.comment_reactions enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'comment_reactions'
      and policyname = 'Anyone can read comment reactions'
  ) then
    create policy "Anyone can read comment reactions"
      on public.comment_reactions
      for select
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'comment_reactions'
      and policyname = 'Users can add their own comment reactions'
  ) then
    create policy "Users can add their own comment reactions"
      on public.comment_reactions
      for insert
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'comment_reactions'
      and policyname = 'Users can update their own comment reactions'
  ) then
    create policy "Users can update their own comment reactions"
      on public.comment_reactions
      for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'comment_reactions'
      and policyname = 'Users can delete their own comment reactions'
  ) then
    create policy "Users can delete their own comment reactions"
      on public.comment_reactions
      for delete
      using (auth.uid() = user_id);
  end if;
end $$;
