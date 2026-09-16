# tmux 长任务与远程会话速查

用于 SSH 远程运维、长时间安装部署、日志观察、Codex/Claude Code 等长任务场景。核心目标：**终端断开后任务继续运行，重新登录后可继续接管原会话。**

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

例如给 Codex 项目单独建一个会话：

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

> 不要在长任务运行时直接输入 `exit`，`exit` 会关闭当前 shell；如果这是会话中最后一个 shell，tmux 会话也会结束。

### 重新进入会话

```bash
tmux attach -t xmg-qa2
```

简写：

```bash
tmux a -t xmg-qa2
```

### 有则进入，无则创建

这是远程运维和手机接管最实用的一条：

```bash
tmux new-session -A -s xmg-qa2
```

指定进入后的工作目录：

```bash
tmux new-session -A -s xmg-qa2 -c /data/dev/xmg-qa2
```

## 3. 会话改名

### 当前会话改名

```bash
tmux rename-session xmg-qa2
```

快捷键：

```text
Ctrl+b  $
```

### 在 tmux 外指定会话改名

```bash
tmux rename-session -t old-name new-name
```

例如：

```bash
tmux rename-session -t xmg-qa xmg-qa2
```

## 4. 窗口常用操作

一个 tmux 会话中可以有多个窗口，类似多个终端标签页。

| 操作 | 快捷键 |
|---|---|
| 新建窗口 | `Ctrl+b c` |
| 下一个窗口 | `Ctrl+b n` |
| 上一个窗口 | `Ctrl+b p` |
| 按编号切换 | `Ctrl+b 0` ~ `Ctrl+b 9` |
| 查看窗口列表 | `Ctrl+b w` |
| 当前窗口改名 | `Ctrl+b ,` |
| 关闭当前窗口 | 在 shell 中执行 `exit`，或 `Ctrl+b &` |

查看当前会话和窗口：

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
| 临时放大/恢复当前 Pane | `Ctrl+b z` |

适合一边运行程序、一边看日志：

```text
┌──────────────────┬──────────────────┐
│ Codex / 安装任务  │ tail -f 日志       │
└──────────────────┴──────────────────┘
```

## 6. 查看历史输出

进入复制/滚动模式：

```text
Ctrl+b  [
```

然后可使用：

```text
方向键
PageUp / PageDown
```

退出查看：

```text
q
```

如果是 Windows CMD、Xshell 或手机终端，优先使用 tmux 自己的复制模式，不依赖终端软件是否保留足够多历史记录。

## 7. 基础复制模式

进入复制模式：

```text
Ctrl+b  [
```

默认按键模式下可以移动光标查看历史输出。若习惯 Vim，可在 `~/.tmux.conf` 中加入：

```bash
set -g mode-keys vi
```

重新加载：

```bash
tmux source-file ~/.tmux.conf
```

> 剪贴板行为受 SSH 客户端、终端和系统环境影响。只想快速复制少量内容时，可直接使用终端软件本身的鼠标选择和复制功能。

## 8. 删除会话、窗口和 Pane

### 删除指定会话

```bash
tmux kill-session -t xmg-qa2
```

### 删除除当前会话外的其他会话

先确认：

```bash
tmux ls
```

再执行：

```bash
tmux kill-session -a
```

### 删除指定窗口

```bash
tmux kill-window -t xmg-qa2:1
```

### 删除指定 Pane

先查看 Pane：

```bash
tmux list-panes -a
```

再按目标删除：

```bash
tmux kill-pane -t xmg-qa2:0.1
```

> `kill-session`、`kill-window`、`kill-pane` 会直接终止其中运行的程序。执行前先确认目标。

## 9. 从 tmux 外查看状态

### 查看会话

```bash
tmux ls
```

### 查看窗口

```bash
tmux list-windows -a
```

### 查看 Pane

```bash
tmux list-panes -a
```

### 查看某会话当前运行命令

```bash
tmux list-panes -t xmg-qa2 -F '#S:#I.#P #{pane_current_command}'
```

### 查看更完整信息

```bash
tmux list-panes -t xmg-qa2 -F '#S:#I.#P pid=#{pane_pid} cmd=#{pane_current_command} path=#{pane_current_path}'
```

## 10. 从外部向 tmux 中发送命令

适合自动化或 Agent 在 tmux 外触发已有会话中的操作。

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

> `send-keys` 相当于远程敲键盘。不要对不确定状态的交互程序盲目发送命令，尤其不要用于自动确认高危操作。

## 11. SSH 断线后的恢复流程

SSH、VPN、Wi-Fi 或手机网络断开时，只要 Linux 主机和 tmux 进程仍正常，tmux 内的程序不会因此退出。

重新登录主机后：

```bash
tmux ls
tmux attach -t xmg-qa2
```

如果提示会话已被其他终端 attach，可强制把其他客户端分离后接管：

```bash
tmux attach -d -t xmg-qa2
```

## 12. 手机 / 远程接管 Codex 推荐流程

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

临时离开：

```text
Ctrl+b  d
```

手机重新 SSH 后：

```bash
tmux attach -t xmg-qa2
```

或者直接：

```bash
tmux new-session -A -s xmg-qa2 -c /data/dev/xmg-qa2
```

这样手机锁屏、SSH 客户端退出或网络短时中断，不会直接影响 tmux 内正在运行的 Codex。

> tmux 只能防 SSH 会话中断，不能防主机重启、断电、OOM Kill 或程序自身崩溃。代码和任务状态仍应通过 Git、Codex resume、日志等机制保留。

## 13. 推荐基础配置

编辑：

```bash
vi ~/.tmux.conf
```

常用配置：

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

已有会话中立即生效。

## 14. 常见问题

### `sessions should be nested with care`

说明当前已经在 tmux 内，又尝试执行 `tmux attach` 或 `tmux new`。

确认：

```bash
echo "$TMUX"
```

有输出通常说明当前就在 tmux 中。

正常情况下直接使用当前会话即可；确实需要从当前会话操作其他 tmux，可在 tmux 外执行，或明确指定服务器 socket，避免无意嵌套。

### `no sessions`

当前没有 tmux 会话：

```bash
tmux new -s ops
```

### attach 后显示异常

先查看：

```bash
echo "$TERM"
```

tmux 内常见值为：

```text
screen
screen-256color
tmux-256color
```

不要为了临时修复显示问题随意修改全局 `TERM`。优先确认 SSH 客户端和服务器是否支持对应终端类型。

### 鼠标滚轮无法查看历史输出

启用：

```bash
set -g mouse on
```

然后：

```bash
tmux source-file ~/.tmux.conf
```

也可以始终使用：

```text
Ctrl+b  [
```

进入 tmux 自己的历史查看模式。

## 15. 运维安全建议

- 长时间安装、升级、迁移、Codex 等任务优先放入 tmux。
- 一个项目或一个运维任务使用一个清晰的会话名，例如 `xmg-qa2`、`k3s-install`、`kernel-upgrade`。
- 删除会话前先执行 `tmux ls` 和 `tmux list-panes -a` 确认目标。
- 不要把 tmux 当作服务守护进程。需要开机自启、故障自动拉起的正式服务应使用 `systemd`。
- SSH 断开前优先使用 `Ctrl+b d` 主动 detach，便于确认任务仍在 tmux 中运行。

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

# 强制接管已 attach 的会话
tmux attach -d -t ops

# 查看 Pane
tmux list-panes -a

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
