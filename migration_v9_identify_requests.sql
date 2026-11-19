-- =============================================================
-- Gimme — v9: photo identification (snap-to-add V0)
-- Run this in: Supabase Dashboard → SQL Editor → New query
--
-- ai_identify_requests keeps one row per identify-product call: who asked,
-- when, the outcome and the token counts. No photos and no results are
-- stored. The Edge Function (service role) is the only writer; users can
-- read their own rows.
--
-- claim_identify_slot() checks the caller's monthly quota and a global
-- 24-hour cap in one transaction, then records a pending request. Failed
-- calls are marked 'failed' afterwards and stop counting against the quota.
-- Like notify_reservation() in v8, it is kept off the REST API for anon and
-- authenticated users: only the service role may execute it.
--
-- Safe to re-run.
-- =============================================================

create table if not exists public.ai_identify_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  created_at    timestamptz not null default now(),
  status        text not null default 'pending'
                check (status in ('pending', 'ok', 'not_product', 'refused', 'failed')),
  result_status text,
  model         text,
  input_tokens  integer,
  output_tokens integer,
  latency_ms    integer
);

create index if not exists ai_identify_requests_user_created_idx
  on public.ai_identify_requests (user_id, created_at desc);

create index if not exists ai_identify_requests_created_idx
  on public.ai_identify_requests (created_at desc);

alter table public.ai_identify_requests enable row level security;

drop policy if exists "ai_identify_requests_select_own" on public.ai_identify_requests;
create policy "ai_identify_requests_select_own" on public.ai_identify_requests
  for select using ((select auth.uid()) = user_id);

create or replace function public.claim_identify_slot(
  p_user_id            uuid,
  p_monthly_limit      integer,
  p_global_daily_limit integer
)
returns table (allowed boolean, request_id uuid, used integer, reason text)
language plpgsql
set search_path = ''
as $$
declare
  v_used   integer;
  v_global integer;
  v_id     uuid;
begin
  -- One claim at a time per user, so parallel requests can't overshoot the quota.
  perform pg_advisory_xact_lock(hashtextextended('identify:' || p_user_id::text, 0));

  select count(*)::integer into v_used
  from public.ai_identify_requests r
  where r.user_id = p_user_id
    and r.status <> 'failed'
    and r.created_at >= date_trunc('month', now() at time zone 'utc') at time zone 'utc';

  if v_used >= p_monthly_limit then
    return query select false, null::uuid, v_used, 'monthly_limit'::text;
    return;
  end if;

  select count(*)::integer into v_global
  from public.ai_identify_requests r
  where r.status <> 'failed'
    and r.created_at >= now() - interval '24 hours';

  if v_global >= p_global_daily_limit then
    return query select false, null::uuid, v_used, 'global_limit'::text;
    return;
  end if;

  insert into public.ai_identify_requests (user_id)
  values (p_user_id)
  returning id into v_id;

  return query select true, v_id, v_used + 1, 'ok'::text;
end;
$$;

revoke execute on function public.claim_identify_slot(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.claim_identify_slot(uuid, integer, integer) to service_role;
