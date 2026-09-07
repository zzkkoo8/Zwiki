# FDE 技能路线图

这是一份面向 AI 辅助开发场景的 FDE（Forward Deployed Engineer）技能路线。目标不是一次学完所有技术，而是按难度逐级形成能力：**先能看懂和修改 → 能独立做前后端项目 → 能稳定生产交付 → 能承担客户现场与 Agent 系统的端到端责任**。

本文结合 Zwiki 现有 FDE / Vibe Coding 规范，并参考 OpenAI 当前 Forward Deployed Engineer、Forward Deployed Software Engineer 及垂直行业 FDE 招聘要求整理。具体开发流程见 [Vibe Coding](vibe-coding.md)，项目开局规则见 [Codex 项目开局规范](codex-project-bootstrap.md)，技术栈和工具索引见 [开发 / 技术栈与工具](../../development/tooling/README.md)。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | FDE / AI Coding / Web 全栈 / Agent |
| 适用范围 | 零基础到可独立交付前端、后端、Agent 与客户现场项目 |
| 默认技术基线 | React + TypeScript + Vite、FastAPI + PostgreSQL、Docker Compose；Go 用于客户机单文件服务 |
| 文档状态 | 已按 OpenAI FDE 当前招聘要求复核 |
| 最后验证 | 2026-09-08 |
| 主要来源 | OpenAI Careers FDE / FDSWE、FDE 开发规范、Zwiki AI Coding 规范 |

## 1. OpenAI 当前 FDE 岗位能力画像

OpenAI 当前 FDE 岗位的共性并不是“某一个框架熟练”，而是**端到端技术交付能力**。官方岗位描述反复强调以下职责：

- 从 discovery、technical scoping、system design、build 一直到 production rollout 全程负责；
- 从第一版 prototype 推进到 stable production，并以真实生产采用和业务效果判断成功；
- 能写和 Review 生产级前端、后端代码，常见语言包括 Python、JavaScript 或同类技术栈；
- 能构建和部署 LLM / generative AI 系统，并理解模型行为如何影响产品体验；
- 深入客户团队，理解业务流程、技术限制和真实使用场景；
- 能拆范围、安排交付顺序、提前发现阻塞，并在 scope / speed / quality 之间做权衡；
- 使用 eval-driven feedback、错误分析和现场反馈持续改进系统；
- 把成功经验沉淀成工具、playbook、reference architecture 或可复用 building blocks；
- 能与客户工程师、产品、研究、安全、GRC、GTM 等不同角色清晰协作；
- 在受监管或高风险场景中进一步处理隐私、安全、授权、治理、审计、human review、escalation 和 launch criteria。

### 经验门槛不是技能项

OpenAI 当前通用 FDE 岗位通常要求 **5+ 年工程或技术部署经验，并包含 customer-facing 工作**；医疗等垂直 FDE 岗位可要求 6+ 年相关经验。

这类要求无法通过“看完课程”获得，因此本路线将其视为**工作经验门槛**，而不是某一条学习技能。技能表解决的是“应该具备哪些能力以及如何验证”，真实项目负责年限仍需在工作中积累。

## 2. 难度分级与学习顺序

| 等级 | 定位 | 达标标准 |
| --- | --- | --- |
| **L0 基础** | 完全零基础 | 能看懂项目、运行环境、HTTP 请求和 Git 变更，在 AI 辅助下安全完成小修改 |
| **L1 初级** | 独立完成简单项目 | 能用 AI 完成一个带真实 API、数据库和页面的 CRUD 全栈项目，并自己验收 |
| **L2 中级** | 稳定生产交付 | 能负责接口、权限、测试、CI、Docker、日志、部署、回滚和基本可观测性 |
| **L3 高级** | 对标 FDE 职责 | 能负责客户发现、复杂系统设计、Agent/Evals、生产采用、风险权衡、handoff 和持续反馈 |

推荐顺序：

```text
L0 全部完成
  ↓
L1 全部完成
  ↓
至少 1 个真实全栈项目
  ↓
L2 稳定交付
  ↓
多个真实生产项目
  ↓
L3 FDE / Agent / 客户现场能力
```

**不要跳级。前一阶段不能稳定验收时，不建议继续堆更高级框架。**

---

# L0 基础：先具备“能跟着 AI 正确开发”的能力

## 3. FDE 与 AI 协作基础

| 技能 | 最小验收标准 |
| --- | --- |
| 理解 FDE 端到端职责 | 能说明需求发现、技术范围、设计、开发、上线、验收和反馈之间的关系 |
| 把需求写成可验收规格 | 写清目标、非目标、输入输出、边界条件、失败路径和验收命令 |
| 固定项目技术栈 | 开发前明确前端、后端、数据库、测试和部署方案，禁止 AI 自行换栈 |
| 分阶段 Gate 开发 | 当前阶段验收未通过时，不允许进入下一阶段 |
| Inspect → Plan → Patch → Verify | AI 先读项目、给最小计划、小步修改并执行真实验证 |
| 基本 AI Code Review | 能检查明显的无关修改、硬编码、Secret、未处理异常和虚构 API |

## 4. Git 与开发环境

| 技能 | 最小验收标准 |
| --- | --- |
| 终端与项目目录 | 能切换目录、查看文件、搜索文本、读取日志和执行项目命令 |
| 环境变量与 Secret | 配置通过环境变量注入，`.env`、Token、密码不进入 Git |
| Git 工作区 / 暂存区 / Commit | 能解释 working tree、staging、commit 的区别 |
| status / diff / add / commit | 提交前能看清修改，只提交当前任务相关文件 |
| branch / switch / fetch / pull / push | 能完成 feature 分支从创建到推送的完整流程 |
| 基本回退 | 能用 restore / revert 等安全撤销错误修改 |

## 5. Web、浏览器与网络基础

| 技能 | 最小验收标准 |
| --- | --- |
| HTML 语义结构 | 能用 header、nav、main、form、table 等元素搭出页面骨架 |
| CSS 盒模型与层叠 | 理解 margin、padding、border、选择器、继承和优先级 |
| Flexbox 与 Grid | 能完成左右布局、居中和卡片网格，不依赖大量绝对定位 |
| JavaScript 基础与异步 | 掌握变量、函数、数组对象、模块、Promise 和 async/await |
| HTTP / REST / JSON | 能解释 URL、Method、Header、Body、状态码和 JSON |
| CORS 与代理 | 能说明跨域原因，并用前端代理或后端 CORS 正确解决 |
| 浏览器 DevTools | 会使用 Elements、Console、Network、Storage 和响应式模式定位问题 |

## 6. UI / UX 基础

| 技能 | 最小验收标准 |
| --- | --- |
| 从用户任务设计信息架构 | 先确定用户要完成什么，再设计菜单、页面和主次操作 |
| 低保真线框图 | 编码前画出导航、内容区、表格、表单、弹窗和主要流程 |
| 视觉层级与排版 | 能通过字号、字重、留白、对齐和对比建立清晰层级 |
| 组件优先意识 | 已有 Button、Form、Table、Dialog 时不让 AI 重造基础组件 |

### L0 里程碑

完成一个极简练习：

```text
读取现有仓库
→ 新建 feature 分支
→ 用 AI 修改一个简单页面或接口
→ 自己检查 diff
→ 启动项目
→ 用浏览器 / curl 验证
→ Commit
```

达到这一阶段后，应能判断“代码到底有没有运行成功”，而不是只相信 AI 的文字说明。

---

# L1 初级：独立完成一个简单前后端项目

## 7. React 前端基础工程

| 技能 | 最小验收标准 |
| --- | --- |
| TypeScript strict | 使用 interface/type、联合类型、类型收窄，并避免滥用 any |
| Vite + React 初始化 | 创建 React + TypeScript 项目并完成开发和生产构建 |
| 组件、Props 与 State | 合理拆组件并完成父子数据和事件传递 |
| Hooks 与副作用 | 正确使用 useState、useEffect、useRef 和自定义 Hook |
| 路由与页面骨架 | 完成登录、列表、详情、设置等路由和统一 Layout |
| Ant Design 企业后台 | 使用 Layout、Table、Form、Modal、Drawer、Tabs 完成管理页面 |
| API 层与类型隔离 | 页面不散落 fetch；建立统一 API Client、类型和错误处理 |
| 响应式验收 | 核心页面在桌面、平板、手机基本可用 |

## 8. Python、FastAPI 与数据库基础

| 技能 | 最小验收标准 |
| --- | --- |
| Python 工程环境 | 创建虚拟环境、安装锁定依赖、读取环境变量并运行程序 |
| Python 数据处理 | 能处理列表、字典、JSON、YAML、文件和 HTTP API |
| FastAPI 路由与 OpenAPI | 实现 GET / POST / PUT / DELETE，并理解自动 API Schema |
| Pydantic 数据模型 | 请求、响应和配置有明确类型校验，不直接传任意 dict |
| SQL 与 PostgreSQL | 掌握表、主键、外键、SELECT、JOIN 和 CRUD |
| 基础分层 | 至少拆分 API、Schema、Service、Model / Repository，不把全部逻辑塞进路由 |

## 9. 前后端第一次完整联调

| 技能 | 最小验收标准 |
| --- | --- |
| 先设计再编码 | 编码前产出页面清单、核心数据模型、API URL / Method / Request / Response |
| 契约优先 | 前后端按照 OpenAPI / JSON Schema 约定字段，禁止两端各自猜接口 |
| 完整 CRUD | 列表、详情、新增、编辑、删除、搜索、分页和错误处理端到端跑通 |
| 页面完整状态 | 至少具备 Loading、Empty、Error、Success 状态 |
| 表单交互与反馈 | 必填、校验、提交中、成功、失败和危险操作确认清晰 |
| PR / MR | 能提交可审查变更，写清改动、验证结果和已知风险 |

### L1 里程碑：第一个完整全栈项目

至少独立完成一次：

```text
需求规格
→ 页面与 API 设计
→ React + TypeScript + Ant Design
→ FastAPI + Pydantic
→ PostgreSQL
→ CRUD 联调
→ Git PR/MR
→ 浏览器真实验收
```

**L1 不是“能让 AI 生成代码”，而是“能让 AI 生成后自己判断、修改和验收”。**

---

# L2 中级：从“能做”升级到“能稳定交付”

## 10. 前端工程化

| 技能 | 最小验收标准 |
| --- | --- |
| Design Tokens 与统一视觉规范 | 统一颜色、字号、间距、圆角、阴影和状态语义 |
| TanStack Query | 使用 Query / Mutation 管理缓存、分页、重试、刷新和服务端状态 |
| React Hook Form + Zod | 复杂表单使用统一 Schema 校验，不把规则散落到组件 |
| Tailwind + shadcn/ui | 产品型 UI 需要自由视觉时使用；与 Ant Design 不无原则混搭 |
| 图标与数据可视化 | 图标风格统一；复杂业务图表使用 ECharts 等成熟组件 |
| 无障碍与键盘操作 | 关键操作可键盘完成，表单有 Label / ARIA |
| AI 视觉验收 | 用截图或 Playwright 检查布局、间距、字体、颜色和响应式 |
| 前端自动测试 | 核心逻辑有单测，关键用户路径至少一条 Playwright E2E |

## 11. 后端生产工程

| 技能 | 最小验收标准 |
| --- | --- |
| SQLAlchemy / SQLModel | 设计模型、Session、关系、查询和事务边界 |
| Alembic 数据库迁移 | Schema 变更可重复执行、可追踪，并具备回退方案 |
| 认证与 RBAC | 登录、身份认证、角色和服务端权限检查完整 |
| 统一错误模型 | 客户端得到稳定错误结构，不靠解析随机字符串判断失败 |
| 日志与 Request ID | 一次请求可以关联前后端和后端日志，且日志不泄露 Secret |
| 后端自动测试 | Service、API、权限和数据库关键路径具备 pytest 测试 |
| 超时、重试与幂等基础 | 外部调用有超时，重试不会重复创建资源或放大故障 |

## 12. 稳定交付与生产基础

| 技能 | 最小验收标准 |
| --- | --- |
| CI 质量门禁 | PR 后自动运行 lint、typecheck、test、build，失败不能合并 |
| 依赖与锁文件治理 | 锁文件提交；升级依赖前查看变化并执行回归测试 |
| 类型化前端客户端 | 前端接口类型从 OpenAPI 生成或集中维护，避免前后端漂移 |
| 登录与权限端到端 | 登录 → 会话 → API 鉴权 → 401/403 → 退出完整验证 |
| 上传、下载和长任务 | 正确处理文件、进度、超时、取消和后台任务 |
| Docker Compose 全栈启动 | Frontend、Backend、DB 等服务可以一条命令启动 |
| 性能与体验检查 | 避免重复请求、无意义重渲染和过大 Bundle，关注核心接口耗时 |
| 健康检查 | 服务有 health/readiness 检查，并能在异常时快速定位依赖故障 |
| 部署、备份和回滚 Runbook | 陌生同事可按文档完成部署、升级、备份、恢复和回滚 |

## 13. 从工程师向 FDE 过渡

OpenAI FDE 岗位要求的不只是代码质量，L2 开始必须加入交付和客户视角。

| 技能 | 最小验收标准 |
| --- | --- |
| 技术 Discovery 基础 | 能把业务描述转成用户流程、数据源、限制条件和待验证假设 |
| Scope 与项目计划 | 能拆 MVP / POC / Production 范围，明确依赖、里程碑和验收标准 |
| 交付排序与阻塞管理 | 先解决关键路径和最大不确定性，不把所有功能同时铺开 |
| Scope / Speed / Quality 权衡 | 能说明为什么某项现在做、以后做或不做，并记录风险 |
| 客户沟通与验收 | 能用简洁文档说明问题、方案、进度、风险和实际验证结果 |
| 基本业务效果指标 | 不只看“服务运行”，还定义用户采用、任务完成或效率改善指标 |

### L2 里程碑：稳定生产交付

至少完成一个可让其他人接手的项目，具备：

- 类型约束；
- 权限与 Secret 管理；
- 自动测试；
- CI；
- Docker Compose；
- 日志和错误处理；
- 健康检查；
- README / Runbook；
- Git 回退点；
- 明确验收标准；
- 至少一次真实用户或业务流程验证。

---

# L3 高级：对标 OpenAI FDE 的端到端交付能力

## 14. LLM、Agent 与评估体系

| 技能 | 最小验收标准 |
| --- | --- |
| Responses API | 后端安全调用模型，支持结构化输出、错误处理和流式响应 |
| Agents SDK 与 Tool Calling | 定义 Agent、工具 Schema、执行边界和工具结果回传 |
| MCP 工具接入 | 理解 Client / Server / Tool，并连接真实 MCP Server |
| 文件检索 / RAG | 导入文档、检索相关内容，并返回可追溯引用 |
| Agent Evals | 使用代表性测试集评估答案质量、工具选择和版本回归 |
| 客户验收 Benchmark | 把客户业务目标转成可重复执行的 acceptance criteria 和 launch threshold |
| Guardrails 与权限边界 | 高风险工具有参数校验、最小权限、拒绝策略和必要人工确认 |
| Human-in-the-loop | 明确哪些结果必须人工审阅，设计 review、escalation 和恢复路径 |
| Tracing 与错误分析 | 查看模型、工具、耗时、异常和上下文链路，并用错误样本驱动改进 |
| 高质量 Agent WebUI | 展示流式文本、工具调用、引用、结构化结果、取消和错误状态 |
| 模型行为与产品体验 | 能识别幻觉、延迟、非确定性和工具失败对用户信任及流程的影响 |

## 15. FDE 端到端客户交付

这部分直接对应 OpenAI 当前 FDE 招聘描述中的核心职责。

| 技能 | 最小验收标准 |
| --- | --- |
| 深度 Discovery | 与工程师、业务和领域专家一起还原真实 workflow，而不是只接收功能清单 |
| Technical Scoping | 把模糊问题转成清晰范围、技术约束、成功标准和实施顺序 |
| System Design | 设计前端、后端、数据、模型、外部 API、Agent Tool、权限和故障边界 |
| Prototype → Production | 能从“验证想法”推进到稳定生产，而不是停留在 Demo |
| Experiment-driven Iteration | 先验证最大风险假设，通过实验和指标决定下一轮实现，而非一次做完 |
| Production Adoption | 关注用户是否真实使用、工作流是否改善，而不仅是部署成功 |
| Measurable Workflow Impact | 为目标流程定义质量、效率、采用率或业务影响指标 |
| Eval-driven Feedback Loop | 用评估结果、错误分析、观测和用户反馈决定模型、提示词、工具或流程优化 |
| 风险识别与计划调整 | 提前识别性能、数据、权限、合规、范围和客户依赖风险并调整交付计划 |
| 复杂环境判断 | 在需求模糊、时间紧、信息不完整时仍能做可解释、可回退的技术决策 |
| Hands-on Coding | 关键路径卡住时能直接修改生产级前端、后端或集成代码，而不是只做协调 |
| 客户基础设施集成 | 能与企业 API、数据平台、身份系统、网络和现有工作流集成 |
| Handoff 与知识转移 | 客户或内部团队可依据文档、Runbook、测试和架构说明继续维护 |

## 16. 安全、治理与受监管场景

OpenAI 医疗、法律和政府类 FDE 岗位进一步强调这些能力。通用 FDE 不一定每天全部用到，但高风险客户交付需要掌握。

| 技能 | 最小验收标准 |
| --- | --- |
| Privacy by Design | 明确数据分类、最小数据使用、保留周期和敏感数据处理边界 |
| Authentication / Authorization | 身份、角色、服务间权限和高风险操作权限清晰 |
| Auditability | 关键用户、模型和工具操作有可追溯记录 |
| Security Review | 上线前检查 Secret、依赖、网络暴露、输入边界和工具权限 |
| Governance | 明确模型、数据、工具的允许用途、责任人和变更流程 |
| Launch Criteria | 在上线前定义质量、安全、性能和人工审核通过条件 |
| Escalation Path | 模型或工具失败时有明确的人工升级、暂停和恢复路径 |

## 17. 可复用工程与组织影响力

OpenAI FDE 还要求把一次客户成功变成可以扩展到更多客户的能力。

| 技能 | 最小验收标准 |
| --- | --- |
| Playbook 沉淀 | 把发现问题、部署、排错、上线和回滚整理成可重复流程 |
| Reference Architecture | 从多个项目提炼稳定架构，而不是复制某客户的临时代码 |
| Reusable Building Blocks | 把通用工具、组件、集成和测试封装成可复用模块 |
| 内部知识库维护 | 关键问题、限制、经验和失败案例可被其他工程师搜索复用 |
| Field → Product / Research Feedback | 把客户现场结果转成清晰、可复现、可行动的产品或模型反馈 |
| 跨团队协作 | 能与 Product、Research、Security、GRC、Sales/GTM 等团队围绕同一交付目标协作 |

## 18. Go 与客户现场单文件服务

Go 不是 Web 全栈的第一学习后端，而是 FDE 在客户机、离线环境和低依赖部署中的补充能力。

| 技能 | 最小验收标准 |
| --- | --- |
| Go 基础与 Module | 建立 go.mod，理解 struct、interface、error 和包结构 |
| Gin REST 服务 | 完成路由、JSON 校验、中间件、日志和基本测试 |
| GORM 数据访问 | 连接数据库并完成模型、迁移和 CRUD |
| 交叉编译单文件交付 | 构建 Linux / Windows 目标产物，并在真实目标机启动验证 |

### L3 里程碑：模拟一次完整 FDE 交付

项目至少经历：

```text
客户问题发现
→ Workflow / 数据 / 约束梳理
→ Scope 与 POC 成功标准
→ 系统设计
→ 全栈 Prototype
→ LLM / Agent / Tool 集成
→ Evals + 人工 Review
→ Production Hardening
→ 部署
→ Adoption / Workflow Impact 验证
→ Handoff
→ Playbook / Reusable Component / Field Feedback
```

这比“做出一个 Agent Demo”更接近 OpenAI 当前 FDE 的实际岗位要求。

## 19. OpenAI 招聘要求与技能路线映射

| OpenAI 官方要求 | 本路线位置 |
| --- | --- |
| Discovery、Technical Scoping | L2 技术 Discovery；L3 深度 Discovery / Technical Scoping |
| System Design、Build、Production Rollout | L1 全栈基础 → L2 稳定交付 → L3 Prototype → Production |
| Production-grade frontend / backend | L1 React + FastAPI；L2 测试、权限、CI、部署 |
| LLM / Generative AI systems | L3 LLM、Agent 与评估体系 |
| Scope / Speed / Quality trade-offs | L2 Scope 与项目计划；L3 风险识别和复杂环境判断 |
| Customer-facing ownership | L2 客户沟通；L3 端到端客户交付 |
| Production adoption / measurable workflow impact | L3 Production Adoption / Workflow Impact |
| Eval-driven feedback | L3 Evals、Benchmark、Tracing、Feedback Loop |
| Guardrails / Security / Governance | L3 安全、治理与受监管场景 |
| Codify patterns into tools / playbooks | L3 可复用工程与组织影响力 |
| Field feedback to Product / Research | L3 Field → Product / Research Feedback |
| 5+ 年工程或部署经验 | 工作经验门槛，不能用学习清单替代 |

## 20. 官方来源

以下页面均来自 OpenAI Careers，岗位内容会随招聘调整，复核时以当前官网为准：

- [Forward Deployed Engineer (FDE) - SF](https://openai.com/careers/forward-deployed-engineer-%28fde%29-sf-san-francisco/)
- [Forward Deployed Engineer - Tokyo](https://openai.com/careers/forward-deployed-engineer-tokyo-tokyo-japan/)
- [Forward Deployed Engineer, Gov](https://openai.com/careers/forward-deployed-engineer-gov-washington-dc/)
- [Forward Deployed Software Engineer - Seattle](https://openai.com/careers/forward-deployed-software-engineer-seattle-seattle/)
- [Forward Deployed Engineer (FDE), Healthcare - SF](https://openai.com/careers/forward-deployed-engineer-%28fde%29-healthcare-sf-san-francisco/)
- [Forward Deployed Engineer (FDE), Legal-SF](https://openai.com/careers/forward-deployed-engineer-%28fde%29-legal-sf-new-york-city/)
- [OpenAI Careers - Forward Deployed 搜索](https://openai.com/careers/search/?q=forward+deployed)

## 相关文档

- [Vibe Coding](vibe-coding.md)
- [Codex 项目开局规范](codex-project-bootstrap.md)
- [ChatGPT 与 Codex](chatgpt-codex.md)
- [AI 资源](../resources.md)
- [开发 / 技术栈与工具](../../development/tooling/README.md)
