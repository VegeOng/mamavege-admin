# MamaVege 管理层平台（mamavege-admin）

妈子素管理层内部平台。与业务平台（promo-traker）分离部署，共用同一个 Supabase 数据层。

## 结构

```
index.html            平台入口（登录后按 app_permissions 权限显示模块卡片）
js/auth/auth.js       全公司共用登录+权限模块（Supabase Auth + RLS 白名单）
finance/
  index.html          财务板块入口
  dashboard.html      月度财务监督（5大数字红绿灯、趋势图、三边对账）
  ap.html             AP 付款管理（原单机版迁移，数据存 Supabase ap_state）
sql/ap-seed.sql       AP 历史数据初始导入
SUPABASE-SETUP.md     Supabase 后台设置步骤 + 全部建表/RLS SQL
```

## 权限模型

`app_permissions`（email / module / role）：module = `finance` / `purchasing` / `hr` / ...，`all` 通配；role = `admin` > `editor` > `viewer`。数据保护在数据库 RLS 层，前端拦截只是体验层。

## 部署

静态站，Vercel 直接 import 本 repo 即可（无需构建配置）。部署后到 Supabase → Authentication → URL Configuration 把域名加进 Redirect URLs。

## 本地预览

```bash
npx serve -p 3457 .
```
