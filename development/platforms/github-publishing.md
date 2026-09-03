# GitHub 发布方案

GitHub 负责保存源码和版本历史；项目最终发布到哪里，取决于它的运行方式。

## 常用方案

| 方案 | 适合 |
| --- | --- |
| GitHub + GitBook | 技术 Wiki、产品文档、知识库 |
| GitHub + GitHub Pages | VitePress、MkDocs、Hugo、Jekyll 等静态站点 |
| GitHub + Vercel | Next.js、React、Vue/Nuxt、轻量 Web/SaaS |
| GitHub + Actions + VPS/云主机 | Docker Compose、前后端服务、自管数据库和中间件 |
| GitHub + Actions + Kubernetes/K3s | 多服务、高可用、滚动发布、集群化部署 |

## Wiki：GitBook

Markdown 文档保存在 GitHub，GitBook 通过 Git Sync 同步并负责阅读和发布。

```text
人工 / ChatGPT / Codex
        ↓
   GitHub Markdown
        ↓
   GitBook Git Sync
        ↓
      Wiki
```

Zwiki 当前就是这套方式：GitHub `main` 是唯一事实源，GitBook 只作为发布层。

## 静态网站：GitHub Pages

VitePress、MkDocs、Hugo、Jekyll 等项目可以由 GitHub Actions 构建后直接发布到 GitHub Pages。

这类方案简单、成本低，适合纯静态内容；如果项目需要长期运行的后端进程、数据库或复杂服务端逻辑，就不适合只用 Pages。

## Web / 轻量 SaaS：Vercel

Next.js、React、Vue/Nuxt 等 Web 项目可以直接连接 GitHub。分支或 Pull Request 可生成 Preview Deployment，合并 `main` 后再发布生产环境。

如果项目依赖长期运行进程、复杂私有网络、自管中间件或大量有状态服务，优先考虑 VPS/云主机，而不是强行放到 Serverless 平台。

## 完整服务器环境：VPS / 云主机

适合 Docker Compose、Java/Go/Python/Node.js 后端，以及 PostgreSQL、Redis 等需要自行管理的组件。

常见流程是：

```text
GitHub
  ↓
GitHub Actions 构建 / 测试
  ↓
镜像或制品
  ↓
VPS / 云主机
  ↓
Nginx / Traefik / Caddy
```

这种方式自由度高，但系统安全、升级、备份和故障恢复也需要自己维护。

## 集群部署：Kubernetes / K3s

只有真正需要多服务、多副本、高可用、滚动发布、自动扩缩容或统一配置管理时，再考虑 Kubernetes/K3s。

个人 Wiki、单个网站或小型应用通常没有必要为了“生产级”提前引入集群复杂度。

## 怎么选

```text
技术 Wiki              → GitBook
纯静态网站             → GitHub Pages
现代 Web / 轻量 SaaS   → Vercel
需要完整服务器环境      → VPS / 云主机
确实需要集群能力        → Kubernetes / K3s
```

一句话：**GitHub 管源码和版本，运行平台按项目需求选。**
