-- Adds verified professor applications, profile badge fields, and private proof storage.
-- Run this in the Supabase SQL editor.

alter table public.profiles
  add column if not exists is_verified_professor boolean not null default false,
  add column if not exists professor_institution text,
  add column if not exists professor_position text,
  add column if not exists professor_department text,
  add column if not exists professor_verified_at timestamptz,
  add column if not exists professor_verified_by uuid references auth.users(id);

create table if not exists public.professor_verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  legal_name text not null check (char_length(btrim(legal_name)) between 2 and 160),
  institution text not null check (char_length(btrim(institution)) between 2 and 180),
  institutional_email text not null check (
    position('@' in institutional_email) > 1
    and position('.' in split_part(institutional_email, '@', 2)) > 1
  ),
  academic_position text not null check (char_length(btrim(academic_position)) between 2 and 120),
  department text not null check (char_length(btrim(department)) between 2 and 160),
  proof_type text not null,
  proof_file_path text not null,
  notes text check (notes is null or char_length(notes) <= 600),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  admin_notes text check (admin_notes is null or char_length(admin_notes) <= 600),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists professor_verification_requests_user_id_idx
  on public.professor_verification_requests(user_id);

create index if not exists professor_verification_requests_status_created_idx
  on public.professor_verification_requests(status, created_at);

alter table public.professor_verification_requests enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'professor_verification_requests'
      and policyname = 'Users can read their own professor verification requests'
  ) then
    create policy "Users can read their own professor verification requests"
      on public.professor_verification_requests
      for select
      using (
        auth.uid() = user_id
        or (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'professor_verification_requests'
      and policyname = 'Users can submit professor verification requests'
  ) then
    create policy "Users can submit professor verification requests"
      on public.professor_verification_requests
      for insert
      with check (auth.uid() = user_id and status = 'pending');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'professor_verification_requests'
      and policyname = 'Admins can review professor verification requests'
  ) then
    create policy "Admins can review professor verification requests"
      on public.professor_verification_requests
      for update
      using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
      with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'Admins can update professor verification fields'
  ) then
    create policy "Admins can update professor verification fields"
      on public.profiles
      for update
      using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
      with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
  end if;
end $$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'professor-verification-proofs',
  'professor-verification-proofs',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can upload professor verification proofs'
  ) then
    create policy "Users can upload professor verification proofs"
      on storage.objects
      for insert
      with check (
        bucket_id = 'professor-verification-proofs'
        and auth.uid()::text = (storage.foldername(name))[1]
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can read their own professor verification proofs'
  ) then
    create policy "Users can read their own professor verification proofs"
      on storage.objects
      for select
      using (
        bucket_id = 'professor-verification-proofs'
        and auth.uid()::text = (storage.foldername(name))[1]
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Admins can read professor verification proofs'
  ) then
    create policy "Admins can read professor verification proofs"
      on storage.objects
      for select
      using (
        bucket_id = 'professor-verification-proofs'
        and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
      );
  end if;
end $$;
