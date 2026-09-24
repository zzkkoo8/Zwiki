# AI Coding

AI Coding 只保留 Coding Agent 在实际开发中的常用流程、配置和验收方法。

## 内容入口

- [FDE 60 天技能表](fde-skills-roadmap.md)：按天训练 AI 协作、Git、Web、全栈、Agent 和现场能力。
- [ChatGPT 与 Codex](chatgpt-codex.md)：ChatGPT / Codex 常用能力、仓库操作、AGENTS.md、Skill 和审查流程。
- [Codex / Claude Code 多渠道切换速查](codex-claude-multi-provider-switching.md)：Profile / Settings、API Key、模型、推理强度和权限组合。
- [Vibe Coding](vibe-coding.md)：Coding Agent 的分阶段实现、验证和 Git 回退流程。
- [Codex 项目开局速查](codex-project-bootstrap.md)：新项目最小目录、README、AGENTS.md、验收命令和 Spec 使用边界。
- [Jev 决策模型与 Agent 门控最佳实践](jev-agent-decision-model.md)：Tool 路由、风险判断、置信度门控、影子测试和 Harness 接入模式。

## 常用 Coding Agent

| 工具 | 适合场景 | 官方入口 |
| --- | --- | --- |
| OpenAI Codex | 仓库级修改、测试、代码审查和长任务 | https://developers.openai.com/codex/ |
| Claude Code | 终端交互开发、代码库分析、Shell 工作流 | https://docs.anthropic.com/en/docs/claude-code/getting-started |
| Cursor | IDE 可视化编辑、代码索引和 Agent 联动 | https://cursor.com/docs |

## 工作原则

1. 先读取现有仓库、`README.md`、`AGENTS.md`、设计稿和测试，再修改代码。
2. 修改已有系统优先最小变更，不顺手重构无关代码。
3. 大任务先明确需求和验收，再分阶段实现。
4. 完成前必须运行真实测试或最接近用户路径的验证。
5. API Key、Token、密码不得写入提示词、代码仓库或日志。

前端、后端、测试框架等通用工程工具放在[开发 / 技术栈与工具](../../development/tooling/README.md)，不在 AI Coding 重复维护。
