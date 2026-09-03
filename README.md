# Zwiki

> 面向日常学习、部署实践和故障处理的个人技术知识库。

- 📖 在线 Wiki：<https://zwiki.gitbook.io/zwiki-docs>
- 💻 GitHub：<https://github.com/zzkkoo8/Zwiki>
- 📦 Clone：`git clone https://github.com/zzkkoo8/Zwiki.git`

这里记录公开组件的可复用技术文章。内容按产品或技术领域组织；安装、配置、运维和故障排查等文章放在各自领域内，避免不同技术栈相互混杂。

GitHub `main` 是 Zwiki 的唯一事实源（SSOT），GitBook 负责同步、展示和公网发布。

```text
ChatGPT / Codex / 人工维护
            ↓
      GitHub Zwiki
      唯一事实源
            ↓
       GitBook Sync
            ↓
      公网技术 Wiki
```

## 快速入口

| 分类 | 主要内容 |
| --- | --- |
| [基建](infrastructure/README.md) | 硬件、系统、网络、基础服务与通用运维 |
| [容器与云原生](cloud-native/README.md) | Docker、Kubernetes、K3s 的部署、运维与排障 |
| [开发](development/README.md) | 工程平台、前后端技术栈、测试与开发工具 |
| [AI](ai/README.md) | AI Coding、Vibe Coding、Skills、插件、模型接入、提示词与 AI 资源 |
| [项目](projects/README.md) | 持续维护项目的目标、架构、设计决策与实施文档 |
| [Zwiki 使用与维护](wiki-ops/README.md) | 日常维护、写入前检查、错误回退、文章规范和模板 |

## 内容原则

- 一级目录按技术领域组织，二级目录按主题组织，具体文章原则上不超过三级导航。
- 同一内容只保留一个权威页面，跨分类通过链接引用，不复制维护。
- 一级目录只在存在实际内容时创建，避免空目录和过度设计。
- 一篇文章聚焦一个问题，标题直接说明目标或故障现象。
- 命令应可复制执行，并写明预期输出、判断标准和风险。
- 涉及变更的文章应提供验证方法；存在风险时应提供回退方案。
- 标明适用版本、验证状态和最后验证日期，避免陈旧内容被误用。
- 只记录可以公开的组件知识，不提交账号、密钥、客户信息或内部敏感资料。

## 使用与维护

- AI Agent 操作规则见 [`AGENTS.md`](AGENTS.md)。
- 日常增删改和目录选择见 [Zwiki 日常维护指南](wiki-ops/daily-operations.md)。
- 修改前执行 [写入前检查](wiki-ops/write-checklist.md)。
- 文章格式与质量遵循 [文章编写规范](CONTRIBUTING.md)。
- 写错后按 [错误回退与恢复](wiki-ops/rollback-guide.md) 操作。

## 编写文章

新增或修改文章时，从以下模板选择最接近的一种：

- [通用技术文章模板](templates/technical-article.md)
- [故障排查模板](templates/troubleshooting.md)
- [部署指南模板](templates/deployment-guide.md)
