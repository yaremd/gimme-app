-- =============================================================
-- Gimme — Phase 3 v2 migration
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- Adds: reserved_comment column, public sharing RLS policies,
--       claim_item and unclaim_item RPCs for the web gifting flow.
-- =============================================================

-- 1. Add missing reserved_comment column
alter table public.wish_items
  add column if not exists reserved_comment text;

-- =============================================================
-- 2. Public read RLS policies (unauthenticated web viewers)
--    These allow anyone to read shared lists and their items
--    without signing in — required for the /share/<token> page.
-- =============================================================

-- Allow anyone to SELECT shared lists (needed for share page)
drop policy if exists "Public read shared lists" on public.wish_lists;
create policy "Public read shared lists"
  on public.wish_lists for select
  using (is_shared = true);

-- Allow anyone to SELECT items that belong to a shared list
drop policy if exists "Public read items of shared lists" on public.wish_items;
create policy "Public read items of shared lists"
  on public.wish_items for select
  using (
    exists (
      select 1 from public.wish_lists l
      where l.id = list_id
        and l.is_shared = true
    )
  );

-- =============================================================
-- 3. claim_item RPC
--    Called by the web UI when a friend clicks "I'll get this".
--    Validates the share token, checks the item is unclaimed,
--    then marks it reserved.
--    Returns JSON: {} on success, { "error": "..." } on failure.
-- =============================================================
create or replace function public.claim_item(
  p_item_id    uuid,
  p_share_token text,
  p_claimer_name text,
  p_comment    text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_list_id uuid;
  v_token   text;
begin
  -- Resolve the item's parent list
  select list_id into v_list_id
  from wish_items
  where id = p_item_id;

  if v_list_id is null then
    return json_build_object('error', 'Item not found');
  end if;

  -- Validate share token matches the list
  select share_token into v_token
  from wish_lists
  where id = v_list_id
    and is_shared = true;

  if v_token is null or v_token <> p_share_token then
    return json_build_object('error', 'Invalid share token');
  end if;

  -- Ensure item is not already reserved or purchased
  if exists (
    select 1 from wish_items
    where id = p_item_id
      and (is_reserved_by_friend = true or is_purchased = true)
  ) then
    return json_build_object('error', 'Item is already reserved or purchased');
  end if;

  -- Claim the item
  update wish_items
  set
    is_reserved_by_friend = true,
    reserved_by_name      = p_claimer_name,
    reserved_comment      = p_comment,
    updated_at            = now()
  where id = p_item_id;

  return '{}'::json;
end;
$$;

-- =============================================================
-- 4. unclaim_item RPC
--    Called when a friend clicks "Undo" to release their claim.
--    Validates the share token to prevent abuse.
--    Returns JSON: {} on success, { "error": "..." } on failure.
-- =============================================================
create or replace function public.unclaim_item(
  p_item_id    uuid,
  p_share_token text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_list_id uuid;
  v_token   text;
begin
  -- Resolve the item's parent list
  select list_id into v_list_id
  from wish_items
  where id = p_item_id;

  if v_list_id is null then
    return json_build_object('error', 'Item not found');
  end if;

  -- Validate share token
  select share_token into v_token
  from wish_lists
  where id = v_list_id
    and is_shared = true;

  if v_token is null or v_token <> p_share_token then
    return json_build_object('error', 'Invalid share token');
  end if;

  -- Release the claim
  update wish_items
  set
    is_reserved_by_friend = false,
    reserved_by_name      = null,
    reserved_comment      = null,
    updated_at            = now()
  where id = p_item_id
    and is_purchased = false;

  return '{}'::json;
end;
$$;

-- Grant execute on RPCs to the anon role (used by the web page)
grant execute on function public.claim_item(uuid, text, text, text) to anon;
grant execute on function public.unclaim_item(uuid, text) to anon;
