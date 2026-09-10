# systemd 与日志运维速查

用于 Linux 服务启动失败、反复重启、配置不生效、端口未监听或需要快速查 systemd/journald 日志时。

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

## 常见现象速查

| 现象 | 首查 | 常见方向 |
| --- | --- | --- |
| `failed (Result: exit-code)` | `status` + `journalctl -u` | 程序返回非 0、配置错误 |
| 服务 active 但端口不通 | `ss -lntup` + 应用日志 | 未监听、监听错地址、应用未就绪 |
| 修改 unit 不生效 | `systemctl cat` | 忘记 `daemon-reload`、被 drop-in 覆盖 |
| 服务持续重启 | `NRestarts` + journal | 应用崩溃、Restart 策略 |
| 重启后才出现问题 | `journalctl -b` / `-b -1` | 启动顺序、挂载、网络、配置差异 |

## 深入学习

- systemctl 官方手册：https://www.freedesktop.org/software/systemd/man/latest/systemctl.html
- journalctl 官方手册：https://www.freedesktop.org/software/systemd/man/latest/journalctl.html
- systemd.unit 官方手册：https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
- Linux Kernel 日志与管理文档：https://docs.kernel.org/admin-guide/

## 反馈与修改

本文只保留现场高频操作。某个具体软件有独立配置检查、reload 或日志规则时，应写到该组件自己的速查页。