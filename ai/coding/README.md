# AI Coding

AI Coding 关注如何用 Coding Agent 完成软件开发工作，包括需求理解、计划、实现、测试、审查、上下文管理和稳定交付。

## 内容入口

- [ChatGPT 与 Codex](chatgpt-codex.md)：ChatGPT 的研究、搜索、Deep Research、Plugin / Skill 用法，以及 Codex 的仓库操作、`AGENTS.md`、Skill、审查和协同开发流程。
- [Vibe Coding](vibe-coding.md)：把 Coding Agent 纳入完整开发流程，通过分阶段门禁、真实验证和 Git 回退实现稳定交付。

## 常用 Coding Agent

| 工具 | 定位 | 推荐使用场景 | 官方入口 |
| --- | --- | --- | --- |
| OpenAI Codex | 面向代码编写、审查和交付的 Coding Agent，可通过 CLI、IDE、Web 等形态使用 | Linux / macOS 终端开发、仓库级修改、长任务和代码审查 | https://developers.openai.com/codex/ |
| Claude Code | Anthropic 的终端 Coding Agent | 代码库分析、交互式开发、Shell 工作流 | https://docs.anthropic.com/en/docs/claude-code/getting-started |
| Cursor | Agent-first 编辑器和终端 Agent | 需要 IDE 可视化编辑、代码索引和 Agent 联动时 | https://cursor.com/docs |

## 工作原则

1. 先读取现有仓库、`README.md`、`AGENTS.md`、设计稿和测试，再修改代码。
2. 大任务先拆阶段，每一阶段必须有可验证输出。
3. 修改已有系统时优先最小变更，不无故重构无关代码。
4. 生成代码后必须运行真实测试或最接近真实用户路径的验证。
5. 保留 Git 提交和回退点，错误修改优先回退，不在错误基础上持续叠补丁。
6. API Key、Token、密码不得直接写入提示词、代码仓库或日志。

## 后续收录方向

- Codex CLI 配置与渠道切换
- Claude Code / Cursor 实战
- 多 Agent 协作
- 上下文与 Memory 管理
- AI 代码审查和自动验收

具体前端、后端、测试框架和工程工具放在[开发 / 技术栈与工具](../../development/tooling/README.md)，避免在 AI Coding 重复维护技术栈清单。
