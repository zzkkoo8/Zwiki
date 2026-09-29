# Agent 工程化检查清单

新建 Agent、把现有 Agent 接入生产，或审计 Codex/运维 Agent 时，先用本页做最小检查。

## 1. 先确认任务是不是适合 Agent

~~~text
□ 输入和目标可描述
□ 有明确成功标准
□ 可以验证最终结果
□ 失败有可接受的回退路径
□ 确实需要模型在运行时做判断
~~~

如果每一步都确定，优先脚本或 Workflow；如果只是查知识，优先 RAG。

## 2. Harness

~~~text
□ 有明确 Agent Contract：目标、输入、输出、禁止事项
□ Agent Loop 有退出条件
□ 长任务有阶段状态，不只靠聊天历史
□ 完成由证据决定，不接受模型只说“完成了”
□ 工具失败、超时和重试策略明确
~~~

## 3. 信息

~~~text
□ Context 只加载当前任务需要的信息
□ Session 与 Task State 分开
□ 临时工作文件进入 Workspace
□ Knowledge 保存外部事实
□ Memory 保存可复用经验，而不是复制知识库
□ Skill 按需加载，不把全部说明塞进 System Prompt
~~~

## 4. 行动与权限

~~~text
□ Read / Write / Destructive 分级
□ 权限由 Policy 层机械执行，不由模型自我判断
□ 写操作声明副作用、幂等性、可否重试
□ 高危动作需要 HITL 或明确禁止
□ 外部凭据使用最小权限和短时凭据
~~~

推荐最小策略：

| 风险 | 示例 | 默认 |
| --- | --- | --- |
| Read | 查 KB、日志、GET API、状态查询 | 自动 |
| Write | 提交分支、改工单、普通配置变更 | 自动或策略审批 |
| High Risk | 生产重启、批量变更、数据库写入 | 人工确认 |
| Forbidden | 不可恢复删除、越权取密钥 | 拒绝 |

## 5. Runtime 与 Sandbox

~~~text
□ 长任务可以暂停、继续或安全重跑
□ 保存 checkpoint / task state
□ Shell、代码和浏览器尽量在隔离环境执行
□ Sandbox 的文件、网络、Secret、CPU/内存边界清楚
□ Agent 服务重启不会导致重复执行高风险写操作
~~~

## 6. 验证与可观测

~~~text
□ 每次模型调用和工具调用有 Trace
□ 记录 task/session、模型、工具、耗时、错误和成本
□ 最终 Artifact / 业务状态可验证
□ 有真实任务 Golden Dataset
□ Badcase 能归因到 Retrieval / Context / Tool / Policy / Model / Runtime
□ 修改后必须回归，而不是只看一次聊天效果
~~~

## 7. 上线门槛

满足下面条件再考虑扩大自主度：

~~~text
可观测
  ↓
可验证
  ↓
可回滚
  ↓
权限受控
  ↓
再提高自动化
~~~

不要反过来先全自动，再补审计和安全。

## 参考资料

- [第 3 章：Harness](https://github.com/aliyun/ai-agent-handbook/blob/main/02-build/%E7%AC%AC%203%20%E7%AB%A0%20%E8%8C%83%E5%BC%8F%EF%BC%9AHarness%20%E7%9A%84%E4%B8%BB%E6%B5%81%E6%9E%84%E5%BB%BA%E6%96%B9%E5%BC%8F%E5%92%8C%E8%B4%A3%E4%BB%BB%E8%BE%B9%E7%95%8C.md)
- [第 4 章：任务、长程推进与协作流转](https://github.com/aliyun/ai-agent-handbook/blob/main/02-build/%E7%AC%AC%204%20%E7%AB%A0%20%E4%BB%BB%E5%8A%A1%EF%BC%9A%E7%BC%96%E6%8E%92%E3%80%81%E9%95%BF%E7%A8%8B%E6%8E%A8%E8%BF%9B%E4%B8%8E%E5%8D%8F%E4%BD%9C%E6%B5%81%E8%BD%AC.md)
- [第 5 章：上下文、状态与可复用能力资产](https://github.com/aliyun/ai-agent-handbook/blob/main/02-build/%E7%AC%AC%205%20%E7%AB%A0%20%E4%BF%A1%E6%81%AF%EF%BC%9A%E4%B8%8A%E4%B8%8B%E6%96%87%E3%80%81%E7%8A%B6%E6%80%81%E4%B8%8E%E5%8F%AF%E5%A4%8D%E7%94%A8%E8%83%BD%E5%8A%9B%E8%B5%84%E4%BA%A7.md)
- [第 6 章：受控执行、验证反馈与交付准备](https://github.com/aliyun/ai-agent-handbook/blob/main/02-build/%E7%AC%AC%206%20%E7%AB%A0%20%E8%A1%8C%E5%8A%A8%EF%BC%9A%E5%8F%97%E6%8E%A7%E6%89%A7%E8%A1%8C%E3%80%81%E9%AA%8C%E8%AF%81%E5%8F%8D%E9%A6%88%E4%B8%8E%E4%BA%A4%E4%BB%98%E5%87%86%E5%A4%87.md)
- [第 14 章：Agent 安全](https://github.com/aliyun/ai-agent-handbook/blob/main/04-governance/%E7%AC%AC%2014%20%E7%AB%A0%E3%80%80Agent%20%E5%AE%89%E5%85%A8.md)

> 本文基于上述一手资料做工程化整理与归纳，不逐字复制原文。上游 ai-agent-handbook 使用 Apache-2.0 License；具体实现和产品能力以各项目当前官方文档为准。
