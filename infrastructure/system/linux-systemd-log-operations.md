# systemd 与日志运维速查

用于 Linux 服务启动失败、反复重启、配置不生效、端口未监听，或需要通过 systemd 托管非交互长任务并查看日志时。

## 快速处理

先看状态和失败原因，再改配置或重启：

```bash
systemctl status <service> --no-pager
systemctl is-active <service>
systemctl is-enabled <service>
systemctl --failed
journalctl -u <service> -n 100 --no-pager
journalctl -u <service> --since '-30 min' --no-pager
journalctl -b -p err --no-pager
dmesg -T | tail -n 100
```

标准顺序：

```text
服务状态 → unit/启动命令 → 应用配置 → 端口冲突 → 权限/目录 → 依赖服务 → 系统资源/内核日志
```

## 必须知道

- **unit**：systemd 管理对象，常见是 `.service`、`.socket`、`.timer`、`.mount`。
- **active / failed**：表示 systemd 看到的当前运行状态；`active` 不等于业务一定可用，还要检查监听端口和业务探测。
- **enabled**：表示是否配置为随相应 target 自动启动，与当前是否正在运行不是同一件事。
- **journal**：systemd-journald 收集的结构化日志，可按服务、启动批次和时间过滤。
- **reload 与 restart**：reload 让支持它的应用重载配置，通常对连接影响更小；restart 会停止并重新启动进程，可能造成业务中断。
- **systemd-run**：临时创建 transient unit 托管命令，适合 Ansible、安装、升级、扫描、迁移等非交互长任务；SSH 断线后任务仍由 systemd 管理。

## 1. 查看服务状态

```bash
systemctl status <service> --no-pager
systemctl is-active <service>
systemctl is-enabled <service>
systemctl show <service> -p ActiveState,SubState,MainPID,ExecMainStatus,Result
```

查看失败服务：

```bash
systemctl --failed
```

查看 unit 实际内容和覆盖配置：

```bash
systemctl cat <service>
systemctl show <service> -p FragmentPath,DropInPaths,ExecStart,EnvironmentFiles
```

如果怀疑名字不对：

```bash
systemctl list-unit-files | grep -i <keyword>
systemctl list-units --type=service --all | grep -i <keyword>
```

## 2. 服务启动失败

先执行：

```bash
systemctl status <service> --no-pager
journalctl -u <service> -b -n 200 --no-pager
```

重点看：

- `ExecStart` 命令或程序不存在；
- 配置语法错误；
- 端口已被占用；
- 用户/组、目录、文件权限错误；
- 环境变量或依赖文件缺失；
- 依赖服务未启动；
- OOM、磁盘满、只读文件系统等系统问题。

查看启动命令：

```bash
systemctl show <service> -p ExecStart
systemctl cat <service>
```

查看端口是否冲突：

```bash
ss -lntup
```

查看服务运行用户：

```bash
systemctl show <service> -p User,Group
```

## 3. journalctl 高频用法

指定服务最近日志：

```bash
journalctl -u <service> -n 100 --no-pager
```

当前启动批次：

```bash
journalctl -u <service> -b --no-pager
```

最近 30 分钟：

```bash
journalctl -u <service> --since '-30 min' --no-pager
```

指定时间段：

```bash
journalctl -u <service> --since '2026-09-10 20:00:00' --until '2026-09-10 21:00:00' --no-pager
```

实时跟踪：

```bash
journalctl -u <service> -f
```

本次启动错误：

```bash
journalctl -b -p err --no-pager
```

查看上一次启动：

```bash
journalctl -b -1 --no-pager
```

如果历史启动日志不存在，检查 journald 是否启用了持久化存储。

## 4. 内核日志

```bash
dmesg -T | tail -n 200
journalctl -k -b --no-pager
```

常见检索：

```bash
journalctl -k -b --no-pager | grep -iE 'oom|out of memory|I/O error|ext4|xfs|nvme|reset|link is down|segfault'
```

内核问题同时参考 [Linux 性能故障快速排查](linux-performance-troubleshooting.md)。

## 5. 修改配置后的安全生效顺序

### 应用自身支持配置检查时

先备份本次要改的配置文件，然后运行应用自己的检查命令。例如 Nginx：

```bash
nginx -t
```

再确认服务支持 reload：

```bash
systemctl cat <service>
```

优先：

```bash
systemctl reload <service>
```

随后立即验证：

```bash
systemctl status <service> --no-pager
journalctl -u <service> --since '-5 min' --no-pager
ss -lntup
```

### 必须 restart 时

`restart` 会终止旧进程并重新启动，可能中断连接。先确认业务窗口、集群冗余和回退配置，再执行：

```bash
systemctl restart <service>
```

验证：

```bash
systemctl is-active <service>
systemctl status <service> --no-pager
journalctl -u <service> --since '-5 min' --no-pager
```

## 6. 修改 unit 文件后不生效

如果修改了 `/etc/systemd/system/*.service` 或 drop-in：

```bash
systemd-analyze verify /etc/systemd/system/<service>.service
systemctl daemon-reload
systemctl cat <service>
```

`daemon-reload` 只让 systemd 重新读取 unit 定义，不会自动重启业务进程。是否需要 reload/restart 取决于具体服务。

创建或编辑 drop-in：

```bash
systemctl edit <service>
```

查看最终合并后的 unit：

```bash
systemctl cat <service>
```

## 7. 服务反复自动重启

```bash
systemctl status <service> --no-pager
systemctl show <service> -p Restart,NRestarts,StartLimitBurst,StartLimitIntervalUSec
journalctl -u <service> -b --no-pager
```

重点判断是应用自身崩溃，还是 unit 配置了 `Restart=` 后被 systemd 拉起。不要只看到“现在是 active”就忽略前面的失败日志。

## 8. 启动很慢或依赖异常

查看依赖关系：

```bash
systemctl list-dependencies <service>
```

查看本次系统启动耗时：

```bash
systemd-analyze
systemd-analyze blame | head -n 30
systemd-analyze critical-chain
```

## 9. 使用 systemd-run 托管非交互长任务

### 适用场景

适合外部运维机或 Codex 通过 SSH 向 Linux 控制机下发的非交互任务：

```text
外部运维机 / Codex
        │
        │ SSH：只负责下发和检查
        ▼
Linux 控制机
        │
        └─ systemd-run
              └─ Ansible / 安装 / 升级 / 扫描 / 迁移脚本
```

SSH、VPN 或终端断开后，任务继续由 PID 1 管理。人类和 Codex 都通过 `systemctl`、`journalctl` 查询状态和日志，不需要重新进入原 SSH 会话。

如果任务需要人类重新进入终端继续输入命令，请使用 [tmux 长任务与远程会话速查](tmux-operations.md)，不要用 `systemd-run` 代替交互终端。

### 最小可用案例

准备脚本：

```bash
/root/tasks/agent-install-20260916/run-249.sh
```

启动：

```bash
systemd-run \
  --unit=agent-install-249 \
  --description='Agent install batch 249' \
  --remain-after-exit \
  /bin/bash /root/tasks/agent-install-20260916/run-249.sh
```

这里使用默认的 **service 模式**。需要防 SSH 断线时不要改成 `systemd-run --scope`。

`--remain-after-exit` 用于任务成功结束后仍保留 unit 状态，方便人类或 Codex 查看 `ExecMainStatus`。确认结果后再清理。

### 人类查看任务状态

```bash
systemctl status agent-install-249 --no-pager
```

更适合脚本和 Codex 的结构化查询：

```bash
systemctl show agent-install-249 \
  -p ActiveState \
  -p SubState \
  -p Result \
  -p MainPID \
  -p ExecMainCode \
  -p ExecMainStatus
```

常见状态：

```text
ActiveState=active
SubState=running
→ 任务仍在执行

ActiveState=active
SubState=exited
Result=success
ExecMainStatus=0
→ 任务命令已成功结束；仍需做业务验收

ActiveState=failed
Result=exit-code
ExecMainStatus!=0
→ 任务失败，立即查看日志
```

`systemctl status` 显示的“成功”只表示命令退出状态成功，不等于业务一定正常。例如 Agent 安装结束后仍应检查 Agent 是否上线，Kubernetes 变更后仍应检查 Pod/健康接口。

### 人类实时看日志

实时跟踪：

```bash
journalctl -fu agent-install-249
```

最近 100 行：

```bash
journalctl -u agent-install-249 -n 100 --no-pager
```

本次任务全部日志：

```bash
journalctl -u agent-install-249 --no-pager
```

因此一般不再需要单独使用：

```bash
> output.log 2>&1
```

journald 已自动收集 stdout/stderr。如果现场规范要求额外保留普通日志文件，可以在 Runner 中额外使用 `tee`，但要注意管道退出码。

### Ansible + --tree 标准案例

建议每次任务建立独立目录：

```text
/root/tasks/agent-install-20260916/
├── run-249.sh
├── hosts-249.txt
└── result-249/
```

Runner：

```bash
#!/usr/bin/env bash
set -eu

TASK_DIR=/root/tasks/agent-install-20260916
RESULT_DIR="$TASK_DIR/result-249"
mkdir -p "$RESULT_DIR"

exec /usr/bin/ansible all \
  --inventory /root/ansible-root/inventory.yml \
  --limit @"$TASK_DIR/hosts-249.txt" \
  --module-name raw \
  --args 'curl -kfsSL -g http://10.7.216.249:80/api/agent/script | bash -s -- --installer_work_dir /tmp --token <TOKEN>' \
  --forks 10 \
  --one-line \
  --tree "$RESULT_DIR"
```

这里使用 `exec`，让 Runner Shell 最终被 Ansible 进程替换，systemd 能直接记录 Ansible 的退出状态。

`--tree` 继续负责保存每台目标主机的独立结果：

```bash
find /root/tasks/agent-install-20260916/result-249 \
  -maxdepth 1 -type f | wc -l
```

> `<TOKEN>` 只是文档占位符。真实 Token、密码和 API Key 不要写入 Zwiki、Git 或普通日志。命令行参数也可能被本机 `ps` 等工具看到，生产环境应优先采用现有密钥管理方案或最小权限的安全注入方式。

### Codex 自动检查

Codex 不需要打开交互终端，直接执行：

```bash
UNIT=agent-install-249
TASK_DIR=/root/tasks/agent-install-20260916

# 状态和退出码
systemctl show "$UNIT" \
  -p ActiveState \
  -p SubState \
  -p Result \
  -p MainPID \
  -p ExecMainStatus

# 最近日志
journalctl -u "$UNIT" -n 100 --no-pager

# Ansible 每台主机结果数量
find "$TASK_DIR/result-249" -maxdepth 1 -type f | wc -l
```

推荐固定判断逻辑：

```text
SubState=running
→ 任务执行中，继续检查日志和结果数量

SubState=exited + Result=success + ExecMainStatus=0
→ 命令执行完成，再进行业务验收

ActiveState=failed / Result!=success / ExecMainStatus!=0
→ 任务失败，检查 journal + result-*/
```

不要仅凭“Ansible 进程不存在”判断成功；进程消失也可能是失败退出。

### 同时启动多个批次

每个批次使用唯一 unit 名：

```bash
systemd-run --unit=agent-install-249 --remain-after-exit /bin/bash /root/tasks/agent-install-20260916/run-249.sh
systemd-run --unit=agent-install-250 --remain-after-exit /bin/bash /root/tasks/agent-install-20260916/run-250.sh
systemd-run --unit=agent-install-251 --remain-after-exit /bin/bash /root/tasks/agent-install-20260916/run-251.sh
```

快速查看：

```bash
systemctl list-units 'agent-install-*' --all
```

批量看最近日志时逐个指定 unit，避免把多个任务日志混在一起。

### 停止任务

```bash
systemctl stop agent-install-249
```

停止属于中断操作。执行前确认任务是否允许中止，以及脚本是否存在升级一半、配置写入一半等风险。

### 任务完成后的清理

成功任务因为使用了 `--remain-after-exit`，检查完成后执行：

```bash
systemctl stop agent-install-249
```

失败任务检查完成后可清除 failed 状态：

```bash
systemctl reset-failed agent-install-249
```

transient unit 被回收后，历史 journal 是否长期保留取决于 journald 的存储与轮转策略。需要长期审计时，应确认 journald 已持久化，或将关键结果同步到任务目录/集中日志平台。

### `--collect` 什么时候用

如果只关心任务运行过程和 journal，不需要在任务结束后继续通过 `systemctl show` 保留最终 unit 状态，可以使用：

```bash
systemd-run \
  --unit=agent-install-249 \
  --collect \
  /bin/bash /root/tasks/agent-install-20260916/run-249.sh
```

`--collect` 会更积极地回收已结束的 transient unit。对于“Codex 稍后回来还要读取最终 `ExecMainStatus`”的场景，优先使用前面的 `--remain-after-exit` 模式，不要同时依赖 `--collect` 保存最终状态。

### systemd-run 与 tmux 如何选择

| 场景 | 推荐方式 |
| --- | --- |
| Ansible 批处理、安装、升级、扫描、迁移 | `systemd-run + journalctl + --tree` |
| Codex 自动下发非交互长任务 | `systemd-run` |
| 人类只需要看进度、日志、退出状态 | `systemd-run` |
| Codex / Claude Code 本身的交互会话 | `tmux` |
| 人类需要重新进入继续输入命令 | `tmux` |
| 人类与 Codex 共用交互式长任务 | `tmux + tee` |
| 临时简单后台命令 | `nohup` 可用，但不作为标准方案 |

统一原则：

```text
非交互自动化长任务
→ systemd-run + journalctl (+ Ansible --tree)

交互式长任务
→ tmux (+ tee / 独立日志)
```

## 常见现象速查

| 现象 | 首查 | 常见方向 |
| --- | --- | --- |
| `failed (Result: exit-code)` | `status` + `journalctl -u` | 程序返回非 0、配置错误 |
| 服务 active 但端口不通 | `ss -lntup` + 应用日志 | 未监听、监听错地址、应用未就绪 |
| 修改 unit 不生效 | `systemctl cat` | 忘记 `daemon-reload`、被 drop-in 覆盖 |
| 服务持续重启 | `NRestarts` + journal | 应用崩溃、Restart 策略 |
| 重启后才出现问题 | `journalctl -b` / `-b -1` | 启动顺序、挂载、网络、配置差异 |
| `systemd-run` 任务看不到 | `systemctl status <unit>` | unit 名写错、已被回收、用了 `--collect` |
| SSH 断开但任务要继续 | `systemd-run` service 模式 | 不要使用 `--scope` 代替 transient service |

## 深入学习

- systemctl 官方手册：https://www.freedesktop.org/software/systemd/man/latest/systemctl.html
- journalctl 官方手册：https://www.freedesktop.org/software/systemd/man/latest/journalctl.html
- systemd-run 官方手册：https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html
- systemd.unit 官方手册：https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
- Linux Kernel 日志与管理文档：https://docs.kernel.org/admin-guide/

## 反馈与修改

本文只保留现场高频操作。某个具体软件有独立配置检查、reload 或日志规则时，应写到该组件自己的速查页。