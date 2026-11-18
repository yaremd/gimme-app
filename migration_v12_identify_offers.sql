-- =============================================================
-- Gimme — v12: shop search for identified photos
-- Run this in: Supabase Dashboard → SQL Editor → New query
--
-- When identify-product names a specific product, the app can ask it once for
-- shops selling that product (a web search, with each price confirmed on the
-- shop's page). The search belongs to the identification's row in
-- ai_identify_requests (v9):
--
--   offers_status   null until the app asks; 'pending' while the search runs;
--                   then 'ok' (offers found), 'none' (nothing confirmed) or
--                   'failed' (the model gave no usable answer). The function
--                   only starts a search on a row whose offers_status is null,
--                   which makes it one search per identification.
--   offers_*        model, tokens, web searches, offers returned and latency,
--                   for cost tracking. Web searches are billed per search on
--                   top of tokens.
--
-- Nothing about the offers themselves (shops, links, prices) is stored. The
-- function writes these columns with the service role; the existing
-- select-own policy lets a user read their own rows.
--
-- Safe to re-run.
-- =============================================================

alter table public.ai_identify_requests
  add column if not exists offers_status        text,
  add column if not exists offers_model         text,
  add column if not exists offers_input_tokens  integer,
  add column if not exists offers_output_tokens integer,
  add column if not exists offers_searches      integer,
  add column if not exists offers_found         integer,
  add column if not exists offers_latency_ms    integer;

alter table public.ai_identify_requests drop constraint if exists ai_identify_requests_offers_status_check;
alter table public.ai_identify_requests
  add constraint ai_identify_requests_offers_status_check
  check (offers_status is null or offers_status in ('pending', 'ok', 'none', 'failed'));

comment on column public.ai_identify_requests.offers_status is
  'Shop search for this identification: null (not asked), pending, ok, none or failed. One per identification.';
