-- =============================================================
-- Gimme — v11: signed-out free try for photo identification
-- Run this in: Supabase Dashboard → SQL Editor → New query
--
-- A signed-out user may identify one photo per device; Apple DeviceCheck
-- remembers which devices used it, so nothing here identifies the device.
-- Those requests are logged in ai_identify_requests (v9) with no user and
-- is_trial = true, so they count toward the global 24-hour cap.
--
-- claim_identify_trial_slot() first refuses while too many free tries are
-- running. DeviceCheck can't test-and-set atomically, so a burst of parallel
-- requests from one device could otherwise all spend the same try; this caps
-- such a burst at a few. It then applies a 24-hour cap on free tries across
-- all devices and the global cap, and records a pending request. Service role
-- only, like claim_identify_slot.
--
-- The 24-hour caps also count failed calls the model was billed for (output
-- tokens recorded), so unusable results can't run past them. A user's monthly
-- quota still ignores failed calls; claim_identify_slot is replaced below only
-- to change how the global cap counts.
--
-- Safe to re-run.
-- =============================================================

alter table public.ai_identify_requests alter column user_id drop not null;

alter table public.ai_identify_requests
  add column if not exists is_trial boolean not null default false;

-- Every row is either a signed-in user's request or an anonymous free try.
alter table public.ai_identify_requests drop constraint if exists ai_identify_requests_caller_check;
alter table public.ai_identify_requests
  add constraint ai_identify_requests_caller_check check ((user_id is not null) <> is_trial);

create index if not exists ai_identify_requests_trial_created_idx
  on public.ai_identify_requests (created_at desc) where is_trial;

create or replace function public.claim_identify_trial_slot(
  p_trial_daily_limit  integer,
  p_global_daily_limit integer
)
returns table (allowed boolean, request_id uuid, used integer, reason text)
language plpgsql
set search_path = ''
as $$
declare
  -- Free tries allowed to run at once, across all devices.
  c_max_in_flight constant integer := 3;
  v_in_flight integer;
  v_trials    integer;
  v_global    integer;
  v_id        uuid;
begin
  -- One trial claim at a time, so parallel requests can't overshoot the caps.
  perform pg_advisory_xact_lock(hashtextextended('identify:trial', 0));

  select count(*)::integer into v_trials
  from public.ai_identify_requests r
  where r.is_trial
    and (r.status <> 'failed' or coalesce(r.output_tokens, 0) > 0)
    and r.created_at >= now() - interval '24 hours';

  -- A request still pending after three minutes was abandoned (the function's
  -- own timeouts end a request within two), so it no longer holds a place.
  select count(*)::integer into v_in_flight
  from public.ai_identify_requests r
  where r.is_trial
    and r.status = 'pending'
    and r.created_at >= now() - interval '3 minutes';

  if v_in_flight >= c_max_in_flight then
    return query select false, null::uuid, v_trials, 'in_flight'::text;
    return;
  end if;

  if v_trials >= p_trial_daily_limit then
    return query select false, null::uuid, v_trials, 'trial_limit'::text;
    return;
  end if;

  select count(*)::integer into v_global
  from public.ai_identify_requests r
  where (r.status <> 'failed' or coalesce(r.output_tokens, 0) > 0)
    and r.created_at >= now() - interval '24 hours';

  if v_global >= p_global_daily_limit then
    return query select false, null::uuid, v_trials, 'global_limit'::text;
    return;
  end if;

  insert into public.ai_identify_requests (user_id, is_trial)
  values (null, true)
  returning id into v_id;

  return query select true, v_id, v_trials + 1, 'ok'::text;
end;
$$;

revoke execute on function public.claim_identify_trial_slot(integer, integer) from public, anon, authenticated;
grant execute on function public.claim_identify_trial_slot(integer, integer) to service_role;

-- Same as v9, except that the global cap also counts billed failures.
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
  where (r.status <> 'failed' or coalesce(r.output_tokens, 0) > 0)
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
