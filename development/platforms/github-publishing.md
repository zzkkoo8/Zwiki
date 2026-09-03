# GitHub 常用组合：Wiki、静态网站与 Web/SaaS 发布

GitHub 不只是代码仓库，也常作为文档、网站和应用部署流程的源代码中心。不同项目应选择不同的发布层，不要把所有项目都塞进同一种托管方式。

## 常见组合

| 组合 | 适用场景 | 发布结果 |
| --- | --- | --- |
| GitHub + GitBook | 技术 Wiki、产品文档、知识库 | GitBook 公网站点 |
| GitHub + VitePress + GitHub Pages | Markdown 文档站、静态技术网站 | `github.io` 或自定义域名 |
| GitHub + Vercel | Next.js、React、Vue/Nuxt、AI Web、轻量 Web/SaaS | `vercel.app` 或自定义域名 |
| GitHub + Actions + VPS/云主机 | Docker、传统前后端、需要长期运行的服务 | 自有服务器域名 |
| GitHub + Actions + Kubernetes/K3s | 多服务、容器化、生产级持续部署 | 集群入口域名 |

## GitHub + GitBook：技术 Wiki

典型流程：

```text
ChatGPT / Codex / 人工编辑
            ↓
        GitHub Markdown
            ↓
         GitBook Git Sync
            ↓
         公网技术 Wiki
```

适合：

- Markdown 为主的技术知识库
- 希望保留 Git 版本历史
- 需要漂亮的文档阅读界面
- 希望 ChatGPT/Codex 直接修改 GitHub 源文件

Zwiki 当前采用这一组合。GitHub `main` 是唯一事实源，GitBook 是发布层。

## GitHub + VitePress + GitHub Pages：静态文档网站

适合纯静态内容，例如：

- VitePress
- MkDocs
- Hugo
- Jekyll
- 构建后只产生 HTML/CSS/JavaScript 的前端站点

典型流程：

```text
GitHub Push
    ↓
GitHub Actions 构建
    ↓
GitHub Pages
    ↓
公网静态网站
```

优点是架构简单、成本低、源码和发布都围绕 GitHub。缺点是不能直接承载需要长期后端进程、数据库或复杂服务端逻辑的 SaaS。

## GitHub + Vercel：Web 与轻量 SaaS

适合：

- Next.js
- React/Vite
- Vue/Nuxt
- Serverless API
- AI Web 应用
- 需要 Preview Deployment 的前端或全栈项目

典型流程：

```text
Codex / 开发者
      ↓
GitHub Branch / Pull Request
      ↓
Vercel Preview
      ↓
合并 main
      ↓
Production Deployment
```

这类组合适合快速上线 Web 应用。若项目依赖长期运行进程、复杂私有网络、中间件或大量有状态服务，则应考虑云主机或 Kubernetes。

## GitHub + Actions + VPS/云主机

适合：

- Docker Compose 应用
- 前后端分离系统
- Java、Go、Python、Node.js 长期运行服务
- PostgreSQL、Redis 等自管依赖

典型流程：

```text
GitHub
  ↓
GitHub Actions 构建/测试
  ↓
Docker Image / Artifact
  ↓
VPS 或云主机部署
  ↓
Nginx / Traefik / Caddy
  ↓
公网域名
```

这种方案控制力高，但服务器安全、升级、备份和故障恢复需要自行维护。

## GitHub + Actions + Kubernetes/K3s

适合已经需要集群能力的项目：

- 多微服务
- 多副本高可用
- 滚动发布
- 自动扩缩容
- 统一配置与 Secret 管理

典型流程：

```text
GitHub
  ↓
CI 构建与测试
  ↓
镜像仓库
  ↓
CD / GitOps
  ↓
Kubernetes / K3s
```

如果只是个人 Wiki 或单个轻量 Web 应用，不建议为了“生产级”而过早引入 Kubernetes。

## 选择建议

```text
Markdown Wiki          → GitBook
纯静态网站             → GitHub Pages
现代 Web / 轻量 SaaS   → Vercel
需要完整服务器环境      → VPS/云主机
真正需要集群能力        → Kubernetes/K3s
```

核心原则是：**GitHub 负责版本化源码，发布平台按应用运行形态选择。**
