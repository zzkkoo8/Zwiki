# Zwiki 使用与维护

Zwiki 的日常维护核心仍只保留两套流程：**写入前检查**与**写入错误后的回退恢复**。另外提供《日常维护指南》，集中说明文章应该放到哪个目录，以及如何直接向 ChatGPT、Codex 或其他 AI Agent 下达增、删、改、移、回退和同步排查指令。

GitHub `main` 是 Zwiki 的唯一事实源（SSOT），GitBook 仅负责同步、展示和发布。

AI 维护默认采用全自动模式：完成写入后由 AI 自行审核全部变更，审核通过后自动合并到 `main`，不要求用户手工审核 Pull Request。Pull Request 主要用于保留差异和审计记录。

## 操作入口

- [日常维护指南](daily-operations.md)：目录选择、分类边界和常用增删改提示词，日常使用优先看这一页。
- [写入前检查](write-checklist.md)：新增、修改、通过 GitBook URL 定位文章、添加附件前执行；文件内同时包含 AI 写入后的自动审核与发布要求。
- [错误回退与恢复](rollback-guide.md)：写入后发现内容、索引或 GitBook 配置错误时执行。
- [文章编写规范](../CONTRIBUTING.md)：只定义技术文章本身的标题、路径、命令、版本、来源和内容质量要求。
- [通用技术文章模板](../templates/technical-article.md)
- [故障排查模板](../templates/troubleshooting.md)
- [部署指南模板](../templates/deployment-guide.md)

## 默认维护流程

```text
用户提出修改
    ↓
AI 写入前检查
    ↓
AI 修改 GitHub 源文件
    ↓
AI 自动审核 diff
    ↓
不通过 → 自动修正并重新审核
    ↓
通过 → 自动合并 main
    ↓
GitBook 自动同步发布
    ↓
AI 向用户报告结果
```

只有无法唯一定位文章、需求存在关键歧义、发现无法安全处理的敏感信息、自动审核持续失败或 GitHub 无法安全合并时，才需要用户介入。

## 日常使用原则

1. 不确定文章放在哪里时，让 AI 先检查[《日常维护指南》](daily-operations.md)和现有目录，再决定唯一主分类。
2. 修改前先检查，优先修改已有内容。
3. 只修改当前任务需要的文件。
4. 普通文章任务不修改 `gitbook-docs.yaml`。
5. 脚本、配置、图片等附件与文章一起存入 GitHub，并使用相对路径引用。
6. AI 写入后自动审核并自动合并，无需人工批准 PR。
7. 文章格式与质量只遵循《文章编写规范》，不在本页重复维护。
8. 发现错误时优先使用 Git 历史恢复，不直接重写 `main` 历史。
