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
-- copy can tell "gone" from "not yet pulled".
-- =============================================================

create table if not exists public.deleted_records (
  id          uuid        not null,
  entity      text        not null check (entity in ('wish_list', 'wish_item')),
  owner_id    uuid        not null references auth.users(id) on delete cascade,
  deleted_at  timestamptz not null default now(),
  primary key (entity, id)
);

-- Row Level Security: a user sees and writes only their own tombstones.
alter table public.deleted_records enable row level security;

drop policy if exists "Users manage their own deletions" on public.deleted_records;
create policy "Users manage their own deletions"
  on public.deleted_records for all
  using      (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Clients pull with `owner_id = me and deleted_at > last_sync`.
create index if not exists deleted_records_owner_deleted_at_idx
  on public.deleted_records (owner_id, deleted_at);

-- Optional housekeeping: tombstones only need to outlive the slowest device's
-- sync gap. The client keeps its own for 90 days; matching that server-side is
-- safe once every device has synced at least once inside the window.
--
--   delete from public.deleted_records where deleted_at < now() - interval '90 days';
