# Codex 项目开局速查

新项目交给 Codex 前，不要先堆很多文档。最小目标只有四个：**知道项目做什么、知道哪些目录能改、知道怎么运行、知道怎么验收。**

## 1. 最小项目结构

小型工具 / Web / Agent 项目先有这些就够：

```text
project/
├── README.md
├── AGENTS.md
├── .gitignore
├── .env.example
├── src/ 或 backend/ frontend/
├── tests/
└── docs/                 # 真有长期设计内容时再建
```

非平凡功能需要 Spec 时再增加：

```text
specs/
└── 001-feature/
    ├── spec.md
    ├── plan.md
    └── tasks.md
```

不要为了“看起来完整”提前创建一堆空的 `ARCHITECTURE.md`、`STATUS.md`、`TODO.md`、`NOTES.md`。

## 2. README 只回答 5 件事

```text
项目做什么
如何安装
如何启动
如何测试
核心目录在哪里
```

最小模板：

```md
# Project Name

一句话说明项目目标。

## Quick Start
<安装命令>
<启动命令>

## Verify
<测试命令>
<构建命令>

## Repository Map
- src/: 主代码
- tests/: 测试
- docs/: 长期设计文档
- AGENTS.md: Agent 工作规则
```

如果 Codex 每次都要猜怎么启动和测试，README / AGENTS 还不够清楚。

## 3. AGENTS.md：短、硬、可执行

OpenAI 当前建议不要把 `AGENTS.md` 写成百科；它更适合作为 Agent 的工作入口和地图。

推荐：

```md
# Project Instructions

## Goal
一句话说明项目目标和非目标。

## Source of Truth
- README.md: 项目入口
- docs/: 稳定设计
- specs/<feature>/: 当前功能需求和计划
- tests/: 完成状态的验证证据

## Workflow
1. 先读相关代码、文档、测试和 git status。
2. 只做当前任务必要修改。
3. 非平凡任务先写/读取 spec 和验收标准。
4. 修改后运行真实测试。
5. 未验证通过不得宣布完成。

## Commands
- install: ...
- dev: ...
- test: ...
- lint: ...
- build: ...

## Forbidden
- 提交密码、Token、私钥
- 删除失败测试来通过 CI
- 无关重构
- 未验证就声称完成
```

长期业务规则、特殊目录说明和项目常用命令放这里；临时任务要求不要永久塞进 `AGENTS.md`。

## 4. 技术栈：按需求选，不为了 AI 统一

已有项目：**遵循现有技术栈。**

新项目优先选择：

```text
团队熟悉
社区成熟
文档完整
测试方便
部署简单
AI 训练样本丰富
```

不要因为 Codex 擅长某个栈就强行重写项目。

常见轻量工具可以直接：

```text
Go 单文件 / 小型服务
Python + FastAPI
TypeScript + React/Vite
Docker Compose
```

实际选型由需求决定，不在 Zwiki 固定“唯一标准技术栈”。

## 5. 一个功能怎么交给 Codex

简单任务：

```text
读取代码
  ↓
明确目标和验收
  ↓
修改
  ↓
测试
  ↓
检查 diff
```

复杂任务：

```text
spec
 ↓
plan
 ↓
tasks
 ↓
implement
 ↓
verify
 ↓
PR
```

Spec 只写 WHAT / WHY / 验收标准；Plan 写 HOW；Tasks 写执行顺序。不要三份文档重复同一段内容。

## 6. 给 Codex 的任务提示词

推荐像写 GitHub Issue 一样：

```text
目标：实现 xxx。

范围：
- 修改 src/xxx
- 不改 xxx

要求：
- 保持现有技术栈
- 最小变更
- 不提交敏感信息

验收：
- <test command>
- <build command>
- <功能验证命令>

完成前检查 git diff，只保留当前任务相关修改。
```

路径、文件名、现有实现和验收命令越明确，Agent 越不需要猜。

## 7. Git 工作流

如果团队要求分支开发：

```bash
git status
git switch -c feature/<name>
```

修改完成：

```bash
<test command>
<lint command>
<build command>
git diff --check
git status
```

再 Commit / PR。

仓库已有自己的 Git 规则时，以仓库规则为准；不要因为本文存在就强制所有项目采用同一种分支模型。

## 8. Definition of Done

至少满足：

```text
□ 用户需求已实现
□ 相关测试通过
□ lint / type / build 按项目要求通过
□ 没有提交密钥和临时文件
□ 文档与实际命令一致
□ git diff 只有本任务必要变更
```

“代码看起来对”不算完成，真实验证结果才算。

## 9. 什么时候增加更多文档

只有出现真实需求时再拆：

| 需求 | 建议文件 |
| --- | --- |
| 架构复杂、多人长期维护 | `docs/ARCHITECTURE.md` |
| 本地开发步骤复杂 | `docs/DEVELOPMENT.md` |
| 测试层次和门禁复杂 | `docs/TESTING.md` |
| 大功能需要独立需求/计划 | `specs/<feature>/` |
| 重要不可逆架构决策 | ADR |

一个事实只维护一个权威位置。

## 推荐开局顺序

```text
仓库和现有代码
      ↓
README
      ↓
AGENTS.md
      ↓
确认启动 / 测试命令
      ↓
需要时补 docs / spec
      ↓
开始实现
```

## 官方资料

- Codex AGENTS.md：https://developers.openai.com/codex/guides/agents-md/
- Codex CLI：https://developers.openai.com/codex/cli/reference/
- OpenAI Harness Engineering：https://openai.com/index/harness-engineering/
- How OpenAI uses Codex：https://openai.com/business/guides-and-resources/how-openai-uses-codex/
