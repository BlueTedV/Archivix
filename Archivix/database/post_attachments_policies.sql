alter table public.post_attachments enable row level security;

drop policy if exists "post_attachments_read_all" on public.post_attachments;
create policy "post_attachments_read_all"
on public.post_attachments
for select
using (true);

drop policy if exists "post_attachments_insert_owner" on public.post_attachments;
create policy "post_attachments_insert_owner"
on public.post_attachments
for insert
to authenticated
with check (
  exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.user_id = auth.uid()
  )
);

drop policy if exists "post_attachments_update_owner" on public.post_attachments;
create policy "post_attachments_update_owner"
on public.post_attachments
for update
to authenticated
using (
  exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.user_id = auth.uid()
  )
);

drop policy if exists "post_attachments_delete_owner" on public.post_attachments;
create policy "post_attachments_delete_owner"
on public.post_attachments
for delete
to authenticated
using (
  exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.user_id = auth.uid()
  )
);
