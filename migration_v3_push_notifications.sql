-- =============================================================
-- Gimme — v3 migration: Push Notifications for Reservations
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- Adds: device_tokens table, pg_net extension,
--       notify_reservation trigger on wish_items
-- =============================================================

-- 1. Device tokens table
create table if not exists public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  token       text not null,
  platform    text not null default 'ios',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique(user_id, token)
);

alter table public.device_tokens enable row level security;

-- Users can only manage their own tokens
create policy "Users manage own device tokens"
  on public.device_tokens for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 2. Enable pg_net for async HTTP calls from triggers
create extension if not exists pg_net with schema extensions;

-- 3. Trigger function: called when an item is reserved
--    Sends item + owner info to the Edge Function via pg_net
create or replace function public.notify_reservation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_service_key text;
  v_list_name text;
begin
  -- Only fire when is_reserved_by_friend transitions false → true
  if NEW.is_reserved_by_friend = true
     and (OLD.is_reserved_by_friend is distinct from true) then

    -- Look up list name for the notification body
    select name into v_list_name
      from public.wish_lists
     where id = NEW.list_id;

    -- Build Edge Function URL
    v_url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url' limit 1);
    if v_url is null then
      v_url := 'https://dyporggvmfyzejopaezc.supabase.co';
    end if;

    v_service_key := (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key' limit 1);
    if v_service_key is null then
      v_service_key := current_setting('request.headers', true)::json->>'authorization';
    end if;

    -- Fire-and-forget HTTP POST to the Edge Function
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
        'list_name',        coalesce(v_list_name, 'your')
      )
    );
  end if;

  return NEW;
end;
$$;

-- 4. Attach trigger to wish_items
drop trigger if exists on_item_reserved on public.wish_items;
create trigger on_item_reserved
  after update on public.wish_items
  for each row
  execute function public.notify_reservation();
