# FDE 技能路线图

这是一份面向 AI 辅助开发场景的 FDE（Forward Deployed Engineer）技能清单。目标不是让新人一次学完所有技术，而是按难度逐级形成能力：先能看懂和修改，再能独立完成前后端项目，最后能稳定交付 Agent、客户现场服务和生产系统。

本文只维护“学什么、学到什么程度”。具体开发流程见 [Vibe Coding](vibe-coding.md)，项目开局规则见 [Codex 项目开局规范](codex-project-bootstrap.md)，具体技术栈与工具索引见 [开发 / 技术栈与工具](../../development/tooling/README.md)，避免重复维护。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | FDE / AI Coding / Web 全栈 / Agent |
| 适用范围 | 零基础到可独立交付前端、后端、Agent 项目 |
| 技术基线 | React + TypeScript + Vite、FastAPI + PostgreSQL、Docker Compose；Go 用于客户机单文件服务 |
| 文档状态 | 已整理 |
| 最后验证 | 2026-09-08 |
| 来源 | FDE 开发规范、现有 FDE 通用技能表、Zwiki 现有 AI Coding 规范 |

## 1. 难度分级

| 等级 | 定位 | 达标标准 |
| --- | --- | --- |
| **L0 基础** | 完全零基础必须掌握 | 能看懂项目、运行环境、HTTP 请求和 Git 变更，能在 AI 辅助下完成小修改 |
| **L1 初级** | 能独立做简单项目 | 能用 AI 完成一个带真实 API 的 CRUD 前后端项目，并自己验收 |
| **L2 中级** | 能稳定交付 | 能设计接口、权限、测试、CI、Docker 和回滚，项目可被别人接手 |
| **L3 高级** | FDE / Agent / 客户现场 | 能处理 Agent、RAG、MCP、复杂集成、客户环境和生产问题 |

推荐学习顺序：**L0 全部完成 → L1 全部完成 → 用真实项目巩固 → L2 → 按项目需要学习 L3**。

---

## 2. FDE 与 AI 协作

| 等级 | 技能 | 最小验收标准 |
| --- | --- | --- |
| L0 | 理解 FDE 端到端职责 | 能说明需求发现、技术范围、设计、开发、上线、验收和反馈之间的关系 |
| L0 | 把需求写成可验收规格 | 写清目标、非目标、输入输出、边界条件、失败路径和验收命令 |
| L0 | 固定项目技术栈 | 开发前明确前端、后端、数据库、测试和部署方案，禁止 AI 自行换栈 |
| L0 | 分阶段 Gate 开发 | 当前阶段验收未通过时，不允许进入下一阶段 |
| L0 | Inspect → Plan → Patch → Verify | AI 修改前先读项目、给最小计划、小步改动并执行真实验证 |
| L1 | 先设计再编码 | 编码前产出页面清单、接口契约、数据模型和主要数据流 |
| L1 | AI 代码 Review | 能检查依赖、错误路径、类型、日志、Secret、无关修改和可维护性 |
| L2 | 范围、风险和阻塞管理 | 能识别依赖、非目标、关键路径、风险和回退点 |
| L2 | 客户沟通与验收 | 能用简洁文档说明问题、方案、进度、风险、验收结果和下一步 |
| L3 | 知识转移与持续反馈 | 能把项目交给客户或同事维护，并把现场反馈转成下一轮工程改进 |

> FDE 开发的流程性约束统一维护在 [Vibe Coding](vibe-coding.md)，本页不重复展开 Prompt 模板和 Gate 细节。

## 3. Git、协作与 CI

| 等级 | 技能 | 最小验收标准 |
| --- | --- | --- |
| L0 | Git 工作区、暂存区和提交 | 能解释 working tree、staging、commit 的区别 |
| L0 | status / diff / add / commit | 提交前能看清修改，只提交本次任务相关文件 |
| L0 | branch / switch / fetch / pull / push | 能完成 feature 分支从创建到推送的完整流程 |
| L1 | Merge Request / Pull Request | 能提交可审查的 PR/MR，说明改动、验证结果和风险 |
| L1 | merge / rebase / 冲突处理 | 能制造并解决一次真实冲突，不破坏主分支历史 |
| L1 | restore / revert / reflog | 能安全撤销错误修改并恢复误删提交 |
| L2 | CI 质量门禁 | Push/PR 后自动执行 lint、typecheck、test、build，失败时禁止合并 |
| L2 | 依赖和锁文件治理 | 锁文件必须提交；升级依赖前先核对版本变化并执行回归验证 |

## 4. Web、浏览器与网络基础

| 等级 | 技能 | 最小验收标准 |
| --- | --- | --- |
| L0 | HTML 语义结构 | 能用 header、nav、main、form、table 等元素搭出页面骨架 |
| L0 | CSS 盒模型与层叠 | 理解 margin、padding、border、选择器、继承和优先级 |
| L0 | Flexbox 与 Grid | 能完成常见左右布局、居中和卡片网格，不依赖大量绝对定位 |
| L0 | JavaScript 基础与异步 | 掌握变量、函数、数组对象、模块、Promise 和 async/await |
| L0 | HTTP / REST / JSON | 能解释 URL、Method、Header、Body、状态码和 JSON 数据 |
| L0 | CORS 与代理 | 能说明为什么跨域，并用 Vite proxy 或后端 CORS 正确解决 |
| L0 | 浏览器 DevTools | 会使用 Elements、Console、Network、Storage 和响应式模式定位问题 |
| L1 | 响应式与跨浏览器验收 | 页面在桌面、平板、手机可用，并验证关键浏览器兼容性 |

## 5. UI / UX 与视觉设计

| 等级 | 技能 | 最小验收标准 |
| --- | --- | --- |
| L0 | 从用户任务设计信息架构 | 先确定用户要完成的任务，再设计菜单、页面和主次操作 |
| L0 | 低保真线框图 | 编码前画出导航、内容区、表格、表单、弹窗和主要流程 |
| L0 | 视觉层级与排版 | 能通过字号、字重、留白、对齐和对比建立清晰层级 |
| L1 | Design Tokens | 统一颜色、字号、间距、圆角、阴影等设计变量 |
| L1 | 间距、颜色和状态语义 | 页面使用稳定的间距体系，并统一 success/warning/error/info 语义 |
| L1 | 组件优先 | Button、Form、Table、Dialog 等优先使用成熟组件，不让 AI 重造基础控件 |
| L1 | 完整页面状态 | 每个数据页面同时考虑 Loading、Empty、Error、Success、No Permission |
| L1 | 表单交互与反馈 | 必填、校验、提交中、成功、失败、危险操作确认都有明确反馈 |
| L2 | 无障碍与键盘操作 | 关键操作可键盘完成，表单有 Label/ARIA，颜色不是唯一信息来源 |
| L2 | AI 视觉验收 | 使用截图或 Playwright 对照检查布局、间距、字体、颜色和响应式 |

## 6. React 前端工程

| 等级 | 技能 | 最小验收标准 |
| --- | --- | --- |
| L0 | TypeScript strict | 能使用 interface/type、联合类型、类型收窄，并避免滥用 any |
| L0 | Vite + React 项目初始化 | 能创建 React + TypeScript 项目并完成开发和生产构建 |
| L0 | 组件、Props 与 State | 能合理拆组件并完成父子数据和事件传递 |
| L0 | Hooks 与副作用 | 正确使用 useState、useEffect、useRef 和自定义 Hook |
| L1 | 路由与页面骨架 | 能完成登录、列表、详情、设置等路由和统一 Layout |
| L1 | Ant Design 企业后台 | 能使用 Layout、Table、Form、Modal、Drawer、Tabs 等完成后台页面 |
| L1 | API 层与类型隔离 | 页面不散落 fetch；建立统一 API Client、类型和错误处理 |
| L2 | TanStack Query | 使用 Query/Mutation 管理缓存、分页、重试、刷新和服务端状态 |
| L2 | React Hook Form + Zod | 复杂表单使用统一 Schema 校验，不把规则散落到各组件 |
| L2 | Tailwind + shadcn/ui | 产品型 UI 需要更自由视觉时使用；与 Ant Design 不无原则混搭 |
| L2 | 图标与数据可视化 | 图标风格统一；复杂业务图表使用 ECharts 等成熟组件 |
| L2 | 前端自动测试 | 核心逻辑有单测，关键用户路径至少有一条 Playwright E2E |

## 7. Python、FastAPI 与数据库

| 等级 | 技能 | 最小验收标准 |
| --- | --- | --- |
| L0 | Python 工程环境 | 能创建虚拟环境、安装锁定依赖、读取环境变量并运行程序 |
| L0 | Python 基础数据处理 | 能处理列表、字典、JSON、YAML、文件和 HTTP API |
| L1 | FastAPI 路由与 OpenAPI | 能实现 GET/POST/PUT/DELETE，并理解自动 API Schema |
| L1 | Pydantic 数据模型 | 请求、响应和配置都有类型校验，不直接传任意 dict |
| L1 | SQL 与 PostgreSQL | 掌握表、主键、外键、SELECT、JOIN 和 CRUD |
| L1 | 分层与依赖注入 | 按 api/service/repository/model/config 分层，不把逻辑塞进路由 |
| L2 | SQLAlchemy / SQLModel | 能设计模型、Session、查询、关系和事务边界 |
| L2 | Alembic 数据库迁移 | Schema 变更可重复执行、可追踪，并有回退方案 |
| L2 | 认证与 RBAC | 登录、身份认证、角色和服务端权限检查完整 |
| L2 | 统一错误、日志和 Request ID | 客户端得到稳定错误结构，日志能关联一次请求且不泄露 Secret |
| L2 | 后端自动测试 | service、API、权限和数据库关键路径具备 pytest 测试 |

## 8. 前后端整合与稳定交付

| 等级 | 技能 | 最小验收标准 |
| --- | --- | --- |
| L1 | 契约优先开发 | 编码前固定 OpenAPI / JSON Schema，前端和后端禁止各自猜字段 |
| L1 | 完整 CRUD 业务流 | 列表、详情、新增、编辑、删除、搜索、分页和错误处理端到端跑通 |
| L2 | 类型化前端客户端 | 前端接口类型从 OpenAPI 生成或集中维护，避免前后端类型漂移 |
| L2 | 登录与权限端到端 | 登录 → 会话 → API 鉴权 → 401/403 → 退出完整验证 |
| L2 | 上传、下载和长任务 | 正确处理文件、进度、超时、取消和后台任务 |
| L2 | Docker Compose 全栈启动 | Frontend、Backend、DB 等服务可一条命令启动，数据持久化明确 |
| L2 | 性能与体验检查 | 避免重复请求、无意义重渲染和过大 Bundle，关注首屏与交互延迟 |
| L2 | 部署、备份和回滚 Runbook | 陌生同事可按文档完成部署、升级、备份、恢复和回滚 |
| L3 | 流式响应与实时 UI | 能使用 SSE / Streaming 为 Agent、日志或任务进度提供增量界面 |

## 9. Agent 与 AI 应用

| 等级 | 技能 | 最小验收标准 |
| --- | --- | --- |
| L2 | Responses API | 后端安全调用模型，支持结构化输出、错误处理和基本流式响应 |
| L2 | Agents SDK 与 Tool Calling | 能定义 Agent、工具 Schema、执行边界和工具结果回传 |
| L2 | MCP 工具接入 | 理解 Client / Server / Tool，并连接一个真实 MCP Server |
| L2 | 文件检索 / RAG | 导入文档、检索相关内容，并在答案中给出可追溯引用 |
| L3 | Agent Evals | 使用固定测试集对答案质量、工具选择和回归变化进行评估 |
| L3 | Guardrails 与权限边界 | 高风险工具有参数校验、最小权限和必要的人工确认 |
| L3 | Tracing 与故障诊断 | 能查看模型调用、工具调用、耗时、异常和上下文链路 |
| L3 | 高质量 Agent 对话 UI | 展示流式文本、工具调用、引用、结构化结果、取消和错误状态 |

## 10. Go 与客户现场服务

Go 不是 Web 全栈的第一学习后端，而是 FDE 在客户机、离线环境和单文件交付场景中的补充能力。

| 等级 | 技能 | 最小验收标准 |
| --- | --- | --- |
| L2 | Go 基础与 Module | 能建立 go.mod，理解 struct、interface、error 和包结构 |
| L2 | Gin REST 服务 | 能完成路由、JSON 校验、中间件、日志和基本测试 |
| L2 | GORM 数据访问 | 能连接数据库并完成模型、迁移和 CRUD |
| L3 | 交叉编译单文件交付 | 构建 Linux / Windows 目标产物，并在客户机真实启动验证 |

## 11. 学习里程碑

### L0 完成：能跟着 AI 开发

应能做到：

- 看懂一个现有仓库的大致结构；
- 使用 Git 安全修改和提交；
- 理解浏览器、HTTP、前端和后端之间的基本关系；
- 能让 AI 按 Gate 小步实现功能，而不是一次性生成整个项目；
- 能自己运行命令判断“到底有没有成功”。

### L1 完成：能独立做一个简单全栈项目

至少独立完成一次：

```text
需求规格
→ 页面和 API 设计
→ React 管理页面
→ FastAPI CRUD
→ PostgreSQL
→ 前后端联调
→ Git PR/MR
→ 实际验收
```

### L2 完成：能稳定交付项目

项目至少具备：

- 类型约束；
- 权限；
- 自动测试；
- CI；
- Docker Compose；
- 日志和错误处理；
- README / Runbook；
- 可回滚的 Git 历史。

达到这一阶段后，才适合把主要精力转向 Agent、复杂集成和客户现场问题。

### L3 完成：具备 FDE 高级扩展能力

能够独立处理：

- Agent / Tool Calling / MCP / RAG；
- Evals、Guardrails、Tracing；
- 流式 AI WebUI；
- 客户现场离线部署和 Go 单文件服务；
- 复杂系统联调、故障定位、交付和知识转移。

## 12. 去重说明

整理时检查了当前 Zwiki `ai/`、`ai/coding/` 和 `development/` 目录：

- [Vibe Coding](vibe-coding.md) 已负责 AI 开发流程、Gate 和验证规范，本页只列技能，不复制完整流程。
- [Codex 项目开局规范](codex-project-bootstrap.md) 已负责新项目目录、Markdown 基线和开工规则，本页不重复模板。
- [开发 / 技术栈与工具](../../development/tooling/README.md) 已负责具体工具和技术栈索引，本页不重复维护资源大全。
- 当前没有其他“FDE 技能路线图”页面，因此本页作为唯一技能清单。

技能表内部没有发现完全重复项。对语义接近内容做了合并，例如“响应式开发 + 跨浏览器验收”“Design Tokens + 间距/颜色规范”；而“本地质量门禁 vs CI 门禁”“后端 RBAC vs 登录权限端到端”职责不同，保留为独立技能。

## 相关文档

- [Vibe Coding](vibe-coding.md)
- [Codex 项目开局规范](codex-project-bootstrap.md)
- [ChatGPT 与 Codex](chatgpt-codex.md)
- [AI 资源](../resources.md)
- [开发 / 技术栈与工具](../../development/tooling/README.md)
