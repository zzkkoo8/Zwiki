# Jev 决策模型与 Agent 门控最佳实践

Jev 适合放在 Agent 或业务工作流的“判断层”：让生成模型负责规划和生成，让 Jev 负责封闭选项中的分类、评分、路由和验证，最终由代码决定是否执行。

最推荐的生产结构不是“Jev 判断 → 直接执行”，而是：

```text
输入 / 当前状态
      ↓
确定性硬规则校验
      ↓
LLM 提议动作（可选）
      ↓
Jev 做窄语义判断
      ↓
代码校验选项、阈值和策略
      ↓
低风险自动执行 / 中高风险审批
      ↓
Tool / API / Shell
      ↓
记录决策与执行结果
```

> 核心原则：**模型负责判断，代码负责授权，执行器负责动作。**

## 适用场景

- **适用组件**：Agent、Coding Agent、Harness、RAG、智能客服、自动化工作流。
- **典型任务**：工具路由、下一步动作选择、风险评分、结果验证、搜索重排、人工升级。
- **不适合**：精确计算、日期比较、确定性规则、开放式长文本生成、多步复杂推理。
- **最后验证**：2026-09-24。

常见用法：

| 场景 | 推荐原语 | 示例 |
| --- | --- | --- |
| 工具 / Agent 路由 | Choice | web_search / shell / kb / no_tool |
| 是否需要人工处理 | Noul | 是否存在高风险或信息不足 |
| 风险、相关性、严重度 | Score | low / medium / high |
| RAG 结果筛选 | Score / Noul | 文档是否与问题直接相关 |
| LLM 输出复核 | Noul / Score | 结论是否有证据支持 |
| 工作流控制 | Choice | continue / retry / ask_user / stop |

## 快速实施

### 1. 先找“语义 if/else”，不要替换确定性代码

优先挑这种逻辑：

```text
这个请求应该调用哪个工具？
这个修改是否与任务相关？
当前信息是否足够继续？
这个结果是否值得送给大模型？
```

不要把下面这些交给 Jev：

```text
CPU > 90%？
两个日期谁更晚？
文件是否存在？
金额是否超过 10000？
用户是否拥有 admin 权限？
```

这些应继续使用普通代码、数据库或策略引擎。

### 2. 选择正确的判断类型

Jev 常用三种原语：

- **Choice**：从预定义选项中选一个，适合路由和状态切换。
- **Noul**：判断某个条件是否成立，返回 yes 的概率；没有单独的 confidence。
- **Score**：沿有序等级做评分，适合风险、严重度、相关度等。

一个问题只表达一个清晰判断。不要把“是否安全、是否相关、是否需要重试”混在同一个问题里。

### 3. 最小 Python 示例

安装官方 SDK：

```bash
pip install typesafe-sdk
```

示例：

```python
from typesafe_sdk import TypeSafeClient, Choice, Noul, Score

state = {
    "request": "读取生产环境 nginx 配置并分析超时参数",
    "environment": "production",
    "requested_action": "read_config",
}

questions = {
    "next_action": Choice(
        instructions="下一步应该采取哪个动作？",
        criteria={
            "read_only": "只读取配置或状态，不修改系统",
            "needs_approval": "需要修改生产系统或执行高风险操作",
            "ask_user": "关键信息不足，需要用户补充",
            "stop": "当前请求不应继续执行",
        },
    ),
    "needs_human": Noul(
        instructions="该请求是否需要人工审批后才能继续？"
    ),
    "risk": Score(
        instructions="评估该动作的执行风险",
        criteria=[
            "低风险：只读、可安全重复",
            "中风险：可能影响服务，但容易回退",
            "高风险：可能导致中断、删除、泄露或不可逆影响",
        ],
    ),
}

with TypeSafeClient() as client:
    response = client.system_one(
        state=state,
        questions=questions,
    )

answers = response.answers
print(answers["next_action"].choice)
print(answers["next_action"].confidence)
print(answers["needs_human"].noul)
print(answers["risk"].score)
```

API Key 只通过服务端安全配置注入，不写入代码、前端、日志或 Wiki。

## Agent / Harness 推荐架构

### 模式 A：工具路由

```text
用户请求
   ↓
代码计算当前允许使用的工具集合
   ↓
过滤无权限 / 不可用 / 高危工具
   ↓
Jev Choice：从剩余工具中选择
   ↓
校验返回值必须属于 allowed_tools
   ↓
低置信度 → ask_user / fallback
   ↓
需要审批 → approval gate
   ↓
Executor 执行
```

关键点：

1. **先过滤，后判断。** 不允许执行的工具不要放进候选集合。
2. 候选项使用稳定 ID，例如 `read_config`、`restart_service`。
3. 显式提供 `no_tool`、`ask_user` 或类似安全出口。
4. Jev 选出的工具必须再次在代码中检查权限和当前可用状态。
5. 模型只能选择动作，不能因此获得执行权限。

### 模式 B：LLM 提议，Jev 复核

适合 Coding Agent、自动运维和变更机器人：

```text
LLM 生成 proposal
      ↓
代码检查 schema / path / scope / diff
      ↓
Jev 并行判断
  ├─ 是否解决任务
  ├─ 证据是否支持
  ├─ 是否存在无关改动
  └─ 是否需要补充信息
      ↓
固定 Decision Table
      ↓
permit / proposal_only / reject / unavailable
      ↓
Host 再做权限与审批
```

这比让同一个生成模型“自己提出、自己批准、自己执行”更容易审计。

### 模式 C：动态工具上下文

当 Agent 有几十到几百个 MCP / Tool 时，不要默认把所有 schema 全塞进生成模型上下文。

可以采用：

```text
任务
 ↓
硬规则筛选
 ↓
Jev 选择 Top-K 相关工具
 ↓
只加载这些工具的完整 schema
 ↓
生成模型规划与调用
```

但必须做影子测试：工具上下文变少可能降低 Token 和延迟，也可能漏掉多步任务后续才需要的工具。不能只看“上下文更短”就判断方案更好。

## 生产最佳实践

### 1. Code first，Jev 只处理语义不确定性

以下内容必须优先留在代码：

- 权限和身份校验；
- 确定性黑白名单；
- 金额、数量、日期和数学计算；
- 文件、资源、服务真实状态；
- Tool 是否存在和当前是否可用；
- 最终执行和回退逻辑。

Jev 用于普通代码难以稳定表达的语义判断。

### 2. State 只给判断真正需要的信息

推荐：

```json
{
  "task": "...",
  "environment": "production",
  "operation": "...",
  "evidence": ["..."]
}
```

避免把几十轮聊天、无关日志和整份仓库上下文全部塞进去。

State 中的仓库文本、用户输入、日志、网页内容都应视为**不可信数据**，不是系统指令。

### 3. 候选集合必须封闭

推荐：

```text
allowed = [read_only, ask_user, stop]
Jev 只能从 allowed 中选
```

不要：

```text
“请告诉我下一步应该运行什么命令”
```

后一种已经重新变成开放式生成问题，应交给生成模型，并由独立策略层审核。

### 4. 阈值必须用自己的数据校准

不要直接把示例里的 `0.8`、`0.85` 当成生产标准。

正确流程：

```text
真实历史样本
   ↓
Jev 影子运行
   ↓
记录概率 / confidence / 人工结果
   ↓
统计误判与人工升级率
   ↓
按业务风险确定阈值
```

Choice / Score 的 confidence 描述的是候选概率分布集中程度，**不是“这次操作正确的概率”**。Noul 的概率本身已经表达二元判断的不确定性。

### 5. 低置信度必须有安全出口

典型策略：

```python
if provider_failed:
    return "unavailable"

if selected_option not in allowed_options:
    return "stop"

if confidence < calibrated_threshold:
    return "ask_user"

if operation_is_high_risk:
    return "needs_approval"

return "execute"
```

不要把“模型服务失败”转换成默认放行。

### 6. 高风险动作永远单独授权

以下动作即使 Jev 高置信度，也不应单独决定执行：

- 删除数据；
- 修改生产配置；
- 重启关键服务；
- 网络、账号、权限变更；
- 密钥和敏感信息读取；
- 打款、采购等财务操作。

推荐：

```text
Jev 判断 = 证据
Authorization / Approval = 权限
Executor = 执行
```

三者分离。

### 7. 同一份 State 上的独立问题尽量一次并行判断

例如工单处理可以一次判断：

```text
topic
needs_refund
urgency
needs_human
```

这些问题相互独立时可以一起提交，然后由代码组合结果。若第二个问题必须依赖第一个答案才能构造新的证据或候选集合，再拆成第二次请求。

### 8. 保存“决策回执”，不要只记最终动作

建议记录：

```text
request_id
model / version
policy_version
state_hash
candidate_ids
probabilities
confidence
threshold
raw_decision
effective_action
approval_result
execution_result
latency
```

不要默认把完整源码、用户隐私、Token 或 Secret 写入日志。需要审计原文时，应使用受控存储和脱敏策略。

## 推荐上线流程

不要第一次接入就替换线上逻辑。

### 阶段 1：Baseline

保留现有代码或人工流程，明确当前准确率、人工量、延迟和成本。

### 阶段 2：Shadow

Jev 跟随线上请求运行，但不影响实际结果，只记录：

- 选择结果；
- probabilities / confidence；
- 与现有决策是否一致；
- 人工最终结论；
- 延迟和成本。

### 阶段 3：Gate

只让 Jev 影响低风险分支：

```text
高置信度 + 低风险 → 自动
其他 → 原流程 / 人工
```

### 阶段 4：逐步扩大

只有在真实数据证明误判、漏判、人工升级率和服务稳定性满足要求后，再扩大自动化范围。

任何高风险分支仍保留独立授权。

## 常见错误

| 错误做法 | 正确做法 |
| --- | --- |
| 所有判断都交给 Jev | 硬规则和计算继续用代码 |
| Jev 选中 Tool 就直接执行 | 代码再次校验权限、状态和审批 |
| 候选里包含禁止工具 | 调用 Jev 前就移除 |
| confidence 高就认为一定正确 | 用真实业务数据校准 |
| provider 超时后默认放行 | fail closed 或转人工 |
| 把所有历史对话塞进 State | 只提供当前判断所需状态 |
| 让 Jev 生成 Shell / SQL | 生成交给 LLM，Jev 做有限判断 |
| 一上线就替换旧逻辑 | baseline → shadow → gate → rollout |

## 什么时候值得引入 Jev

满足下面至少一个条件时值得评估：

- 代码里已经出现大量难维护的自然语言 if/else；
- Agent 工具太多，需要快速做 Tool / Skill 路由；
- 生成模型只为了返回一个标签却消耗较高延迟和 Token；
- 需要把“模型建议”与“执行权限”拆开；
- 需要概率、阈值和人工升级机制；
- RAG / 搜索需要快速语义筛选或重排。

如果一个问题普通代码能稳定解决，继续使用普通代码通常更简单。

## 官方资料

- TypeSafe Jev 介绍：https://typesafe.ai/blog/introducing-system-one-models-and-jev
- TypeSafe 官方文档：https://docs.typesafe.ai/
- TypeSafe 官方 Skills：https://github.com/typesafe-ai/skills
- Jev Tool Router 示例：https://github.com/TypeSafeAI/typesafe-playground/blob/main/docs/tool-router.md
- Jev Harness 社区实验：https://github.com/TypeSafeAI/jev-harness

> Zwiki 只保留可直接落地的工程模式。具体模型版本、API 字段、价格、配额和 SDK 参数以 TypeSafe 官方实时文档为准。
