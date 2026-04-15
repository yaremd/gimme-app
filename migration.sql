-- =============================================================
-- Gimme — Phase 3 Supabase migration
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- =============================================================

-- wish_lists
create table if not exists public.wish_lists (
  id            uuid          primary key,
  owner_id      uuid          not null references auth.users(id) on delete cascade,
  name          text          not null,
  emoji         text          not null default '✨',
  color_hex     text          not null default '#6C63FF',
  is_shared     boolean       not null default false,
  share_token   text,
  is_pinned     boolean       not null default false,
  is_archived   boolean       not null default false,
  created_at    timestamptz   not null default now(),
  updated_at    timestamptz   not null default now()
);

-- wish_items
create table if not exists public.wish_items (
  id                      uuid            primary key,
  list_id                 uuid            not null references public.wish_lists(id) on delete cascade,
  owner_id                uuid            not null references auth.users(id) on delete cascade,
  title                   text            not null,
  notes                   text,
  url                     text,
  image_url               text,
  price_double            double precision,
  currency                text,
  priority                text            not null default 'medium',
  is_purchased            boolean         not null default false,
  is_reserved_by_friend   boolean         not null default false,
  reserved_by_name        text,
  end_date                timestamptz,
  notifications_enabled   boolean         not null default false,
  is_pinned               boolean         not null default false,
  is_archived             boolean         not null default false,
  created_at              timestamptz     not null default now(),
  updated_at              timestamptz     not null default now()
);

-- Row Level Security
alter table public.wish_lists enable row level security;
alter table public.wish_items  enable row level security;

-- Policies: each user sees and writes only their own data
create policy "Users manage their own lists"
  on public.wish_lists for all
  using  (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Users manage their own items"
  on public.wish_items for all
  using  (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);
