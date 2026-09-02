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
| [Linux](linux/README.md) | 系统管理、存储、网络、安全、性能与排障 |
| [硬件](hardware/README.md) | 服务器、CPU、内存、磁盘、RAID、网卡与 BMC |
| [网络](network/README.md) | TCP/IP、路由交换、DNS、TLS、代理、负载均衡与抓包 |
| [Docker](docker/README.md) | Engine、镜像、容器、Compose、网络、存储与排障 |
| [Kubernetes](kubernetes/README.md) | 集群、工作负载、网络、存储、安全与故障定位 |
| [K3s](k3s/README.md) | 安装、节点、运行时、备份恢复、升级与排障 |
| [开发工具与平台](dev-platforms/README.md) | GitHub、文档发布、静态站点、Web/SaaS 部署与 CI/CD |
| [Zwiki 使用与维护](wiki-ops/README.md) | 写入前检查、错误回退与恢复 |

## 内容原则

- 一级目录只在存在实际内容时创建，避免空目录和过度设计。
- 一篇文章聚焦一个问题，标题直接说明目标或故障现象。
- 命令应可复制执行，并写明预期输出、判断标准和风险。
- 涉及变更的文章应提供验证方法；存在风险时应提供回退方案。
- 标明适用版本、验证状态和最后验证日期，避免陈旧内容被误用。
- 只记录可以公开的组件知识，不提交账号、密钥、客户信息或内部敏感资料。

## 使用与维护

- AI Agent 操作规则见 [`AGENTS.md`](AGENTS.md)。
- 修改前执行 [写入前检查](wiki-ops/write-checklist.md)。
- 写错后按 [错误回退与恢复](wiki-ops/rollback-guide.md) 操作。

## 编写文章

新增内容前请阅读[编写与维护规范](CONTRIBUTING.md)，并从以下模板选择最接近的一种：

- [通用技术文章模板](templates/technical-article.md)
- [故障排查模板](templates/troubleshooting.md)
- [部署指南模板](templates/deployment-guide.md)
