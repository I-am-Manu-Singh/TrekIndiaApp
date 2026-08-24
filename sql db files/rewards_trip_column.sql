-- =============================================================================
-- Trek Booking App — Reward System SQL Migration
-- Run this in your Supabase SQL Editor (safe to run multiple times)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: Trip & Package reward_points columns
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS reward_points INT NOT NULL DEFAULT 0;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1b: All missing trips columns (from edit_trip_screen writes)
-- Safe to run multiple times — all use ADD COLUMN IF NOT EXISTS
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE trips ADD COLUMN IF NOT EXISTS cancellation_policy  TEXT;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS terms_conditions      TEXT;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS traveler_form_url     TEXT;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS google_map_link       TEXT;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS orientation           TEXT DEFAULT 'North';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS start_point           TEXT;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS package_type          TEXT DEFAULT 'Standard';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS trail_type            TEXT DEFAULT 'Mixed';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS peak_elevation        TEXT DEFAULT 'N/A';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS total_distance        TEXT DEFAULT '0 km';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS carry_list            JSONB DEFAULT '[]';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS seasonal_info         JSONB DEFAULT '{}';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS pickup_options        JSONB DEFAULT '[]';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS images                JSONB DEFAULT '[]';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS inclusions            JSONB DEFAULT '[]';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS exclusions            JSONB DEFAULT '[]';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS itinerary             JSONB DEFAULT '[]';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS available_dates       JSONB DEFAULT '[]';
ALTER TABLE trips ADD COLUMN IF NOT EXISTS slot_capacity         INT NOT NULL DEFAULT 15;

ALTER TABLE trip_packages
  ADD COLUMN IF NOT EXISTS reward_points INT NOT NULL DEFAULT 0;


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: reward_points cache column on profiles (for fast list display)
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS reward_points INT NOT NULL DEFAULT 0;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3: Create reward_ledger with unified schema
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS reward_ledger (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  points       INT         NOT NULL,                   -- always positive magnitude
  type         TEXT        NOT NULL DEFAULT 'credit',  -- 'credit' | 'debit'
  description  TEXT,
  reference_id TEXT,                                   -- booking group_id or voucher code
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4: Schema migration — handle old column names if table already existed
-- ─────────────────────────────────────────────────────────────────────────────

-- 4a. If old schema had 'points_changed' instead of 'points', copy and drop it
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'reward_ledger' AND column_name = 'points_changed'
  ) THEN
    -- Add new column if missing
    ALTER TABLE reward_ledger ADD COLUMN IF NOT EXISTS points INT;
    -- Copy absolute values from old column
    UPDATE reward_ledger
      SET points = ABS(points_changed)
      WHERE points IS NULL OR points = 0;
    -- Drop old column (comment out if you want to keep it as backup)
    ALTER TABLE reward_ledger DROP COLUMN IF EXISTS points_changed;
  END IF;
END $$;

-- 4b. Normalize type values: uppercase → lowercase
UPDATE reward_ledger
  SET type = LOWER(type)
  WHERE type IN ('CREDIT', 'DEBIT');

-- 4c. Drop and re-apply the CHECK constraint to allow only lowercase values
ALTER TABLE reward_ledger DROP CONSTRAINT IF EXISTS reward_ledger_type_check;
ALTER TABLE reward_ledger
  ADD CONSTRAINT reward_ledger_type_check CHECK (type IN ('credit', 'debit'));

-- 4d. Ensure 'points' column is NOT NULL with default 0 (safe after migration)
ALTER TABLE reward_ledger
  ALTER COLUMN points SET NOT NULL,
  ALTER COLUMN points SET DEFAULT 0;

-- 4e. Drop legacy columns that old code added but new code does not use
ALTER TABLE reward_ledger DROP COLUMN IF EXISTS booking_id;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 5: Indexes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_reward_ledger_user_id
  ON reward_ledger(user_id);

CREATE INDEX IF NOT EXISTS idx_reward_ledger_created_at
  ON reward_ledger(created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 6: Row Level Security
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE reward_ledger ENABLE ROW LEVEL SECURITY;

-- Users can read only their own entries
DROP POLICY IF EXISTS "Users read own ledger" ON reward_ledger;
CREATE POLICY "Users read own ledger"
  ON reward_ledger FOR SELECT
  USING (auth.uid() = user_id);

-- Admins can read all entries (needed for AdminRewardsScreen)
DROP POLICY IF EXISTS "Admins read all ledger" ON reward_ledger;
CREATE POLICY "Admins read all ledger"
  ON reward_ledger FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- Any authenticated user / service role can insert (booking flow + admin adjustments)
DROP POLICY IF EXISTS "Service inserts ledger" ON reward_ledger;
CREATE POLICY "Service inserts ledger"
  ON reward_ledger FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 7: Live balance helper view (optional — useful for dashboards)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW reward_balances AS
SELECT
  user_id,
  COALESCE(SUM(CASE WHEN type = 'credit' THEN points ELSE 0 END), 0) AS total_earned,
  COALESCE(SUM(CASE WHEN type = 'debit'  THEN points ELSE 0 END), 0) AS total_redeemed,
  GREATEST(
    COALESCE(SUM(CASE WHEN type = 'credit' THEN points ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN type = 'debit'  THEN points ELSE 0 END), 0),
    0
  ) AS balance
FROM reward_ledger
GROUP BY user_id;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 8: Sync profiles.reward_points cache from ledger (run once)
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE profiles p
SET reward_points = COALESCE(rb.balance, 0)
FROM reward_balances rb
WHERE p.id = rb.user_id;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 9: Verify
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  (SELECT COUNT(*) FROM reward_ledger)        AS ledger_rows,
  (SELECT COUNT(*) FROM reward_balances)       AS users_with_points,
  (SELECT SUM(balance) FROM reward_balances)   AS total_outstanding_pts,
  (SELECT column_name FROM information_schema.columns
    WHERE table_name = 'reward_ledger' AND column_name = 'points')   AS has_points_col,
  (SELECT column_name FROM information_schema.columns
    WHERE table_name = 'reward_ledger' AND column_name = 'points_changed') AS old_col_present;
