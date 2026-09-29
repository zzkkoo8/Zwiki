# 可观测、评估与 Badcase

Agent 是否“变好了”不能只靠聊天体验。生产环境至少要建立 **Trace → Trajectory → Badcase → 修复 → 回归** 的闭环。

## 先记录什么

每次任务至少记录：

~~~text
task_id / session_id
agent_version
model
prompt/skill/tool version
tool_calls
latency
errors
token/cost
approvals
artifacts
final_status
verification_result
~~~

## Trace、Session、Trajectory

- **Trace**：一次执行过程中发生了哪些调用和事件。
- **Session**：一段会话或交互的连续容器。
- **Trajectory**：为了完成一个任务，Agent 实际走过的动作和决策路径。

评估复杂 Agent 时，只看最终回答不够。最终答案对，也可能经过危险或低效路径；最终答案错，也可能是工具故障而不是模型问题。

## Badcase 归因

发现失败后先分类：

~~~text
Knowledge    缺资料或资料过期
Retrieval    没召回正确内容
Context      信息组织/压缩错误
Tool         参数、描述或接口失败
Policy       权限或审批策略错误
Runtime      超时、状态、恢复失败
Model        信息充分时仍持续判断错误
Verification 验收条件错误或缺失
~~~

不要发现错误就直接改 Prompt 或换模型。

## Golden Dataset

从真实业务中先选少量高价值任务：

- 常见任务；
- 高风险任务；
- 历史 Badcase；
- 边界输入；
- 工具失败场景。

每条至少包含：

~~~text
input
required_context
expected_outcome
allowed/forbidden_actions
verification
optional_reference_trajectory
~~~

从 20～50 条真正能人工审完的用例开始，比一次构建几千条低质量样本更有价值。

## 优化闭环

~~~text
线上 Trace
   ↓
发现 Badcase
   ↓
补齐证据
   ↓
归因
   ↓
修改 Context / Tool / Skill / Policy / Model
   ↓
离线回归
   ↓
小流量验证
   ↓
上线
~~~

经过验证的经验可以沉淀成 Skill、Memory、工具规则或 Harness 机制，但不要允许 Agent 无审核地修改自己的生产控制逻辑。

## 参考资料

- [第 13 章：Agent 的可观测性](https://github.com/aliyun/ai-agent-handbook/blob/main/04-governance/%E7%AC%AC%2013%20%E7%AB%A0%E3%80%80Agent%20%E7%9A%84%E5%8F%AF%E8%A7%82%E6%B5%8B%E6%80%A7.md)
- [第 19 章：Agent 轨迹数据](https://github.com/aliyun/ai-agent-handbook/blob/main/05-optimization/%E7%AC%AC%2019%20%E7%AB%A0%E3%80%80Agent%20%E8%BD%A8%E8%BF%B9%E6%95%B0%E6%8D%AE.md)
- [第 21 章：Agent 黄金数据集](https://github.com/aliyun/ai-agent-handbook/blob/main/05-optimization/%E7%AC%AC%2021%20%E7%AB%A0%E3%80%80Agent%20%E9%BB%84%E9%87%91%E6%95%B0%E6%8D%AE%E9%9B%86.md)
- [第 22 章：Agent 优化：Badcase](https://github.com/aliyun/ai-agent-handbook/blob/main/05-optimization/%E7%AC%AC%2022%20%E7%AB%A0%E3%80%80Agent%20%E4%BC%98%E5%8C%96%EF%BC%9ABadcase.md)
- [第 23 章：受控自进化](https://github.com/aliyun/ai-agent-handbook/blob/main/05-optimization/%E7%AC%AC%2023%20%E7%AB%A0%E3%80%80%E5%8F%97%E6%8E%A7%E8%87%AA%E8%BF%9B%E5%8C%96.md)

> 本文基于上述一手资料做工程化整理与归纳，不逐字复制原文。上游 ai-agent-handbook 使用 Apache-2.0 License；具体实现和产品能力以各项目当前官方文档为准。
