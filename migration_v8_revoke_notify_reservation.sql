-- =============================================================
-- Gimme — v8: keep notify_reservation() off the REST API
-- Run this in: Supabase Dashboard → SQL Editor → New query
--
-- notify_reservation() is the trigger function behind on_item_reserved
-- (migration_v3, updated in v4). It is SECURITY DEFINER, and functions in
-- `public` are executable by everyone by default, so Supabase's security
-- advisor flagged it as reachable at /rest/v1/rpc/notify_reservation.
-- Postgres refuses to run a trigger function outside a trigger, so it was
-- never callable in practice, but it has no business on the API surface.
--
-- EXECUTE is checked when a trigger is created, not when it fires, so
-- on_item_reserved keeps firing for anon reservations via claim_item and for
-- signed-in users alike.
--
-- Safe to re-run.
-- =============================================================

revoke execute on function public.notify_reservation() from public, anon, authenticated;
