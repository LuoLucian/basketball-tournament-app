# 德泰科技园篮球赛事管理系统

> 响应式自适应网页应用，手机/iPad/电脑均可访问，无需APP。

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端框架 | Vue 3 + Vite + Composition API |
| 状态管理 | Pinia |
| 路由 | Vue Router 4 |
| 样式 | Tailwind CSS 3 |
| 拖拽 | VueDraggable 4 (Sortable.js) |
| 后端/DB | Supabase (PostgreSQL + Auth + Realtime + Storage) |
| 部署 | Vercel + Supabase（**完全免费**） |

## 快速开始

### 1. 安装依赖

```bash
npm install
```

### 2. 配置环境变量

复制 `.env.example` 为 `.env.local`，填入你的 Supabase 项目信息：

```bash
cp .env.example .env.local
```

在 [supabase.com](https://supabase.com) 创建免费项目，在项目设置 → API 中找到：
- `VITE_SUPABASE_URL` → Project URL
- `VITE_SUPABASE_ANON_KEY` → anon/public key

### 3. 初始化数据库

在 Supabase SQL Editor 中执行 `supabase/schema.sql` 文件，创建所有数据表和RLS策略。

### 4. 启动开发服务器

```bash
npm run dev
```

访问 http://localhost:3000

## 项目结构

```
src/
├── views/
│   ├── auth/          # 登录、注册
│   ├── admin/         # 后台管理（球员、团队、用户）
│   ├── game/          # 赛事相关（大厅、录入、详情）
│   └── stats/         # 统计排行
├── components/
│   ├── ui/            # 通用UI组件
│   ├── game/          # 赛事组件（拖拽面板、计分板）
│   └── stats/         # 统计图表组件
├── stores/            # Pinia 状态管理
├── router/            # Vue Router 路由配置
├── composables/       # 可复用逻辑
├── utils/             # 工具函数
└── assets/            # 静态资源
```

## 角色权限

| 角色 | 描述 |
|------|------|
| 总管理员 | 全权限，含系统配置、数据修正 |
| 普通管理员 | 赛事管理、球员管理、排行榜查看 |
| 记录员 | 仅负责录入被指派赛事的数据 |
| 普通用户 | 查看公开数据，个人信息管理 |

## 部署

```bash
npm run build
# 将 dist/ 目录部署到 Vercel
```

Vercel 自动 HTTPS，全球 CDN，**零成本无需备案**。
