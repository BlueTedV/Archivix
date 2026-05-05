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

  create table if not exists public.post_reactions (
    id uuid primary key default gen_random_uuid(),
    post_id uuid references public.posts(id) on delete cascade,
    paper_id uuid references public.papers(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    reaction_value smallint not null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
  );

  alter table public.post_reactions
    add column if not exists paper_id uuid references public.papers(id) on delete cascade;

  alter table public.post_reactions
    add column if not exists post_id uuid references public.posts(id) on delete cascade;

  alter table public.post_reactions
    add column if not exists user_id uuid references auth.users(id) on delete cascade;

  alter table public.post_reactions
    add column if not exists reaction_value smallint;

  alter table public.post_reactions
    add column if not exists created_at timestamptz default timezone('utc', now());

  alter table public.post_reactions
    add column if not exists updated_at timestamptz default timezone('utc', now());

  alter table public.post_reactions
    alter column post_id drop not null;

  update public.post_reactions
  set created_at = timezone('utc', now())
  where created_at is null;

  update public.post_reactions
  set updated_at = timezone('utc', now())
  where updated_at is null;

  do $$
  begin
    if not exists (
      select 1
      from pg_constraint
      where conname = 'post_reactions_paper_id_fkey'
        and conrelid = 'public.post_reactions'::regclass
    ) then
      alter table public.post_reactions
        add constraint post_reactions_paper_id_fkey
        foreign key (paper_id) references public.papers(id) on delete cascade;
    end if;
  end
  $$;

  do $$
  begin
    if to_regclass('public.paper_reactions') is not null then
      execute $sql$
        insert into public.post_reactions (
          id,
          post_id,
          paper_id,
          user_id,
          reaction_value,
          created_at,
          updated_at
        )
        select
          pr.id,
          null,
          pr.paper_id,
          pr.user_id,
          pr.reaction_value,
          pr.created_at,
          pr.updated_at
        from public.paper_reactions pr
        where not exists (
          select 1
          from public.post_reactions unified
          where unified.id = pr.id
        )
      $sql$;
    end if;
  end
  $$;

  alter table public.post_reactions
    alter column user_id set not null;

  alter table public.post_reactions
    alter column reaction_value set not null;

  alter table public.post_reactions
    alter column created_at set not null;

  alter table public.post_reactions
    alter column updated_at set not null;

  alter table public.post_reactions
    drop constraint if exists post_reactions_reaction_value_check;

  alter table public.post_reactions
    add constraint post_reactions_reaction_value_check
    check (reaction_value in (-1, 1));

  alter table public.post_reactions
    drop constraint if exists post_reactions_target_check;

  alter table public.post_reactions
    add constraint post_reactions_target_check
    check (
      (case when post_id is null then 0 else 1 end) +
      (case when paper_id is null then 0 else 1 end) = 1
    );

  create index if not exists idx_post_reactions_post_id
    on public.post_reactions (post_id);

  create index if not exists idx_post_reactions_paper_id
    on public.post_reactions (paper_id);

  create index if not exists idx_post_reactions_user_id
    on public.post_reactions (user_id);

  create unique index if not exists idx_post_reactions_post_user_unique
    on public.post_reactions (post_id, user_id)
    where post_id is not null;

  create unique index if not exists idx_post_reactions_paper_user_unique
    on public.post_reactions (paper_id, user_id)
    where paper_id is not null;

  drop trigger if exists set_post_reactions_updated_at on public.post_reactions;
  create trigger set_post_reactions_updated_at
  before update on public.post_reactions
  for each row
  execute function public.set_updated_at();

  alter table public.post_reactions enable row level security;

  drop policy if exists "post_reactions_read_all" on public.post_reactions;
  drop policy if exists "post_reactions_manage_own" on public.post_reactions;

  create policy "post_reactions_read_all"
  on public.post_reactions
  for select
  using (true);

  create policy "post_reactions_manage_own"
  on public.post_reactions
  for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

  do $$
  begin
    if to_regclass('public.paper_reactions') is not null then
      execute 'drop policy if exists "paper_reactions_read_all" on public.paper_reactions';
      execute 'drop policy if exists "paper_reactions_manage_own" on public.paper_reactions';
      execute 'drop trigger if exists set_paper_reactions_updated_at on public.paper_reactions';
      execute 'drop table if exists public.paper_reactions cascade';
    end if;
  end
  $$;
