alter table public.papers
  add column if not exists submitted_at timestamptz,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid,
  add column if not exists rejection_reason text;

update public.papers
set status = 'published'
where status is null
   or btrim(status) = '';

update public.papers
set submitted_at = coalesce(submitted_at, created_at)
where status in ('submitted', 'under_review', 'published', 'rejected')
  and submitted_at is null;

update public.papers
set reviewed_at = coalesce(reviewed_at, published_at, created_at)
where status = 'published'
  and reviewed_at is null;

alter table public.papers
  alter column status set default 'draft';

alter table public.papers
  drop constraint if exists papers_status_check;

alter table public.papers
  add constraint papers_status_check
  check (status in ('draft', 'submitted', 'under_review', 'published', 'rejected'));

create index if not exists idx_papers_status_created_at
  on public.papers (status, created_at desc);

drop policy if exists "papers_admin_review_read" on public.papers;
create policy "papers_admin_review_read"
on public.papers
for select
to authenticated
using (
  coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
);

drop policy if exists "papers_admin_review_update" on public.papers;
create policy "papers_admin_review_update"
on public.papers
for update
to authenticated
using (
  coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
)
with check (
  coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
);
