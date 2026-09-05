# ChatGPT 与 Codex

ChatGPT 和 Codex 解决的不是同一类问题。日常开发最省事的分工是：ChatGPT 负责研究、分析、方案和文档；Codex 进入真实仓库完成修改、测试、调试和 Git 工作。复杂任务先用 ChatGPT 把目标和约束说清楚，再交给 Codex 落地。

## 文档信息

- **适用范围**：ChatGPT、Codex CLI / IDE、个人与小团队 AI Coding
- **适用版本**：以 2026-09 OpenAI 官方文档为准
- **文档状态**：已验证
- **最后验证**：2026-09-03
- **来源**：OpenAI 官方文档

## 1. 什么时候用 ChatGPT，什么时候用 Codex

| 任务 | 推荐工具 |
| --- | --- |
| 快速问答、解释概念、整理思路 | ChatGPT |
| 查询最新版本、产品能力、价格、规则 | ChatGPT + Web 搜索 |
| 多来源技术调研、方案比较、形成带引用报告 | ChatGPT `/Deepresearch` |
| 读取 GitHub、GitBook、Gmail 等外部系统 | ChatGPT + Plugin / App |
| 阅读和修改真实代码仓库 | Codex |
| Bug 定位、测试、重构、代码审查 | Codex |
| 执行 shell、构建、lint、测试 | Codex |
| 完成分支、Commit、PR 前检查 | Codex + Git |

简单判断：需要“研究和决策”时优先 ChatGPT；需要“进入仓库执行”时优先 Codex。

## 2. ChatGPT 最常用的提示词写法

不需要固定模板。任务稍复杂时，把下面四项交代清楚即可：

```text
目标：最终要解决什么问题
上下文：环境、文件、已有方案、数据来源
输出：要报告、命令、表格、代码还是文档
边界：哪些不能改，哪些结论必须验证
```

例如：

```text
目标：判断当前 K3s 故障的根因并给出修复方案。
上下文：Ubuntu 22.04，附上节点状态和日志。
输出：按“现象 → 证据 → 根因 → 修复 → 验证”整理。
边界：禁止高危操作；不确定的地方先查官方资料。
```

不要为了显得专业把提示词写成几千字。稳定不变的要求应该放到项目规则或 Skill，当前提示词只描述这一次任务。

## 3. ChatGPT 最常用的工具

### Web 搜索

适合最新版本、新闻、价格、官方规则、软件文档等会变化的信息。需要最新事实时，不要只依赖模型记忆。

### Deep Research

多来源调研时使用：

```text
/Deepresearch
```

适合技术选型、行业调研、多个方案横向比较。Deep Research 会先形成研究计划，再输出带引用的报告。简单查一个事实没必要使用它。

### Plugin、App 和 Skill

ChatGPT 中可以输入 `@` 显式选择可用的 Plugin 或 Skill，例如：

```text
@GitHub 检查这个仓库当前目录和文档规范。
```

Plugin / App 负责连接外部系统和数据；Skill 负责复用一套工作方法。需要反复执行的流程更适合做成 Skill，而不是每次复制一大段提示词。

## 4. Codex 最常用的工作方式

Codex 开始工作前先让它读真实仓库，不要直接让它凭空生成实现。

推荐开局：

```text
先读取 AGENTS.md、README、相关设计文档和当前 git 状态，理解现有实现后再修改。

本次任务：
1. 定位现状和问题；
2. 给出最小变更方案；
3. 实施修改；
4. 运行已有测试、lint、typecheck/build；
5. 检查 git diff，清理无关修改；
6. 汇总修改文件、验证结果和剩余风险。

除非任务明确要求，不重构无关代码、不修改无关配置、不删除现有功能。
```

### `/plan`

复杂任务先规划：

```text
/plan
```

让 Codex 先调查仓库并提出方案，再开始修改。小修复没必要强制走完整 Plan。

### `AGENTS.md`

长期项目规则写在仓库的 `AGENTS.md`，例如：

- 项目如何启动；
- 测试、lint、build 命令；
- 哪些目录可以修改；
- 禁止操作；
- Git / PR 规则；
- 完成任务前必须执行的验证。

Codex 会在开始工作前读取 `AGENTS.md`。不要把同一批长期规则在每个提示词里重复一遍。

### Skill

重复出现的专项流程做成 Skill，例如系统化调试、TDD、代码审查、发布检查和固定格式的报告生成。

Codex CLI / IDE 中常用：

```text
/skills
$skill-name
```

Skill 本质上是包含 `SKILL.md` 的可复用工作流。

### 文件和审查

Codex CLI 中可以用 `@` 引用工作区文件，或用 `/mention` 添加文件上下文。完成修改后可运行：

```text
/review
```

先让 Codex 自查一遍，再进入 PR。

## 5. Prompt、AGENTS.md、Skill、Plugin / MCP 怎么分工

| 机制 | 放什么 |
| --- | --- |
| Prompt | 当前这一次任务 |
| `AGENTS.md` | 当前仓库长期有效的工程规则 |
| Skill | 可重复执行的标准流程 |
| Plugin / App | ChatGPT 或 Codex 与外部系统连接 |
| MCP | 给 Agent 提供标准化工具和数据接口 |
| Git / CI | 确定性的版本控制、测试和质量门禁 |

一个简单判断：只用一次写 Prompt；项目长期遵守写 `AGENTS.md`；反复执行做 Skill；需要访问外部系统接 Plugin / App / MCP。

## 6. 推荐的 ChatGPT + Codex 日常流程

```text
需求 / 故障 / 想法
        ↓
ChatGPT
搜索资料、Deep Research、比较方案
        ↓
形成明确目标、约束、验收标准
        ↓
Codex
读取仓库 → /plan → 修改
        ↓
Test / Lint / Build
        ↓
/review + git diff
        ↓
Feature Branch → PR → CI → Merge
        ↓
ChatGPT
整理技术文档、运维手册或知识库文章
```

详细的软件开发阶段门禁和 Git 交付规范见 [Vibe Coding](vibe-coding.md)。

## 7. 最值得保留的规则

1. 需要最新事实时联网查，不猜版本和规则。
2. 多来源复杂问题用 Deep Research，简单问题直接搜索或聊天。
3. ChatGPT 提示词写目标和边界，不堆无意义角色设定。
4. Codex 先读仓库再改代码，复杂任务先 `/plan`。
5. 长期规则写 `AGENTS.md`，重复流程做 Skill。
6. 代码修改必须经过真实测试，不能用“理论上可行”代替验证。
7. 完成前检查 `git diff`，避免 AI 顺手修改无关文件。
8. 重要项目使用 Feature Branch → PR → CI → Review → Merge。
9. 密码、Token、Cookie、私钥和真实客户数据不要写进提示词或仓库。

## 参考资料

- [OpenAI Prompting](https://learn.chatgpt.com/docs/prompting)
- [OpenAI Deep Research](https://help.openai.com/en/articles/10500283-deep-research-faq)
- [OpenAI Plugins in ChatGPT and Codex](https://help.openai.com/en/articles/20001256/)
- [OpenAI Codex CLI](https://learn.chatgpt.com/docs/codex/cli)
- [OpenAI AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [OpenAI Build Skills](https://learn.chatgpt.com/docs/build-skills)
