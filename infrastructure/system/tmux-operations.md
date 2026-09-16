# tmux 长任务与远程会话速查

用于 SSH 远程运维、长时间安装部署、日志观察、Codex/Claude Code 等长任务场景。核心目标：**终端断开后任务继续运行，人类能重新接管，Agent/Codex 也能从外部检查状态和结果。**

## 1. 安装与确认

```bash
# 查看是否已安装
tmux -V

# Debian / Ubuntu
apt install -y tmux

# RHEL / CentOS / Rocky / AlmaLinux / Kylin
yum install -y tmux
# 新版本系统也可使用
dnf install -y tmux
```

## 2. 最常用操作

### 创建会话

```bash
tmux new -s ops
```

例如：

```bash
tmux new -s xmg-qa2
```

### 查看所有会话

```bash
tmux ls
```

也可以：

```bash
tmux list-sessions
```

### 临时离开，但保持任务运行

在 tmux 内按：

```text
Ctrl+b  d
```

先按 `Ctrl+b`，松开后再按 `d`。

> 不要在长任务运行时直接输入 `exit`。`exit` 会关闭当前 shell；如果这是会话中最后一个 shell，tmux 会话也会结束。

### 重新进入会话

```bash
tmux attach -t xmg-qa2
```

简写：

```bash
tmux a -t xmg-qa2
```

### 有则进入，无则创建

远程运维和手机接管常用：

```bash
tmux new-session -A -s xmg-qa2
```

指定工作目录：

```bash
tmux new-session -A -s xmg-qa2 -c /data/dev/xmg-qa2
```

## 3. 会话改名

当前会话改名：

```bash
tmux rename-session xmg-qa2
```

快捷键：

```text
Ctrl+b  $
```

在 tmux 外指定会话改名：

```bash
tmux rename-session -t old-name new-name
```

## 4. 窗口常用操作

一个 tmux Session 可以有多个 Window，类似多个终端标签页。

| 操作 | 快捷键 |
|---|---|
| 新建窗口 | `Ctrl+b c` |
| 下一个窗口 | `Ctrl+b n` |
| 上一个窗口 | `Ctrl+b p` |
| 按编号切换 | `Ctrl+b 0` ~ `Ctrl+b 9` |
| 查看窗口列表 | `Ctrl+b w` |
| 当前窗口改名 | `Ctrl+b ,` |
| 关闭当前窗口 | `exit` 或 `Ctrl+b &` |

查看当前会话、窗口和 Pane：

```bash
tmux display-message 'session=#S window=#I:#W pane=#P'
```

## 5. Pane 分屏常用操作

| 操作 | 快捷键 |
|---|---|
| 左右分屏 | `Ctrl+b %` |
| 上下分屏 | `Ctrl+b "` |
| 切换 Pane | `Ctrl+b` + 方向键 |
| 显示 Pane 编号 | `Ctrl+b q` |
| 关闭当前 Pane | `exit` 或 `Ctrl+b x` |
| 临时放大/恢复 | `Ctrl+b z` |

适合一边运行任务、一边查看日志。

## 6. 查看历史输出

进入复制/滚动模式：

```text
Ctrl+b  [
```

使用方向键、`PageUp`、`PageDown` 查看，按 `q` 退出。

如果通过 Windows CMD、Xshell 或手机终端接入，优先使用 tmux 自己的历史模式，不依赖 SSH 客户端保留多少终端历史。

## 7. 删除会话、窗口和 Pane

删除指定会话：

```bash
tmux kill-session -t xmg-qa2
```

删除指定窗口：

```bash
tmux kill-window -t xmg-qa2:1
```

查看 Pane：

```bash
tmux list-panes -a
```

删除指定 Pane：

```bash
tmux kill-pane -t xmg-qa2:0.1
```

> `kill-session`、`kill-window`、`kill-pane` 会终止其中运行的前台程序。长任务运行期间不要把“清理 tmux”当作普通清理动作。

## 8. 从 tmux 外查看状态

查看会话：

```bash
tmux ls
```

查看窗口：

```bash
tmux list-windows -a
```

查看某个 Session 的 Pane 和当前程序：

```bash
tmux list-panes -t xmg-qa2 \
  -F '#S:#I.#P window=#{window_name} pid=#{pane_pid} cmd=#{pane_current_command} dead=#{pane_dead} path=#{pane_current_path}'
```

不进入 tmux，直接读取最近 200 行屏幕历史：

```bash
tmux capture-pane -p -S -200 -t xmg-qa2:0.0
```

这类命令特别适合 Codex/Agent 自动巡检，因为不需要 attach，也不会改变人类当前终端状态。

## 9. 从外部向 tmux 中发送命令

先确认目标 Pane：

```bash
tmux list-panes -a
```

向指定 Pane 输入命令并回车：

```bash
tmux send-keys -t xmg-qa2:0.0 'pwd' Enter
```

例如：

```bash
tmux send-keys -t xmg-qa2:0.0 'git status' Enter
```

> `send-keys` 相当于远程敲键盘。不要对未知状态的交互程序盲目发送命令，也不要用它自动确认高危操作。

## 10. SSH 断线后的恢复

SSH、VPN、Wi-Fi 或手机网络断开时，只要 Linux 主机和 tmux 仍正常，tmux 内程序不会因为 SSH 断开而退出。

重新登录：

```bash
tmux ls
tmux attach -t xmg-qa2
```

如果会话已被其他客户端 attach，可接管：

```bash
tmux attach -d -t xmg-qa2
```

## 11. 手机 / 远程接管 Codex

推荐链路：

```text
手机或电脑
   ↓
VPN / Tailscale / 企业内网
   ↓
SSH Linux
   ↓
tmux
   ↓
Codex / Claude Code / 长任务
```

首次启动：

```bash
cd /data/dev/xmg-qa2
tmux new -s xmg-qa2
codex
```

离开：

```text
Ctrl+b  d
```

再次 SSH 后：

```bash
tmux attach -t xmg-qa2
```

> tmux 只能防 SSH 会话中断，不能防主机重启、断电、OOM Kill 或程序自身崩溃。代码、任务结果和日志仍需单独持久化。

## 12. 人类 + Codex 自动执行长任务：标准模式

### 适用场景

典型架构：

```text
外部运维机
└─ Codex / Agent
     │
     │ SSH：只负责下发和检查
     ▼
内网 Linux 控制机
└─ tmux Session
     ├─ manager249 → Ansible / 安装 / 升级任务
     ├─ manager250 → Ansible / 安装 / 升级任务
     └─ manager251 → Ansible / 安装 / 升级任务
```

目标同时满足：

1. 外部 SSH 断开后任务继续运行。
2. 人类可以 `tmux attach` 实时查看和接管。
3. Codex 不进入交互界面也能检查状态。
4. stdout/stderr 有永久日志。
5. Ansible 每台主机结果有独立记录。
6. 任务完成后能明确得到真实退出码。

### 推荐组合

```text
tmux       → 托管进程、断线续跑、人工接管
tee        → 同时输出到 tmux 屏幕和永久日志
--tree     → 保存 Ansible 每台目标主机的执行结果
status/rc  → 给人类和 Codex 一个明确的最终状态
```

不要只用：

```bash
ansible ... > output.log 2>&1
```

这样日志虽然保留，但 attach 到 tmux 后通常看不到实时输出。

推荐：

```bash
ansible ... 2>&1 | tee -a output.log
```

这样：

```text
                 ┌─→ tmux 屏幕：人类实时看
Ansible → tee ───┤
                 └─→ output.log：Codex/人类事后查

Ansible --tree ─────→ result-*/：每台主机结果
```

### 目录建议

每次长任务建立独立目录，不把结果散落在 `/root`：

```text
/root/tasks/agent-install-20260916/
├── run-249.sh
├── hosts-249.txt
├── output-249.log
├── result-249/
├── status-249
└── rc-249
```

多批任务可继续增加 `250`、`251` 等编号。

### Runner 脚本模板

以 Ansible 批量任务为例：

```bash
#!/usr/bin/env bash
set -u
set -o pipefail

TASK_DIR=/root/tasks/agent-install-20260916
LOG="$TASK_DIR/output-249.log"
RESULT_DIR="$TASK_DIR/result-249"
STATUS_FILE="$TASK_DIR/status-249"
RC_FILE="$TASK_DIR/rc-249"

mkdir -p "$RESULT_DIR"
printf 'RUNNING\n' > "$STATUS_FILE"

/usr/bin/ansible all \
  --inventory /root/ansible-root/inventory.yml \
  --limit @"$TASK_DIR/hosts-249.txt" \
  --module-name raw \
  --args 'curl -kfsSL -g http://10.7.216.249:80/api/agent/script | bash -s -- --installer_work_dir /tmp --token <TOKEN>' \
  --forks 10 \
  --one-line \
  --tree "$RESULT_DIR" \
  2>&1 | tee -a "$LOG"

rc=${PIPESTATUS[0]}
printf '%s\n' "$rc" > "$RC_FILE"

if [ "$rc" -eq 0 ]; then
  printf 'SUCCESS\n' > "$STATUS_FILE"
else
  printf 'FAILED\n' > "$STATUS_FILE"
fi

exit "$rc"
```

这里的关键点是：

```bash
rc=${PIPESTATUS[0]}
```

用了 `tee` 后，普通 `$?` 很容易拿到的是管道最后一个命令 `tee` 的退出状态，而不是 Ansible 的真实退出状态。`PIPESTATUS[0]` 明确保存 Ansible 的退出码。

> `<TOKEN>` 只是占位符。真实 Token、密码、API Key 不要写进 Zwiki、Git 仓库或普通日志。生产环境应使用现有密钥管理方式或至少使用仅 root 可读的独立配置文件。

### Codex 创建 tmux 任务

先创建 Session 和窗口。建议窗口里保留正常交互 Shell，再通过 `send-keys` 启动 Runner。这样任务结束后窗口仍可供人类检查。

```bash
SESSION=cw-agent-full-20260916
TASK_DIR=/root/tasks/agent-install-20260916

# 首个窗口
tmux new-session -d -s "$SESSION" -n manager249

# 其他并行窗口
tmux new-window -d -t "$SESSION" -n manager250
tmux new-window -d -t "$SESSION" -n manager251

# 下发任务
tmux send-keys -t "$SESSION:manager249" "bash $TASK_DIR/run-249.sh" Enter
tmux send-keys -t "$SESSION:manager250" "bash $TASK_DIR/run-250.sh" Enter
tmux send-keys -t "$SESSION:manager251" "bash $TASK_DIR/run-251.sh" Enter
```

自动化执行前先避免重名 Session：

```bash
tmux has-session -t "$SESSION" 2>/dev/null && {
  echo "tmux session already exists: $SESSION"
  exit 1
}
```

不要在不确认旧任务状态的情况下直接复用已有 Session 名并重复下发命令。

### 人类查看

进入任务：

```bash
tmux attach -t cw-agent-full-20260916
```

窗口列表：

```text
Ctrl+b  w
```

或直接切换：

```text
Ctrl+b  0
Ctrl+b  1
Ctrl+b  2
```

因为 Runner 使用 `tee`，窗口内会实时看到 Ansible 输出。

也可以完全不进入 tmux：

```bash
tail -F /root/tasks/agent-install-20260916/output-249.log
```

### Codex 自动检查

Codex 不需要 attach，优先使用非交互命令：

```bash
TASK_DIR=/root/tasks/agent-install-20260916
SESSION=cw-agent-full-20260916

# tmux 是否存在
tmux has-session -t "$SESSION"

# 每个窗口当前进程
tmux list-panes -t "$SESSION" \
  -F 'window=#{window_name} pid=#{pane_pid} cmd=#{pane_current_command} dead=#{pane_dead}'

# 最近的屏幕输出
tmux capture-pane -p -S -100 -t "$SESSION:manager249"

# 永久日志
tail -n 100 "$TASK_DIR/output-249.log"

# 明确状态和退出码
cat "$TASK_DIR/status-249"
cat "$TASK_DIR/rc-249"

# Ansible 是否仍在运行
pgrep -af ansible

# 已产生多少主机结果
find "$TASK_DIR/result-249" -maxdepth 1 -type f | wc -l
```

判断逻辑建议固定为：

```text
status = RUNNING
    ↓
检查 tmux / ansible 进程 / 日志更新时间

status = SUCCESS 且 rc = 0
    ↓
任务正常完成，再做业务验收

status = FAILED 或 rc != 0
    ↓
读取 output.log + result-* 定位失败主机

没有 status/rc 且进程消失
    ↓
按异常中断处理，不要默认成功
```

### 查看日志是否还在增长

一次性查看文件大小和更新时间：

```bash
stat -c '%y %s %n' /root/tasks/agent-install-20260916/output-249.log
```

持续观察：

```bash
watch -n 2 "stat -c '%y %s %n' /root/tasks/agent-install-20260916/output-249.log"
```

如果日志大小持续增加，通常表示任务仍在产生输出；但最终状态仍以进程、`status-*`、`rc-*` 和业务验收为准。

### 为什么同时保留 `tee` 和 `--tree`

两者用途不同，不重复：

| 数据 | 用途 |
|---|---|
| tmux 屏幕 | 人类实时观察、临时接管 |
| `output-249.log` | 完整顺序日志、Codex 检查、事后审计 |
| `result-249/` | Ansible 每台主机独立结果，便于统计失败主机 |
| `status-249` | `RUNNING / SUCCESS / FAILED` 快速判断 |
| `rc-249` | Runner/Ansible 的最终退出码 |

### tmux 和 systemd-run 怎么选

| 场景 | 推荐 |
|---|---|
| 人类需要随时进入现场、Agent 也需要自动检查 | `tmux + tee + 结果目录` |
| 完全无人值守、正式后台批处理、需要 systemd 生命周期管理 | `systemd-run` / systemd service |
| 临时一次性小任务 | `nohup` 可用，但不建议作为批量运维标准方案 |

对于“外部 Codex 通过 SSH 向内网控制机下发 Ansible 长任务”这种场景，优先使用本节的 tmux 标准模式。

## 13. 推荐基础配置

编辑 `~/.tmux.conf`：

```bash
# 鼠标滚动、点击 Pane
set -g mouse on

# 增加历史输出保留行数
set -g history-limit 100000

# 避免程序自动修改窗口名
set -g allow-rename off

# Vim 风格复制模式，可按习惯选择
set -g mode-keys vi
```

加载：

```bash
tmux source-file ~/.tmux.conf
```

## 14. 常见问题

### attach 后窗口一片空白

先看 Pane 当前程序：

```bash
tmux list-panes -t ops \
  -F 'window=#{window_name} pid=#{pane_pid} cmd=#{pane_current_command} dead=#{pane_dead} start=#{pane_start_command}'
```

再抓历史输出：

```bash
tmux capture-pane -p -S -500 -t ops:0
```

如果 Runner 使用：

```bash
command > output.log 2>&1
```

那么 tmux 本身没有日志滚动是正常现象。需要查看 `output.log`，或后续任务改用：

```bash
command 2>&1 | tee -a output.log
```

### `sessions should be nested with care`

说明当前已经在 tmux 内，又尝试执行 `tmux attach` 或 `tmux new`。

确认：

```bash
echo "$TMUX"
```

有输出通常说明当前就在 tmux 中。

### `no sessions`

当前没有 tmux 会话：

```bash
tmux new -s ops
```

### 鼠标滚轮无法查看历史

启用：

```bash
set -g mouse on
```

然后：

```bash
tmux source-file ~/.tmux.conf
```

或使用：

```text
Ctrl+b  [
```

## 15. 运维安全建议

- 长时间安装、升级、迁移、Codex 等任务优先放入 tmux。
- 一个项目或一个批次使用清晰的 Session 名，例如 `xmg-qa2`、`k3s-install`、`cw-agent-full-20260916`。
- 批量任务使用独立任务目录，保存 Runner、日志、状态、退出码和结果。
- 删除会话前先执行 `tmux ls`、`tmux list-panes -a`，确认没有重要任务。
- 不要把 Token、密码、API Key 写入 Zwiki、Git 或公开日志。
- `tee` 之后要显式保留原始命令退出码，避免日志写成功但实际任务失败。
- tmux 不是服务守护器。需要开机自启、异常自动拉起的正式服务使用 systemd。

## 16. 高频命令表

```bash
# 创建
tmux new -s ops

# 查看
tmux ls

# 进入
tmux attach -t ops

# 有则进入，无则创建
tmux new-session -A -s ops

# 指定工作目录
tmux new-session -A -s xmg-qa2 -c /data/dev/xmg-qa2

# 改名
tmux rename-session -t old-name new-name

# 强制接管已 attach 会话
tmux attach -d -t ops

# 查看 Pane
tmux list-panes -a

# 抓取屏幕历史
tmux capture-pane -p -S -100 -t ops:0.0

# 外部发送命令
tmux send-keys -t ops:0.0 'pwd' Enter

# 删除会话
tmux kill-session -t ops
```

高频快捷键：

```text
Ctrl+b d    临时离开
Ctrl+b c    新建窗口
Ctrl+b n    下一个窗口
Ctrl+b p    上一个窗口
Ctrl+b w    窗口列表
Ctrl+b %    左右分屏
Ctrl+b "    上下分屏
Ctrl+b z    放大/恢复 Pane
Ctrl+b [    查看历史输出
Ctrl+b $    会话改名
```
