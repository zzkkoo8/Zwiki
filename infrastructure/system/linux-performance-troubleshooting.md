# Linux 性能故障快速排查

用于 Linux 主机出现“系统卡、Load 高、CPU/内存/IO 异常、磁盘满、进程占用高”时快速定位。常用开局信息采集见 [Linux 运维开局常用命令](linux-ops-bootstrap.md)，磁盘扩容见 [Linux 磁盘与 LVM 扩容](linux-lvm-disk-expansion.md)。

## 快速处理

先按固定顺序判断，不要一上来重启服务或杀进程：

```text
Load → CPU/进程 → 内存/OOM → 磁盘容量/inode → 磁盘 IO → 网络连接 → 服务/内核日志
```

```bash
uptime
top
ps aux --sort=-%cpu | head
ps aux --sort=-%mem | head
free -h
vmstat 1 5
df -hT
df -ih
lsblk -f
systemctl --failed
journalctl -b -p err --no-pager
dmesg -T | tail -n 100
```

如果已安装 `sysstat` / `iotop`：

```bash
iostat -xz 1 5
pidstat -u -r -d 1 5
iotop -oPa
```

## 必须知道

- **Load Average**：过去 1/5/15 分钟可运行或不可中断等待任务的平均数量。Load 高不等于 CPU 一定高，IO 等待也可能把 Load 拉高。
- **iowait**：CPU 等待 IO 完成的时间比例。高 iowait 需要继续看磁盘 `await`、队列和具体进程，不能只凭一个数值定故障。
- **OOM**：内存紧张时 Linux OOM Killer 可能终止进程。必须查内核日志确认，不要仅凭“进程突然没了”判断。
- **RSS / VIRT**：RSS 更接近进程实际驻留物理内存；VIRT 包含映射但未实际占用的虚拟地址空间，不能直接当作真实内存使用量。
- **Swap**：有 swap 使用并不必然异常；持续大量换入换出且伴随响应慢才更值得关注。
- **inode**：文件系统容量还有空间但 inode 用尽时，同样无法创建新文件。
- **`%util` / `await`**：`iostat` 中 `%util` 表示设备忙碌程度，`await` 表示请求平均等待时间。阈值与磁盘类型、并发模型相关，不宜机械套固定告警值。

## 1. Load 高：先判断 CPU 还是 IO

```bash
uptime
cat /proc/loadavg
nproc
vmstat 1 5
```

接着看 CPU 和运行队列：

```bash
top
ps -eo pid,ppid,stat,%cpu,%mem,comm --sort=-%cpu | head -n 20
```

判断：

- CPU 接近满载、热点进程明确：继续看进程线程和应用日志。
- CPU 不高但 Load 很高：重点检查 `vmstat` 的 `b`、`wa`，以及磁盘 IO、NFS/块设备等待。
- Load 只是短时尖峰且业务正常：先观察趋势，不直接处置。

查看某 PID 的线程：

```bash
ps -Lp <PID> -o pid,tid,psr,stat,%cpu,%mem,comm --sort=-%cpu | head -n 30
```

## 2. 内存不足 / OOM

```bash
free -h
vmstat 1 5
ps aux --sort=-%mem | head -n 20
```

查 OOM 证据：

```bash
journalctl -k -b --no-pager | grep -iE 'out of memory|oom|killed process'
dmesg -T | grep -iE 'out of memory|oom|killed process'
```

查看指定进程：

```bash
cat /proc/<PID>/status | grep -E 'VmRSS|VmSize|VmSwap|Threads'
```

如果确认某服务不断涨内存，先保存现场并检查应用日志、资源限制、版本变更。不要把 `kill -9` 当作第一步；强杀不会给进程正常清理资源的机会。

## 3. Swap 异常

```bash
swapon --show
free -h
vmstat 1 10
```

重点观察 `si` / `so`。持续明显换入换出并伴随高延迟时，再定位高内存进程和内存容量是否不足。

## 4. 磁盘满 / inode 满

```bash
df -hT
df -ih
findmnt
```

先定位大目录：

```bash
du -xhd1 / 2>/dev/null | sort -h
du -xhd1 /var 2>/dev/null | sort -h
```

若 `df` 很满但 `du` 对不上，检查“已删除但仍被进程占用”的文件：

```bash
lsof +L1 2>/dev/null
```

`lsof` 可能需要额外安装。确认文件仍被哪个进程持有后，再决定是否通过应用自身轮转、reload/restart 释放句柄。

## 5. 磁盘 IO 高

系统自带工具先看：

```bash
vmstat 1 5
cat /proc/diskstats
```

有 `sysstat` 时：

```bash
iostat -xz 1 5
pidstat -d 1 5
```

有 `iotop` 时：

```bash
iotop -oPa
```

排查顺序：

```text
哪个磁盘忙 → await/队列是否异常 → 哪个进程读写 → 是业务正常流量还是日志/备份/异常循环 → 查应用日志
```

不要通过写 `/proc/sys/vm/drop_caches` 来“修复 IO 高”；这会改变缓存状态，通常只适合受控测试，不是生产故障常规处理手段。

## 6. 单进程 CPU 或 IO 异常

```bash
ps -fp <PID>
cat /proc/<PID>/status
cat /proc/<PID>/io
ls -l /proc/<PID>/fd | head
```

如果安装了 `strace`，仅在确认性能影响可接受时短时观察：

```bash
strace -p <PID> -tt -T
```

`strace` 会增加目标进程开销，高负载生产环境应谨慎。

## 7. 性能问题可能其实是网络问题

```bash
ss -s
ss -antp
ip -s link
```

如果表现为“进程 CPU 不高但请求很慢”，继续使用 [网络故障快速排查](../network/network-troubleshooting.md) 检查路由、端口、重传和上游服务。

## 8. 最后看服务和内核日志

```bash
systemctl --failed
journalctl -b -p warning --no-pager
journalctl -u <service> --since '-30 min' --no-pager
dmesg -T | tail -n 200
```

服务类问题继续看 [systemd 与日志运维速查](linux-systemd-log-operations.md)。

## 常见现象速查

| 现象 | 优先检查 | 常见方向 |
| --- | --- | --- |
| Load 高、CPU 也高 | `top`、`ps --sort=-%cpu` | 计算密集、死循环、突发流量 |
| Load 高、CPU 不高 | `vmstat`、`iostat` | IO 等待、NFS/块设备阻塞 |
| 进程突然消失 | `journalctl -k`、`dmesg` | OOM、崩溃、人工/服务管理器终止 |
| 磁盘有空间但不能写文件 | `df -ih` | inode 耗尽 |
| `df` 与 `du` 差异很大 | `lsof +L1` | 删除文件仍被进程打开 |
| 系统间歇卡顿 | `vmstat`、`iostat`、日志 | swap 抖动、IO 尖峰、内核/硬件异常 |

## 深入学习

- Linux Kernel `/proc` 文档：https://docs.kernel.org/filesystems/proc.html
- Linux Kernel 内存管理文档：https://docs.kernel.org/admin-guide/mm/index.html
- Red Hat RHEL 9 性能监控与管理：https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/
- `sysstat` 项目：https://github.com/sysstat/sysstat

## 反馈与修改

发现命令、判断方法或链接失效时，通过 Zwiki 的统一反馈入口提交；新增专项场景优先补充本文，避免重复创建性能命令大全。