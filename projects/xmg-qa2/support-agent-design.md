> [!IMPORTANT]
> **自动生成阅读镜像，请勿直接编辑。**
>
> 权威源：<https://github.com/zzkkoo8/xmg-qa2/blob/main/docs/design/XMG-QA2-SUPPORT-AGENT-DESIGN.md>
>
> Source Commit: `fd5e19c813aa86e8c56830fdb0cd197f28b85c9f`

# xmg-qa2 技术支持 Agent 设计

版本：1.1；日期：2026-09-05；Pre-Implementation。

## 1. 产品定义

小马哥的首要功能是高质量回答问题，表现为能持续调查的数字技术支持工程师。先理解所问，能可靠回答就及时回答，缺证据则自主补齐；任务管理与 Web 等能力保障这一过程。它将内部产品资料、官方公开文档、模型通用知识和获准现场观察放在同一调查工作区，提出并验证假设，明确哪些结论已证实、哪些仍待补充。

问题的业务单位是 SupportTask，聊天输入是 Turn；一次进程执行是 Run。三个概念分开后，任务才能在等待几天、换入口、Worker 重启后继续。规范性要求见[需求基线](../requirements/REQUIREMENTS-BASELINE.md)，本文不复制一套不同范围。

## 2. 一个完整场景

1. 工程师在钉钉问：“WAF 更新后反向代理出现 502。”系统持久接收事件，返回任务编号。
2. 小马哥确认产品、版本和现象，优先检索匹配的内部资料。若信息已足够，给有引用的答案。
3. 证据不够时提出可验证假设，并根据配置选择官方资料或已授权只读 API/MCP；不机械调用全部工具。
4. 现场连接不可用时，保存已知事实与待验证项，生成有边界的诊断步骤，创建 HumanRequest，进入 WAITING_FOR_HUMAN。
5. 工程师第二天回传日志，系统验证 task/request/身份和状态版本，只消费一次恢复事件。保留原有证据，继续验证。
6. 目标完整回答且通过检查后输出原因、依据、建议、风险及必要报告，状态 RESOLVED；仍待现场验证则保持等待。只有用户确认才 CLOSED。
7. 如果仍有版本冲突或不能排除反例，输出阶段判断与下一步，并保持等待/暂停，不编造已解决结论。

## 3. 两个不能混淆的边界

“只读”约束客户生产目标；系统必须能写自己的任务与报告，并向授权渠道发送答复。人工协助是补现场证据、执行工程师自行评估的建议或接手案件，不是批准小马哥重启/改配置的通道。

模型知识可以解释 Linux/网络机制并提出假设，但不能伪装成产品官方支持、现场真实结果或有出处的文档。动态证据裁决针对具体命题，不把“能安装成功”直接当成“官方支持”。

## 4. 能力如何扩展

Capability Registry 暴露可用能力；Workflow 配置允许阶段、优先级和条件；Policy 决定是否能在当前客户/设备/数据范围调用。新增提供方先实现 Adapter 和 Contract Test，再启用配置，不改 Core 私有厂商分支。

Skill 的说明、脚本与资源经过审查及版本固定；临时脚本默认给人执行，本地验证也必须使用隔离测试环境。任意生产 shell 不是 V1 能力。

## 5. 答案与报告

简单答复：结论 → 必要步骤 → 引用 → 未确认事项。复杂调查自动生成 Markdown 报告，内容为问题/环境、观察证据、假设与验证、已排除项、当前结论、建议、执行风险、待办与来源。

Chat 与 Admin 为两个业务面板，共用前端工程和后端权限。Chat 负责沟通/补证，Admin 配置连接、能力、工作流、主题与 HTML/Markdown 模板。报告可选择安全 HTML 导出，旧结果固定模板版本；新增交互页面通过构建期扩展。发布提供预构建镜像、在线配置包与按平台验证的离线包，部署端不需要开发工具链。

报告必须区分建议执行与确实执行过的步骤，保留采集时间和产品版本。不能将 trace、模型内部思维链、凭证和原始客户秘密作为报告内容。下载与分享按 case 权限检查。

## 6. 具体设计入口

| 需要了解 | 文档 |
| --- | --- |
| 问题理解、自主调查与答案检查 | [QA Core](../architecture/QA-CORE.md) |
| 什么是好答案、如何评测 | [Answer Quality](../governance/ANSWER-QUALITY.md) |
| 主流方案、热度及取舍 | [选型审计](../research/2026-09-05-STACK-AUDIT.md) |
| 组件分工与部署 | [Architecture](../architecture/ARCHITECTURE-BASELINE.md) |
| 持久任务/并发/恢复 | [Task Model](../architecture/SESSION-EVENT-MODEL.md) |
| 配置、升级能力与失败路径 | [Workflow](../architecture/WORKFLOW-MODEL.md) |
| 知识引用与来源裁决 | [Knowledge Contract](../architecture/KNOWLEDGE-CONTRACT.md) |
| 插件、MCP/Skill 与只读策略 | [Plugin Contract](../architecture/PLUGIN-CONTRACT.md) |
| 分阶段实现与验收 | [Delivery Plan](../plans/V1-DELIVERY-PLAN.md) |
| 双面板、个性化与交付 | [Web](../architecture/WEB-CONSOLE.md)、[模板](../architecture/PRESENTATION-CONTRACT.md)、[分发部署](../architecture/DISTRIBUTION-DEPLOYMENT.md) |
| 是否可进入编码 | [就绪判断与 Codex 交接](../plans/IMPLEMENTATION-READINESS.md) |

本轮解决的是设计冲突。真实 KB、钉钉、工具、并发和恢复能力尚须按计划实现和验收，不以文档完成代替软件完成。
