-- Account Dashboard: Monthly Performance Summary
-- Run in Supabase SQL Editor (project wjhgezvrxlhpexocfsea)
-- Drop old version if it was already created: DROP TABLE IF EXISTS monthly_summary;

CREATE TABLE IF NOT EXISTS monthly_summary (
  id                    BIGSERIAL PRIMARY KEY,
  month                 TEXT NOT NULL UNIQUE,          -- 'YYYY-MM'

  -- Revenue by channel
  rev_offline           NUMERIC(14,2) NOT NULL DEFAULT 0,   -- MT + GT
  rev_online            NUMERIC(14,2) NOT NULL DEFAULT 0,   -- Shopee/Lazada/TikTok
  rev_international     NUMERIC(14,2) NOT NULL DEFAULT 0,   -- IB

  -- Expenses by category (order matches user's spec)
  exp_ads_promotions    NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_dc_rebates        NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_lazada_fee        NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_listing_fee       NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_marketing         NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_shopee_fee        NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_b2b_subscription  NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_transaction_fees  NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_transportation    NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_admin             NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_payroll           NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_upkeep            NUMERIC(14,2) NOT NULL DEFAULT 0,
  exp_rental_utility    NUMERIC(14,2) NOT NULL DEFAULT 0,

  notes                 TEXT DEFAULT '',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_monthly_summary_month ON monthly_summary(month);

ALTER TABLE monthly_summary ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ms_select" ON monthly_summary FOR SELECT
  USING (mv_has_module('accountdashboard', ARRAY['viewer','editor','admin']));

CREATE POLICY "ms_insert" ON monthly_summary FOR INSERT
  WITH CHECK (mv_has_module('accountdashboard', ARRAY['editor','admin']));

CREATE POLICY "ms_update" ON monthly_summary FOR UPDATE
  USING (mv_has_module('accountdashboard', ARRAY['editor','admin']));

CREATE POLICY "ms_delete" ON monthly_summary FOR DELETE
  USING (mv_has_module('accountdashboard', ARRAY['admin']));

-- Add permission for your account (skip if you already have module='all' admin):
-- INSERT INTO app_permissions (email, module, role)
-- VALUES ('ohy4896@gmail.com', 'accountdashboard', 'admin')
-- ON CONFLICT (email, module) DO UPDATE SET role='admin';
