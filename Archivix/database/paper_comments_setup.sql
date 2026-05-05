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
  paper_id uuid references public.papers(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  author_label text not null,
  body text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.paper_comments
  add column if not exists post_id uuid references public.posts(id) on delete cascade;

alter table public.paper_comments
  add column if not exists paper_id uuid references public.papers(id) on delete cascade;

alter table public.paper_comments
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.paper_comments
  add column if not exists author_label text;

alter table public.paper_comments
  add column if not exists body text;

alter table public.paper_comments
  add column if not exists created_at timestamptz default timezone('utc', now());

alter table public.paper_comments
  add column if not exists updated_at timestamptz default timezone('utc', now());

alter table public.paper_comments
  alter column paper_id drop not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'paper_comments_post_id_fkey'
      and conrelid = 'public.paper_comments'::regclass
  ) then
    alter table public.paper_comments
      add constraint paper_comments_post_id_fkey
      foreign key (post_id) references public.posts(id) on delete cascade;
  end if;
end
$$;

do $$
begin
  if to_regclass('public.post_comments') is not null then
    execute $sql$
      insert into public.paper_comments (
        id,
        paper_id,
        post_id,
        user_id,
        author_label,
        body,
        created_at,
        updated_at
      )
      select
        pc.id,
        null,
        pc.post_id,
        pc.user_id,
        pc.author_label,
        pc.body,
        pc.created_at,
        pc.updated_at
      from public.post_comments pc
      where not exists (
        select 1
        from public.paper_comments unified
        where unified.id = pc.id
      )
    $sql$;
  end if;
end
$$;

update public.paper_comments
set author_label = 'Researcher'
where author_label is null
   or char_length(btrim(author_label)) = 0;

update public.paper_comments
set body = 'Comment unavailable.'
where body is null
   or char_length(btrim(body)) = 0;

alter table public.paper_comments
  alter column user_id set not null;

alter table public.paper_comments
  alter column author_label set not null;

alter table public.paper_comments
  alter column body set not null;

alter table public.paper_comments
  drop constraint if exists paper_comments_body_check;

alter table public.paper_comments
  add constraint paper_comments_body_check
  check (
    char_length(btrim(body)) > 0
    and char_length(body) <= 2000
  );

alter table public.paper_comments
  drop constraint if exists paper_comments_target_check;

alter table public.paper_comments
  add constraint paper_comments_target_check
  check (
    (case when paper_id is null then 0 else 1 end) +
    (case when post_id is null then 0 else 1 end) = 1
  );

create index if not exists idx_paper_comments_paper_id_created_at
  on public.paper_comments (paper_id, created_at asc);

create index if not exists idx_paper_comments_post_id_created_at
  on public.paper_comments (post_id, created_at asc);

create index if not exists idx_paper_comments_user_id
  on public.paper_comments (user_id);

drop trigger if exists set_paper_comments_updated_at on public.paper_comments;
create trigger set_paper_comments_updated_at
before update on public.paper_comments
for each row
execute function public.set_updated_at();

alter table public.paper_comments enable row level security;

drop policy if exists "paper_comments_read_published" on public.paper_comments;
drop policy if exists "paper_comments_insert_own_on_published" on public.paper_comments;
drop policy if exists "paper_comments_read_visible" on public.paper_comments;
drop policy if exists "paper_comments_insert_own" on public.paper_comments;
drop policy if exists "paper_comments_update_own" on public.paper_comments;
drop policy if exists "paper_comments_delete_own" on public.paper_comments;

create policy "paper_comments_read_visible"
on public.paper_comments
for select
using (
  (
    paper_id is not null
    and exists (
      select 1
      from public.papers
      where papers.id = paper_comments.paper_id
        and papers.status = 'published'
    )
  )
  or (
    post_id is not null
    and exists (
      select 1
      from public.posts
      where posts.id = paper_comments.post_id
    )
  )
);

create policy "paper_comments_insert_own"
on public.paper_comments
for insert
to authenticated
with check (
  auth.uid() = user_id
  and (
    (
      paper_id is not null
      and post_id is null
      and exists (
        select 1
        from public.papers
        where papers.id = paper_comments.paper_id
          and papers.status = 'published'
      )
    )
    or (
      post_id is not null
      and paper_id is null
      and exists (
        select 1
        from public.posts
        where posts.id = paper_comments.post_id
      )
    )
  )
);

create policy "paper_comments_update_own"
on public.paper_comments
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "paper_comments_delete_own"
on public.paper_comments
for delete
to authenticated
using (auth.uid() = user_id);

do $$
begin
  if to_regclass('public.post_comments') is not null then
    execute 'drop policy if exists "post_comments_read_all" on public.post_comments';
    execute 'drop policy if exists "post_comments_insert_own" on public.post_comments';
    execute 'drop policy if exists "post_comments_update_own" on public.post_comments';
    execute 'drop policy if exists "post_comments_delete_own" on public.post_comments';
    execute 'drop trigger if exists set_post_comments_updated_at on public.post_comments';
    execute 'drop table if exists public.post_comments cascade';
  end if;
end
$$;
