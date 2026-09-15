# Zwiki 使用与维护

GitHub `main` 是 Zwiki 唯一事实源；GitBook 只负责同步、展示和发布。

## 操作入口

- [Zwiki 日常维护指南](daily-operations.md)：目录选择和常用增删改流程。
- [Zwiki 快速修改](quick-edit-and-feedback.md)：从 GitBook 进入 GitHub 原文、小改和纠错入口。
- [写入前检查](write-checklist.md)：新增或修改前执行。
- [错误回退与恢复](rollback-guide.md)：内容、导航或同步写错后的恢复流程。
- [文章编写规范](../CONTRIBUTING.md)：Zwiki 场景速查的写作规则。
- [通用技术文章模板](../templates/technical-article.md)
- [故障排查模板](../templates/troubleshooting.md)
- [部署指南模板](../templates/deployment-guide.md)

## 默认维护流程

```text
用户提出修改
    ↓
查现有文章 / 定位唯一源文件
    ↓
临时分支修改
    ↓
自动审核 diff
    ↓
PR → merge main
    ↓
GitBook 从 GitHub 同步
```

## 原则

- 优先修改已有文章，不重复建同主题页面。
- 普通正文任务不修改 `gitbook-docs.yaml`。
- 同一事实只维护一个源文件。
- GitBook 页面正文不作为独立事实源维护。
- 脚本、配置、图片等附件进入 GitHub，并用相对路径引用。
- 写错优先用 Git 历史恢复，不用强推改写 `main` 历史。
