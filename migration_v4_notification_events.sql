-- =============================================================
-- Gimme — v4 migration: In-app Notification Events Inbox
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- Adds: notification_events table, updates notify_reservation()
--       trigger to insert an event row alongside the push.
-- =============================================================

-- 1. Create the notification_events table
create table if not exists public.notification_events (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references auth.users(id) on delete cascade,
  list_id     uuid not null references public.wish_lists(id) on delete cascade,
  item_id     uuid not null references public.wish_items(id) on delete cascade,
  list_name   text not null,
  item_title  text not null,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

alter table public.notification_events enable row level security;

-- Owners can only see and update their own events
create policy "Users manage own notification events"
  on public.notification_events for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Useful index for the inbox query (owner ordered by time)
create index if not exists notification_events_owner_created
  on public.notification_events (owner_id, created_at desc);

-- 2. Update notify_reservation() to also write the in-app event row.
--    The INSERT happens synchronously inside the trigger (guaranteed),
--    so the inbox shows an event even if the push delivery fails later.
create or replace function public.notify_reservation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url         text;
  v_service_key text;
  v_list_name   text;
begin
  -- Only fire when is_reserved_by_friend transitions false → true
  if NEW.is_reserved_by_friend = true
     and (OLD.is_reserved_by_friend is distinct from true) then

    -- Look up list name once for both the event row and the push body
    select name into v_list_name
      from public.wish_lists
     where id = NEW.list_id;

    -- ── In-app inbox event ────────────────────────────────────────
    insert into public.notification_events
      (owner_id, list_id, item_id, list_name, item_title)
    values
      (NEW.owner_id, NEW.list_id, NEW.id,
       coalesce(v_list_name, 'your list'), NEW.title);

    -- ── Push notification via Edge Function ───────────────────────
    v_url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url' limit 1);
    if v_url is null then
      v_url := 'https://dyporggvmfyzejopaezc.supabase.co';
    end if;

    v_service_key := (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key' limit 1);
    if v_service_key is null then
      v_service_key := current_setting('request.headers', true)::json->>'authorization';
    end if;

    perform net.http_post(
      url     := v_url || '/functions/v1/send-reservation-notification',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || coalesce(v_service_key, '')
      ),
      body    := jsonb_build_object(
        'item_id',          NEW.id,
        'item_title',       NEW.title,
        'owner_id',         NEW.owner_id,
        'reserved_by_name', NEW.reserved_by_name,
        'list_id',          NEW.list_id,
        'list_name',        coalesce(v_list_name, 'your list')
      )
    );
  end if;

  return NEW;
end;
$$;
