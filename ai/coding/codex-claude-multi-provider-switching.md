# Codex / Claude Code 多渠道切换速查

Linux 开发机需要在官方渠道、私有网关、多 API Key、多模型之间切换时，不要反复手改同一个配置。最简单的思路是：**渠道配置固定成 Profile，Key 放环境变量，模型和推理强度启动时覆盖。**

## 1. Codex：推荐结构

```text
~/.codex/config.toml                 基础配置 / provider 定义
~/.codex/baizhi.config.toml          baizhi Profile
~/.codex/openrouter.config.toml      openrouter Profile
```

官方 Profile 文件格式是：

```text
$CODEX_HOME/<profile>.config.toml
```

启动：

```bash
codex --profile baizhi
```

或短参数：

```bash
codex -p baizhi
```

## 2. Codex：配置一个私有渠道

`~/.codex/config.toml`：

```toml
[model_providers.baizhi]
name = "Baizhi"
base_url = "https://gateway.example.com/v1"
env_key = "BAIZHI_API_KEY"
wire_api = "responses"
supports_websockets = false
```

Key 不写配置文件：

```bash
export BAIZHI_API_KEY='<YOUR_KEY>'
```

`wire_api` 当前只支持 `responses`。第三方网关仅仅“兼容 OpenAI API”不代表一定兼容 Codex，需要实际支持 Responses API。

如果网关支持 WebSocket，可去掉 `supports_websockets = false` 或按实际能力设置。

## 3. Codex：Profile 固定渠道和默认模型

`~/.codex/baizhi.config.toml`：

```toml
model_provider = "baizhi"
model = "deepseek-v3.2"
model_reasoning_effort = "high"
```

启动：

```bash
codex -p baizhi
```

临时换模型：

```bash
codex -p baizhi -m deepseek-v4-pro
```

临时换推理强度：

```bash
codex -p baizhi \
  -m deepseek-v4-pro \
  -c 'model_reasoning_effort="high"'
```

Codex 当前支持的 reasoning 配置值为：

```text
minimal / low / medium / high / xhigh
```

是否真正可用取决于当前模型。

## 4. Codex：最常用启动组合

日常开发：

```bash
codex \
  -p baizhi \
  -C /data/dev/project \
  -s workspace-write \
  -a on-request
```

测试机自动处理、不要反复人工确认：

```bash
codex \
  -p baizhi \
  -C /data/dev/project \
  -a never \
  -s workspace-write \
  -c 'sandbox_workspace_write.network_access=true'
```

额外允许一个工作目录：

```bash
codex \
  -p baizhi \
  -C /data/dev/project \
  --add-dir /data/dev/shared \
  -a never \
  -s workspace-write
```

优先 `--add-dir`，不要为了多写一个目录直接切 `danger-full-access`。

### 关于 `-a never`

`-a never` 只是不再弹审批，**不会取消 sandbox**。

当前 Codex 的 approval 常用值：

```text
on-request
never
```

`untrusted` 已不再支持，`on-failure` 已弃用。

## 5. Codex：自动 Git 操作

普通：

```bash
codex -a never -s workspace-write
```

适合自动改源码、跑测试、构建，但不要直接理解为“所有 Git 操作都能随意执行”。如果任务涉及受保护路径、凭据或 workspace 外目录，仍会受 sandbox 限制。

推荐顺序：

```text
workspace-write
    ↓
需要其他目录时 --add-dir
    ↓
只有隔离测试机确有必要时才提高权限
```

下面这种绕过审批和 sandbox 的模式不要作为日常默认值：

```bash
codex --dangerously-bypass-approvals-and-sandbox
```

## 6. Codex 常见报错

### Model metadata not found

例如：

```text
Model metadata for `xxx` not found. Defaulting to fallback metadata
```

常见原因是第三方模型不在 Codex 内置模型目录中。先确认：

```text
模型 ID 正确
网关 Responses API 兼容
上下文长度 / reasoning 能力与实际模型一致
```

能正常请求不代表 fallback metadata 一定最优；第三方模型问题优先看网关自身说明。

### WebSockets 502 / fallback HTTPS

如果网关根本不支持 Codex WebSocket transport，可在 provider 中显式：

```toml
supports_websockets = false
```

如果网关宣称支持但返回 502，则应排查反向代理、Upgrade/Connection 头、LB 和网关实现，不要只在 Codex 客户端反复重试。

## 7. Claude Code：最简单的渠道切换

Claude Code 可以把非敏感渠道配置放到不同 settings 文件。

例如：

```text
~/.claude/profiles/gateway-a.json
```

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://llm-gateway.example.com"
  }
}
```

凭据单独放环境变量：

```bash
export CLAUDE_GATEWAY_TOKEN='<YOUR_TOKEN>'
```

启动：

```bash
ANTHROPIC_AUTH_TOKEN="$CLAUDE_GATEWAY_TOKEN" \
claude \
  --settings ~/.claude/profiles/gateway-a.json \
  --model <model>
```

切回其他渠道时换 settings / 环境变量即可，不要把真实 Key 写进项目仓库。

需要完整隔离登录状态、插件和会话时，再考虑不同 `CLAUDE_CONFIG_DIR`；普通换模型/网关没必要。

## 8. 建议做两个短命令

Codex：

```bash
alias cx-baizhi='codex -p baizhi'
alias cx-openrouter='codex -p openrouter'
```

使用：

```bash
cx-baizhi -C /data/dev/project -m deepseek-v4-pro
```

Claude Code：

```bash
alias cl-gw='claude --settings ~/.claude/profiles/gateway-a.json'
```

不要把 API Key 直接写进 alias。

## 官方资料

- Codex Config Reference：https://developers.openai.com/codex/config-reference/
- Codex CLI Reference：https://developers.openai.com/codex/cli/reference/
- Codex AGENTS.md：https://developers.openai.com/codex/guides/agents-md/
- Claude Code 文档：https://docs.anthropic.com/en/docs/claude-code/
