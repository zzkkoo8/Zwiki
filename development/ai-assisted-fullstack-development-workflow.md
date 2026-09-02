# AI 辅助全栈开发规范：分阶段验收与稳定交付

本文用于规范使用 Coding Agent 开发前端、后端和 AI 应用的过程。核心目标不是“让 AI 尽快写完代码”，而是让项目**可验证、可回退、可接手、可持续迭代**。

本文基于 FDE 开发规范整理，强化两条执行原则：

1. **稳定输出前端 + 后端项目**：优先使用主流、AI 熟悉、类型和测试工具完善的技术栈。
2. **阶段门禁（Gate）**：一个阶段验收通过后，才允许进入下一阶段；当前阶段失败时，只修当前阶段，不提前扩散代码。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | AI Coding / Web 全栈开发 / FDE 工程规范 |
| 适用范围 | 新项目、现有项目功能开发、Bug 修复、小规模重构 |
| 适用版本 | 通用流程，具体框架版本以项目锁文件为准 |
| 文档状态 | 已验证流程规范 |
| 最后验证 | 2026-09-02 |
| 来源 | FDE《从零开始，用 Coding Agent 产出可维护的代码》、Git/GitLab/React 等项目实践 |

## 1. 核心原则

### 1.1 AI 不是一次性项目生成器

禁止把“开发一个完整系统”作为一条指令直接交给 AI。

正确方式是把开发过程拆成多个可独立验收的阶段：

```text
需求与约束
  ↓ Gate 0
架构与接口契约
  ↓ Gate 1
项目脚手架
  ↓ Gate 2
后端能力
  ↓ Gate 3
前端能力
  ↓ Gate 4
前后端联调
  ↓ Gate 5
质量与回归
  ↓ Gate 6
部署与交付
```

**硬规则：当前 Gate 未通过，不进入下一 Gate。**

AI 可以帮助分析失败原因、修复和补测试，但不能通过“先继续做后面的，最后一起修”绕过门禁。

### 1.2 优先选择 AI 友好的技术栈

FDE 原规范的核心判断是：优先选择社区主流、文档成熟、AI 训练样本丰富的技术栈，而不是为了新颖使用冷门框架。

推荐基线：

| 场景 | 推荐技术栈 | 原因 |
| --- | --- | --- |
| 企业管理后台 | TypeScript + React + Ant Design + Vite | 强类型、组件标准化、资料多、AI 生成稳定 |
| Web API / AI 应用后端 | Python + FastAPI + Pydantic | Python 生态与 AI/LLM 工具链统一，接口 Schema 清晰 |
| 数据库 | PostgreSQL | 通用、成熟、SQL 能力完整 |
| 客户机长期运行服务 | Go + Gin | 静态类型、单二进制、便于离线和跨平台交付 |
| 本地集成 | Docker Compose | 环境一致、依赖可复现、便于整体验收 |
| 版本与协作 | Git + Feature Branch + MR/PR + CI | 变更可比较、可回退、可审查 |

技术栈一旦在 Gate 0 确认，AI 不得自行切换框架、升级大版本或引入替代库。

## 2. AI 开发四阶段循环

每一个 Gate 内部都重复同一套最小闭环：

```text
Inspect → Plan → Patch → Verify
```

### Inspect：先读再改

AI 必须先检查：

- 当前目录和项目结构；
- `README`、`AGENTS.md`、规范文件；
- 当前依赖与锁文件；
- 相关代码和测试；
- 当前 Git 状态和分支。

禁止未阅读现有实现就直接生成替代方案。

### Plan：先给最小计划

AI 应明确：

- 本次只改什么；
- 不改什么；
- 预计涉及哪些文件；
- 如何验收；
- 失败时如何回退。

### Patch：小步修改

一次只实现一个明确目标：

- 一个接口；
- 一个数据模型；
- 一个页面；
- 一个表单流程；
- 一个 Bug；
- 一个小重构。

禁止一次大范围重写整个项目。

### Verify：用结果而不是描述验收

AI 不能用“应该可以”“理论上没问题”作为完成依据。

必须给出真实验证结果，例如：

```bash
pnpm lint
pnpm build
pytest -q
curl http://127.0.0.1:8000/healthz
docker compose config
docker compose ps
```

只有命令、测试、页面交互和实际响应都满足当前 Gate 的验收标准，才能继续。

## 3. Gate 0：需求、范围和技术基线

### 输入

- 用户目标；
- 当前业务流程；
- 必要功能；
- 非目标；
- 数据来源；
- 运行环境和限制。

### AI 要完成

输出一份简短规格：

```text
目标
非目标
主要用户流程
输入 / 输出
关键数据字段
异常与边界条件
技术栈
目录规划
验收标准
```

### 验收条件

- 功能范围没有明显歧义；
- 技术栈已经固定；
- 明确哪些功能本期不做；
- 已定义最终怎么判断项目成功。

### 阻断条件

以下任一存在时禁止开始编码：

- 数据来源未知；
- 核心字段未定义；
- 前后端框架未确定；
- AI 仍需要自己“猜需求”。

## 4. Gate 1：架构、数据模型和 API 契约

这一阶段不做完整页面，也不实现大量业务逻辑。

### AI 要完成

至少输出：

```text
浏览器
  ↓
Frontend
  ↓ HTTP / JSON
Backend API
  ↓
PostgreSQL / 外部 API / Agent Tool
```

并确定：

- 页面和路由清单；
- 核心数据模型；
- API URL、Method；
- Request / Response Schema；
- 错误码和错误结构；
- 身份认证和权限边界。

### 验收条件

前后端都能只看接口契约回答：

- 请求发到哪里；
- 需要哪些字段；
- 返回哪些字段；
- 失败时返回什么。

**前端和后端禁止各自猜字段。**

## 5. Gate 2：项目脚手架

### 后端

至少具备：

```text
backend/
├── app/
│   ├── api/
│   ├── models/
│   ├── schemas/
│   ├── services/
│   └── config/
├── tests/
└── pyproject.toml
```

### 前端

至少具备：

```text
frontend/
└── src/
    ├── api/
    ├── components/
    ├── pages/
    ├── hooks/
    └── types/
```

### 验收条件

后端至少：

```bash
# 示例，以实际项目命令为准
pytest -q
```

并存在健康检查：

```bash
curl -f http://127.0.0.1:8000/healthz
```

前端至少：

```bash
pnpm install
pnpm lint
pnpm build
```

全部通过后才能开始业务功能。

## 6. Gate 3：后端先形成稳定 API

为了减少前后端同时变化造成的返工，默认先让后端 API 达到“可联调”状态。

推荐开发顺序：

```text
数据模型
→ Schema
→ Repository / 数据访问
→ Service
→ API Route
→ 错误处理
→ 测试
```

### 后端硬要求

- 请求和响应有明确 Schema；
- 参数必须校验；
- 非 2xx 路径必须处理；
- 业务逻辑不要全部写在路由函数；
- Secret 不硬编码；
- 数据库变更可迁移；
- 关键路径有测试；
- 日志能定位请求失败原因。

### 验收条件

至少完成一次真实 API 验收：

```bash
curl -X POST http://127.0.0.1:8000/api/users ...
curl http://127.0.0.1:8000/api/users
```

同时测试：

- 正常请求；
- 缺少必填字段；
- 非法输入；
- 不存在资源；
- 权限失败（如果有权限）；
- 数据库异常或外部 API 失败的关键路径。

后端接口不稳定时，不进入真实前后端联调。

## 7. Gate 4：前端页面和视觉验收

前端推荐固定使用：

```text
TypeScript strict
React 函数组件 + Hooks
Ant Design（企业后台）
Vite
```

需要更自由的产品型视觉时可以采用 Tailwind + shadcn/ui，但一个项目应尽量保持单一设计系统，避免无原则混搭。

### 开发顺序

```text
Layout / 路由
→ 页面骨架
→ 列表 / 卡片
→ 表单
→ Modal / Drawer
→ Loading / Empty / Error
→ 权限状态
→ 视觉调整
```

### 前端硬要求

- TypeScript `strict` 开启；
- 不用 `any` 逃避类型问题；
- 页面组件与 API 层分离；
- Loading / Empty / Error 状态完整；
- 表单有校验和提交反馈；
- 删除等危险操作有二次确认；
- 控制台无红色错误；
- 页面在目标分辨率下无明显溢出和错位。

### 验收条件

至少验证：

```bash
pnpm lint
pnpm build
```

并人工走通：

```text
打开页面
→ 查看列表
→ 新增
→ 编辑
→ 删除
→ 刷新
→ 模拟请求失败
```

视觉验收至少检查：

- 对齐；
- 间距；
- 字号层级；
- 表格和表单密度；
- 按钮主次；
- Loading / Empty / Error 状态；
- 响应式或目标分辨率。

## 8. Gate 5：前后端联调

只有 Gate 3 和 Gate 4 各自独立通过后才进入联调。

### 联调顺序

一次只联调一个用户流程，例如：

```text
GET /users
→ 列表展示
→ 验收

POST /users
→ 新增表单
→ 验收

PUT /users/:id
→ 编辑
→ 验收

DELETE /users/:id
→ 删除
→ 验收
```

不要一次把所有 API 接上再统一排错。

### 验收条件

- Network 中请求 URL、Method 正确；
- Request 与 Schema 一致；
- Response 与前端类型一致；
- 401 / 403 / 404 / 422 / 500 能正确展示；
- 前端没有直接依赖后端内部实现；
- 后端不为迁就单个页面临时破坏公共 API 契约。

## 9. Gate 6：质量门禁和回归

FDE 原规范要求 AI 代码必须人工 Review，并强调依赖、错误路径、目录结构、Secret、锁文件和真实 happy path。

这里统一成提交前门禁。

### 通用 Review Checklist

- [ ] 改动范围符合任务，没有顺手重构无关文件
- [ ] 新依赖确实必要且版本正确
- [ ] 锁文件已更新
- [ ] 没有硬编码 Token、密码、客户数据
- [ ] 错误路径已处理
- [ ] 命名和目录结构一致
- [ ] 没有明显重复代码和超大文件
- [ ] 没有遗留调试代码
- [ ] 至少一个真实 happy path 已跑通
- [ ] 核心边界条件有测试或手工验证记录

### 前端门禁

```bash
pnpm lint
pnpm build
```

项目配置了测试时继续执行：

```bash
pnpm test
pnpm exec playwright test
```

### Python / FastAPI 门禁

以项目实际工具为准，典型为：

```bash
pytest -q
```

如果项目配置了 Ruff / mypy：

```bash
ruff check .
mypy .
```

### Go 门禁

```bash
go fmt ./...
go vet ./...
go test ./...
go build ./...
```

任一门禁失败，不进入部署。

## 10. Gate 7：部署、运行与回退

### 交付前必须明确

- 环境变量清单；
- 数据目录；
- 端口；
- 数据库初始化 / Migration；
- 启动方式；
- 健康检查；
- 日志位置；
- 备份方式；
- 回退版本。

Docker Compose 项目至少检查：

```bash
docker compose config
docker compose up -d
docker compose ps
docker compose logs --tail=100
```

### 最终验收

陌生同事只根据 README / Runbook 应能完成：

```text
获取代码或产物
→ 配置环境变量
→ 启动
→ 验证健康检查
→ 完成一个真实业务流程
→ 查看日志
→ 停止
→ 恢复或回退
```

如果必须依赖开发者口头指导才能部署，交付不算完成。

## 11. Git 工作纪律

所有 AI 修改都必须可追踪和可回退。

推荐流程：

```bash
git switch main
git pull --rebase
git switch -c feature/<name>
```

每完成一个独立 Gate 或明确子任务后，先验收，再形成有意义的 commit。

提交前至少执行：

```bash
git status
git diff
git diff --staged
```

禁止：

- 在生产稳定分支直接让 AI 大面积修改；
- 未检查 `git diff` 就提交；
- 使用 `git push --force` 覆盖共享分支；
- AI 自行删除未知文件；
- AI 未经说明自动升级大量依赖。

需要重写 Feature 分支历史时优先：

```bash
git push --force-with-lease
```

## 12. 推荐给 Coding Agent 的项目级约束

可将以下规则写入 `AGENTS.md` 或项目开发规范：

```text
1. 修改前先阅读项目结构、README、AGENTS.md、相关代码和测试。
2. 当前只处理用户指定的 Gate，不提前实现后续 Gate。
3. 每次先给最小实施计划，再修改代码。
4. 不修改无关文件，不顺手重构。
5. 不自行更换技术栈，不升级大版本，不新增非必要依赖。
6. 每完成一个子任务立即执行该阶段验收。
7. 验收失败时只修失败项，不继续开发下一项。
8. 所有“完成”结论必须附带实际执行的验证命令和结果。
9. Secret、Token、客户数据不得写入代码、日志或 Git。
10. 最终输出必须说明：改了什么、为什么、如何验证、还有什么风险。
```

## 13. 最推荐的实际开发节奏

对于一个典型“后台管理系统 + API”项目：

```text
Day / Step 1
需求规格 + 技术栈
→ 人工确认

Day / Step 2
数据模型 + API 契约
→ curl / Schema 验收

Day / Step 3
后端一个 CRUD 闭环
→ pytest + curl 验收

Day / Step 4
前端一个 CRUD 页面
→ lint + build + 浏览器验收

Day / Step 5
只联调这个 CRUD
→ 真实端到端验收

Day / Step 6
复制同样模式扩展下一功能

最后
完整回归 + CI + Docker + Runbook
```

这种方式看起来比“一次让 AI 写完整系统”慢，但返工明显更少，问题定位范围更小，最终交付速度通常更稳定。

## 14. AI Agent 项目的扩展规则

Agent、RAG、MCP、Tool Calling 等能力应放在基础 Web 全栈闭环之后。

推荐顺序：

```text
普通 API / 页面稳定
→ Agent 单一任务
→ 单一 Tool
→ Tool 权限与失败路径
→ 会话 / 状态
→ RAG / 外部知识
→ Evals
→ 多 Agent / 高级编排
```

不要在普通 CRUD、权限、日志和部署尚未稳定时，就同时引入多 Agent、复杂 RAG 和大量工具调用。

## 15. 结论

AI 辅助开发的稳定性，不来自更长的 Prompt，而来自工程控制：

> **固定技术栈 + 小步开发 + 阶段验收 + Git 可回退 + 自动化质量门禁。**

FDE 的目标不是让 AI 一次生成最多代码，而是让每一次生成都处于可理解、可验证、可回退的范围内。

最重要的一条执行规则：

> **当前阶段没有验收通过，就不要进入下一阶段。**

## 相关文档与资源

- [Zwiki 编写与维护规范](../CONTRIBUTING.md)
- [通用技术文章模板](../templates/technical-article.md)
- [GitHub .gitignore 模板](https://github.com/github/gitignore)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitLab CI/CD](https://docs.gitlab.com/ee/ci/)
- [TypeScript](https://www.typescriptlang.org/docs/)
- [React](https://react.dev/)
- [Ant Design](https://ant.design/components/overview-cn/)
- [Vite](https://vite.dev/)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Gin](https://gin-gonic.com/)
- [GORM](https://gorm.io/)
