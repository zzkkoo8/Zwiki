# Zwiki AI Agent 操作规范

## 核心原则

1. GitHub `main` 是 Zwiki 的唯一事实源（SSOT）。
2. GitBook 仅作为同步、展示和发布层，不作为独立知识源维护。
3. 修改 Zwiki 前，必须先执行 [`wiki-ops/write-checklist.md`](wiki-ops/write-checklist.md) 中的写入前检查。
4. 只修改完成当前任务所必需的文件和内容，避免顺手重构、批量改名或调整无关目录。
5. 新增文章前必须检查是否已有相同或高度相关内容，优先补充存量文章。
6. 未明确要求时，不得移动、重命名或删除已有文章。
7. 普通文章维护不得修改 `gitbook-docs.yaml`。
8. 修改存量文章时，保持原路径、目录结构和无关章节不变。
9. 脚本、配置、图片等附件应存入 GitHub，并在 Markdown 中使用相对路径引用。
10. 禁止提交密码、Token、Cookie、私钥、客户信息及其他敏感数据。
11. “文档信息”等少量键值元数据统一使用加粗键值列表，不使用 Markdown 两列表格；只有方案对比、兼容矩阵、参数清单等确有横向比较价值时才使用表格。

## 内容定位

Zwiki 是**常见运维、产品部署和技术场景的快速实施方案库**，不是百科全书，也不是官方手册副本。

写文章时默认遵循：

```text
结论 / 最短路径
        ↓
可复制命令或配置
        ↓
验证方法
        ↓
常见异常分支
        ↓
必要风险和回退
        ↓
官方资料链接
```

具体要求：

- 开头先告诉读者“现在该执行什么”，不要先写大段概念背景。
- 优先记录 80% 现场最常用的方法；低频参数和完整原理直接链接官方文档。
- 不复制官方已有的大篇幅参数表、架构说明、全部 CLI 选项和完整兼容矩阵。
- 示例应能直接复制并只需替换少量变量；必要时允许给出“最快但不安全”的测试方案，同时清楚标注风险和生产替代方案。
- 同一命令不要在多篇文章重复解释；链接到唯一权威页面。
- 真实事故案例、内核/启动恢复、产品安装验收清单可保留必要细节，不为追求短而删除现场证据、回退步骤或验收项。
- 新增文章明显超过约 10 KB 时，应主动检查是否混入了官方手册内容、重复背景或多个主题；有合理原因时可以保留。

## 内容分类边界

新增或迁移文章时优先保持 GitHub 物理目录和 GitBook 导航语义一致。一级按领域、二级按主题、三级放具体文章；原则上不要增加第四级导航。

- `infrastructure/`：基建，包括硬件、系统、网络、基础服务。
- `cloud-native/`：容器与云原生，包括 Docker、Kubernetes、K3s。
- `development/platforms/`：工程平台，包括 GitHub、GitBook、GitLab、Vercel、CI/CD 等开发协作与发布平台。
- `development/tooling/`：技术栈与工具，包括前端、后端、全栈、设计和测试工具。
- `ai/coding/`：AI Coding，包括 Vibe Coding、Codex、Claude Code、Cursor、多 Agent 协作、上下文管理和 AI 代码审查。
- `ai/`：其他 AI 专属内容，包括模型接入、API Key / Token 获取与安全配置、Skills、插件、MCP、提示词和 AI 资源。
- `projects/`：项目阅读页或外部项目自动镜像。
- `wiki-ops/`：Zwiki 自身的维护、写入、回退和同步操作说明。

分类入口 `README.md` 可以作为 GitHub 目录说明存在，但如果只是导航概览，不必重复出现在 GitBook 左侧目录。所谓“概览页”不得把有实际价值的文章压成额外一层。

同一内容只能有一个权威页面。跨分类需要引用时使用 Markdown 链接，不复制同一份说明到多个目录。

## GitBook 使用边界

GitBook 只用于发布配置和只读诊断，不作为 Zwiki 正文或导航的事实源。

允许使用 GitBook：

- 检查 Git Sync 是否成功；
- 检查页面是否已经同步或发布；
- 查看公开页面树、页面路径和导航层级；
- 调整站点级展示能力，例如 Page Actions、Header/Footer 等不属于正文的配置。

禁止通过 GitBook：

- 把正文修改只留在 GitBook 而不进入 GitHub；
- 绕过 GitHub 修改 `SUMMARY.md` 对应导航；
- 使用 GitBook Change Request 维护由 Git Sync 管理的长期正文。

所有正文、导航、附件和回退操作必须写入 GitHub，再由 GitBook Git Sync 同步发布。

## AI 自动写入、审核与发布

Zwiki 默认采用 AI 全自动维护，不要求用户手工审核 Pull Request。

标准流程：

```text
用户提出新增或修改要求
        ↓
AI 执行写入前检查
        ↓
在临时分支完成必要修改
        ↓
创建或更新 Pull Request 作为差异与审计记录
        ↓
AI 自动审核全部变更
        ↓
审核失败 → AI 自动修正 → 重新审核
        ↓
审核通过 → AI 自动合并到 main
        ↓
GitBook Git Sync 自动发布
        ↓
向用户报告修改结果和提交/PR 信息
```

AI 自动审核至少检查：

1. 变更是否与用户要求一致，是否修改了无关文件或无关章节。
2. 新增内容是否与现有文章重复，是否应优先更新存量文章。
3. 文章是否仍然是“场景速查”，有没有重新复制大篇幅官方手册内容。
4. `SUMMARY.md` 新增或修改的链接是否指向真实文件，导航层级是否合理。
5. Markdown 内部相对链接、附件路径是否与仓库文件对应。
6. 普通文章任务是否误改 `gitbook-docs.yaml`。
7. 是否存在密码、Token、Cookie、私钥、客户信息等敏感内容。
8. 是否发生未经用户要求的删除、移动、重命名或大范围重构。
9. 文档信息是否按规范使用键值列表，是否存在仅为元数据展示而创建的无意义小表格。
10. 最终 diff 是否保持完成当前任务所需的最小变更。

默认不等待人工批准 PR。只有出现以下情况时才停止自动合并并向用户确认：

- 无法唯一定位用户要修改的文章或文件。
- 用户要求存在关键歧义，继续执行可能修改错误内容。
- 发现疑似敏感信息且无法安全脱敏。
- AI 自动审核持续失败且无法自动修正。
- GitHub 合并发生冲突或平台拒绝合并，无法安全自动处理。

## GitBook URL 与 GitHub 源文件映射

Zwiki 发布站点：`https://zwiki.gitbook.io/zwiki-docs`

GitHub 仓库：`https://github.com/zzkkoo8/Zwiki`

当用户提供 GitBook 页面 URL 并要求修改时：

1. 先确认 URL 属于 Zwiki 发布站点。
2. 根据 GitBook 页面路径、标题和 `SUMMARY.md` 定位 GitHub 中对应 Markdown 源文件。
3. 必须确认唯一对应关系后才能修改；不得仅根据 URL 猜测文件路径。
4. 只修改 GitHub 中的 Markdown 源文件。
5. GitHub 更新并通过 AI 自动审核后，自动合并到 `main`，再由 GitBook Git Sync 自动同步发布。

公开页面已经启用 GitBook Page Action 的 **Edit on GitHub**，人工小改可直接从页面跳到源文件。

## 外部项目自动镜像

`projects/` 下明确标记为“自动生成阅读镜像”的页面不得直接编辑。

以 xmg-qa2 为例：

- 权威源：`zzkkoo8/xmg-qa2`；
- 源文件：`docs/design/XMG-QA2-SUPPORT-AGENT-DESIGN.md`；
- Zwiki 镜像：`projects/xmg-qa2/support-agent-design.md`；
- 同步 Workflow：`.github/workflows/sync-xmg-qa2.yml`。

当用户要求修改这类镜像页面时：

1. 根据镜像页中的权威源定位原始 GitHub 仓库和源文件。
2. 修改原始仓库中的源文件，不直接修改 Zwiki 镜像。
3. 等待同步 Workflow 自动更新 Zwiki；需要立即同步时可手动运行对应 Workflow。
4. Zwiki `main` 更新后，再由 GitBook Git Sync 发布。

自动镜像 Workflow 是普通 PR 流程的受限例外：仅允许执行确定性的单向文件同步，只能修改预先声明的镜像目标文件，不得借同步任务修改其他 Zwiki 内容。

## 写入错误处理

如果已经写入错误内容，按照 [`wiki-ops/rollback-guide.md`](wiki-ops/rollback-guide.md) 执行恢复。

默认优先使用 `git revert` 或“恢复指定文件后新增恢复提交”的方式，避免使用 `reset --hard` 配合强制推送改写 `main` 历史。
