# 系统

记录操作系统的安装、配置、运维、性能分析、安全加固和故障排查文章。当前内容以 Linux / Ubuntu 为主，同时收录 macOS 等操作系统的实用排障记录。

## 常用速查

- [Linux 运维开局常用命令](linux-ops-bootstrap.md)：接手、新装或临时排查主机时先做基础信息采集。
- [Linux 性能故障快速排查](linux-performance-troubleshooting.md)：Load、CPU、内存、OOM、磁盘 IO、inode 和高占用进程定位。
- [systemd 与日志运维速查](linux-systemd-log-operations.md)：服务启动失败、反复重启、配置不生效和 journald/内核日志排查。
- [Linux 在线/离线软件包管理速查](linux-offline-package-management.md)：系统匹配、依赖下载、离线安装、校验和回退。
- [Linux 磁盘与 LVM 扩容](linux-lvm-disk-expansion.md)：磁盘、分区、PV/VG/LV 扩容和文件系统扩容。

## 专题文章

- [机房内网服务器临时通过 macOS 代理上网](linux-temporary-internet-via-macos-proxy.md)
- [Ubuntu22 内核漏洞安全加固](ubuntu22-kernel-security-hardening.md)
- [macOS 合盖后崩溃重启排查](macos-lid-close-restart.md)

## 收录范围

- 系统安装、启动与内核
- 用户、权限和认证
- systemd、进程与服务
- 磁盘、文件系统、LVM 和 I/O
- 主机网络、DNS 客户端、SSH 和防火墙
- 日志、监控、性能和安全加固
- 软件包管理、Shell 命令与脚本
- 系统故障定位与恢复

## 边界

- 操作系统自身配置与故障归“系统”。
- 路由交换、协议、流量路径和网络设备归“网络”。
- DNS/NTP/Nginx/HAProxy 等通用服务的部署与维护归“基础服务”。

## 文章归类

文章直接存放在本目录；同一主题积累到三篇以上时，再建立对应子目录。例如磁盘类文章可逐步整理到 `storage/`，故障文章可整理到 `troubleshooting/`。

新增文章优先使用[通用技术文章模板](../../templates/technical-article.md)或[故障排查模板](../../templates/troubleshooting.md)。