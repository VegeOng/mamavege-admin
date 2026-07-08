# MamaVege 管理层平台 · Supabase 后台设置清单

Supabase 项目：`https://wjhgezvrxlhpexocfsea.supabase.co`（与业务平台共用数据层）

> 如果你之前已按 promo-traker 里的 `management/SUPABASE-SETUP.md` 做过第 1、2 步和财务表 SQL，
> 那只需：① URL Configuration 加上新域名 ② 执行下方 **第 3-B 节（ap_state 表）** ③ 执行 `sql/ap-seed.sql`。
> 所有 SQL 都是幂等的，重复执行不出错。

---

## 第 1 步：开启 Email 登录、关闭公开注册

Supabase Dashboard → **Authentication**：

1. **Sign In / Providers** → 确认 **Email** provider 已启用（默认开启）。建议关掉 *Confirm email*（内部工具）。
2. **Auth settings** → 关闭 **Allow new users to sign up**（关键：防外人自己注册）。
3. **URL Configuration**：
   - **Site URL**：管理平台的 Vercel 域名（例如 `https://mamavege-admin.vercel.app`）
   - **Redirect URLs** 加上（Magic Link 跳转用）：
     - `https://<管理平台域名>/index.html`
     - `https://<管理平台域名>/finance/index.html`
     - `https://<管理平台域名>/finance/dashboard.html`
     - `https://<管理平台域名>/finance/ap.html`
     - 本地测试：`http://localhost:*`

## 第 2 步：建你的账号

**Authentication → Users → Add user → Create new user**：
Email `ohy4896@gmail.com` + 强密码，勾选 **Auto Confirm User**。

给同事开账号同样操作，然后在 `app_permissions` 加权限行（见文末）。

## 第 3-A 步：权限系统 + 财务监督表（与业务平台版相同，已执行过可跳过）

```sql
-- 1) 通用权限表（全公司共用：finance / purchasing / hr / warehouse / production...）
create table if not exists public.app_permissions (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  module      text not null,          -- 模块名；'all' = 全模块通配
  role        text not null default 'viewer' check (role in ('admin','editor','viewer')),
  note        text,
  created_at  timestamptz not null default now(),
  unique (email, module)
);

-- 2) 月度财务表
create table if not exists public.finance_monthly (
  id               uuid primary key default gen_random_uuid(),
  month            date not null unique,
  net_sales        numeric,
  gross_margin_pct numeric,
  opex             numeric,
  inventory        numeric,
  cash_balance     numeric,
  recon_sales_dash numeric,
  recon_ecom       numeric,
  note             text,
  updated_by       text,
  updated_at       timestamptz not null default now()
);

-- 3) 目标线表
create table if not exists public.finance_targets (
  id             uuid primary key default gen_random_uuid(),
  effective_from date not null unique,
  sales_min      numeric,
  margin_min_pct numeric,
  opex_max       numeric,
  inventory_max  numeric,
  cash_min       numeric default 0,
  note           text,
  created_at     timestamptz not null default now()
);

-- 4) 权限判断函数（SECURITY DEFINER，避免 RLS 自引用死循环）
create or replace function public.mv_has_module(p_module text, p_roles text[])
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.app_permissions
    where lower(email) = lower(coalesce(auth.jwt()->>'email',''))
      and module in (p_module, 'all')
      and role = any(p_roles)
  );
$$;
revoke all on function public.mv_has_module(text, text[]) from public;
grant execute on function public.mv_has_module(text, text[]) to authenticated;

-- 5) RLS：app_permissions
alter table public.app_permissions enable row level security;
drop policy if exists "perm_read_own"  on public.app_permissions;
drop policy if exists "perm_admin_all" on public.app_permissions;
create policy "perm_read_own" on public.app_permissions
  for select to authenticated
  using ( lower(email) = lower(coalesce(auth.jwt()->>'email',''))
          or public.mv_has_module('permissions', array['admin']) );
create policy "perm_admin_all" on public.app_permissions
  for all to authenticated
  using ( public.mv_has_module('permissions', array['admin']) )
  with check ( public.mv_has_module('permissions', array['admin']) );

-- 6) RLS：finance_monthly（读=viewer+ / 写=editor+ / 删=admin）
alter table public.finance_monthly enable row level security;
drop policy if exists "fin_read"   on public.finance_monthly;
drop policy if exists "fin_insert" on public.finance_monthly;
drop policy if exists "fin_update" on public.finance_monthly;
drop policy if exists "fin_delete" on public.finance_monthly;
create policy "fin_read" on public.finance_monthly
  for select to authenticated
  using ( public.mv_has_module('finance', array['admin','editor','viewer']) );
create policy "fin_insert" on public.finance_monthly
  for insert to authenticated
  with check ( public.mv_has_module('finance', array['admin','editor']) );
create policy "fin_update" on public.finance_monthly
  for update to authenticated
  using ( public.mv_has_module('finance', array['admin','editor']) )
  with check ( public.mv_has_module('finance', array['admin','editor']) );
create policy "fin_delete" on public.finance_monthly
  for delete to authenticated
  using ( public.mv_has_module('finance', array['admin']) );

-- 7) RLS：finance_targets（同上）
alter table public.finance_targets enable row level security;
drop policy if exists "tgt_read"   on public.finance_targets;
drop policy if exists "tgt_insert" on public.finance_targets;
drop policy if exists "tgt_update" on public.finance_targets;
drop policy if exists "tgt_delete" on public.finance_targets;
create policy "tgt_read" on public.finance_targets
  for select to authenticated
  using ( public.mv_has_module('finance', array['admin','editor','viewer']) );
create policy "tgt_insert" on public.finance_targets
  for insert to authenticated
  with check ( public.mv_has_module('finance', array['admin','editor']) );
create policy "tgt_update" on public.finance_targets
  for update to authenticated
  using ( public.mv_has_module('finance', array['admin','editor']) )
  with check ( public.mv_has_module('finance', array['admin','editor']) );
create policy "tgt_delete" on public.finance_targets
  for delete to authenticated
  using ( public.mv_has_module('finance', array['admin']) );

-- 8) 第一批授权：Vege = 全模块 admin
insert into public.app_permissions (email, module, role, note)
values ('ohy4896@gmail.com', 'all', 'admin', 'CEO Vege · 全模块管理员')
on conflict (email, module) do update set role = excluded.role;

-- 9) 目标线：2026 H2
insert into public.finance_targets (effective_from, sales_min, margin_min_pct, opex_max, inventory_max, cash_min, note)
values ('2026-07-01', 550000, 38, 220000, 750000, 0, '2026 H2 目标：销售≥550k/月、毛利≥38%、费用≤220k/月、库存年底≤750k、现金为正')
on conflict (effective_from) do update set
  sales_min=excluded.sales_min, margin_min_pct=excluded.margin_min_pct,
  opex_max=excluded.opex_max, inventory_max=excluded.inventory_max,
  cash_min=excluded.cash_min, note=excluded.note;

-- 10) 2026 H1 实际数据（现金余额待补；库存只有6月底数）
insert into public.finance_monthly (month, net_sales, gross_margin_pct, opex, inventory, note) values
  ('2026-01-01', 403536, 48.5, 300803, null, null),
  ('2026-02-01', 393950,  3.2, 276084, null, '节日备货导致毛利率扭曲'),
  ('2026-03-01', 425882, 39.0, 220440, null, null),
  ('2026-04-01', 540718, 42.0, 227150, null, null),
  ('2026-05-01', 641493, 51.9, 204004, null, null),
  ('2026-06-01', 403035, 46.1, 342472, 1065209, '库存天数约132天')
on conflict (month) do nothing;
```

## 第 3-B 步：AP 付款管理表（本次新增，必须执行）

```sql
-- AP 状态表：4 行 JSONB（base=历史发票 / main=付款状态+自定义发票+银行余额 / summaries / master）
create table if not exists public.ap_state (
  key        text primary key,
  data       jsonb not null default '{}'::jsonb,
  updated_by text,
  updated_at timestamptz not null default now()
);

alter table public.ap_state enable row level security;
drop policy if exists "ap_read"   on public.ap_state;
drop policy if exists "ap_insert" on public.ap_state;
drop policy if exists "ap_update" on public.ap_state;
drop policy if exists "ap_delete" on public.ap_state;
create policy "ap_read" on public.ap_state
  for select to authenticated
  using ( public.mv_has_module('finance', array['admin','editor','viewer']) );
create policy "ap_insert" on public.ap_state
  for insert to authenticated
  with check ( public.mv_has_module('finance', array['admin','editor']) );
create policy "ap_update" on public.ap_state
  for update to authenticated
  using ( public.mv_has_module('finance', array['admin','editor']) )
  with check ( public.mv_has_module('finance', array['admin','editor']) );
create policy "ap_delete" on public.ap_state
  for delete to authenticated
  using ( public.mv_has_module('finance', array['admin']) );
```

## 第 4 步：导入 AP 历史数据

把 **`sql/ap-seed.sql`** 整个文件内容贴进 SQL Editor 执行（179 张历史发票 + 付款状态 + 汇总 + 主档）。

> ⚠️ 数据快照 = v45 文件生成时刻。如果那之后你还在旧版页面操作过（勾付款、填 voucher、改银行余额），
> 在旧版页面点「📤 导出 JSON」，然后到新平台 AP 页右上「📥 导入」粘贴，即可覆盖为最新状态。
> 银行余额（PBB/OCBC）在快照里是 0，记得导入或在 Dashboard 直接点击编辑补上。

---

## 日常管理

**给同事开权限**（先建账号，再执行）：

```sql
-- 财务同事可录入/操作 AP：
insert into public.app_permissions (email, module, role, note)
values ('someone@mamavege.com', 'finance', 'editor', '财务部');
-- role 三档：admin（管权限+可删）> editor（可录入/修改，AP 页要求 editor 以上）> viewer（只读月度监督）
```

**未来扩展模块**（purchasing / hr / warehouse / production）：新表照抄第 3-B 节的 policy 把 `'finance'` 换成新模块名；`js/auth/auth.js` 和权限表不用改，平台首页 `index.html` 的 MODULES 数组加一行即可。

## 安全说明

- 真正的防线在数据库 RLS：没登录或不在 `app_permissions` 白名单，读写全部被数据库拒绝，前端拦截只是体验层。anon key 写在前端是 Supabase 的正常设计。
- AP 数据是整块 JSONB 后写覆盖（last-write-wins），适合单人/少人操作；多人同时改同一块会互相覆盖，未来若多人并发再拆关系表。
