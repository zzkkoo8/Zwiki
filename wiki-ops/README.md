# Zwiki 使用与维护

Zwiki 的日常维护只保留两套流程：**写入前检查**与**写入错误后的回退恢复**。

GitHub `main` 是 Zwiki 的唯一事实源（SSOT），GitBook 仅负责同步、展示和发布。

## 操作入口

- [写入前检查](write-checklist.md)：新增、修改、通过 GitBook URL 定位文章、添加附件前执行。
- [错误回退与恢复](rollback-guide.md)：写入后发现内容、索引或 GitBook 配置错误时执行。

## 日常使用原则

1. 修改前先检查，优先修改已有内容。
2. 只修改当前任务需要的文件。
3. 普通文章任务不修改 `gitbook-docs.yaml`。
4. 脚本、配置、图片等附件与文章一起存入 GitHub，并使用相对路径引用。
5. 发现错误时优先使用 Git 历史恢复，不直接重写 `main` 历史。
