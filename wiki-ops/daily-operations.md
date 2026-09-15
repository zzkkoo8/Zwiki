# Zwiki 日常维护指南

日常维护只需要解决两个问题：**文章放哪里**，以及**怎么告诉 AI 要改什么**。分支、PR、自审、合并和 GitBook 同步按 Zwiki 规则自动处理。

## 1. 文章放哪里

| 内容 | 目录 |
| --- | --- |
| Linux、系统、SSH、软件包、磁盘、性能 | `infrastructure/system/` |
| 路由、DNS 协议、抓包、VPN、链路 | `infrastructure/network/` |
| Nginx、NTP、DNS 服务、HAProxy 等 | `infrastructure/services/` |
| Docker | `cloud-native/docker/` |
| Kubernetes、kubectl、Helm、K9s | `cloud-native/kubernetes/` |
| K3s | `cloud-native/k3s/` |
| GitHub、GitBook、CI/CD | `development/platforms/` |
| 前后端、测试、设计工具 | `development/tooling/` |
| Codex、Claude Code、Vibe Coding | `ai/coding/` |
| 模型、Skills、插件、Prompt | `ai/` |
| 项目设计和项目镜像 | `projects/` |
| Zwiki 自身维护 | `wiki-ops/` |

判断规则：

- 一篇文章只选一个主分类，跨分类用链接引用。
- 已有同主题文章时优先修改，不重复新建。
- 不确定放哪里时，让 AI 先查目录和相关文章，不要自己猜。
- 一级领域 → 二级主题 → 具体文章，原则上不增加第四级导航。

## 2. 最短提示词怎么写

### 新增

```text
在 Zwiki 新增《标题》，内容覆盖：……
先检查是否已有同主题文章；有则补充存量，没有再选择最合适目录创建。
按 Zwiki 速查规范写，完成后自动审核、合并并检查 GitBook 同步。
```

### 修改

```text
优化 Zwiki 的《标题》：……
保持原路径，只改必要内容；优先给最短可执行方案，官方长文只给链接。
```

### 根据 GitBook URL 修改

```text
修改这个 Zwiki 页面：<GitBook URL>
需要修改：……
先定位唯一 GitHub Markdown 源文件，只修改 GitHub，不直接维护 GitBook 正文。
```

### 删除

```text
删除 Zwiki 的《标题》。
先检查 SUMMARY、README、内部引用和是否存在唯一内容，再删除正文和失效链接。
```

### 移动

```text
把《标题》从“分类 A”移动到“分类 B”。
同步修正文件路径、SUMMARY 和内部相对链接，不改无关内容。
```

### 回退

```text
回退刚才对 Zwiki 的错误修改。
按 rollback-guide 恢复相关提交或文件，不要 reset --hard + force push；完成后检查 main 和 GitBook。
```

## 3. AI 默认会做什么

只要明确说“修改 Zwiki”，默认流程是：

```text
查现有文章和目录
      ↓
定位唯一 GitHub 源文件
      ↓
临时分支最小修改
      ↓
审核 diff / 链接 / 敏感信息
      ↓
PR → merge main
      ↓
GitBook 从 GitHub 同步
```

不需要每次重复说明“先查重、建分支、PR、自审、合并”。

## 4. 附件

脚本、配置、图片放到文章对应的 `assets/` 目录并用相对路径引用。

```text
infrastructure/system/
├── example.md
└── assets/example/
    └── check.sh
```

脚本应说明用途、适用环境、风险和验证方法。不得提交真实密码、Token、Cookie、私钥或客户数据。

## 5. 自动镜像页面

`projects/` 下标记为“自动生成阅读镜像”的页面不能直接编辑。

例如 xmg-qa2：

```text
先修改 xmg-qa2 原仓库权威源
        ↓
同步 Workflow 更新 Zwiki
        ↓
GitBook 再从 Zwiki main 发布
```

## 6. GitBook 显示异常

先判断 GitHub 是否正确：

```text
GitHub main 正确
    ↓
检查 Git Sync 状态
    ↓
检查 SUMMARY / 页面路径
    ↓
必要时重新执行 GitHub → GitBook import
```

不要为了修 GitBook 展示问题，在 GitBook 中另维护一份正文。

## 相关规则

- [写入前检查](write-checklist.md)
- [Zwiki 快速修改](quick-edit-and-feedback.md)
- [错误回退与恢复](rollback-guide.md)
- [文章编写规范](../CONTRIBUTING.md)
- [AI Agent 操作规范](../AGENTS.md)
