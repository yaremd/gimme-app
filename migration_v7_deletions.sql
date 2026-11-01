-- =============================================================
-- Gimme — v7: deletion tombstones
-- Run this in: Supabase Dashboard → SQL Editor → New query
--
-- Sync reconciles by copying every unmatched row to the other side, in both
-- directions: a local row the server lacks is pushed up, a server row the
-- device lacks is pulled down. That makes a deleted record indistinguishable
-- from one the other side simply hasn't seen yet, so whichever copy outlives
-- the delete recreates the other and the record comes back.
--
-- This table records the deletions themselves, so a device that still holds a
-- copy can tell "gone" from "not yet pulled". The database keeps it, not the
-- app: a trigger writes the tombstone in the same transaction as the DELETE,
-- and another refuses any write that would bring a tombstoned row back. That
-- holds for every client, including builds that predate this migration and
-- have no idea tombstones exist.
--
-- Safe to re-run.
-- =============================================================

create table if not exists public.deleted_records (
  id          uuid        not null,
  entity      text        not null check (entity in ('wish_list', 'wish_item')),
  owner_id    uuid        not null references auth.users(id) on delete cascade,
  -- Server clock only. Clients pull with `deleted_at > cursor`, where the
  -- cursor is a deleted_at they were handed — never their own clock.
  deleted_at  timestamptz not null default now(),
  primary key (entity, id)
);

-- Clients pull with `owner_id = me and deleted_at > cursor`.
create index if not exists deleted_records_owner_deleted_at_idx
  on public.deleted_records (owner_id, deleted_at);

-- Row Level Security: a user reads only their own tombstones. Nobody writes
-- them directly; the triggers below do, as the table owner.
alter table public.deleted_records enable row level security;

drop policy if exists "Users manage their own deletions" on public.deleted_records;
drop policy if exists "Users read their own deletions"   on public.deleted_records;
create policy "Users read their own deletions"
  on public.deleted_records for select
  using (auth.uid() = owner_id);

-- ── Record a tombstone whenever a list or item row is deleted ──────────────
-- Fires for cascades too, so deleting a list tombstones every item in it.

create or replace function public.record_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- The whole account is being deleted (auth.users cascades into these
  -- tables): there is nobody left to tell, and the owner row is already gone,
  -- so the insert would violate the owner_id foreign key and abort the
  -- account deletion.
  if not exists (select 1 from auth.users where id = old.owner_id) then
    return old;
  end if;

  insert into public.deleted_records (id, entity, owner_id, deleted_at)
  values (old.id, tg_argv[0], old.owner_id, now())
  on conflict (entity, id) do update set deleted_at = excluded.deleted_at;

  return old;
end;
$$;

drop trigger if exists wish_lists_record_deletion on public.wish_lists;
create trigger wish_lists_record_deletion
  after delete on public.wish_lists
  for each row execute function public.record_deletion('wish_list');

drop trigger if exists wish_items_record_deletion on public.wish_items;
create trigger wish_items_record_deletion
  after delete on public.wish_items
  for each row execute function public.record_deletion('wish_item');

-- ── Refuse writes that would resurrect a deleted row ───────────────────────
-- An upsert can reach the server after the DELETE it raced with: a push that
-- was already in flight, a full sync that read the row first, another device
-- that never heard about the deletion. Each such row is dropped silently
-- (returning NULL skips it) rather than raising, so one stale row can't fail
-- the batch upsert it arrived in and wedge sync for everything else.

create or replace function public.skip_deleted_list()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.deleted_records
    where entity = 'wish_list' and id = new.id
  ) then
    return null;
  end if;
  return new;
end;
$$;

create or replace function public.skip_deleted_item()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- An item in a deleted list counts as deleted too: its list_id foreign key
  -- would reject it anyway, and failing the whole batch is worse.
  if exists (
    select 1 from public.deleted_records
    where (entity = 'wish_item' and id = new.id)
       or (entity = 'wish_list' and id = new.list_id)
  ) then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists wish_lists_skip_deleted on public.wish_lists;
create trigger wish_lists_skip_deleted
  before insert or update on public.wish_lists
  for each row execute function public.skip_deleted_list();

drop trigger if exists wish_items_skip_deleted on public.wish_items;
create trigger wish_items_skip_deleted
  before insert or update on public.wish_items
  for each row execute function public.skip_deleted_item();

-- Trigger-only: keep them off the REST API's /rpc surface. EXECUTE is checked
-- when a trigger is created, not when it fires, so the triggers keep working.
revoke execute on function public.record_deletion()   from public, anon, authenticated;
revoke execute on function public.skip_deleted_list() from public, anon, authenticated;
revoke execute on function public.skip_deleted_item() from public, anon, authenticated;

-- Optional housekeeping: tombstones only need to outlive the slowest device's
-- sync gap. The client keeps its own for 90 days; matching that server-side is
-- safe once every device has synced at least once inside the window.
--
--   delete from public.deleted_records where deleted_at < now() - interval '90 days';
