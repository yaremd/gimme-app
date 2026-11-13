-- =============================================================
-- Gimme — v10: Pro comes from verified App Store purchases only
-- Run this in: Supabase Dashboard → SQL Editor → New query
--
-- v6 let every signed-in user insert and update their own profiles row, and
-- the app grants Pro whenever profiles.is_pro is true. So one request —
-- PATCH /rest/v1/profiles?id=eq.<uid> {"is_pro": true}, sent with the user's
-- own token — unlocked the lifetime purchase for free on every device, and
-- identify-product (snap-to-add) trusts the same flag for its Pro quota.
--
-- From here on:
--   * clients can still read their own profile but can no longer write it;
--   * the verify-purchase Edge Function checks Apple's signature on a
--     StoreKit 2 transaction and, as the service role, calls
--     record_pro_transaction(), which stores the purchase in pro_purchases
--     and recomputes is_pro from the account's purchases;
--   * one App Store purchase belongs to one Gimme account: the first account
--     to present it keeps it until that account is deleted;
--   * the newest statement Apple signed about a purchase wins, so replaying
--     the original purchase JWS can't undo a refund or revocation.
--
-- Apply this before deploying verify-purchase, which calls
-- record_pro_transaction(). App builds older than the one that calls
-- verify-purchase keep Pro on the purchasing device (StoreKit), but their
-- direct upserts to profiles now fail, so their purchases don't reach the
-- account until the user updates.
--
-- Safe to re-run.
-- =============================================================

-- ── 1. Clients read their own profile; only the service role writes ───────

drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

-- Without those policies RLS already refuses client writes. Revoking the
-- privileges too means a policy added later by mistake can't reopen them.
revoke insert, update, delete, truncate on public.profiles from anon, authenticated;

-- profiles_select_own (v6) stays: the app reads is_pro after sign-in.

-- ── 2. Verified purchases ───────────────────────────────────────────────────

create table if not exists public.pro_purchases (
  -- Stable across restores and devices, so it identifies the purchase itself.
  original_transaction_id text        primary key,
  user_id                 uuid        not null references auth.users (id) on delete cascade,
  transaction_id          text        not null,
  product_id              text        not null,
  environment             text        not null,
  purchased_at            timestamptz,
  revoked_at              timestamptz,
  revocation_reason       integer,
  -- signedDate of the newest Apple-signed statement applied to this row.
  signed_at               timestamptz not null,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create index if not exists pro_purchases_user_idx on public.pro_purchases (user_id);

-- No policies: clients neither read nor write purchases. The service role
-- bypasses RLS.
alter table public.pro_purchases enable row level security;
revoke all on public.pro_purchases from anon, authenticated;

-- ── 3. record_pro_transaction(): the only path that sets is_pro ─────────────
-- Called by verify-purchase after it has verified the transaction's JWS.
-- Returns what the purchase means for the caller:
--   'active'                    the caller owns it and it is not revoked
--   'revoked'                   Apple refunded or revoked it
--   'claimed_by_other_account'  it is active but belongs to another account
-- and the caller's resulting is_pro.

create or replace function public.record_pro_transaction(
  p_user_id                 uuid,
  p_original_transaction_id text,
  p_transaction_id          text,
  p_product_id              text,
  p_environment             text,
  p_purchased_at            timestamptz,
  p_revoked_at              timestamptz,
  p_revocation_reason       integer,
  p_signed_at               timestamptz
)
returns table (outcome text, caller_is_pro boolean)
language plpgsql
set search_path = ''
as $$
declare
  v_row public.pro_purchases%rowtype;
begin
  -- One call at a time per purchase, so two accounts racing to claim the
  -- same one can't both win.
  perform pg_advisory_xact_lock(hashtextextended('pro:' || p_original_transaction_id, 0));

  select * into v_row
  from public.pro_purchases p
  where p.original_transaction_id = p_original_transaction_id;

  if not found then
    -- First sight of this purchase: it belongs to whoever presents it. A
    -- revoked one is stored too, so its older active JWS can't be replayed.
    insert into public.pro_purchases (
      original_transaction_id, user_id, transaction_id, product_id, environment,
      purchased_at, revoked_at, revocation_reason, signed_at
    )
    values (
      p_original_transaction_id, p_user_id, p_transaction_id, p_product_id, p_environment,
      p_purchased_at, p_revoked_at, p_revocation_reason, p_signed_at
    )
    returning * into v_row;

  elsif p_signed_at > v_row.signed_at
        -- The owner's newer statements apply in full. Anyone may report a
        -- newer revocation: Apple signed it, and it can only take Pro away.
        and (v_row.user_id = p_user_id or p_revoked_at is not null) then
    update public.pro_purchases p
    set transaction_id    = p_transaction_id,
        product_id        = p_product_id,
        environment       = p_environment,
        purchased_at      = p_purchased_at,
        revoked_at        = p_revoked_at,
        revocation_reason = p_revocation_reason,
        signed_at         = p_signed_at,
        updated_at        = now()
    where p.original_transaction_id = p_original_transaction_id
    returning * into v_row;
  end if;
  -- Otherwise it's a replay, a re-sync of the same JWS, or another account
  -- presenting someone else's purchase: nothing about the purchase changes.

  -- The owner is Pro while any of their purchases stands.
  insert into public.profiles as pr (id, is_pro, updated_at)
  values (
    v_row.user_id,
    exists (
      select 1 from public.pro_purchases p
      where p.user_id = v_row.user_id and p.revoked_at is null
    ),
    now()
  )
  on conflict (id) do update
    set is_pro = excluded.is_pro, updated_at = excluded.updated_at;

  return query select
    (case
       when v_row.revoked_at is not null then 'revoked'
       when v_row.user_id = p_user_id   then 'active'
       else 'claimed_by_other_account'
     end)::text,
    coalesce((select pr.is_pro from public.profiles pr where pr.id = p_user_id), false);
end;
$$;

-- Service role only, like claim_identify_slot() in v9: keep it off the REST
-- API for anon and signed-in users.
revoke execute on function public.record_pro_transaction(
  uuid, text, text, text, text, timestamptz, timestamptz, integer, timestamptz
) from public, anon, authenticated;
grant execute on function public.record_pro_transaction(
  uuid, text, text, text, text, timestamptz, timestamptz, integer, timestamptz
) to service_role;

-- ── 4. Drop Pro that no verified purchase backs ─────────────────────────────
-- Until now any client could set is_pro, so no existing true can be trusted.
-- Production had no profiles rows when this was written (2026-11-13); this
-- clears anything written through the old policies before they were dropped.
-- Real purchasers get Pro back the next time the app syncs their StoreKit
-- entitlement on sign-in.

update public.profiles pr
set is_pro = false, updated_at = now()
where pr.is_pro
  and not exists (
    select 1 from public.pro_purchases p
    where p.user_id = pr.id and p.revoked_at is null
  );
