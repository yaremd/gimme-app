-- Migration v5: Add anonymous_reservations to wish_lists
-- When enabled, no one can see who claimed an item — only that it's reserved.

ALTER TABLE wish_lists
  ADD COLUMN IF NOT EXISTS anonymous_reservations boolean NOT NULL DEFAULT false;
