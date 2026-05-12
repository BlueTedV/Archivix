-- ArchivIX — notifications_setup.sql
-- Run this in the Supabase SQL editor AFTER follows_setup.sql.
-- Creates the notifications table, notification preferences table,
-- and the database triggers that fire notifications automatically.

create extension if not exists pgcrypto;

-- ─── Notification types ───────────────────────────────────────────────────────
-- paper_approved      — admin published the user's paper
-- paper_rejected      — admin rejected the user's paper
-- post_comment        — someone commented on the user's post/paper
-- content_liked       — someone liked the user's content
-- milestone_views     — content reached a view milestone (100, 500, 1000, …)
-- new_follower        — someone followed the user
-- following_upload    — a user the current user follows uploaded new content

-- ─── Notifications table ─────────────────────────────────────────────────────

create table if not exists public.notifications (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  type          text not null,
  title         text not null,
  body          text not null default '',
  -- Optional deep-link data so the app can navigate to the relevant content.
  data          jsonb not null default '{}'::jsonb,
  is_read       boolean not null default false,
  created_at    timestamptz not null default timezone('utc', now()),

  constraint notifications_type_check check (
    type in (
      'paper_approved',
      'paper_rejected',
      'post_comment',
      'content_liked',
      'milestone_views',
      'new_follower',
      'following_upload'
    )
  )
);

create index if not exists idx_notifications_user_id_created_at
  on public.notifications (user_id, created_at desc);

create index if not exists idx_notifications_user_id_is_read
  on public.notifications (user_id, is_read)
  where is_read = false;

-- ─── Notification preferences table ─────────────────────────────────────────

create table if not exists public.notification_preferences (
  user_id               uuid primary key references auth.users(id) on delete cascade,
  paper_approved        boolean not null default true,
  paper_rejected        boolean not null default true,
  post_comment          boolean not null default true,
  content_liked         boolean not null default true,
  milestone_views       boolean not null default true,
  new_follower          boolean not null default true,
  following_upload      boolean not null default true,
  updated_at            timestamptz not null default timezone('utc', now())
);

-- Auto-create a default preferences row when a new user signs up.
create or replace function public.handle_new_user_notification_prefs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_notification_prefs on auth.users;
create trigger on_auth_user_created_notification_prefs
after insert on auth.users
for each row
execute function public.handle_new_user_notification_prefs();

-- Back-fill preferences for existing users.
insert into public.notification_preferences (user_id)
select id from auth.users
on conflict (user_id) do nothing;

-- ─── RLS — notifications ─────────────────────────────────────────────────────

alter table public.notifications enable row level security;

drop policy if exists "notifications_read_own" on public.notifications;
create policy "notifications_read_own"
on public.notifications
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
on public.notifications
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own"
on public.notifications
for delete
to authenticated
using (auth.uid() = user_id);

-- Service-role inserts are used by triggers (security definer functions bypass RLS).

-- ─── RLS — notification_preferences ─────────────────────────────────────────

alter table public.notification_preferences enable row level security;

drop policy if exists "notification_prefs_read_own" on public.notification_preferences;
create policy "notification_prefs_read_own"
on public.notification_preferences
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "notification_prefs_upsert_own" on public.notification_preferences;
create policy "notification_prefs_upsert_own"
on public.notification_preferences
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- ─── Helper: insert notification if user has that type enabled ────────────────

create or replace function public.insert_notification_if_enabled(
  p_user_id   uuid,
  p_type      text,
  p_title     text,
  p_body      text,
  p_data      jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enabled boolean;
  v_col     text;
begin
  -- Map notification type to the preferences column name.
  v_col := p_type;

  execute format(
    'select coalesce(%I, true) from public.notification_preferences where user_id = $1',
    v_col
  )
  into v_enabled
  using p_user_id;

  -- Default to enabled if no preferences row exists yet.
  if v_enabled is null then
    v_enabled := true;
  end if;

  if v_enabled then
    insert into public.notifications (user_id, type, title, body, data)
    values (p_user_id, p_type, p_title, p_body, p_data);
  end if;
end;
$$;

-- ─── Trigger: paper status change → paper_approved / paper_rejected ──────────

create or replace function public.notify_paper_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Only fire when status actually changes.
  if new.status = old.status then
    return new;
  end if;

  if new.status = 'published' then
    perform public.insert_notification_if_enabled(
      new.user_id,
      'paper_approved',
      'Document Published',
      'Your document "' || left(new.title, 80) || '" is now live.',
      jsonb_build_object('paper_id', new.id, 'title', new.title)
    );
  elsif new.status = 'rejected' then
    perform public.insert_notification_if_enabled(
      new.user_id,
      'paper_rejected',
      'Document Needs Changes',
      'Your document "' || left(new.title, 80) || '" was returned with feedback.',
      jsonb_build_object(
        'paper_id', new.id,
        'title', new.title,
        'rejection_reason', coalesce(new.rejection_reason, '')
      )
    );
  end if;

  return new;
end;
$$;

drop trigger if exists notify_on_paper_status_change on public.papers;
create trigger notify_on_paper_status_change
after update on public.papers
for each row
execute function public.notify_paper_status_change();

-- ─── Trigger: new comment → post_comment ─────────────────────────────────────

create or replace function public.notify_new_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id  uuid;
  v_title     text;
  v_content_id uuid;
  v_content_type text;
begin
  -- Determine which content was commented on and who owns it.
  if new.paper_id is not null then
    select user_id, title
    into v_owner_id, v_title
    from public.papers
    where id = new.paper_id;
    v_content_id := new.paper_id;
    v_content_type := 'paper';
  elsif new.post_id is not null then
    select user_id, title
    into v_owner_id, v_title
    from public.posts
    where id = new.post_id;
    v_content_id := new.post_id;
    v_content_type := 'post';
  else
    return new;
  end if;

  -- Don't notify users when they comment on their own content.
  if v_owner_id is null or v_owner_id = new.user_id then
    return new;
  end if;

  perform public.insert_notification_if_enabled(
    v_owner_id,
    'post_comment',
    'New Comment',
    coalesce(new.author_label, 'Someone') || ' commented on "' || left(coalesce(v_title, 'your content'), 60) || '".',
    jsonb_build_object(
      'content_type', v_content_type,
      'content_id', v_content_id,
      'comment_id', new.id,
      'commenter_id', new.user_id
    )
  );

  return new;
end;
$$;

drop trigger if exists notify_on_new_comment on public.paper_comments;
create trigger notify_on_new_comment
after insert on public.paper_comments
for each row
execute function public.notify_new_comment();

-- ─── Trigger: new reaction → content_liked ───────────────────────────────────

create or replace function public.notify_new_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id  uuid;
  v_title     text;
  v_content_id uuid;
  v_content_type text;
begin
  -- Only notify for likes (reaction_value = 1), not dislikes.
  if new.reaction_value <> 1 then
    return new;
  end if;

  if new.paper_id is not null then
    select user_id, title
    into v_owner_id, v_title
    from public.papers
    where id = new.paper_id;
    v_content_id := new.paper_id;
    v_content_type := 'paper';
  elsif new.post_id is not null then
    select user_id, title
    into v_owner_id, v_title
    from public.posts
    where id = new.post_id;
    v_content_id := new.post_id;
    v_content_type := 'post';
  else
    return new;
  end if;

  -- Don't notify users when they like their own content.
  if v_owner_id is null or v_owner_id = new.user_id then
    return new;
  end if;

  perform public.insert_notification_if_enabled(
    v_owner_id,
    'content_liked',
    'Someone Liked Your Content',
    '"' || left(coalesce(v_title, 'Your content'), 60) || '" received a like.',
    jsonb_build_object(
      'content_type', v_content_type,
      'content_id', v_content_id,
      'liker_id', new.user_id
    )
  );

  return new;
end;
$$;

drop trigger if exists notify_on_new_reaction on public.post_reactions;
create trigger notify_on_new_reaction
after insert on public.post_reactions
for each row
execute function public.notify_new_reaction();

-- ─── Trigger: new follow → new_follower ──────────────────────────────────────

create or replace function public.notify_new_follower()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_follower_name text;
begin
  select coalesce(username, full_name, 'Someone')
  into v_follower_name
  from public.profiles
  where id = new.follower_id;

  perform public.insert_notification_if_enabled(
    new.following_id,
    'new_follower',
    'New Follower',
    coalesce(v_follower_name, 'Someone') || ' started following you.',
    jsonb_build_object('follower_id', new.follower_id)
  );

  return new;
end;
$$;

drop trigger if exists notify_on_new_follower on public.user_follows;
create trigger notify_on_new_follower
after insert on public.user_follows
for each row
execute function public.notify_new_follower();

-- ─── Trigger: new paper/post published → following_upload ────────────────────

create or replace function public.notify_followers_of_upload()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_follower record;
  v_content_type text;
  v_content_id   uuid;
begin
  -- For papers: only fire when status transitions to 'published'.
  if TG_TABLE_NAME = 'papers' then
    if new.status <> 'published' or old.status = 'published' then
      return new;
    end if;
    v_content_type := 'paper';
    v_content_id   := new.id;
  else
    -- For posts: fire on INSERT only (posts are always public).
    v_content_type := 'post';
    v_content_id   := new.id;
  end if;

  -- Notify every follower of the content owner.
  for v_follower in
    select follower_id
    from public.user_follows
    where following_id = new.user_id
  loop
    perform public.insert_notification_if_enabled(
      v_follower.follower_id,
      'following_upload',
      'New Upload from Someone You Follow',
      'A new ' || v_content_type || ' was posted: "' || left(new.title, 60) || '".',
      jsonb_build_object(
        'content_type', v_content_type,
        'content_id', v_content_id,
        'author_id', new.user_id,
        'title', new.title
      )
    );
  end loop;

  return new;
end;
$$;

-- Paper: fires when status changes to published.
drop trigger if exists notify_followers_on_paper_publish on public.papers;
create trigger notify_followers_on_paper_publish
after update on public.papers
for each row
execute function public.notify_followers_of_upload();

-- Post: fires on every new insert.
drop trigger if exists notify_followers_on_new_post on public.posts;
create trigger notify_followers_on_new_post
after insert on public.posts
for each row
execute function public.notify_followers_of_upload();

-- ─── View milestone function (called from Flutter, not a trigger) ─────────────
-- The app calls this RPC after incrementing views to check for milestones.

create or replace function public.check_and_notify_view_milestone(
  p_content_type text,  -- 'paper' or 'post'
  p_content_id   uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id  uuid;
  v_title     text;
  v_views     int;
  v_milestone int;
  v_milestones int[] := array[100, 500, 1000, 5000, 10000];
begin
  if p_content_type = 'paper' then
    select user_id, title, views_count
    into v_owner_id, v_title, v_views
    from public.papers
    where id = p_content_id;
  else
    select user_id, title, views_count
    into v_owner_id, v_title, v_views
    from public.posts
    where id = p_content_id;
  end if;

  if v_owner_id is null then return; end if;

  -- Check if the current view count exactly hits a milestone.
  foreach v_milestone in array v_milestones loop
    if v_views = v_milestone then
      perform public.insert_notification_if_enabled(
        v_owner_id,
        'milestone_views',
        v_milestone || ' Views!',
        '"' || left(coalesce(v_title, 'Your content'), 60) || '" just reached ' || v_milestone || ' views.',
        jsonb_build_object(
          'content_type', p_content_type,
          'content_id', p_content_id,
          'milestone', v_milestone
        )
      );
      exit; -- Only one milestone per view increment.
    end if;
  end loop;
end;
$$;

grant execute on function public.check_and_notify_view_milestone(text, uuid) to anon, authenticated;
