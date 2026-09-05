# Codex 项目开局规范

新项目交给 Codex 前，先建立**稳定技术栈、清晰目录、持久项目指令和可执行验收命令**。目标不是堆很多文档，而是让人和 AI 都能快速回答：项目做什么、怎么运行、怎么改、怎么测试、什么算完成。

本文适用于以 Codex 为主要 Coding Agent 的新项目，也适用于整理缺少工程约束的存量仓库。

## 文档信息

- **技术领域**：AI Coding / Codex / 项目工程化
- **适用范围**：Web、API、AI 应用、内部工具、通用软件项目
- **文档状态**：推荐基线
- **最后验证**：2026-09-03
- **主要参考**：OpenAI Codex、OpenAI Cookbook、GitHub Spec Kit、FastAPI Full Stack Template、Next.js

## 1. 推荐技术基线

原则：**优先主流、强类型、文档成熟、测试工具完善、AI 训练样本丰富的技术栈；已有项目优先遵循现有技术栈，不为“统一”而重写。**

通用 Web / AI 项目推荐：

| 层 | 推荐 | 说明 |
| --- | --- | --- |
| 后端 | Python + FastAPI + Pydantic | AI/LLM 生态成熟，Schema 清晰，API 易测试 |
| ORM / 数据 | SQLAlchemy 或 SQLModel + PostgreSQL | 社区成熟，迁移与关系模型清晰 |
| 前端 | TypeScript + React + Vite | 类型明确、构建简单、资料丰富 |
| UI | Ant Design（管理后台）或 shadcn/ui + Tailwind CSS | 组件模式成熟，减少 AI 自造 UI |
| 单元/集成测试 | pytest | Python 生态标准选择 |
| E2E | Playwright | 浏览器真实路径验证成熟 |
| 运行环境 | Docker Compose | 本地、CI、交付环境更容易一致 |
| CI | GitHub Actions | 与 GitHub Flow 直接衔接 |
| Git | GitHub Flow + 短生命周期任务分支 | 可审计、可回退、适合 Agent 开发 |

需要 SSR/SEO 或服务端 React 时再选 Next.js；普通内部系统和前后端分离项目优先 React + Vite，减少框架隐式行为。

## 2. 推荐目录结构

最小但完整的 Codex 项目建议如下：

```text
project/
├── README.md
├── AGENTS.md
├── CONTRIBUTING.md
├── .gitignore
├── .env.example
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEVELOPMENT.md
│   └── TESTING.md
├── backend/                 # 有后端时
├── frontend/                # 有前端时
├── tests/                   # 按项目需要拆 unit/integration/e2e
├── .github/
│   └── workflows/
├── .specify/                # 使用 GitHub Spec Kit 时
│   └── memory/
│       └── constitution.md
└── specs/
    └── 001-feature-name/
        ├── spec.md
        ├── plan.md
        └── tasks.md
```

其中真正建议开局就建立的 Markdown 文件只有 6 个：

| 文件 | 作用 | 必要性 |
| --- | --- | --- |
| `README.md` | 项目入口、Quick Start、目录和验收入口 | 必须 |
| `AGENTS.md` | Codex 持久项目规则、边界、命令和完成标准 | 必须 |
| `CONTRIBUTING.md` | Git 分支、Commit、PR、合并规则 | 必须 |
| `docs/ARCHITECTURE.md` | 架构、组件边界、数据流、接口关系 | 必须 |
| `docs/DEVELOPMENT.md` | 环境、启动、依赖、迁移、调试命令 | 必须 |
| `docs/TESTING.md` | 测试类型、命令、质量门禁 | 必须 |

如果使用 Spec Kit，再增加 `.specify/memory/constitution.md` 和每个 Feature 的 `spec.md / plan.md / tasks.md`。`SECURITY.md`、ADR、CHANGELOG 等根据项目规模再加，不要为“看起来专业”提前制造空文档。

## 3. README.md

`README.md` 面向人和 AI，负责回答“这是什么、如何启动、去哪里找详细规则”。不要把所有细节都塞进 README。

推荐内容：

```text
# Project Name

一句话说明项目目标和主要用户。

## Scope
- 本期做什么
- 明确不做什么

## Stack
- Backend: ...
- Frontend: ...
- Database: ...

## Quick Start
1. 安装依赖
2. 配置 .env
3. 启动服务

## Verify
列出最关键的 lint / test / build / health check 命令。

## Repository Map
说明 backend、frontend、tests、docs、specs 的职责。

## Docs
- Architecture: docs/ARCHITECTURE.md
- Development: docs/DEVELOPMENT.md
- Testing: docs/TESTING.md
- Agent Rules: AGENTS.md
```

## 4. AGENTS.md

这是 Codex 最重要的项目级持久上下文。OpenAI Codex 会读取作用域内的 `AGENTS.md`；大型仓库还可以在子目录放更具体的 `AGENTS.md`，下层规则覆盖上层对应范围。

推荐保持短、硬、可执行：

```text
# Project Instructions

## Goal
一句话说明项目目标、主要边界和非目标。

## Source of Truth
- README：项目入口
- docs/ARCHITECTURE.md：稳定架构
- specs/<feature>/：当前功能需求与计划
- 测试结果：完成状态的最终证据

## Workflow
1. 先读取相关代码、文档、测试和 git status。
2. 禁止直接在 main 开发。
3. 一项任务一个 feature/fix/refactor/docs/chore 分支。
4. 大任务按 spec → plan → tasks → implement → verify 执行。
5. 修改遵循最小变更原则，不顺手重构无关代码。

## Stack
列出固定语言、框架、包管理器和主要版本范围。
未经批准不得自行切换框架或升级大版本。

## Commands
- install: ...
- dev: ...
- lint: ...
- test: ...
- build: ...

## Definition of Done
- 需求满足
- 相关测试通过
- lint/type/build 通过
- 文档与代码一致
- git diff 只包含当前任务必要变更

## Forbidden
- force push main
- 绕过测试宣布完成
- 提交密码/Token/私钥
- 擅自修改治理规则
```

原则：**只写 Codex 每次工作都需要知道的长期规则。** 临时需求不要永久塞进 `AGENTS.md`。

## 5. CONTRIBUTING.md

负责 Git 和协作流程，避免把 Git 规则散落在提示词里。

```text
# Contributing

## Branches
main 始终保持可运行、可发布、可回退。
禁止直接在 main 开发。

任务分支：
- feature/*
- fix/*
- refactor/*
- docs/*
- chore/*

## Commits
提交应小而完整，推荐：
feat: / fix: / refactor: / test: / docs: / chore:

## Pull Request
合并前必须：
- 同步最新 main
- 完成测试、lint、type/build
- 审查 git diff
- 确认没有敏感信息

推荐 Squash Merge；合并后删除任务分支。
```

## 6. docs/ARCHITECTURE.md

这份文件只保存**相对稳定的系统事实**，避免写每日进度。

```text
# Architecture

## Goals / Non-goals
系统解决什么问题，不解决什么问题。

## System Context
用户 → Frontend → Backend/API → Database / External Services

## Components
逐项说明组件：职责、入口、依赖、禁止承担的职责。

## Data Flow
描述核心请求如何进入、处理、持久化和返回。

## API / Contract Boundary
说明关键接口、Schema、鉴权和错误结构的权威位置。

## Data Model
列出核心实体和关系，不复制完整数据库 DDL。

## Constraints
性能、安全、部署、兼容性、离线环境等硬约束。

## Architecture Decisions
只记录已经确认且影响长期结构的重要决策；复杂决策可拆 ADR。
```

判断标准：一个新 Codex 会话读取它后，应该能知道“哪些组件能改、哪些边界不能随便跨”。

## 7. docs/DEVELOPMENT.md

所有可复制的本地开发命令集中在这里。

```text
# Development

## Prerequisites
语言、运行时、Docker、数据库等版本要求。

## Setup
从 clone 到第一次成功启动的完整命令。

## Environment
说明 .env.example 中每个必要变量的用途；禁止记录真实密钥。

## Run
前端、后端、依赖服务的启动和停止命令。

## Database
迁移、初始化、测试数据和回退命令。

## Debug
日志位置、健康检查、常见诊断命令。

## Common Problems
只保留高频且已验证的问题。
```

如果 Codex 每次都要猜“怎么启动项目”，说明这份文档不合格。

## 8. docs/TESTING.md

把“完成”变成可执行命令，而不是 AI 的主观判断。

```text
# Testing

## Test Layers
- Unit：纯逻辑
- Integration：数据库/API/外部适配层
- E2E：真实用户关键路径

## Commands
- unit: ...
- integration: ...
- e2e: ...
- lint: ...
- type check: ...
- build: ...

## Quality Gate
普通代码变更至少通过相关测试 + lint/type。
发布前通过完整测试 + build + 关键 E2E。

## Test Rules
- 修 Bug 先增加可复现测试或等价验证
- 不删除失败测试来“通过 CI”
- Mock 只替代不稳定外部边界，不替代核心业务逻辑
```

## 9. 使用 Spec Kit 时的文档职责

GitHub Spec Kit 适合管理**变化中的 Feature**，不要和长期项目文档互相复制。

```text
.specify/memory/constitution.md   项目不可轻易违反的治理原则
specs/001-xxx/spec.md            WHAT / WHY / 验收标准
specs/001-xxx/plan.md            HOW / 架构影响 / 技术方案
specs/001-xxx/tasks.md           可执行任务和验证顺序
```

推荐 Constitution 只保留原则：

```text
1. main 必须保持稳定。
2. 一项 Feature 一个任务分支。
3. 非平凡功能必须先有明确 Spec 和验收标准。
4. 代码完成必须有真实测试/构建证据。
5. 优先最小变更，禁止无关重构。
6. 不提交敏感信息，不绕过安全和质量门禁。
```

不要在 Constitution 里写死大量 shell 命令；具体命令属于 `AGENTS.md`、`DEVELOPMENT.md` 或 CI。

## 10. 不建议重复维护的文件

OpenAI Cookbook 的示例工作流包含 `GOALS.md`、`PLANS.md`、`PROMPTS.md` 等文件，它们适合自定义 harness。但如果项目已经使用 Spec Kit，则通常不必再同时维护这些同义文档：

| 文件 | 使用 Spec Kit 后建议 |
| --- | --- |
| `GOALS.md` | 目标放 README + Feature spec |
| `PLANS.md` | 使用 `specs/*/plan.md` |
| `TODO.md` | 使用 `specs/*/tasks.md` 或 Issue |
| `PROMPTS.md` | 非必要，不把对话历史当项目事实源 |
| `STATUS.md` | 非必要，状态优先由 Git/Issue/PR/测试表达 |
| `NOTES.md` | 临时笔记不要升级为正式项目事实源 |

核心原则：**一个事实只维护一个权威位置。** 文档越多，不代表 Codex 上下文越好；重复和过期文档反而会增加冲突与 Token 消耗。

## 11. Codex 新项目开局顺序

推荐顺序：

```text
创建 Git 仓库
  ↓
确定技术栈和范围
  ↓
README.md
  ↓
AGENTS.md
  ↓
ARCHITECTURE / DEVELOPMENT / TESTING
  ↓
Git + CI 基线
  ↓
初始化 Spec Kit（需要时）
  ↓
从 main 创建任务分支
  ↓
spec → plan → tasks
  ↓
Codex implement
  ↓
verify → PR → Squash Merge
```

开局验收至少满足：

```text
□ Codex 能一句话说明项目目标和非目标
□ Codex 知道核心目录和架构边界
□ Codex 不需要猜启动、测试和构建命令
□ Codex 知道禁止直接在 main 开发
□ 一项 Feature 有独立 Spec / Plan / Tasks
□ CI 能执行至少 lint + test + build 中适用的门禁
□ .env.example 存在，但仓库没有真实密钥
```

满足这些条件后，再让 Codex 大规模实现功能，稳定性通常明显高于“空目录 + 一条长提示词”直接开工。

## 12. 参考项目

- OpenAI Codex：<https://github.com/openai/codex>
- OpenAI Cookbook - Codex development workflow：<https://github.com/openai/openai-cookbook/blob/main/examples/codex/iterating-development-workflows-with-codex.md>
- GitHub Spec Kit：<https://github.com/github/spec-kit>
- FastAPI Full Stack Template：<https://github.com/fastapi/full-stack-fastapi-template>
- Next.js：<https://github.com/vercel/next.js>

相关 Zwiki 文档：

- [Vibe Coding](vibe-coding.md)
- [ChatGPT 与 Codex](chatgpt-codex.md)
