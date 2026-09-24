# Jev 决策模型与 Agent 门控最佳实践

Jev 适合做 Agent 和业务工作流里的“语义判断层”：**生成模型负责规划和生成，Jev 负责有限选项中的判断，代码负责授权和执行。**

推荐生产结构：

```text
输入 / 当前状态
      ↓
确定性硬规则
      ↓
LLM 提议动作（可选）
      ↓
Jev：分类 / 评分 / 路由 / 验证
      ↓
代码：校验选项 + 阈值 + 权限策略
      ↓
低风险自动执行 / 高风险审批
      ↓
Tool / API / Shell
```

> 最重要的边界：**Jev 的判断是证据，不是执行权限。**

## 适用场景

- **适用**：Agent、Coding Agent、Harness、RAG、客服、自动化工作流。
- **常见用途**：Tool 路由、下一步动作、风险评分、结果验证、搜索重排、人工升级。
- **不适合**：精确计算、日期比较、确定性规则、开放式文本生成、多步复杂推理。
- **最后验证**：2026-09-24。

| 需求 | 原语 | 示例 |
| --- | --- | --- |
| 从固定集合选一个 | Choice | shell / browser / kb / no_tool |
| 判断条件是否成立 | Noul | 是否需要人工审批 |
| 有序等级评分 | Score | 低 / 中 / 高风险 |

其中 Noul 返回“yes”的概率，没有单独的 confidence。

## 快速实施

### 1. 只替换“语义 if/else”

适合交给 Jev：

```text
这个请求应该调用哪个工具？
当前证据是否支持这个修改？
信息是否足够继续？
这个检索结果是否真正相关？
```

继续交给普通代码：

```text
CPU > 90%？
文件是否存在？
两个日期谁更晚？
金额是否超过阈值？
用户是否拥有 admin 权限？
```

原则：**能用确定性代码解决，就不要调用模型。**

### 2. 最小 Python 示例

```bash
pip install typesafe-sdk
```

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
    response = client.system_one(state=state, questions=questions)
```

API Key 只放服务端安全配置，不写入代码、前端、日志或 Wiki。

## Agent / Harness 推荐模式

### Tool 路由

```text
用户请求
   ↓
代码计算 allowed_tools
   ↓
移除无权限 / 不可用 / 高危工具
   ↓
Jev Choice
   ↓
校验返回值仍属于 allowed_tools
   ↓
低置信度 → ask_user / fallback
   ↓
高风险 → approval
   ↓
Executor
```

必须做到：

1. **先过滤，后路由**：禁止工具不要进入候选集合。
2. 候选项使用稳定 ID。
3. 显式提供 `no_tool`、`ask_user` 或 `stop`。
4. Jev 选中 Tool 后，代码再次检查权限和实时状态。
5. 模型服务异常时不得默认放行。

### LLM 提议，Jev 复核

适合 Coding Agent、自动运维和变更机器人：

```text
LLM proposal
     ↓
代码校验 schema / path / scope / diff
     ↓
Jev 并行判断
 ├─ 是否解决任务
 ├─ 证据是否支持
 ├─ 是否有无关改动
 └─ 是否需要补充信息
     ↓
固定 Decision Table
     ↓
permit / proposal_only / reject / unavailable
     ↓
Host 权限与审批
```

不要让同一个生成模型同时“提出、批准、执行”。

### 动态 Tool 上下文

Tool / MCP 很多时，可以先用硬规则 + Jev 选择 Top-K，再只加载相关 Tool schema：

```text
任务 → 硬规则筛选 → Jev Top-K → 加载完整 schema → LLM 规划
```

该模式必须先做影子测试。上下文变短不代表能力一定更好，多步任务可能后续才需要未加载的 Tool。

## 生产最佳实践

### 1. Code first

以下能力必须留在代码或策略引擎：

- 身份与权限；
- 黑白名单；
- 数学、金额、日期计算；
- 文件和服务真实状态；
- Tool 可用性；
- 最终执行、回退和审批。

Jev 只处理普通规则难以表达的语义判断。

### 2. State 最小化

推荐：

```json
{
  "task": "...",
  "environment": "production",
  "operation": "...",
  "evidence": ["..."]
}
```

不要默认塞入几十轮聊天、整份日志或整个仓库。

用户输入、网页、日志和仓库文本都应视为**不可信数据**，不能因为内容里出现指令就改变系统策略。

### 3. 候选集合必须封闭

推荐：

```text
allowed = [read_only, ask_user, stop]
```

不推荐：

```text
“请告诉我下一步应该运行什么命令”
```

开放式生成应交给 LLM；Jev 负责在固定候选中判断。

### 4. 阈值必须用真实业务数据校准

不要直接复制 Demo 中的 `0.8` 或 `0.85`。

正确流程：

```text
历史样本
  ↓
Shadow 运行
  ↓
记录 probabilities / confidence / 人工结果
  ↓
统计误判、漏判、人工升级率
  ↓
按业务风险确定阈值
```

Choice / Score 的 confidence 是概率分布的集中程度，**不是“本次操作正确率”**。

### 5. 低置信度和异常必须有安全出口

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

高风险动作如删除数据、生产变更、重启关键服务、权限变更、密钥读取和财务操作，即使模型高置信度，也应保留独立审批。

### 6. 独立问题尽量一次判断

同一份 State 可以同时判断：

```text
topic
risk
needs_human
evidence_supports
```

这些问题彼此独立时可一次提交，由代码组合结果。只有后续问题必须依赖前一个答案才能获得新证据时，才拆成多次请求。

### 7. 保存决策回执

至少记录：

```text
request_id
model / version
policy_version
state_hash
candidate_ids
probabilities / confidence
threshold
raw_decision
effective_action
approval_result
execution_result
latency
```

日志中不要默认保存完整源码、隐私数据、Token 或 Secret。

## 推荐上线流程

```text
Baseline
   ↓
Shadow：只记录，不影响线上结果
   ↓
Gate：仅低风险 + 达到阈值的分支自动化
   ↓
Rollout：根据真实指标逐步扩大
```

Shadow 阶段至少观察：

- 与当前规则 / 人工结论的一致率；
- 误判和漏判；
- 人工升级率；
- Provider 失败率；
- 延迟和成本；
- 不同阈值下的业务后果。

高风险分支始终保留独立授权。

## 常见错误

| 错误 | 正确做法 |
| --- | --- |
| 所有判断都交给 Jev | 硬规则和计算继续用代码 |
| Jev 选中 Tool 就执行 | 再校验权限、状态和审批 |
| 候选里包含禁止 Tool | 调用前删除 |
| confidence 高就认为正确 | 用真实数据校准 |
| Provider 超时默认放行 | fail closed 或转人工 |
| 把全部历史塞入 State | 只给当前判断需要的信息 |
| 让 Jev 生成 Shell / SQL | LLM 生成，Jev 做有限判断 |
| 首次上线直接替换旧逻辑 | Baseline → Shadow → Gate |

## 什么时候值得引入

出现以下任一情况时值得评估：

- 代码里有大量难维护的自然语言 if/else；
- Agent Tool / Skill 很多，需要快速路由；
- 生成模型只为了返回一个标签，成本和延迟过高；
- 需要把“模型建议”和“执行权限”分离；
- 需要概率、阈值和人工升级机制；
- RAG / 搜索需要快速语义筛选或重排。

如果普通代码已经稳定解决问题，就继续使用普通代码。

## 官方资料

- TypeSafe Jev：https://typesafe.ai/blog/introducing-system-one-models-and-jev
- TypeSafe Docs：https://docs.typesafe.ai/
- TypeSafe Skills：https://github.com/typesafe-ai/skills
- Tool Router 示例：https://github.com/TypeSafeAI/typesafe-playground/blob/main/docs/tool-router.md
- Jev Harness 社区实验：https://github.com/TypeSafeAI/jev-harness

> API 字段、模型版本、价格、配额和 SDK 参数变化较快，实施前以 TypeSafe 官方实时文档为准。
