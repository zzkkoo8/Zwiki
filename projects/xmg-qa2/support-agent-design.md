> [!IMPORTANT]
> **阅读镜像，不是事实源。** 权威设计稿位于 [zzkkoo8/xmg-qa2 → docs/design/XMG-QA2-SUPPORT-AGENT-DESIGN.md](https://github.com/zzkkoo8/xmg-qa2/blob/main/docs/design/XMG-QA2-SUPPORT-AGENT-DESIGN.md)。
> 本次镜像对应 xmg-qa2 `main` 提交 `a2c5399f7c86c19913ca857e7745544e30e0f6c5`。后续设计修改必须先进入 xmg-qa2，再同步本页。

# xmg-qa2 技术支持专家 Agent 设计稿

Status: **Architecture Baseline / Pre-Implementation**

## 1. 产品定位

xmg-qa2 是一款面向客户技术支持场景的 **问题回答专家 Agent**。

它不是“问一次知识库、再让模型回答”的普通 RAG Chatbot，而是一个可控的技术问题调查与回答 Runtime：

- 自动读取 `xmg-kb` 及其他 Knowledge Provider。
- 自动调用已授权的第三方产品 API。
- 自动调用 MCP、诊断工具和运维工具。
- 根据已有 Evidence 判断是否需要继续调查。
- 在必要时建立 Hypothesis，并主动获取新证据进行验证或推翻。
- 简单问题直接回答，避免无意义的工具调用。
- 复杂问题自动整理为结构化技术分析报告。

目标不是无限自主执行，而是：

> **在时间、步骤、成本、权限和安全边界内，尽最大合理努力获得足够证据并回答客户问题。**

---

## 2. 核心设计原则

### 2.1 Workflow First

外层执行流程必须由显式 Workflow / State Graph 控制。

确定性规则负责：

- 状态转移
- timeout
- retry
- max steps
- max duration
- permission
- tool allowlist
- token/cost budget
- cancellation
- termination condition

LLM/Agent 只在适合语义推理的节点中工作，例如：

- 问题理解
- Query rewrite
- Evidence 语义判断
- Hypothesis 生成
- 下一调查动作建议
- 回答与报告生成

### 2.2 Controlled Agentic Investigation

允许 Agent 在明确边界内进行多步调查，但禁止无限自由 Agent Loop。

一次 Investigation 必须至少受到：

```text
max_steps
max_duration
tool_allowlist
permission
provider_timeout
retry_limit
token/cost_budget
termination_condition
```

约束。

### 2.3 Evidence First

Knowledge、API、Tool 返回的信息统一转换成 Evidence。

任何重要结论应能反查其 Evidence；证据不足时必须显式说明不确定性，不得把 Provider 故障或无结果伪装成确定答案。

### 2.4 Everything External Through Contract

以下外部能力必须通过稳定 Contract / Plugin 接入：

- Channel
- Knowledge
- Model
- Tool
- Policy

核心 Workflow 不认识 Dify、RAGFlow、DingTalk、某个具体模型 SDK 或某个产品 API 的私有类型。

### 2.5 Provider Neutral

替换 xmg-kb、Dify、RAGFlow、LLM、Channel 或 Tool Provider，不应要求修改 Harness Core。

---

## 3. 总体架构

```text
                   Customer / Engineer
                           |
               DingTalk / REST / Web
                           |
                     Channel Adapter
                           |
                           v
                    Harness Gateway
                           |
               Session / Auth / Policy
                           |
                           v
                    Support Workflow
                           |
             +-------------+-------------+
             |                           |
             v                           v
       Initial Knowledge           Investigation
          Retrieval                   Loop
             |                           |
             |                 +---------+---------+
             |                 |         |         |
             |                 v         v         v
             |               KB/API     MCP      Tools
             |                 |         |         |
             +-----------------+---------+---------+
                               |
                               v
                        Evidence Workspace
                               |
                    Hypothesis / Verify / Reason
                               |
                    Evidence sufficient?
                         |             |
                        YES            NO
                         |             |
                         |        continue / ask user
                         |        / controlled fallback
                         v
                 Answer / Technical Report
```

跨层能力：

```text
Config / Secrets / Trace / Metrics / Audit
Retry / Timeout / Circuit Breaker / Rate Limit
```

---

## 4. Support Workflow

推荐的核心状态流程：

```text
receive_input
      |
normalize_input
      |
policy_check
      |
understand_problem
      |
initial_retrieve
      |
evaluate_evidence
      |
      +---- sufficient --------------------+
      |                                    |
      |                                    v
      |                               generate_answer
      |                                    |
      |                                    v
      |                              verify_grounding
      |                                    |
      |                                    v
      |                                 finalize
      |
      +---- insufficient ---> plan_next_action
                                  |
                                  v
                            execute_action
                                  |
                                  v
                           collect_evidence
                                  |
                                  v
                         verify / update hypothesis
                                  |
                                  v
                              continue?
                            /          \
                          YES          NO
                           |            |
                           +------> generate answer/report
```

每一步必须有可观测事件和明确失败路径。

---

## 5. Investigation 模型

复杂问题使用 Investigation 表达整个调查过程。

建议稳定领域模型：

```text
Thread
  └── Turn
       └── Investigation
            ├── InvestigationStep[]
            ├── Evidence[]
            ├── Hypothesis[]
            ├── ToolRequest[]
            ├── ToolResult[]
            └── Decision[]
```

### InvestigationStep

每一步至少记录：

- action
- capability/provider
- input
- output reference
- evidence ids
- latency
- retry count
- result status
- reason for next decision

这样可以完整复盘“为什么得到这个答案”。

---

## 6. Evidence 模型

统一 Evidence 至少包含：

```text
evidence_id
content
title
source
uri
provider_id
document_or_resource_id
chunk_or_result_id
score/confidence
metadata
knowledge_or_tool_version
timestamp
```

Evidence 来源可以是：

- xmg-kb 文档片段
- 其他知识库
- 产品 REST API
- MCP Tool
- Linux/容器/集群诊断结果
- 第三方产品状态
- 用户补充信息

不同 Provider 的 score 不允许直接假设可比较；跨 Provider 排序时需要标准化或 rerank。

---

## 7. Capability / Plugin Architecture

稳定能力类别：

```text
KnowledgeProvider
ModelProvider
ToolProvider
ChannelProvider
PolicyProvider
```

Harness 通过 Capability Registry 发现能力。

Workflow 或 Agent 只能根据 Contract 和 capability 选择能力，禁止出现：

```text
if provider == "dify":
...
elif provider == "ragflow":
...
```

这种 Provider 私有业务逻辑。

---

## 8. xmg-kb 的边界

`xmg-kb` 是独立知识工程项目和知识源，不属于 xmg-qa2 内部模块。

```text
Raw Documents
   |
Parse / Clean / Deduplicate / Classify / Chunk / Index
   |
   v
xmg-kb
   |
Knowledge Contract
   |
   v
xmg-qa2
```

xmg-qa2 不负责：

- PDF/PPT/Word 原始解析
- OCR
- 文档清洗
- 去重
- 分类
- 切片
- Embedding 批处理
- 知识库构建

xmg-qa2 只消费已发布的 Knowledge Contract，并记录 knowledge version。

---

## 9. Tool 与产品 API

产品 API、MCP、诊断工具统一视为 Tool/Capability。

工具至少声明：

```text
capability
description
input_schema
output_schema
side_effect_level
required_permission
timeout
retry_policy
```

### 工具风险分级

建议至少区分：

- `READ_ONLY`：查询状态、读取日志、获取配置。
- `CONTROLLED_WRITE`：有限配置修改，需要明确 Policy。
- `HIGH_RISK`：重启、删除、升级、破坏性操作，默认要求人工审批。

V1 优先实现只读诊断工具链路。

---

## 10. 错误模型

外部 Provider 错误必须映射为稳定错误类型：

```text
NoResult
ConfigurationError
AuthenticationError
PermissionDenied
TimeoutError
RateLimitError
ProviderUnavailable
InvalidResponse
ContractViolation
ToolExecutionFailed
```

关键规则：

> `ProviderUnavailable` 绝不能被转换成 `NoResult`。

这样才能区分“没有相关知识”和“知识库其实挂了”。

---

## 11. 输出模型

### 简单问题

直接输出：

- 结论
- 关键步骤/建议
- Evidence/Citation
- 必要风险提示

### 复杂问题

自动生成 Technical Report，至少包含：

1. 问题描述
2. 环境与上下文
3. 调查过程
4. 关键 Evidence
5. Hypothesis 与验证结果
6. 根因/当前判断
7. 解决方案
8. 风险与限制
9. 后续建议
10. Evidence / Source References

---

## 12. 可观测性

每一次问题处理至少可以关联：

```text
trace_id
thread_id
turn_id
investigation_id
workflow_id
workflow_version
step_id
provider_id
operation_id
latency
retry_count
token/cost
evidence_ids
final_outcome
```

目标是让运维人员可以回答：

> Agent 为什么调用这个工具、它拿到了什么证据、为什么继续调查、为什么最终停止、最终结论依据是什么？

---

## 13. Runtime 与 LangGraph 边界

LangGraph 仅作为 Workflow Runtime Engine。

不得进入稳定领域模型和 Provider Contract。

原则：

```text
domain
  ^
harness/contracts
  ^
workflows + runtime
  ^
plugins + infrastructure
  ^
api + channels
```

禁止：

```text
domain -> langgraph
domain -> fastapi
workflow -> concrete provider SDK
contracts -> provider implementation
```

未来即使替换 Workflow Engine，也不应破坏 Domain 和 Plugin Contract。

---

## 14. V1 范围

第一阶段只验证核心架构闭环：

- Thread / Turn / Investigation
- Evidence / Hypothesis
- Stable Provider Contracts
- Capability Registry
- Core Support Workflow
- Controlled Agentic Investigation
- Fake Knowledge Provider
- Fake Tool Provider
- Fake Model Provider
- 最小 API
- Trace / Audit 基线
- Unit / Contract / Workflow / Integration / E2E Tests

### V1 不包含

- 真实 xmg-kb 接入
- DingTalk 生产接入
- 真实产品 API
- 高风险自动执行工具
- 知识清洗平台
- 通用 Multi-Agent Supervisor
- 大型管理后台

---

## 15. 后续 Feature 建议顺序

```text
001 Core Support Harness
        |
002 xmg-kb Knowledge Provider
        |
003 Tool / Product API Runtime
        |
004 Expert Investigation Workflow Enhancement
        |
005 Technical Report Generation
        |
006 DingTalk Channel
        |
007 Evaluation / Observability / Production Hardening
```

每个 Feature 独立执行完整 Spec Kit 生命周期，避免把整个产品塞入一个巨大 Spec。

---

## 16. SpecKit 开发门禁

```text
Constitution
  -> Specify
  -> Clarify
  -> Plan
  -> Checklist
  -> Tasks
  -> Analyze
  -> HUMAN CODING GATE
  -> Implement
  -> Verify
  -> Converge
  -> PR
  -> CI / Review
  -> Squash Merge
```

正式编码前必须达到：

```text
Critical = 0
High = 0
```

并获得人工明确授权。

---

## 17. 一句话架构定义

> **xmg-qa2 = XMG Harness + Deterministic Support Workflow + Controlled Agentic Investigation + Evidence Workspace + Pluggable Knowledge/API/Tool Providers。**

Agent 可以主动调查，但 Runtime 必须可控；能力可以持续扩展，但必须通过稳定 Contract；结论可以复杂，但必须有 Evidence。
