# Skills 与插件

本页收录能直接增强 ChatGPT、Codex、Claude Code、Cursor 等 Agent 能力的 Skills、插件和 MCP 资源。原先放在“开发资源”中的 AI Skills 已迁移到这里，避免重复维护。

## 概念边界

| 类型 | 作用 |
| --- | --- |
| Skill | 给 Agent 一套可复用的操作规范、方法或工作流，例如设计、TDD、调试、评审 |
| Plugin | 将 Skills、外部应用或其他能力打包成可安装扩展 |
| MCP | 让 Agent 通过标准协议访问外部工具、数据源或服务 |

选择原则：能用 Skill 解决的工作流问题，不必为了“更强”额外接 MCP；需要访问外部系统或执行工具时，再考虑插件或 MCP。

## 精选项目

| 名字 | 介绍 | 安装 | 用法 | 项目 URL |
| --- | --- | --- | --- | --- |
| Superpowers | 面向 Coding Agent 的工程化 Skills 集合，覆盖 brainstorming、计划、TDD、系统化调试、代码评审、并行 Agent 和完成前验证。 | 在支持插件的 Agent 中通过插件目录安装 `superpowers`；具体入口以当前客户端为准。 | 让 Agent 根据任务自动调用相应 Skill，典型流程为设计 → 计划 → 实现/测试 → Review → 验证 → 合并。 | https://github.com/obra/superpowers |
| Vercel Agent Skills | Vercel 官方 Agent Skills 集合，覆盖 React / Next.js 性能、Web 设计、可访问性、组件组合和部署等规范。 | `npx skills add vercel-labs/agent-skills` | 安装后让 Agent 执行对应审查或实现任务，例如 React 性能审计、Web UI 可访问性检查。 | https://github.com/vercel-labs/agent-skills |

## ChatGPT / Codex 插件

OpenAI 的插件可以包含 Skills、连接应用和应用模板。安装插件不等于自动获得外部账户权限，涉及第三方服务时仍需要正常授权。

官方说明：<https://help.openai.com/en/articles/20001256-plugins-in-codex/>

## 收录原则

- 优先官方、社区高热且持续维护的项目。
- 每个 Skill / 插件必须写清楚：解决什么问题、安装方式、最短用法和项目来源。
- 同类能力只保留少量主流项目，不做无筛选的链接大全。
- 涉及第三方账号授权时，只写授权流程，不保存凭据。
