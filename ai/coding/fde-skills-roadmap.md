# FDE 60 天必备技能表

这是一份面向 AI 辅助开发场景的 FDE（Forward Deployed Engineer）每日训练表。目标不是 60 小时后达到 OpenAI FDE 的招聘资历，而是用 **每天 1 小时**，从零开始建立一套可执行的 FDE 基础能力：能让 AI 稳定完成前端、后端和 Agent 项目，能自己验收结果，并逐步具备客户发现、技术范围、系统设计、生产交付和复盘沉淀能力。

OpenAI 当前 FDE 岗位强调端到端交付：从 discovery、technical scoping、system design、build 到 production rollout，并通过 production adoption、workflow impact 和 eval-driven feedback 衡量结果。FDSWE 岗位同时强调 full-stack、迭代式开发、客户现场协作和可复用工程抽象。因此本表不是传统“前端课 + 后端课”的拼接，而是按 FDE 实际交付顺序设计。

> OpenAI 当前通用 FDE 岗位通常要求 5+ 年工程或技术部署经验，并包含 customer-facing 工作。真实项目经验不能由课程替代；本表解决的是“每天练什么、练到什么程度”。

## 使用方法

每天只做一行，不建议跳级。固定 1 小时：

```text
15 分钟：阅读当天资料，只看与任务直接相关的部分
35 分钟：让 AI 辅助完成当天动手任务
10 分钟：自己执行命令、操作页面或检查结果，完成验收
```

执行规则：

1. **当天未验收通过，不进入下一天。**
2. AI 必须遵循 [Vibe Coding](vibe-coding.md) 的 `Inspect → Plan → Patch → Verify`。
3. 不要求背语法；要求能解释关键概念、能让 AI 正确实现、能识别明显错误、能亲自验收。
4. 默认全栈技术基线：`React + TypeScript + Vite + Ant Design + FastAPI + PostgreSQL + Docker Compose`。
5. Go 是客户机单文件服务补充能力；Agent 主线使用 OpenAI API / Agents SDK / MCP。

---

## 第 1 阶段：开发与 AI 基础（Day 1–10）

| Day | 难度 | 技能类型 | 今日技能 | 1 小时任务 / 验收 | 在线学习资源 |
| ---: | --- | --- | --- | --- | --- |
| 1 | L0 | FDE | 理解 FDE 是什么 | 阅读 OpenAI FDE 岗位；用自己的话写出 `发现问题 → 设计 → 开发 → 上线 → 反馈` 五步职责 | [OpenAI FDE](https://openai.com/careers/forward-deployed-engineer-%28fde%29-seattle-seattle/) |
| 2 | L0 | AI Coding | 把需求写成可验收任务 | 选一个小功能，写清目标、非目标、输入、输出、异常、验收方式 | [Zwiki：Vibe Coding](vibe-coding.md) |
| 3 | L0 | AI Coding | Gate 分阶段开发 | 把一个小项目拆成 3 个 Gate，并为每个 Gate 写“通过条件” | [Zwiki：Vibe Coding](vibe-coding.md) |
| 4 | L0 | Linux / CLI | 终端、目录和文件 | 完成 `pwd/ls/cd/mkdir/cp/mv/rm/cat/grep` 基本操作，并能找到项目日志和配置文件 | [Linux 101](https://101.lug.ustc.edu.cn/) |
| 5 | L0 | 网络 | HTTP / REST / JSON | 用浏览器 Network 或 `curl` 请求一个 API，指出 Method、Header、Body、Status Code | [MDN HTTP 中文](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Guides/Overview) |
| 6 | L0 | Git | 工作区、暂存区、提交 | 新建仓库，修改文件并完成 `status → diff → add → commit` | [Pro Git 中文版](https://git-scm.com/book/zh/v2) |
| 7 | L0 | Git | 分支和远端 | 创建 feature 分支，完成一次 `switch/push/pull` | [Pro Git 中文版](https://git-scm.com/book/zh/v2) |
| 8 | L0 | Git | PR / MR | 在测试仓库提交一次 Pull Request，并写改动说明和验证结果 | [GitHub PR 中文文档](https://docs.github.com/zh/pull-requests) |
| 9 | L0 | Git | 回退与恢复 | 制造一次错误修改，分别练习 `restore`、`revert`；知道 reflog 用于什么 | [Pro Git 中文版](https://git-scm.com/book/zh/v2) |
| 10 | L0 | AI Coding | AI Code Review | 让 AI 生成一段有明显问题的代码，人工检查硬编码、Secret、未处理异常、无关改动，并要求修复 | [GitHub Copilot 提示工程](https://docs.github.com/zh/copilot/concepts/prompting/prompt-engineering) |

**阶段验收：** 能安全使用 Git 修改项目；能把需求拆成小任务；能判断 AI 是否真的完成，而不是只相信回复文字。

---

## 第 2 阶段：Web 与 UI 基础（Day 11–20）

| Day | 难度 | 技能类型 | 今日技能 | 1 小时任务 / 验收 | 在线学习资源 |
| ---: | --- | --- | --- | --- | --- |
| 11 | L0 | Web | HTML 语义结构 | 手写或让 AI 生成一个含 Header、Nav、Main、Form、Table 的页面，并能解释各区域 | [MDN 学习 Web 开发](https://developer.mozilla.org/zh-CN/docs/Learn_web_development) |
| 12 | L0 | Web | CSS 盒模型 | 修改 margin、padding、border、width，使用 DevTools 验证盒模型变化 | [MDN CSS 中文](https://developer.mozilla.org/zh-CN/docs/Learn_web_development/Core/Styling_basics) |
| 13 | L0 | Web | Flexbox / Grid | 完成一个左侧菜单 + 主内容区和一个三列卡片布局 | [MDN CSS 布局](https://developer.mozilla.org/zh-CN/docs/Learn_web_development/Core/CSS_layout) |
| 14 | L0 | Web | JavaScript 基础 | 完成变量、数组、对象、函数、条件和循环的小练习 | [MDN JavaScript 中文](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Guide) |
| 15 | L0 | Web | 异步与 fetch | 用 `fetch + async/await` 请求一个 JSON API，并把结果输出到页面 | [MDN JavaScript 中文](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Guide) |
| 16 | L0 | Web | 浏览器 DevTools | 用 Elements、Console、Network、Storage 定位一个前端报错 | [Chrome DevTools 中文](https://developer.chrome.com/docs/devtools?hl=zh-cn) |
| 17 | L0 | UI / UX | 信息架构和线框图 | 为“用户管理”画列表页、详情页、新增页的低保真线框图 | [Ant Design 设计体系](https://ant.design/docs/spec/introduce-cn/) |
| 18 | L0 | UI / UX | 视觉层级与 Design Token | 固定字号、主色、间距、圆角；把一个杂乱页面改成统一风格 | [Ant Design 设计价值观](https://ant.design/docs/spec/values-cn/) |
| 19 | L0 | UI / UX | 页面状态 | 为列表页补齐 Loading、Empty、Error、Success、No Permission 五种状态 | [Ant Design 组件总览](https://ant.design/components/overview-cn/) |
| 20 | L0 | UI / UX | 响应式与基础无障碍 | 用手机宽度检查页面；确保表单有 Label、按钮可聚焦、页面无明显横向溢出 | [MDN Web 学习区](https://developer.mozilla.org/zh-CN/docs/Learn_web_development) |

**阶段验收：** 能读懂普通 Web 页面结构，能借助 AI 做出布局合理、视觉一致、有完整状态的基础页面。

---

## 第 3 阶段：React 前端工程（Day 21–30）

| Day | 难度 | 技能类型 | 今日技能 | 1 小时任务 / 验收 | 在线学习资源 |
| ---: | --- | --- | --- | --- | --- |
| 21 | L1 | TypeScript | TypeScript strict | 学会基础类型、interface/type、联合类型；项目开启 strict，不用 `any` 逃避错误 | [TypeScript 中文文档](https://www.typescriptlang.org/zh/docs/) |
| 22 | L1 | React | Vite + React 初始化 | 创建 React + TypeScript + Vite 项目，能 `dev` 和 `build` | [Vite 中文指南](https://cn.vite.dev/guide/) |
| 23 | L1 | React | 组件、Props、State | 拆出父组件和两个子组件，完成数据传递和按钮更新状态 | [React 中文快速入门](https://zh-hans.react.dev/learn) |
| 24 | L1 | React | Hooks | 使用 `useState/useEffect/useRef` 完成搜索框和数据加载 | [React 中文文档](https://zh-hans.react.dev/learn) |
| 25 | L1 | React | 路由与 Layout | 创建登录、列表、详情、设置四个路由和统一页面框架 | [React Router](https://reactrouter.com/home) |
| 26 | L1 | 前端组件 | Ant Design | 用 Layout、Menu、Table、Form、Modal、Drawer 完成一个管理页面 | [Ant Design React 中文](https://ant.design/docs/react/introduce-cn/) |
| 27 | L1 | 前端工程 | API Client 与类型 | 建立统一 `api/` 层，禁止页面散落 `fetch`；请求和响应都有 TS 类型 | [Bulletproof React](https://github.com/alan2207/bulletproof-react) |
| 28 | L1 | 前端工程 | TanStack Query | 对列表请求实现 loading、error、缓存和刷新 | [TanStack Query](https://tanstack.com/query/latest/docs/framework/react/overview) |
| 29 | L1 | 前端工程 | 表单校验 | 使用 React Hook Form + Zod 完成一个带必填、格式和错误提示的表单 | [React Hook Form](https://react-hook-form.com/) / [Zod](https://zod.dev/) |
| 30 | L1 | 前端质量 | Build + E2E + 视觉验收 | `lint/build` 全通过；用浏览器完整走一遍新增、编辑、删除流程并截图验收 | [Playwright 官方](https://playwright.dev/docs/intro) |

**阶段验收：** 能在 AI 辅助下独立产出一个结构清晰、美观、可构建的 React 企业后台页面，而不是只会生成静态 Demo。

---

## 第 4 阶段：Python、FastAPI 与数据库（Day 31–40）

| Day | 难度 | 技能类型 | 今日技能 | 1 小时任务 / 验收 | 在线学习资源 |
| ---: | --- | --- | --- | --- | --- |
| 31 | L1 | Python | Python 环境与依赖 | 建立虚拟环境、安装依赖、读取环境变量，能解释 requirements/pyproject 的作用 | [Python 官方中文教程](https://docs.python.org/zh-cn/3/tutorial/) |
| 32 | L1 | Python | 数据结构、文件和 JSON | 读取 JSON 文件，处理列表/字典并输出新文件 | [Python 官方中文教程](https://docs.python.org/zh-cn/3/tutorial/) |
| 33 | L1 | Python | HTTP API 与异常 | 调用一个 HTTP API，加入 timeout、异常捕获和日志 | [Requests 中文文档](https://requests.readthedocs.io/projects/cn/zh-cn/latest/) |
| 34 | L1 | FastAPI | 路由与 OpenAPI | 创建 `GET/POST/PUT/DELETE` 四类接口并打开 `/docs` 查看 Schema | [FastAPI 中文教程](https://fastapi.tiangolo.com/zh/tutorial/) |
| 35 | L1 | FastAPI | Pydantic 模型 | 为请求、响应和配置建立模型，让非法参数返回明确错误 | [FastAPI 中文教程](https://fastapi.tiangolo.com/zh/tutorial/) |
| 36 | L1 | 后端架构 | 分层与依赖注入 | 把路由、业务逻辑、数据访问拆开，至少形成 `api/service/repository` | [FastAPI 中文教程](https://fastapi.tiangolo.com/zh/tutorial/) |
| 37 | L1 | 数据库 | SQL / PostgreSQL | 创建两张有关联的表，完成 Insert、Select、Join、Update、Delete | [PostgreSQL 中文教程](https://postgresql.ac.cn/docs/current/tutorial.html) |
| 38 | L2 | 数据库 | ORM 与 Migration | 使用 SQLAlchemy/SQLModel 建模，并完成一次 Alembic Migration | [SQLModel](https://sqlmodel.tiangolo.com/) / [Alembic](https://alembic.sqlalchemy.org/) |
| 39 | L2 | 后端安全 | 登录、认证与 RBAC | 实现一个登录接口和两种角色；验证无权限请求被服务端拒绝 | [FastAPI 安全教程](https://fastapi.tiangolo.com/zh/tutorial/security/) |
| 40 | L2 | 后端质量 | 错误、日志、Request ID、pytest | 统一错误结构；为一个 Service 和一个 API 写测试并通过 | [pytest 中文站](https://pytest.cn/en/stable/getting-started.html) |

**阶段验收：** 能在 AI 辅助下完成真实数据库 CRUD API，具备类型校验、分层、权限、日志和基础测试。

---

## 第 5 阶段：全栈稳定交付（Day 41–50）

| Day | 难度 | 技能类型 | 今日技能 | 1 小时任务 / 验收 | 在线学习资源 |
| ---: | --- | --- | --- | --- | --- |
| 41 | L2 | 全栈 | API 契约优先 | 开发前先固定一个功能的 URL、Method、Request/Response Schema，前后端都按契约实现 | [FastAPI OpenAPI](https://fastapi.tiangolo.com/zh/how-to/extending-openapi/) |
| 42 | L2 | 全栈 | CRUD 端到端 | 打通 React → FastAPI → PostgreSQL 的列表、新增、编辑、删除 | [FastAPI Full Stack Template](https://github.com/fastapi/full-stack-fastapi-template) |
| 43 | L2 | 全栈 | 登录权限端到端 | 验证 Login → Session/Token → API → 401/403 → Logout 全流程 | [FastAPI 安全教程](https://fastapi.tiangolo.com/zh/tutorial/security/) |
| 44 | L2 | 全栈 | 文件与长任务 | 完成一次上传/下载；理解耗时任务为什么不能阻塞普通 HTTP 请求 | [FastAPI 文件上传](https://fastapi.tiangolo.com/zh/tutorial/request-files/) |
| 45 | L2 | Docker | 镜像基础 | 为前端或后端写 Dockerfile，构建并启动容器 | [Docker 从入门到实践](https://docker-practice.github.io/zh-cn/) |
| 46 | L2 | Docker | Docker Compose | 前端、后端、PostgreSQL 一条命令启动，并验证数据持久化 | [Docker 从入门到实践](https://docker-practice.github.io/zh-cn/) |
| 47 | L2 | CI/CD | GitHub Actions CI | Push/PR 自动执行 lint、test、build，制造一次失败确认 Gate 生效 | [GitHub Actions 中文文档](https://docs.github.com/zh/actions) |
| 48 | L2 | 可运维性 | 健康检查与可观测性 | 增加 `/healthz`；日志能定位请求，至少能看到失败原因和耗时 | [OpenTelemetry 中文文档](https://opentelemetry.io/zh/docs/) |
| 49 | L2 | 交付 | 备份、恢复和回滚 | 写一页 Runbook：部署、升级、数据库备份、恢复、Git/Docker 回滚 | [Docker 从入门到实践](https://docker-practice.github.io/zh-cn/) |
| 50 | L2 | 综合验收 | 完整项目验收 | 从新环境按 README 启动项目，跑测试、构建、登录和一条核心业务流程；全部通过才算完成 | [Zwiki：Vibe Coding](vibe-coding.md) |

**阶段验收：** 项目不再只是“我电脑能跑”，而是别人可按文档启动、验证、升级和回退。

---

## 第 6 阶段：Agent 与 FDE 高级能力（Day 51–60）

| Day | 难度 | 技能类型 | 今日技能 | 1 小时任务 / 验收 | 在线学习资源 |
| ---: | --- | --- | --- | --- | --- |
| 51 | L2 | LLM API | OpenAI API / Responses | 后端完成一次模型调用，并使用环境变量管理 Key；处理超时和失败 | [OpenAI API Quickstart](https://developers.openai.com/api/docs/quickstart) |
| 52 | L2 | Agent | Tool Calling / 结构化输出 | 定义一个工具 Schema，让模型正确调用工具并返回结构化结果 | [OpenAI Agents SDK 简中](https://openai.github.io/openai-agents-python/zh/) |
| 53 | L2 | Agent | Agents SDK | 创建一个最小 Agent，包含 instructions、tool 和 session/context | [OpenAI Agents SDK 简中](https://openai.github.io/openai-agents-python/zh/) |
| 54 | L2 | Agent | MCP | 连接一个受信任 MCP Server，列出工具并成功调用一次；说明最小权限原则 | [Agents SDK MCP 简中](https://openai.github.io/openai-agents-python/zh/mcp/) |
| 55 | L2 | Agent | RAG / 文件检索 | 导入几份资料，回答一个问题并给出可追溯来源；人工检查引用是否支持结论 | [OpenAI Cookbook](https://github.com/openai/openai-cookbook) |
| 56 | L3 | Agent 质量 | Evals、Tracing、Guardrails | 建 5 条固定测试问题，记录成功/失败；查看一次 Trace；为高风险 Tool 增加审批或校验 | [OpenAI Agents SDK 简中](https://openai.github.io/openai-agents-python/zh/) |
| 57 | L2 | Go / 现场服务 | Go + Gin | 创建最小 Gin `/ping` 服务，理解 Module、struct、error，并构建二进制 | [Gin 中文快速入门](https://gin-gonic.com/zh-cn/docs/quickstart/) |
| 58 | L3 | Go / 现场服务 | GORM + 单文件交付 | 用 GORM 做最小 CRUD；交叉编译一个 Linux/Windows 目标二进制并启动验证 | [GORM 中文文档](https://gorm.io/zh_CN/docs/index.html) |
| 59 | L3 | FDE | Discovery、Scoping、System Design | 选择一个真实业务场景，写：现状工作流、痛点、成功指标、范围/非范围、架构图、风险、分阶段交付计划 | [OpenAI FDE](https://openai.com/careers/forward-deployed-engineer-%28fde%29-seattle-seattle/) |
| 60 | L3 | FDE | Prototype → Production → Adoption → Handoff | 为 Day 59 场景写一页交付方案：Prototype 验收、生产上线条件、采用指标、Eval 反馈、回退、客户交接、可复用 Playbook | [OpenAI FDSWE](https://openai.com/careers/forward-deployed-software-engineer-seattle-seattle/) |

**阶段验收：** 不只会调用模型，而是开始理解如何把 AI 系统安全地放进真实工作流，并能从客户问题一路推进到生产、验收和交接。

---

## 60 天完成后应该达到什么程度

完成全部 60 天，至少应能独立完成一次以下闭环：

```text
客户 / 用户问题
→ 需求与成功标准
→ 技术范围与架构
→ React 前端
→ FastAPI 后端
→ PostgreSQL
→ Git / PR
→ 自动测试与 CI
→ Docker Compose
→ Agent / Tool / RAG（需要时）
→ 实际验收
→ 部署与回滚
→ README / Runbook / Handoff
```

如果其中任何一步仍只能“让 AI 自己决定并相信它”，就说明对应技能还没有过关，应返回那一天重复练习。

这 60 小时的目标是**熟悉 FDE 必备技能和正确工作方式**，不是达到高级工程师熟练度。OpenAI FDE 当前招聘中要求的多年工程、客户现场和生产交付经验，仍然需要通过真实项目长期积累。

## 推荐长期循环

60 天后不再继续无限增加课程，而是反复做真实小项目：

1. 每个项目都执行 `需求 → Gate → 实现 → Verify → 交付`。
2. 每次项目只补当前暴露出来的短板。
3. 优先增加真实用户、真实数据库、真实部署和真实故障场景。
4. 把成功方案沉淀为模板、脚手架、Skill、Runbook 或 Playbook。

这比继续刷更多框架，更接近 OpenAI FDE 所要求的“从现场问题到生产系统，再把经验反哺产品和可复用工程资产”的能力模型。

## 主要依据

- [OpenAI Forward Deployed Engineer - Seattle](https://openai.com/careers/forward-deployed-engineer-%28fde%29-seattle-seattle/)
- [OpenAI Forward Deployed Software Engineer - Seattle](https://openai.com/careers/forward-deployed-software-engineer-seattle-seattle/)
- [OpenAI FDE Healthcare](https://openai.com/careers/forward-deployed-engineer-%28fde%29-healthcare-sf-san-francisco/)
- [Vibe Coding](vibe-coding.md)
- [Codex 项目开局规范](codex-project-bootstrap.md)
- [开发 / 技术栈与工具](../../development/tooling/README.md)
