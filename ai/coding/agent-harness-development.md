# Agent Harness 开发速查

- **适用范围**：需要让 LLM 持续调用工具、管理上下文和状态，并在权限、沙箱、恢复机制约束下完成多步任务的 Agent。
- **最后验证**：2026-09-24
- **定位**：本页是开发选型与最小落地教程，不复制各框架完整手册。

## 结论

不要从零实现一套大而全的 Harness。先根据目标选成熟底座：

| 需求 | 优先参考 | 原因 |
| --- | --- | --- |
| 云端长任务、少运维 | OpenAI Agents API / Codex Harness | 托管 Session、上下文压缩、子 Agent、工具/MCP、沙箱和恢复 |
| 自建通用企业 Agent | LangChain Deep Agents | 开源、模型无关，内置文件系统、Skills、子 Agent、HITL，底层使用 LangGraph |
| 软件工程 / Shell / 文件类 Agent | OpenHands Software Agent SDK | Agent Loop、Workspace、工具、安全分析、远程 Agent Server 较完整 |
| 学习 Harness 最小实现 | mini-swe-agent | 核心 Agent 类约百行，适合理解循环、环境和工具边界 |
| 设计成熟 Coding Agent 产品 | Codex / Claude Code | 重点参考权限、上下文文件、MCP、Session、子任务和开发体验 |

> 只做 KB RAG 问答时，通常不需要先引入完整 Harness。先做检索 + 模型回答；出现工具调用、长任务、审批、恢复、沙箱等需求后再升级。

## Harness 到底负责什么

可以把 Agent 看成：

```text
Agent = Model + Harness + Tools/Skills + Runtime
```

典型 Harness 至少负责：

```text
用户 / API
    ↓
Harness
├─ Agent Loop        模型 ↔ 工具循环
├─ Context           指令、文档、上下文压缩
├─ Tool Router       Function / API / MCP / Script
├─ State             Session、Checkpoint、任务状态
├─ Policy            Allow / Deny / Approval
├─ Recovery          超时、重试、恢复
└─ Observability     日志、Trace、Token、耗时
    ↓
Runtime / Sandbox
├─ 文件系统
├─ Shell / Code
├─ Browser
└─ 企业内网服务
```

模型负责决定下一步做什么；Harness 负责把这个决定安全、可恢复地执行下去。

### Harness、Framework、Runtime、MCP 的边界

- **Harness**：围绕模型的执行控制层，组织上下文、工具调用、状态、权限和反馈循环。
- **Agent Framework**：开发 Agent 的 SDK / 抽象，例如 LangChain、OpenAI Agents SDK。
- **Runtime**：保证任务可持续运行的底座，例如 checkpoint、durable execution、streaming、interrupt。
- **MCP**：工具和上下文的标准连接协议，不负责完整 Agent Loop。
- **Skill**：可复用的业务说明、工作流或工具组合。

不同项目命名并不完全一致，开发时应关注能力边界，而不是名称。

## 值得直接研究的 Harness 案例

### 1. OpenAI Codex Harness / Agents API

适合研究“托管型生产 Harness”应该包含什么。

当前 Agents API 直接运行 Codex Harness，官方公开的关键能力包括：

- Durable Session：同一任务可持续执行并恢复。
- 自动上下文压缩。
- Multi-agent / Subagent。
- Function Tool、Programmatic Tool Calling 和 MCP。
- OpenAI 托管沙箱或 self-hosted 环境。
- Streaming / Webhook 获取长任务进度。
- Skills 和文件工作区。

它最值得借鉴的不是某个 SDK 调用，而是 **Harness 与执行环境分离**：

```text
应用服务
   ↓
Codex Harness
   ↓
Environment
   ├─ OpenAI Hosted Sandbox
   └─ Self-hosted Sandbox
```

这样模型与工具循环可以保持稳定，而 Shell、文件、私网程序运行在隔离环境中。

### 2. LangChain Deep Agents

如果要直接基于开源库开发通用 Agent，Deep Agents 是当前很有代表性的 Harness。

它不是另一个底层 Runtime，而是：

```text
Deep Agents Harness
        ↓
LangChain create_agent
        ↓
LangGraph Runtime
```

默认已经包含长任务常用能力：

- TODO / Planning；
- 文件系统工具；
- Skills；
- Subagents；
- 上下文摘要与工具输出卸载；
- 可插拔 Backend / Sandbox；
- Persistent Memory；
- Human-in-the-loop；
- LangGraph checkpoint / streaming / interrupt。

如果业务是知识问答、产品支持、数据分析、自动运维编排等通用企业 Agent，可以先用它完成 MVP，再决定是否需要自己维护 Harness。

### 3. OpenHands Software Agent SDK

OpenHands 更适合研究“软件工程 Agent”的完整实现。

其核心 Agent 明确包含：

- reasoning-action loop；
- tool orchestration；
- context management / condenser；
- security validation；
- workspace abstraction。

同时 Agent Server 把 SDK 暴露为 HTTP / WebSocket 服务，Workspace 可以放在本机，也可以放到 Docker、Kubernetes 或远端隔离环境。

如果 Agent 需要大量执行 Shell、改文件、跑测试、浏览器操作，可以重点参考 OpenHands 的 **Agent 与 Workspace 分离**、事件流和安全策略。

### 4. mini-swe-agent

学习 Harness 时建议一定读一次 mini-swe-agent。

它刻意把 Agent 保持得很小，核心思想只有：

```text
读取任务
  ↓
调用模型
  ↓
模型决定动作
  ↓
环境执行
  ↓
结果回到历史
  ↓
继续，直到完成
```

这能避免一开始就被复杂框架带偏。生产 Harness 本质上也是在这个循环外围逐步增加上下文、权限、沙箱、状态、恢复和可观测性。

### 5. Codex / Claude Code

这两类成熟 Coding Agent 适合研究产品层设计，而不是照搬内部实现。

重点观察：

- 项目级说明文件：`AGENTS.md` / `CLAUDE.md`；
- Session continue / resume；
- 工具权限 Allow / Deny / Approval；
- MCP 接入；
- 子 Agent / Hooks / 自动化；
- Git、Shell、文件操作如何和人工审核衔接。

其中 OpenAI 的 Harness Engineering 实践还有一个很重要的结论：**不要把全部知识塞进一个巨大的 AGENTS.md**。入口文件应像目录，详细知识放在仓库内结构化文档中，让 Agent 按需逐层读取。

## 30 分钟做一个最小 Harness

最短路径可以直接用 Deep Agents 验证业务，不先造底层 Runtime。

### 1. 创建项目

在开发机执行：

```bash
mkdir harness-demo && cd harness-demo
uv init
uv add deepagents
```

配置模型。模型名称按当前供应商账号实际可用值填写：

```bash
export MODEL='openai:<your-model>'
export OPENAI_API_KEY='CHANGE_ME'
```

不要把 API Key 写入代码或 Git。

### 2. 创建 app.py

```python
import os

from deepagents import create_deep_agent


def query_kb(question: str) -> str:
    """查询企业知识库。这里替换成真实 KB SDK / HTTP API。"""
    return f"[demo kb] {question}"


def get_ticket(ticket_id: str) -> str:
    """读取工单，只允许只读查询。"""
    return f"[demo ticket] {ticket_id}"


agent = create_deep_agent(
    model=os.environ["MODEL"],
    tools=[query_kb, get_ticket],
    system_prompt=(
        "你是技术支持 Agent。优先查询知识库；"
        "只有知识库不足时再查询工单；禁止执行写操作。"
    ),
)

result = agent.invoke(
    {
        "messages": [
            {
                "role": "user",
                "content": "查询产品启动失败的处理方法；必要时查看工单 T-1001",
            }
        ]
    }
)

print(result)
```

执行：

```bash
uv run python app.py
```

这个版本已经具备最基本的：

```text
Model
  ↕
Agent Loop
  ↕
Tool Router
  ├─ query_kb
  └─ get_ticket
```

先确认工具选择逻辑稳定，再继续增加能力。

## 从 Demo 升级到生产

不要一次性上多 Agent。按下面顺序增加。

### 第 1 层：工具标准化

每个工具至少定义：

```text
name
description
input schema
output schema
timeout
permission level
retry policy
```

工具尽量：

- 单一职责；
- 输入输出结构化；
- 读操作和写操作分开；
- 写操作尽量幂等；
- 大结果保存为文件 / Artifact，只给模型摘要和引用；
- 错误返回明确原因，不把空输出误认为失败。

### 第 2 层：权限和审批

建议最少分三类：

| 等级 | 示例 | 默认策略 |
| --- | --- | --- |
| Read | KB 查询、日志查询、GET API | 自动允许 |
| Write | 修改工单、提交 Git、重启普通服务 | 规则允许或人工批准 |
| Destructive | 删除、重装、生产变更 | 默认拒绝或强制人工批准 |

不要让模型自己判断自己是否有权限。权限必须由 Harness / Policy 层执行。

### 第 3 层：Sandbox

只要 Agent 能执行 Shell、Python、浏览器或不可信代码，就应考虑隔离环境。

推荐结构：

```text
Harness Service
     │
     ├─ LLM / Context / Policy / State
     │
     └──────── Executor API ────────┐
                                    ↓
                              Sandbox / Container
                              ├─ Shell
                              ├─ Files
                              ├─ Browser
                              └─ 临时依赖
```

生产环境不要默认让 Agent 在 Harness 服务宿主机直接执行任意 Shell。

### 第 4 层：State 与 Recovery

长任务至少保存：

- session_id；
- 当前任务状态；
- 最近 checkpoint；
- 已执行工具及结果；
- 待审批动作；
- 最终 Artifact。

服务重启后应能从 checkpoint 继续，而不是重新执行整个任务。

### 第 5 层：Context Engineering

推荐仓库结构：

```text
AGENTS.md                 # 入口和导航，不写成百科全书
docs/
├─ architecture.md
├─ product/
├─ operations/
└─ decisions/
skills/
├─ query-kb/
└─ inspect-host/
tools/
├─ kb/
├─ api/
└─ ops/
```

核心原则是 **progressive disclosure**：Agent 先看到少量稳定入口，需要时再读取具体文档和 Skill。

### 第 6 层：Observability 与 Evals

至少记录：

- task / session id；
- 模型和版本；
- 每次工具调用；
- 工具耗时和错误；
- token / cost；
- 人工介入次数；
- 最终成功 / 失败原因。

建立 20～50 个真实任务作为回归集，比不断修改 Prompt 更有效。每次 Harness、模型或工具升级都重新跑。

## 企业项目推荐目录

一个够用且不复杂的结构：

```text
agent/
├─ app.py
├─ agents/
│  └─ support.py
├─ tools/
│  ├─ kb.py
│  └─ ticket.py
├─ skills/
│  └─ support/
│     └─ SKILL.md
├─ policy/
│  └─ tools.yaml
├─ runtime/
│  └─ sandbox.py
└─ tests/
   └─ eval_cases.yaml
```

只有出现明确需求后再增加：

- 多 Agent；
- 长期 Memory；
- Workflow DSL；
- 向量数据库；
- 消息队列；
- 独立调度平台。

## 选型规则

可以直接按下面判断：

```text
只有 RAG 问答？
  └─ 是 → 不上完整 Harness

需要 KB + API / MCP 工具？
  └─ 是 → Deep Agents 或轻量自建 Harness

需要 Shell / 文件 / 浏览器？
  └─ 是 → 加 Sandbox；优先参考 OpenHands / Codex

需要小时级长任务、暂停和恢复？
  └─ 是 → 必须有 checkpoint / durable runtime

需要云端托管、尽量少维护？
  └─ 是 → 评估 OpenAI Agents API

需要完全掌控部署和数据路径？
  └─ 是 → 开源 Harness + 自建 Runtime / Sandbox
```

## 最小验收清单

上线一个 Harness 前至少验证：

```text
□ 工具参数错误时不会误执行
□ Read / Write / Destructive 权限可以机械执行
□ Agent 无法绕过 Tool Policy
□ Shell / Code 在隔离环境执行
□ 工具超时和 5xx 有明确恢复策略
□ Session 中断后可以继续或安全重跑
□ 每次工具调用和最终结果可追踪
□ 有真实任务回归集，不只靠人工体验
```

## 官方资料

- OpenAI Harness Engineering: https://openai.com/index/harness-engineering/
- OpenAI Agents API: https://developers.openai.com/api/docs/guides/agents-api/overview
- OpenAI Agents API Architecture: https://developers.openai.com/api/docs/guides/agents-api/architecture
- VS Code Agent Harnesses: https://code.visualstudio.com/docs/agents/concepts/agent-harnesses
- LangChain Deep Agents: https://github.com/langchain-ai/deepagents
- LangChain Deep Agents 文档: https://docs.langchain.com/oss/python/deepagents/overview
- OpenHands Software Agent SDK: https://github.com/OpenHands/software-agent-sdk
- OpenHands SDK 文档: https://docs.openhands.dev/sdk
- mini-swe-agent: https://github.com/SWE-agent/mini-swe-agent
- Claude Code 文档: https://docs.anthropic.com/en/docs/claude-code/overview

更新 Harness 或模型前，优先查看上述官方资料；具体 API、模型名和默认能力可能随版本变化。
