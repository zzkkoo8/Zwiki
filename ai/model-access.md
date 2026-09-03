# 模型与接入

本页记录主流模型平台的账号、API Key / Token 获取、环境变量配置和接入原则。只记录获取与配置方法，Zwiki 不保存任何真实凭据。

## 先区分两个“Token”

- **API Key / Access Token**：用于认证调用模型平台，属于敏感凭据。
- **模型 Token**：模型计费和上下文长度使用的文本计量单位，不是登录密码。

本文主要讨论前者。

## OpenAI

官方入口：

- API Quickstart：<https://platform.openai.com/docs/quickstart>
- API Keys：<https://platform.openai.com/api-keys>

获取 API Key 后，在 macOS / Linux 中优先通过环境变量提供：

```bash
export OPENAI_API_KEY="<your-api-key>"
```

应用代码从环境变量读取，不要把 Key 写入前端代码、Git 仓库或公开配置文件。

> Codex 也支持使用 ChatGPT 账户登录。ChatGPT 登录态和 OpenAI API Key 是两套不同的认证/计费入口，不应混为一谈。

## Anthropic

官方入口：

- Claude Platform 文档：<https://docs.anthropic.com/>
- Console：<https://console.anthropic.com/>

常见环境变量：

```bash
export ANTHROPIC_API_KEY="<your-api-key>"
```

## OpenRouter

OpenRouter 提供统一 API 接入多个模型提供商，适合需要多模型切换、统一余额和兼容 OpenAI SDK 的场景。

官方入口：

- 首页 / Quickstart：<https://openrouter.ai/>
- API Keys：<https://openrouter.ai/keys>

常见环境变量：

```bash
export OPENROUTER_API_KEY="<your-api-key>"
```

## 配置建议

本机 Shell：

```text
~/.zshrc 或 ~/.bashrc
        ↓
export XXX_API_KEY=...
        ↓
程序通过环境变量读取
```

服务器 / CI：

```text
GitHub Actions Secrets / Vault / Secret Manager
        ↓
运行时注入
        ↓
应用读取环境变量
```

不要采用：

```text
config.py / .md / Dockerfile / 前端 JavaScript
        ↓
直接硬编码真实 Key
```

## 安全规则

1. API Key、Token、Cookie、私钥禁止提交到 Zwiki 或业务代码仓库。
2. `.env` 中如果包含真实 Key，应加入 `.gitignore`；仓库只提交 `.env.example`。
3. Key 泄露后优先撤销并重新生成，不要只删除 Git 当前版本，因为 Git 历史中可能仍保留旧值。
4. 生产环境优先为不同项目使用独立 Key，便于限额、审计和撤销。
5. 浏览器前端不能直接持有服务器侧模型 API Key，应通过自己的后端转发。
