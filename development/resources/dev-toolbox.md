# 前后端开发工具箱

本页只收录当前 GitHub 上高热、持续维护、文档成熟，并且能直接提升前端、后端和 AI Coding 效率的项目。筛选日期：`2026-09-03`。

安装与用法只保留最短上手路径；正式用于项目时仍以项目官方 README / 文档为准。

## 设计

| 名字 | 介绍 | 安装 | 用法 | 项目 URL |
| --- | --- | --- | --- | --- |
| awesome-design-md | 收集大量真实产品设计体系的 `DESIGN.md`。把设计规则直接交给 Coding Agent，可显著减少 AI 页面风格漂移。适合在正式写前端前先固定视觉语言。 | 无需安装。从项目中选择一个合适的 `DESIGN.md`，复制到自己的项目根目录并命名为 `DESIGN.md`。 | 让 Coding Agent 在开发页面前先读取 `DESIGN.md`，例如：`先读取 DESIGN.md，再按该设计系统实现登录页和后台 Layout。` | https://github.com/VoltAgent/awesome-design-md |

## 前端

| 名字 | 介绍 | 安装 | 用法 | 项目 URL |
| --- | --- | --- | --- | --- |
| shadcn/ui | 高热度 React UI 组件方案。组件代码直接进入项目，便于 AI 阅读、修改和统一风格，特别适合 Tailwind / Next.js / Vite 项目。 | `pnpm dlx shadcn@latest init` | 按需加入组件，例如 `pnpm dlx shadcn@latest add button`，然后直接在项目源码中组合和修改。 | https://github.com/shadcn-ui/ui |
| Next.js | Vercel 维护的 React 全栈框架，社区和 AI 训练样本都非常充足。适合产品型 Web、SSR、后台接口和轻量 SaaS。 | `npx create-next-app@latest` | 进入项目后运行 `npm run dev`；页面、Server Components、Route Handlers 等按官方 App Router 结构开发。 | https://github.com/vercel/next.js |

## 后端与全栈

| 名字 | 介绍 | 安装 | 用法 | 项目 URL |
| --- | --- | --- | --- | --- |
| FastAPI | Python 高性能 API 框架，基于类型标注、Pydantic 和 OpenAPI，接口契约清晰，特别适合 AI 应用和前后端分离项目。 | 已安装 `uv` 时执行 `uv add "fastapi[standard]"`；也可在虚拟环境中使用 pip 安装。 | 创建 `main.py` 后运行 `uv run fastapi dev`，默认可通过 `/docs` 验证自动生成的 OpenAPI/Swagger 文档。 | https://github.com/fastapi/fastapi |
| Full Stack FastAPI Template | FastAPI 官方组织维护的完整全栈模板，已组合 React、TypeScript、Vite、Tailwind、shadcn/ui、PostgreSQL、Playwright、Pytest、Docker Compose 和 GitHub Actions。适合不想从空目录搭骨架时直接起项目。 | 在 GitHub 页面点击 **Use this template** 创建自己的仓库，然后 clone 到本地。 | 完整 Compose 启动可执行 `docker compose run --rm backend bash scripts/prestart.sh`，再执行 `docker compose watch`。也可按仓库 `development.md` 分别启动 FastAPI 和 Vite。 | https://github.com/fastapi/full-stack-fastapi-template |

## 测试与验收

| 名字 | 介绍 | 安装 | 用法 | 项目 URL |
| --- | --- | --- | --- | --- |
| Playwright | Microsoft 维护的端到端 Web 测试和浏览器自动化框架，可统一测试 Chromium、Firefox、WebKit。适合把 AI 生成页面的“能打开”提升为真实用户流程验收。 | `npm init playwright@latest` | 运行 `npx playwright test`；优先为登录、新增、编辑、删除等关键用户路径建立 E2E 测试。 | https://github.com/microsoft/playwright |

## AI Coding 与 Skills

| 名字 | 介绍 | 安装 | 用法 | 项目 URL |
| --- | --- | --- | --- | --- |
| Superpowers | 面向 Coding Agent 的开发方法与 Skills 集合，覆盖 brainstorming、计划、TDD、系统化调试、代码评审、并行 Agent 和完成前验证。适合让 Codex 等 Agent 从“一次性生成”切换到可审计工程流程。 | Codex CLI 中执行 `/plugins`，搜索 `superpowers`，选择 **Install Plugin**。 | 安装后按任务自动触发相关 Skill；典型流程为设计 → 实施计划 → TDD/实现 → Review → 验证 → 合并。 | https://github.com/obra/superpowers |
| Vercel Agent Skills | Vercel 官方 Agent Skills 集合，包含 React/Next.js 性能规范、Web 设计与可访问性检查、组件组合模式、Vercel 优化和部署等技能。 | `npx skills add vercel-labs/agent-skills` | 安装后让 Agent 直接执行对应任务，例如：`Review this React component for performance issues` 或 `Review my UI for accessibility and UX issues`。 | https://github.com/vercel-labs/agent-skills |

## 推荐组合

对于以 AI Coding 为主的常规前后端项目，可先采用这一最小组合：

```text
设计约束        → awesome-design-md
前端 UI         → shadcn/ui
React 全栈      → Next.js
Python API      → FastAPI
全栈脚手架      → Full Stack FastAPI Template
真实页面验收    → Playwright
Agent 工程流程  → Superpowers
React/设计审计  → Vercel Agent Skills
```

不要为了“工具齐全”把所有项目同时引入一个代码库。先根据项目技术栈选择必要组件，再由测试和验收结果决定是否增加工具。
