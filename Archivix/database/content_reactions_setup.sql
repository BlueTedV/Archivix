create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.paper_reactions (
  id uuid primary key default gen_random_uuid(),
  paper_id uuid not null references public.papers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction_value smallint not null check (reaction_value in (-1, 1)),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (paper_id, user_id)
);

create table if not exists public.post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction_value smallint not null check (reaction_value in (-1, 1)),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (post_id, user_id)
);

create index if not exists idx_paper_reactions_paper_id
  on public.paper_reactions (paper_id);

create index if not exists idx_paper_reactions_user_id
  on public.paper_reactions (user_id);

create index if not exists idx_post_reactions_post_id
  on public.post_reactions (post_id);

create index if not exists idx_post_reactions_user_id
  on public.post_reactions (user_id);

drop trigger if exists set_paper_reactions_updated_at on public.paper_reactions;
create trigger set_paper_reactions_updated_at
before update on public.paper_reactions
for each row
execute function public.set_updated_at();

drop trigger if exists set_post_reactions_updated_at on public.post_reactions;
create trigger set_post_reactions_updated_at
before update on public.post_reactions
for each row
execute function public.set_updated_at();

alter table public.paper_reactions enable row level security;
alter table public.post_reactions enable row level security;

drop policy if exists "paper_reactions_read_all" on public.paper_reactions;
create policy "paper_reactions_read_all"
on public.paper_reactions
for select
using (true);

drop policy if exists "paper_reactions_manage_own" on public.paper_reactions;
create policy "paper_reactions_manage_own"
on public.paper_reactions
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "post_reactions_read_all" on public.post_reactions;
create policy "post_reactions_read_all"
on public.post_reactions
for select
using (true);

drop policy if exists "post_reactions_manage_own" on public.post_reactions;
create policy "post_reactions_manage_own"
on public.post_reactions
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
