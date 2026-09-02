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

## GitBook URL 与 GitHub 源文件映射

Zwiki 发布站点：`https://zwiki.gitbook.io/zwiki-docs`

GitHub 仓库：`https://github.com/zzkkoo8/Zwiki`

当用户提供 GitBook 页面 URL 并要求修改时：

1. 先确认 URL 属于 Zwiki 发布站点。
2. 根据页面 URL、页面标题和 `SUMMARY.md` 定位 GitHub 中对应的 Markdown 源文件。
3. 必须确认唯一对应关系后才能修改；不得仅根据 URL 猜测文件路径。
4. 若存在多个候选文件或无法确认对应关系，应停止写入并向用户确认。
5. 默认修改 GitHub 中的 Markdown 源文件，不直接在 GitBook 中修改正文。
6. GitHub 更新后由 GitBook Git Sync 自动同步发布。

## 写入错误处理

如果已经写入错误内容，按照 [`wiki-ops/rollback-guide.md`](wiki-ops/rollback-guide.md) 执行恢复。

默认优先使用 `git revert` 或“恢复指定文件后新增恢复提交”的方式，避免使用 `reset --hard` 配合强制推送改写 `main` 历史。
