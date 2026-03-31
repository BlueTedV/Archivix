create extension if not exists pgcrypto;

create table if not exists public.paper_versions (
  id uuid primary key default gen_random_uuid(),
  paper_id uuid not null references public.papers(id) on delete cascade,
  version_number integer not null,
  title text not null,
  abstract text not null default '',
  category_id uuid null references public.categories(id) on delete set null,
  category_name text,
  pdf_url text,
  pdf_file_name text,
  pdf_file_size bigint,
  authors_snapshot jsonb not null default '[]'::jsonb,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  editor_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  unique (paper_id, version_number)
);

create table if not exists public.post_versions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  version_number integer not null,
  title text not null,
  content text not null default '',
  category_id uuid null references public.categories(id) on delete set null,
  category_name text,
  attachments_snapshot jsonb not null default '[]'::jsonb,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  editor_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  unique (post_id, version_number)
);

create index if not exists idx_paper_versions_paper_id
  on public.paper_versions (paper_id, version_number desc);

create index if not exists idx_post_versions_post_id
  on public.post_versions (post_id, version_number desc);

alter table public.paper_versions enable row level security;
alter table public.post_versions enable row level security;

drop policy if exists "paper_versions_read_all" on public.paper_versions;
create policy "paper_versions_read_all"
on public.paper_versions
for select
using (true);

drop policy if exists "paper_versions_insert_owner" on public.paper_versions;
create policy "paper_versions_insert_owner"
on public.paper_versions
for insert
to authenticated
with check (
  auth.uid() = editor_user_id
  and auth.uid() = owner_user_id
  and exists (
    select 1
    from public.papers p
    where p.id = paper_id
      and p.user_id = auth.uid()
  )
);

drop policy if exists "post_versions_read_all" on public.post_versions;
create policy "post_versions_read_all"
on public.post_versions
for select
using (true);

drop policy if exists "post_versions_insert_owner" on public.post_versions;
create policy "post_versions_insert_owner"
on public.post_versions
for insert
to authenticated
with check (
  auth.uid() = editor_user_id
  and auth.uid() = owner_user_id
  and exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.user_id = auth.uid()
  )
);

drop policy if exists "papers_pdf_read_authenticated" on storage.objects;
create policy "papers_pdf_read_authenticated"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'papers-pdf'
);

drop policy if exists "papers_pdf_insert_owner_folder" on storage.objects;
create policy "papers_pdf_insert_owner_folder"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'papers-pdf'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "papers_pdf_update_owner_folder" on storage.objects;
create policy "papers_pdf_update_owner_folder"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'papers-pdf'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'papers-pdf'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "papers_pdf_delete_owner_folder" on storage.objects;
create policy "papers_pdf_delete_owner_folder"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'papers-pdf'
  and (storage.foldername(name))[1] = auth.uid()::text
);
