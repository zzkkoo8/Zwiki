# 系统

记录操作系统常见运维、排障和快速实施方案。优先给可直接执行的命令；完整原理和官方手册只保留链接。

## 常用速查

- [Linux 运维开局速查](linux-ops-bootstrap.md)：接手或排查主机时先确认系统、资源、网络、磁盘和失败服务。
- [Linux 批量运维速查](linux-batch-operations.md)：SSH、Ansible、密码登录、Python 引导和分批执行。
- [tmux 长任务与远程会话速查](tmux-operations.md)：SSH 断线保活、会话恢复，以及人类 + Codex 共用的 `tmux + tee + --tree` 长任务标准模式。
- [Linux 性能故障快速排查](linux-performance-troubleshooting.md)：CPU、内存、Load、磁盘 IO 和高占用进程定位。
- [systemd 与日志运维速查](linux-systemd-log-operations.md)：服务状态、启动失败和日志查看。
- [Linux 离线软件安装速查](linux-offline-package-management.md)：RPM/DEB、依赖、Python 和 pip 包离线下载与安装。
- [Linux 磁盘与 LVM 扩容](linux-lvm-disk-expansion.md)：磁盘、分区、LVM 和文件系统扩容。

## 专题文章

- [机房内网服务器临时通过 macOS 代理上网](linux-temporary-internet-via-macos-proxy.md)
- [Ubuntu22 内核漏洞安全加固](ubuntu22-kernel-security-hardening.md)
- [macOS 合盖后崩溃重启排查](macos-lid-close-restart.md)

## 收录边界

- 操作系统自身配置、SSH、软件包、日志、磁盘、性能和安全归“系统”。
- 路由、协议、流量路径和网络设备归“网络”。
- Nginx、DNS、NTP、HAProxy 等通用服务归“基础服务”。
- Docker、Kubernetes、K3s 归“容器与云原生”。

新增文章优先使用[通用技术文章模板](../../templates/technical-article.md)或[故障排查模板](../../templates/troubleshooting.md)。
