# Zwiki

> 面向常见运维、产品部署和技术问题的**快速实施方案库**。

- 📖 在线 Wiki：<https://zwiki.gitbook.io/zwiki-docs>
- 💻 GitHub：<https://github.com/zzkkoo8/Zwiki>
- 📦 Clone：`git clone https://github.com/zzkkoo8/Zwiki.git`

Zwiki 不重写官方手册。每篇文章优先回答：**现在该执行什么、怎么判断成功、失败后先查哪里。** 完整参数、原理和版本矩阵直接链接官方文档。

GitHub `main` 是唯一事实源（SSOT），GitBook 负责同步、搜索和发布。

```text
人工 / ChatGPT / Codex
        ↓
   GitHub main
        ↓
   GitBook Sync
        ↓
      Zwiki
```

## 快速入口

| 分类 | 主要内容 |
| --- | --- |
| [基建](infrastructure/README.md) | Linux、网络、Nginx、硬件和常用运维 |
| [容器与云原生](cloud-native/README.md) | Docker、Kubernetes、K3s、K9s、Helm |
| [开发](development/README.md) | GitHub、开发工具和工程平台 |
| [AI](ai/README.md) | Codex、Claude Code、Vibe Coding、模型和 Skills |
| [项目](projects/README.md) | 项目设计、实施记录和自动镜像 |
| [Zwiki 使用与维护](wiki-ops/README.md) | 写入、修改、回退和文章规范 |

## 文章默认结构

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

## 内容原则

- 一篇文章解决一个明确场景，标题直接说明要做什么或排查什么。
- 开头先给最常用、最短、可落地的方案，不先讲大段背景。
- 命令和配置尽量做到复制即可改参数使用。
- 同一知识只保留一个权威页面，其他页面用链接引用。
- 官方已经写得很完整的内容不复制，只记录 Zwiki 场景需要的部分并给官方链接。
- 变更操作必须说明验证方式；高风险操作必须说明影响或回退入口。
- 真实案例可保留必要现场证据；产品部署清单可保留完整验收项，不为追求短而删关键步骤。
- 不提交密码、Token、私钥、客户信息或未脱敏现场数据。

## 修改

GitBook 页面右上角 Page Actions 已启用 **Edit on GitHub**，可直接进入对应 Markdown 源文件。

维护规则：

- [Zwiki 快速修改](wiki-ops/quick-edit-and-feedback.md)
- [写入前检查](wiki-ops/write-checklist.md)
- [文章编写规范](CONTRIBUTING.md)
- [错误回退与恢复](wiki-ops/rollback-guide.md)
- AI Agent 规则：[`AGENTS.md`](AGENTS.md)
