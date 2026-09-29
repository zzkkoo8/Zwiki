# Tool、MCP、Skill 与权限

Agent 能调用工具以后，重点不再是“接了多少工具”，而是工具是否容易选对、权限是否可控、失败后是否安全。

## 边界

- **Tool / Function**：具体动作接口。
- **MCP**：标准化连接外部工具、数据和服务。
- **Skill**：完成一类任务的方法、规则和工作流。
- **Policy**：决定某个身份在当前任务是否可以执行某个动作。
- **HITL**：高风险步骤交由人确认。

MCP 解决“怎么接”，不自动解决授权、审计、幂等、重试和生产安全。

## 工具最小契约

每个 Tool 至少声明：

~~~text
name
description
input_schema
output_schema
error_schema
timeout
permission_level
side_effect
idempotent
retry_policy
~~~

其中生产环境特别重要的是：

- 是否有外部副作用；
- 是否幂等；
- 失败后是否可以安全重试。

没有这三项，自动重试很容易把一次写操作放大成事故。

## 权限分级

~~~text
Tool Request
    ↓
Policy Check
    ├─ Read        → 自动允许
    ├─ Write       → 条件允许 / 审批
    ├─ High Risk   → HITL
    └─ Forbidden   → 拒绝
~~~

不要让模型根据提示词自己决定“这个命令应该没危险”。真正的权限检查应在模型之外执行。

## MCP 接入生产需要补的能力

企业内 MCP 通常还需要：

- 服务注册和发现；
- 版本与灰度；
- 调用身份；
- 最小权限；
- Secret 管理；
- 参数校验；
- 审计日志；
- 速率与预算限制；
- 服务健康和熔断。

工具多时不要一次把全部描述塞入 Context，应做按需发现或分类检索。

## Skill 与 MCP 如何选

~~~text
只是告诉 Agent 怎么做？
  → Skill

需要访问外部系统或执行动作？
  → Tool / MCP

需要把多步做法固化，并调用若干工具？
  → Skill + Tool/MCP

需要审批和限制副作用？
  → 再加 Policy / HITL
~~~

## Agent 资产管理

规模上来后，Prompt、Skill、MCP Server、Agent 都应该有：

~~~text
owner
version
status
permissions
dependencies
change_history
review_status
release_channel
~~~

不要把几十个 MCP 和 Skill 分散在个人配置里长期维护。

## 参考资料

- [第 6 章：受控执行、验证反馈与交付准备](https://github.com/aliyun/ai-agent-handbook/blob/main/02-build/%E7%AC%AC%206%20%E7%AB%A0%20%E8%A1%8C%E5%8A%A8%EF%BC%9A%E5%8F%97%E6%8E%A7%E6%89%A7%E8%A1%8C%E3%80%81%E9%AA%8C%E8%AF%81%E5%8F%8D%E9%A6%88%E4%B8%8E%E4%BA%A4%E4%BB%98%E5%87%86%E5%A4%87.md)
- [第 9 章：AI 网关与统一流量治理](https://github.com/aliyun/ai-agent-handbook/blob/main/03-run/%E7%AC%AC%209%20%E7%AB%A0%20%20AI%20%E7%BD%91%E5%85%B3%E4%B8%8E%E7%BB%9F%E4%B8%80%E6%B5%81%E9%87%8F%E6%B2%BB%E7%90%86.md)
- [第 14 章：Agent 安全](https://github.com/aliyun/ai-agent-handbook/blob/main/04-governance/%E7%AC%AC%2014%20%E7%AB%A0%E3%80%80Agent%20%E5%AE%89%E5%85%A8.md)
- [第 15 章：AI 资产的发现与管理](https://github.com/aliyun/ai-agent-handbook/blob/main/04-governance/%E7%AC%AC%2015%20%E7%AB%A0%E3%80%80AI%20%E8%B5%84%E4%BA%A7%E7%9A%84%E5%8F%91%E7%8E%B0%E4%B8%8E%E7%AE%A1%E7%90%86.md)

> 本文基于上述一手资料做工程化整理与归纳，不逐字复制原文。上游 ai-agent-handbook 使用 Apache-2.0 License；具体实现和产品能力以各项目当前官方文档为准。
