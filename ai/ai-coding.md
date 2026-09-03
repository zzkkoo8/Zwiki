# AI Coding

AI Coding 关注如何用 Coding Agent 提升软件开发效率，包括 Vibe Coding、代码理解、计划、实现、测试、审查和交付。

## Vibe Coding 是什么

Vibe Coding 可以理解为：开发者主要描述目标、约束和验收结果，由 AI Agent 完成大量代码生成与修改，人类把精力放在需求、架构、验证和最终决策上。

它适合原型、内部工具、CRUD、脚手架和明确边界的小功能；生产项目不能只靠“看起来能跑”，仍应保留版本控制、测试、代码审查、安全检查和回退能力。

## 推荐工作流

```text
明确目标与验收标准
        ↓
让 Agent 读取现有仓库和项目规范
        ↓
先设计 / 计划，再实现
        ↓
小步修改
        ↓
自动测试 + 实际页面/接口验证
        ↓
检查 Git diff
        ↓
提交和回退点
```

对于完整前后端项目，继续使用 [AI 全栈开发规范（FDE）](../development/ai-fullstack-workflow.md) 作为工程主流程。

## 常用 Coding Agent

| 工具 | 定位 | 推荐使用场景 | 官方入口 |
| --- | --- | --- | --- |
| OpenAI Codex | 面向代码编写、审查和交付的 Coding Agent，可通过 CLI、IDE、Web 等形态使用 | Linux / macOS 终端开发、仓库级修改、长任务和代码审查 | https://developers.openai.com/codex/ |
| Claude Code | Anthropic 的终端 Coding Agent | 代码库分析、交互式开发、Shell 工作流 | https://docs.anthropic.com/en/docs/claude-code/getting-started |
| Cursor | Agent-first 编辑器和终端 Agent | 需要 IDE 可视化编辑、代码索引和 Agent 联动时 | https://cursor.com/docs |

## 使用原则

1. 让 Agent 先读取项目内 `README.md`、`AGENTS.md`、设计稿和现有代码，不要从空白假设开始。
2. 大任务先拆阶段；每一阶段必须有可验证输出。
3. 修改已有系统时优先最小变更，不无故重构无关代码。
4. 生成代码后必须运行真实测试或最接近真实用户路径的验证。
5. 保留 Git 提交点；AI 改错时优先回退，不在错误基础上不断叠加补丁。
6. API Key、Token、密码不得直接写入提示词、代码仓库或日志。

## 后续收录方向

- Codex CLI 配置与渠道切换
- Claude Code / Cursor 实战
- Vibe Coding 项目模板
- 多 Agent 协作
- 上下文与 Memory 管理
- AI 代码审查和自动验收
