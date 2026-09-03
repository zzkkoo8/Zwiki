# Zwiki 日常维护指南

本页用于回答两个日常问题：**新文章应该放在哪里**，以及**如何直接给 ChatGPT、Codex 或其他 AI Agent 下达 Zwiki 增删改维护指令**。

Zwiki 的唯一事实源是 GitHub `main`。正常维护只修改 GitHub Markdown，由 AI 自动审核、合并，再由 GitBook Git Sync 发布。

## 1. 新文章放到哪个目录

优先按“文章主要解决什么问题”选择一个唯一主分类，不要为了方便检索把同一篇文章复制到多个目录。跨领域内容通过 Markdown 链接互相引用。

| GitBook 分类 | GitHub 目录 | 适合收录的内容 |
| --- | --- | --- |
| 基建 / 硬件 | `infrastructure/hardware/` | 服务器、CPU、内存、磁盘、RAID、网卡、GPU、BMC、BIOS、固件和硬件故障 |
| 基建 / 系统 | `infrastructure/system/` | Linux、Ubuntu、内核、systemd、存储、权限、软件包、安全加固和系统故障 |
| 基建 / 网络 | `infrastructure/network/` | TCP/IP、路由交换、VLAN、DNS 协议、TLS、代理、抓包、链路与网络故障 |
| 基建 / 基础服务 | `infrastructure/services/` | DNS 服务、NTP/Chrony、OpenSSH、Nginx、HAProxy、Keepalived、NFS、Samba、rsync 等通用服务 |
| 容器与云原生 / Docker | `cloud-native/docker/` | Docker Engine、镜像、容器、Compose、网络、存储和 Docker 部署排障 |
| 容器与云原生 / Kubernetes | `cloud-native/kubernetes/` | Kubernetes 集群、工作负载、网络、存储、安全、调度与排障 |
| 容器与云原生 / K3s | `cloud-native/k3s/` | K3s 安装、节点、运行时、升级、备份恢复和故障排查 |
| 开发 / 工程平台 | `development/platforms/` | GitHub、GitBook、GitLab、Vercel、CI/CD 等开发协作与发布平台 |
| 开发 / 技术栈与工具 | `development/tooling/` | 前端、后端、全栈、测试、设计等非 AI 专属技术栈与开发工具 |
| AI / AI Coding | `ai/coding/` | Vibe Coding、Codex、Claude Code、Cursor、Coding Agent、上下文管理、多 Agent 和 AI 代码审查 |
| AI / Skills 与插件 | `ai/skills-plugins.md` 或后续同主题页面 | Agent Skills、插件、MCP、Superpowers 等 AI 能力扩展 |
| AI / 模型与接入 | `ai/model-access.md` 或后续同主题页面 | 模型选择、OpenAI/Anthropic/OpenRouter、API Key/Token 的合法申请与配置、模型渠道切换 |
| AI / 提示词 | `ai/prompting.md` 或后续同主题页面 | Prompt Engineering、系统提示词、开发提示词、审计提示词和提示词模板 |
| AI / AI 资源 | `ai/resources.md` 或后续同主题页面 | AI 教程、评测、Awesome 项目、综合资源站和学习资源 |
| 项目 | `projects/` | 项目设计稿、项目文档阅读入口；标记为“自动生成阅读镜像”的页面禁止直接编辑 |
| Zwiki 使用与维护 | `wiki-ops/` | Zwiki 自身的维护、写入、回退、同步和操作手册 |
| 模板 | `templates/` | 技术文章、故障排查、部署指南等写作模板 |

### 分类判断原则

1. **系统本身的问题**放“基建 / 系统”；运行在系统之上的通用服务放“基建 / 基础服务”。
2. Docker、Kubernetes、K3s 统一放 `cloud-native/`，不与“基础服务”混用。
3. GitHub、GitBook、CI/CD 等平台放“开发 / 工程平台”；前后端框架、测试和设计工具放“开发 / 技术栈与工具”。
4. Coding Agent、Vibe Coding、Prompt、模型、Skills、插件和 MCP 放“AI”；其中 Vibe Coding 归“AI / AI Coding”。
5. 具体项目自己的架构和设计文档放“项目”，即使项目本身属于 AI 产品，也不要混入通用 AI 知识。
6. 同一主题已有文章时优先修改存量文章，不重复新建。
7. 不确定分类时，不需要自己猜，让 AI 先审计现有目录和相关文章后决定。

### 导航层级原则

```text
一级：领域
二级：主题
三级：具体文章
```

原则上不建立第四级 GitBook 导航。仅用于说明目录职责的 `README.md` 可以保留在 GitHub，但如果没有独立阅读价值，不必重复显示在 GitBook 左侧目录。

## 2. 最推荐的提示词写法

日常使用不需要写很长的提示词。只要说清楚**目标、对象、必须保留的约束**即可，其余查重、路径判断、分支、PR、自审、合并和 GitBook 同步由 Zwiki 规则自动处理。

### 新增文章：让 AI 自动选目录

```text
在 Zwiki 新增《文章标题》。
内容需要覆盖：……
先检查现有目录和同主题文章，选择最合适的目录；已有相同主题时优先补充存量文章，不要重复创建。
完成后更新必要的 SUMMARY.md，AI 自审并自动合并 main，再检查 GitBook 同步结果。
```

### 新增文章：已经知道分类

```text
在 Zwiki 的“AI → Skills 与插件”新增《XXX》。
整理成可直接使用的技术文档，包含原理、安装、用法、验证和官方项目 URL。
先查重，已有同主题文章就直接优化存量文章。
```

### 修改存量文章

```text
优化 Zwiki 的《XXX》存量文章。
补充：……
不要新建重复文章，不要改文件路径，不要重写无关章节，只做必要修改。
```

### 直接根据 GitBook URL 修改

```text
修改这个 Zwiki 页面：
https://zwiki.gitbook.io/zwiki-docs/...

需要修改：……
先通过 SUMMARY.md 确认唯一对应的 GitHub Markdown，只修改 GitHub 源文件，不直接编辑 GitBook。
```

### 删除文章

```text
删除 Zwiki 的《XXX》。
删除前检查它是否被 SUMMARY.md、README 或其他文章引用，并确认没有需要迁移到其他文章的唯一内容。
确认可删除后，删除源 Markdown 和失效导航/引用；不要删除无关文件。AI 自审后自动合并。
```

### 移动或调整目录

```text
把 Zwiki 的《XXX》从“旧分类”移动到“新分类”。
保持正文内容不变，更新 GitHub 物理路径、SUMMARY.md 和仓库内相关相对链接；检查旧路径是否还有引用。
完成后检查 GitBook 实际导航。
```

### 增加脚本、配置或图片附件

```text
给 Zwiki 的《XXX》增加附件：……
附件放入与文章对应的 assets 目录，Markdown 使用相对路径引用。
脚本需要说明用途、适用环境、风险、验证和回退；不得写入真实密码、Token、Cookie 或私钥。
```

### 回退刚才的错误修改

```text
刚才对 Zwiki 的修改有问题。
按 Zwiki 回退规范恢复上一笔相关修改，优先使用 git revert 或恢复指定文件后新增恢复提交，不要 reset --hard + force push。
恢复后核对 GitHub main 和 GitBook 页面。
```

### GitBook 显示异常

```text
这个 Zwiki 页面显示异常：
https://zwiki.gitbook.io/zwiki-docs/...

先只读检查 GitBook Git Sync、页面树和对应 GitHub Markdown。
GitHub 内容正确时不要改正文；定位是同步、导航、路径还是发布问题后再处理。
```

### 修改自动镜像的项目文档

以 `xmg-qa2` 为例：

```text
修改 Zwiki 中 xmg-qa2 的《技术支持专家 Agent 设计稿》：……
这是自动镜像页面，请修改 xmg-qa2 原仓库的权威源，不要直接修改 Zwiki 镜像。
修改后触发/等待同步 Workflow，并检查 Zwiki 与 GitBook 已刷新。
```

## 3. 增、删、改、移的固定动作

| 操作 | AI 默认动作 |
| --- | --- |
| 新增 | 查重 → 选目录 → 创建 Markdown → 必要时更新分类 README/SUMMARY → 自审 → 合并 |
| 修改 | 定位唯一源文件 → 只改目标章节 → 路径不变则通常不动 SUMMARY → 自审 → 合并 |
| 删除 | 检查引用和唯一内容 → 删除源文件 → 清理失效索引/引用 → 自审 → 合并 |
| 移动 | 确认新分类 → 移动物理文件 → 更新 SUMMARY 和相对链接 → 检查旧路径引用 → 自审 → 合并 |
| 附件 | 放入文章相关 `assets/` → 使用相对路径 → 检查敏感信息和风险说明 → 自审 → 合并 |
| 回退 | 查提交历史 → 优先 `git revert` 或恢复单文件 → 新增恢复提交 → 检查 GitBook |

## 4. 你不需要每次重复说明的规则

只要明确说“修改 Zwiki”，AI 默认就应该执行：

```text
检查现有内容和目录
    ↓
定位唯一事实源 GitHub
    ↓
只做必要修改
    ↓
临时分支 + PR 记录 diff
    ↓
AI 自动审核
    ↓
审核通过自动合并 main
    ↓
GitBook Git Sync
    ↓
检查最终页面并报告结果
```

以下情况才需要停下来询问：无法唯一定位文章、需求存在关键歧义、发现无法安全处理的敏感信息、自动审核持续失败或 GitHub 无法安全合并。

## 5. 最短提示词模板

大多数情况下，一句话就够：

```text
新增：在 Zwiki 的“分类”新增《标题》，内容包括……，先查重后自动完成。

修改：优化 Zwiki 的《标题》，只修改……，不要新建或改路径。

URL 修改：修改这个 Zwiki 页面 <GitBook URL>：……，只改 GitHub 源文件。

删除：删除 Zwiki 的《标题》，先检查引用和唯一内容，再清理索引。

移动：把《标题》从“分类 A”移动到“分类 B”，同步修正路径、SUMMARY 和引用。

回退：回退刚才对 Zwiki 的错误修改，按 rollback-guide 执行并验证 GitBook。
```

更具体的写入检查见[《Zwiki 写入前检查》](write-checklist.md)，错误恢复见[《错误回退与恢复》](rollback-guide.md)，文章格式见[《文章编写规范》](../CONTRIBUTING.md)。
