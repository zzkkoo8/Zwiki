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

GitBook 只允许作为**只读诊断工具**使用，不允许作为 Zwiki 正文或导航的写入入口。

允许使用 GitBook 检查：

- Git Sync 是否成功；
- 页面是否已经同步或发布；
- 当前公开页面树、页面路径和导航层级；
- GitHub 内容正确但 GitBook 展示异常时的发布层状态。

禁止通过 GitBook 执行：

- 新增、修改或删除正文；
- 修改 `SUMMARY.md` 对应的导航结构；
- 使用 GitBook Change Request 维护由 Git Sync 管理的内容；
- 绕过 GitHub 直接修复 GitBook 中的 Markdown 内容。

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
3. `SUMMARY.md` 新增或修改的链接是否指向真实文件，导航层级是否合理。
4. Markdown 内部相对链接、附件路径是否与仓库文件对应。
5. 普通文章任务是否误改 `gitbook-docs.yaml`。
6. 是否存在密码、Token、Cookie、私钥、客户信息等敏感内容。
7. 是否发生未经用户要求的删除、移动、重命名或大范围重构。
8. 文档信息是否按规范使用键值列表，是否存在仅为元数据展示而创建的无意义小表格。
9. 最终 diff 是否保持最小必要变更。

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
2. GitBook 只用于读取页面标题、路径和同步状态，不在 GitBook 中修改正文。
3. 根据页面 URL、页面标题和 `SUMMARY.md` 定位 GitHub 中对应的 Markdown 源文件。
4. 必须确认唯一对应关系后才能修改；不得仅根据 URL 猜测文件路径。
5. 若存在多个候选文件或无法确认对应关系，应停止写入并向用户确认。
6. 只修改 GitHub 中的 Markdown 源文件。
7. GitHub 更新并通过 AI 自动审核后，自动合并到 `main`，再由 GitBook Git Sync 自动同步发布。

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
