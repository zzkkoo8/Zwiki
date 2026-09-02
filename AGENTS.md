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
8. 最终 diff 是否保持最小必要变更。

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
2. 根据页面 URL、页面标题和 `SUMMARY.md` 定位 GitHub 中对应的 Markdown 源文件。
3. 必须确认唯一对应关系后才能修改；不得仅根据 URL 猜测文件路径。
4. 若存在多个候选文件或无法确认对应关系，应停止写入并向用户确认。
5. 默认修改 GitHub 中的 Markdown 源文件，不直接在 GitBook 中修改正文。
6. GitHub 更新并通过 AI 自动审核后，自动合并到 `main`，再由 GitBook Git Sync 自动同步发布。

## 写入错误处理

如果已经写入错误内容，按照 [`wiki-ops/rollback-guide.md`](wiki-ops/rollback-guide.md) 执行恢复。

默认优先使用 `git revert` 或“恢复指定文件后新增恢复提交”的方式，避免使用 `reset --hard` 配合强制推送改写 `main` 历史。
