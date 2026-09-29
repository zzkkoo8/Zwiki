# Context、State、Memory 与 Knowledge

Agent 信息管理最容易出现的问题，是把所有内容都塞进上下文窗口。生产设计应先区分信息的生命周期，再决定放哪里。

## 快速判断

| 对象 | 解决什么问题 | 典型内容 |
| --- | --- | --- |
| Context | 本轮模型现在需要看到什么 | 指令、相关文档、工具结果摘要 |
| Session | 一次会话的交互连续性 | 消息、游标、会话元数据 |
| Task State | 任务已经推进到哪里 | 阶段、计划、待审批、检查点 |
| Workspace | 当前任务产生的工作材料 | 文件、补丁、截图、临时数据 |
| Memory | 以后任务还值得复用的经验 | 用户偏好、已验证策略、经验规则 |
| Knowledge | 外部事实和业务知识 | 产品文档、SOP、FAQ、制度、代码文档 |
| Skill | 如何完成某类任务的方法 | 步骤、规则、脚本入口、验证方法 |

## Context 的原则

不要追求“全部塞进去”，而要做按需构建：

~~~text
稳定系统指令
    +
当前任务状态
    +
最相关 Knowledge
    +
当前需要的 Skill
    +
最近工具结果
    ↓
本轮 Context
~~~

长任务中应使用摘要、文件卸载或 Artifact 引用，避免每轮重复注入完整日志和大文档。

## State 不等于聊天记录

如果任务需要几个小时、等待审批或跨进程恢复，关键事实必须进入结构化 Task State。

至少保存：

~~~text
task_id
status
current_stage
plan
completed_steps
pending_action
approval_state
checkpoint
artifacts
last_error
~~~

服务重启后应能判断“从哪里继续”，而不是重新读取全部聊天猜进度。

## Memory 与 Knowledge 不要混用

**Knowledge** 是外部事实，应有来源、版本和更新机制。

**Memory** 是 Agent 从交互和运行中保留的可复用信息，应能更新、淘汰和删除。

常见错误：

- 把产品手册长期复制进 Memory；
- 把一次失败结论永久写入 Memory；
- 不记录来源和时间；
- 只新增，不支持更新和遗忘。

## Skill 使用渐进式披露

入口只告诉 Agent“有哪些能力”和“什么时候用”，需要时再读取完整 Skill。

推荐：

~~~text
AGENTS.md / System
  ↓
Skill 索引
  ↓
选择相关 Skill
  ↓
读取具体步骤
  ↓
执行并验证
~~~

这样比维护一个越来越大的系统提示词更稳定。

## RAG Agent 的优先级

只做知识问答时，先解决：

1. 文档质量；
2. Chunk / Retrieval；
3. 产品或租户过滤；
4. Context 组装；
5. 答案引用；
6. Golden Dataset 与回归。

没有工具执行需求时，不需要先引入完整 Runtime、多 Agent 和复杂 Memory。

## 参考资料

- [第 5 章：上下文、状态与可复用能力资产](https://github.com/aliyun/ai-agent-handbook/blob/main/02-build/%E7%AC%AC%205%20%E7%AB%A0%20%E4%BF%A1%E6%81%AF%EF%BC%9A%E4%B8%8A%E4%B8%8B%E6%96%87%E3%80%81%E7%8A%B6%E6%80%81%E4%B8%8E%E5%8F%AF%E5%A4%8D%E7%94%A8%E8%83%BD%E5%8A%9B%E8%B5%84%E4%BA%A7.md)
- [第 8 章：Agent 状态存储与语义资产](https://github.com/aliyun/ai-agent-handbook/blob/main/03-run/%E7%AC%AC%208%20%E7%AB%A0%20Agent%20%E7%8A%B6%E6%80%81%E5%AD%98%E5%82%A8%E4%B8%8E%E8%AF%AD%E4%B9%89%E8%B5%84%E4%BA%A7.md)
- [第 15 章：AI 资产的发现与管理](https://github.com/aliyun/ai-agent-handbook/blob/main/04-governance/%E7%AC%AC%2015%20%E7%AB%A0%E3%80%80AI%20%E8%B5%84%E4%BA%A7%E7%9A%84%E5%8F%91%E7%8E%B0%E4%B8%8E%E7%AE%A1%E7%90%86.md)

> 本文基于上述一手资料做工程化整理与归纳，不逐字复制原文。上游 ai-agent-handbook 使用 Apache-2.0 License；具体实现和产品能力以各项目当前官方文档为准。
