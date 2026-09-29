# Agent 工程化

本分类记录 Agent 从 Demo 走向可持续运行时最需要补齐的工程能力。核心不是堆更多模型或更多 Agent，而是把 **任务、上下文、工具、权限、运行环境、状态、验证和观测** 变成可控制的系统能力。

## 最短结论

把 Agent 分成几层理解，排障和设计会简单很多：

~~~text
Model
  ↓
Harness
  ├─ Task / Plan
  ├─ Context / State
  ├─ Tool / Skill / MCP
  ├─ Permission / Verification
  └─ Recovery
  ↓
Runtime
  ↓
Sandbox / Environment
  ↓
企业系统、代码、浏览器、Shell
~~~

- **Model**：理解、推理、生成和动作选择。
- **Harness**：组织任务并约束模型如何行动。
- **Runtime**：承载长任务、调度、等待、恢复和并发。
- **Sandbox / Environment**：限定文件、Shell、浏览器、网络和资源的影响范围。
- **Platform / Gateway**：多 Agent 规模化后再统一做路由、身份、审计、配额和资产管理。

不要把所有问题都归因于“模型不够聪明”。很多生产问题实际来自上下文、工具定义、权限、状态恢复或验证机制。

## 阅读顺序

1. [Agent 工程化检查清单](agent-engineering-checklist.md)：新 Agent 立项和上线前先过一遍。
2. [Context、State、Memory 与 Knowledge](context-state-memory-knowledge.md)：解决信息应该放在哪里。
3. [Tool、MCP、Skill 与权限](tools-mcp-skills-permissions.md)：解决 Agent 能做什么、谁允许它做。
4. [Runtime、Sandbox 与长任务](runtime-sandbox-long-tasks.md)：解决任务如何持续运行和隔离。
5. [多 Agent 与 AI Gateway](multi-agent-gateway.md)：只有单 Agent 不够时再引入。
6. [可观测、评估与 Badcase](observability-evaluation-badcase.md)：解决如何证明 Agent 真的变好了。
7. [Agent 安全与治理](security-governance.md)：解决越权、注入、资产和审计问题。
8. [运维 Agent 生产闭环](ops-agent-production-pattern.md)：把上述能力映射到 Linux/K8s/生产运维。

Coding Agent 的 Harness 实现另见 [Agent Harness 开发速查](../coding/agent-harness-development.md)。

## 什么时候不要上复杂 Agent

以下场景优先选择更简单方案：

- 只是固定知识问答：先做 RAG。
- 步骤完全确定：优先 Workflow / Script。
- 工具只有一两个且无长任务：轻量 Function Calling 足够。
- 没有明确收益：不要为了“多 Agent”拆成多个 Agent。
- 不能定义成功标准：先把验收条件补齐，再增加自主执行。

## 参考资料

- [AI Agent HandBook README](https://github.com/aliyun/ai-agent-handbook/blob/main/README.md)
- [第 1 章：AI 原生应用的新阶段](https://github.com/aliyun/ai-agent-handbook/blob/main/01-architecture/%E7%AC%AC%201%20%E7%AB%A0%E3%80%80AI%20%E5%8E%9F%E7%94%9F%E5%BA%94%E7%94%A8%E7%9A%84%E6%96%B0%E9%98%B6%E6%AE%B5.md)
- [第 2 章：Agentic Application 参考架构](https://github.com/aliyun/ai-agent-handbook/blob/main/01-architecture/%E7%AC%AC%202%20%E7%AB%A0%E3%80%80Agentic%20Application%20%E5%8F%82%E8%80%83%E6%9E%B6%E6%9E%84.md)
- [第 3 章：Harness 的主流构建方式和责任边界](https://github.com/aliyun/ai-agent-handbook/blob/main/02-build/%E7%AC%AC%203%20%E7%AB%A0%20%E8%8C%83%E5%BC%8F%EF%BC%9AHarness%20%E7%9A%84%E4%B8%BB%E6%B5%81%E6%9E%84%E5%BB%BA%E6%96%B9%E5%BC%8F%E5%92%8C%E8%B4%A3%E4%BB%BB%E8%BE%B9%E7%95%8C.md)

> 本文基于上述一手资料做工程化整理与归纳，不逐字复制原文。上游 ai-agent-handbook 使用 Apache-2.0 License；具体实现和产品能力以各项目当前官方文档为准。
