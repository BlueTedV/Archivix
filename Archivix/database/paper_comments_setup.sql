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

create table if not exists public.paper_comments (
  id uuid primary key default gen_random_uuid(),
  paper_id uuid not null references public.papers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  author_label text not null,
  body text not null check (char_length(btrim(body)) > 0 and char_length(body) <= 2000),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_paper_comments_paper_id_created_at
  on public.paper_comments (paper_id, created_at asc);

create index if not exists idx_paper_comments_user_id
  on public.paper_comments (user_id);

drop trigger if exists set_paper_comments_updated_at on public.paper_comments;
create trigger set_paper_comments_updated_at
before update on public.paper_comments
for each row
execute function public.set_updated_at();

alter table public.paper_comments enable row level security;

drop policy if exists "paper_comments_read_published" on public.paper_comments;
create policy "paper_comments_read_published"
on public.paper_comments
for select
using (
  exists (
    select 1
    from public.papers
    where papers.id = paper_comments.paper_id
      and papers.status = 'published'
  )
);

drop policy if exists "paper_comments_insert_own_on_published" on public.paper_comments;
create policy "paper_comments_insert_own_on_published"
on public.paper_comments
for insert
to authenticated
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.papers
    where papers.id = paper_comments.paper_id
      and papers.status = 'published'
  )
);

drop policy if exists "paper_comments_update_own" on public.paper_comments;
create policy "paper_comments_update_own"
on public.paper_comments
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "paper_comments_delete_own" on public.paper_comments;
create policy "paper_comments_delete_own"
on public.paper_comments
for delete
to authenticated
using (auth.uid() = user_id);
