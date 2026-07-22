-- ============================================================
-- AR 客户账目（finance/ar.html）— 云端存储表
-- 与旧版 localStorage 同构的 key/value 表，一行一个 key
-- 权限：复用 finance 模块（老板 all/admin + 财务 finance/editor）
-- Run in Supabase SQL Editor (project wjhgezvrxlhpexocfsea)
-- ============================================================

CREATE TABLE IF NOT EXISTS ar_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by TEXT
);

ALTER TABLE ar_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ar_state_sel" ON ar_state FOR SELECT
  USING (mv_has_module('finance', ARRAY['viewer','editor','admin']));
CREATE POLICY "ar_state_ins" ON ar_state FOR INSERT
  WITH CHECK (mv_has_module('finance', ARRAY['editor','admin']));
CREATE POLICY "ar_state_upd" ON ar_state FOR UPDATE
  USING (mv_has_module('finance', ARRAY['editor','admin']));
CREATE POLICY "ar_state_del" ON ar_state FOR DELETE
  USING (mv_has_module('finance', ARRAY['editor','admin']));
