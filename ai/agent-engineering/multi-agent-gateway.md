# 多 Agent 与 AI Gateway

多 Agent 不是默认架构。只有一个 Agent 已经因为上下文、权限、专业能力或并行任务边界变得难以维护时，再拆分。

## 什么时候值得拆成多 Agent

典型信号：

- 不同角色需要完全不同的工具和权限；
- 子任务可以独立验收；
- 上下文差异很大，放在一个 Agent 中持续污染；
- 有明确并行收益；
- 不同团队维护不同能力。

不适合拆分：

- 只是为了让架构看起来先进；
- 子 Agent 输出无法验证；
- 共享状态没有统一来源；
- 任务只是固定流水线，Workflow 更简单。

## 最小协作模型

~~~text
Coordinator
   ├─ Agent A → Result + Evidence
   ├─ Agent B → Result + Evidence
   └─ Agent C → Result + Evidence
          ↓
     Aggregate / Verify
~~~

委派时至少携带：

~~~text
task_id
objective
input
allowed_tools
permission_scope
deadline
expected_output
success_criteria
~~~

不要把整个上游 Context 原样复制给所有子 Agent。

## AI Gateway 的作用

多模型、多 MCP、多 Agent 以后，再考虑统一入口：

~~~text
Agent
  ↓
AI Gateway
  ├─ Identity
  ├─ Routing
  ├─ AuthZ
  ├─ Rate Limit
  ├─ Budget
  ├─ Retry / Fallback
  ├─ Audit
  └─ Trace
      ↓
Model / MCP / Agent
~~~

Gateway 适合承接跨应用一致的流量治理，但不应该替代业务层的任务状态和最终权限判断。

## 防止协作失控

必须关注：

- 调用深度上限；
- 总步骤和总 Token 预算；
- 超时；
- 循环调用检测；
- 幂等任务 ID；
- 单个 Agent 失败后的降级；
- 聚合结果的证据验证。

## 参考资料

- [第 9 章：AI 网关与统一流量治理](https://github.com/aliyun/ai-agent-handbook/blob/main/03-run/%E7%AC%AC%209%20%E7%AB%A0%20%20AI%20%E7%BD%91%E5%85%B3%E4%B8%8E%E7%BB%9F%E4%B8%80%E6%B5%81%E9%87%8F%E6%B2%BB%E7%90%86.md)
- [第 11 章：Multi-Agent 协作与编排](https://github.com/aliyun/ai-agent-handbook/blob/main/03-run/%E7%AC%AC%2011%E7%AB%A0%20%20Multi-Agent%20%E5%8D%8F%E4%BD%9C%E4%B8%8E%E7%BC%96%E6%8E%92.md)
- [第 12 章：Agent 分布式通信](https://github.com/aliyun/ai-agent-handbook/blob/main/03-run/%E7%AC%AC%2012%20%E7%AB%A0%20Agent%20%E5%88%86%E5%B8%83%E5%BC%8F%E9%80%9A%E4%BF%A1.md)

> 本文基于上述一手资料做工程化整理与归纳，不逐字复制原文。上游 ai-agent-handbook 使用 Apache-2.0 License；具体实现和产品能力以各项目当前官方文档为准。
