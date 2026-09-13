# Codex 与 Claude Code 多渠道、多 API Key、多模型切换速查

在 Linux 开发机上，最稳妥的做法是把**渠道、凭据、模型、权限**分开管理：Codex 用官方 `--profile` + `model_provider`，Claude Code 用 `--settings` + 环境变量或 `apiKeyHelper`；模型再用启动参数临时覆盖。这样切渠道不需要反复改主配置，也不会把 API Key 写进项目仓库。

## 文档信息

- **技术领域**：AI Coding / Codex CLI / Claude Code
- **适用范围**：Linux 开发机、测试机、CI/自动化终端
- **适用版本**：以 2026-09-13 OpenAI、Anthropic 官方文档为准
- **文档状态**：已验证
- **最后验证**：2026-09-13
- **来源**：OpenAI、Anthropic 官方文档

## 1. 推荐组织方式

| 项目 | Codex | Claude Code |
| --- | --- | --- |
| 切渠道 | `--profile <name>` | `--settings <file>` + 环境变量 |
| 多 API Key | `model_providers.<id>.env_key` 指向不同环境变量 | 为不同渠道注入 `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN`，轮换凭据用 `apiKeyHelper` |
| 启动切模型 | `-m <model>` | `--model <model>` |
| 会话内切模型 | `/model` | `/model` |
| 推理强度 | `-c 'model_reasoning_effort="high"'` | `--effort high` |
| 工作目录 | `-C /path/to/project` | 先进入目录，或从目标目录启动 |
| 自动执行 | `-a never` 配合合适的 sandbox | `--permission-mode auto` / `dontAsk`，按任务选择 |
| 高权限模式 | `-s danger-full-access` / `--yolo` | `--dangerously-skip-permissions` |

原则：**Profile/Settings 决定长期渠道配置，启动参数只覆盖本次会话。API Key 只从环境变量、Vault 或凭据 Helper 注入。**

## 2. Codex：多渠道、多 Key、多模型

### 2.1 在用户配置中定义渠道

Codex 用户级配置位于：

```text
~/.codex/config.toml
```

自定义模型渠道使用 `model_providers.<id>`。官方当前只支持 `responses` wire API；第三方网关必须兼容该协议，不能因为“兼容 OpenAI API”就默认一定可用。

示例：同一个 OpenRouter 配两组 Key，再加一个企业网关：

```toml
[model_providers.openrouter_primary]
name = "OpenRouter Primary"
base_url = "https://openrouter.ai/api/v1"
env_key = "OPENROUTER_KEY_PRIMARY"
wire_api = "responses"

[model_providers.openrouter_backup]
name = "OpenRouter Backup"
base_url = "https://openrouter.ai/api/v1"
env_key = "OPENROUTER_KEY_BACKUP"
wire_api = "responses"

[model_providers.gateway_a]
name = "Gateway A"
base_url = "https://gateway.example.com/v1"
env_key = "GATEWAY_A_API_KEY"
wire_api = "responses"
```

真实 Key 不写入 TOML：

```bash
export OPENROUTER_KEY_PRIMARY='<secret>'
export OPENROUTER_KEY_BACKUP='<secret>'
export GATEWAY_A_API_KEY='<secret>'
```

更推荐由 Vault、`pass`、1Password CLI、CI Secret 等在启动前注入，而不是把真实 Key 长期明文写进 `~/.bashrc`。

### 2.2 为渠道建立 Codex Profile

Codex Profile 文件与 `config.toml` 放在同一目录：

```text
~/.codex/openrouter-primary.config.toml
~/.codex/openrouter-backup.config.toml
~/.codex/gateway-a.config.toml
```

例如：

```toml
# ~/.codex/openrouter-primary.config.toml
model_provider = "openrouter_primary"
model = "<model-id>"
model_reasoning_effort = "high"
```

```toml
# ~/.codex/openrouter-backup.config.toml
model_provider = "openrouter_backup"
model = "<model-id>"
model_reasoning_effort = "medium"
```

```toml
# ~/.codex/gateway-a.config.toml
model_provider = "gateway_a"
model = "<model-id>"
```

启动时直接切：

```bash
codex -p openrouter-primary
codex -p openrouter-backup
codex -p gateway-a
```

临时换模型，不改 Profile：

```bash
codex -p gateway-a -m '<model-id>'
```

临时改推理强度：

```bash
codex -p gateway-a \
  -m '<model-id>' \
  -c 'model_reasoning_effort="high"'
```

支持的推理档位取决于模型。当前 Codex 配置字段支持 `minimal | low | medium | high | xhigh`，模型不支持时不要强行指定。

查看 Codex 当前模型目录：

```bash
codex debug models
```

会话中可以用：

```text
/model
```

切换当前模型及可用的推理强度。

### 2.3 Codex 常用启动组合

日常交互开发，官方推荐的低摩擦组合：

```bash
codex \
  -p gateway-a \
  -C /data/dev/project \
  -s workspace-write \
  -a on-request
```

测试机自动改源码、跑测试、允许联网，但不弹审批：

```bash
codex \
  -p gateway-a \
  -C /data/dev/project \
  -a never \
  -s workspace-write \
  -c 'sandbox_workspace_write.network_access=true'
```

需要同时操作其他工作目录时，优先增加目录，不要直接放开整个系统：

```bash
codex \
  -p gateway-a \
  -C /data/dev/project \
  --add-dir /data/dev/shared \
  -s workspace-write \
  -a on-request
```

本地 Ollama：

```bash
codex \
  --oss \
  --local-provider ollama \
  -m '<local-model>' \
  -s workspace-write \
  -a on-request
```

无人值守任务：

```bash
codex exec \
  -p gateway-a \
  -C /data/dev/project \
  -s workspace-write \
  -a never \
  --json \
  -o /tmp/codex-result.txt \
  '执行测试并汇总失败原因'
```

### 2.4 自动 Git 操作要特别注意

`-a never` 只是取消审批提示，**不会取消 sandbox 限制**。

Codex 官方当前规定：默认 `workspace-write` 下，工作区中的 `.git` 仍是只读保护路径。因此下面这组参数适合自动修改源码、构建和测试，但不能把它理解成“自动 commit/push 已完全放开”：

```bash
codex -a never -s workspace-write
```

如果任务必须让 Codex 自己执行 branch / commit / push，有两种选择：

1. **推荐**：Codex 负责源码修改，Git 提交/推送由外部脚本、CI 或人工完成。
2. **隔离测试机才考虑**：明确使用 `danger-full-access`，并确保机器、账号、网络和凭据本身已经做隔离。

```bash
codex \
  -p gateway-a \
  -C /data/dev/project \
  -a never \
  -s danger-full-access
```

不要在普通开发机上把下面参数当默认启动方式：

```bash
codex --dangerously-bypass-approvals-and-sandbox
```

它会同时绕过审批和 sandbox，官方也只建议在外部已经加固的隔离环境中使用。

## 3. Claude Code：多渠道、多 Key、多模型

Claude Code 没有 Codex 同名的 `--profile` 参数。Linux 开发机最实用的官方组合是：

```text
渠道配置文件（--settings）
        +
当前渠道凭据（环境变量 / apiKeyHelper）
        +
当前模型（--model）
```

### 3.1 直连 Anthropic 与网关

Claude Code 网关使用：

```bash
export ANTHROPIC_BASE_URL='https://llm-gateway.example.com'
```

凭据变量按网关认证方式选择：

```bash
# Authorization: Bearer
export ANTHROPIC_AUTH_TOKEN='<secret>'

# 或 x-api-key
export ANTHROPIC_API_KEY='<secret>'
```

官方含义：

- `ANTHROPIC_AUTH_TOKEN`：发送 `Authorization: Bearer ...`
- `ANTHROPIC_API_KEY`：发送 `x-api-key: ...`
- `apiKeyHelper`：适合 Vault、SSO、定期轮换凭据

网关凭据存在时会优先于已保存的 claude.ai / Console 登录；取消网关变量后可回到原来的登录方式。

### 3.2 用 `--settings` 做渠道配置

建立仅包含**非敏感渠道设置**的文件：

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

启动：

```bash
ANTHROPIC_AUTH_TOKEN="$CLAUDE_GATEWAY_A_TOKEN" \
claude \
  --settings ~/.claude/profiles/gateway-a.json \
  --model sonnet \
  --permission-mode plan
```

如果凭据来自 Vault，优先使用官方 `apiKeyHelper`：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://llm-gateway.example.com"
  },
  "apiKeyHelper": "~/bin/get-gateway-key.sh"
}
```

Helper 必须只把凭据输出到 stdout，不要额外输出日志。

如果需要连同登录状态、会话历史、插件等整套隔离，可以用不同 `CLAUDE_CONFIG_DIR`。这属于“完整环境隔离”，不是普通切模型的首选：

```bash
CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude
CLAUDE_CONFIG_DIR="$HOME/.claude-lab" claude
```

### 3.3 Claude Code 常用启动组合

只分析和规划：

```bash
claude \
  --model sonnet \
  --effort high \
  --permission-mode plan
```

日常自动模式：

```bash
claude \
  --model sonnet \
  --effort high \
  --permission-mode auto
```

主模型不可用时按顺序回退：

```bash
claude \
  --model sonnet \
  --fallback-model opus,haiku \
  --permission-mode auto
```

指定网关 Profile：

```bash
ANTHROPIC_AUTH_TOKEN="$CLAUDE_GATEWAY_A_TOKEN" \
claude \
  --settings ~/.claude/profiles/gateway-a.json \
  --model sonnet \
  --effort high \
  --permission-mode auto
```

脚本化输出：

```bash
claude \
  -p '执行测试并汇总失败原因' \
  --model sonnet \
  --permission-mode default \
  --output-format json
```

高权限模式同样不要作为普通开发机默认值：

```bash
claude --dangerously-skip-permissions
```

### 3.4 Claude 会话内快速切模型

启动时：

```bash
claude --model sonnet
claude --model opus
claude --model haiku
```

会话中：

```text
/model
```

Claude Code 官方说明：`--model` 会覆盖 settings 中的 `model` 和 `ANTHROPIC_MODEL`；`--effort` 只影响当前会话。模型切换后首个请求可能重新建立模型对应的 Prompt Cache。

## 4. 建议加两个 Shell 快捷入口

不建议记一堆长命令。把“渠道选择”封装成短函数，模型和权限继续通过参数覆盖。

### Codex

加入 `~/.bashrc`：

```bash
cx() {
  local profile="$1"
  shift

  case "$profile" in
    or1) codex -p openrouter-primary "$@" ;;
    or2) codex -p openrouter-backup "$@" ;;
    gw)  codex -p gateway-a "$@" ;;
    *)
      echo '用法: cx {or1|or2|gw} [codex参数...]'
      return 2
      ;;
  esac
}
```

使用：

```bash
cx gw -m '<model-id>' -C /data/dev/project -s workspace-write -a on-request
cx or1 -C /data/dev/project -a never -s workspace-write
```

### Claude Code

使用子 Shell，避免某个渠道的变量污染后续会话：

```bash
clx() (
  unset ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN

  local channel="$1"
  shift

  case "$channel" in
    direct)
      export ANTHROPIC_API_KEY="$CLAUDE_DIRECT_KEY"
      claude "$@"
      ;;
    gw)
      export ANTHROPIC_AUTH_TOKEN="$CLAUDE_GATEWAY_A_TOKEN"
      claude --settings "$HOME/.claude/profiles/gateway-a.json" "$@"
      ;;
    *)
      echo '用法: clx {direct|gw} [claude参数...]'
      return 2
      ;;
  esac
)
```

使用：

```bash
clx direct --model sonnet --permission-mode plan
clx gw --model opus --effort high --permission-mode auto
```

这些函数只负责“选渠道”，不要把真实 Key 直接写进函数。

## 5. 排错与确认当前渠道

Codex：

```bash
codex doctor
codex debug models
```

进入 Codex 后：

```text
/status
/model
```

Claude Code：

```bash
claude doctor
claude --debug
```

进入 Claude Code 后：

```text
/status
/model
```

Claude 连接自建网关时，`/status` 应显示当前 Anthropic base URL 和正在生效的凭据来源。不要用 `echo $API_KEY` 之类命令把完整密钥打进终端日志。

## 6. 选型建议

- **只切模型**：直接用 `-m` / `--model`，无需建立新渠道配置。
- **同一渠道多 Key**：为每个 Key 使用独立环境变量，不要反复覆盖同一个 Key 文件。
- **多网关**：Codex 建独立 Profile；Claude 建独立 `--settings` 文件，再由 Shell 包装函数选择。
- **动态/短期凭据**：Codex 使用自定义 provider 的 `auth.command`，Claude 使用 `apiKeyHelper`。
- **普通开发机**：优先 workspace/plan/auto 等受控模式，不使用危险跳过权限参数。
- **专用测试机无人值守**：可以提高自动化权限，但应先隔离 Git 凭据、SSH Key、云凭据和生产网络，再考虑 full access。

## 7. 官方参考

### OpenAI Codex

- [Codex CLI / Developer commands](https://developers.openai.com/codex/cli/reference)
- [Codex Configuration Reference](https://developers.openai.com/codex/config-reference)
- [Codex Advanced Config](https://learn.chatgpt.com/docs/config-file/config-advanced)
- [Codex Authentication](https://developers.openai.com/codex/auth)
- [Codex Agent approvals and security](https://learn.chatgpt.com/docs/agent-approvals-security)

### Anthropic Claude Code

- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Claude Code Settings](https://code.claude.com/docs/en/settings)
- [Claude Code LLM gateway](https://code.claude.com/docs/en/llm-gateway)
- [Connect Claude Code to an LLM gateway](https://code.claude.com/docs/en/llm-gateway-connect)

## 相关文档

- [ChatGPT 与 Codex](chatgpt-codex.md)
- [Codex 项目开局规范](codex-project-bootstrap.md)
- [模型与接入](../model-access.md)
