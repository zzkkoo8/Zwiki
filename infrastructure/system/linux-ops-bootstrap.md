# Linux 运维开局速查

接手、新装或临时排查 Linux 主机时，先用最少命令确认：**系统是谁、资源够不够、网络通不通、服务有没有挂、磁盘是否异常。本指南只为快速检查主机情况。**

## 1. 先跑这一组

```bash
hostnamectl
cat /etc/os-release
uname -r
uptime
free -h
lsblk -f
df -hT
ip -br addr
ip route
ss -lntup
systemctl --failed
```

如果只想快速看重点：

```bash
uptime
free -h
df -hT
ip -br addr
ip route
systemctl --failed
```

### 一键采集当前状态和部署业务

需要快速摸清一台陌生 Linux 主机时，优先使用附件脚本生成一份 Markdown 报告：

- [collect-linux-host-info.sh](assets/linux-ops-bootstrap/collect-linux-host-info.sh)

生产机建议先下载、做 Bash 语法检查，再执行：

```bash
curl -fsSL https://raw.githubusercontent.com/zzkkoo8/Zwiki/main/infrastructure/system/assets/linux-ops-bootstrap/collect-linux-host-info.sh -o /tmp/collect-linux-host-info.sh \
  && bash -n /tmp/collect-linux-host-info.sh \
  && sudo bash /tmp/collect-linux-host-info.sh \
  | tee "linux-host-info-$(hostname)-$(date +%F-%H%M).md"
```

没有 `sudo` 权限时直接用当前用户执行即可，但监听端口、容器、LVM 等信息可能不完整。

脚本默认只读，主要采集：

- 系统、内核、运行时间和负载；
- CPU、内存、磁盘、文件系统和 LVM；
- 网卡、路由、DNS、监听端口；
- 失败服务、正在运行的 systemd 服务；
- CPU / 内存占用最高的进程；
- Docker、Podman、nerdctl、CRI 容器；
- K3s / Kubernetes 节点与 Pod、Helm Release；
- Nginx、HAProxy、Redis、MySQL、PostgreSQL、Java、Python、Go 等常见组件版本。

这些信息通常足够快速判断**主机当前状态、容器/集群环境以及部署了哪些业务**。脚本不会主动提权，也不会读取密码、Token、Cookie、私钥、进程环境变量、Kubernetes Secret、业务配置正文或原始日志正文。

> 采集报告会包含主机名、IP、端口、服务名、容器名和镜像名。发送给外部人员或 AI 前先检查并脱敏。

## 2. CPU、内存、进程

实时：

```bash
top
```

CPU / 内存最高的进程：

```bash
ps aux --sort=-%cpu | head
ps aux --sort=-%mem | head
```

查进程：

```bash
pgrep -af <keyword>
ps -fp <PID>
```

如果已经出现高负载、OOM、磁盘 I/O 等问题，直接看 [Linux 性能故障快速排查](linux-performance-troubleshooting.md)，不要在本文继续展开性能原理。

## 3. 服务和日志

失败服务：

```bash
systemctl --failed
```

指定服务：

```bash
systemctl status <service> --no-pager
journalctl -u <service> -n 100 --no-pager
```

最近系统错误：

```bash
journalctl -b -p err --no-pager
dmesg -T | tail -n 100
```

常用变更：

```bash
systemctl restart <service>
systemctl reload <service>
systemctl enable --now <service>
```

更完整的 systemd / journalctl 操作见 [systemd 与日志运维速查](linux-systemd-log-operations.md)。

## 4. 网络、路由、端口

地址和路由：

```bash
ip -br addr
ip route
```

确认访问某个 IP 实际走哪条路由：

```bash
ip route get 192.168.1.100
```

监听端口：

```bash
ss -lntup
```

不安装额外工具测试 TCP 端口：

```bash
timeout 3 bash -c '</dev/tcp/192.168.1.100/443'
echo $?
```

返回 `0` 表示 TCP 建连成功。

已安装 `nc` 时：

```bash
nc -zv 192.168.1.100 22 80 443
```

DNS：

```bash
cat /etc/resolv.conf
getent hosts example.com
```

网络问题继续看 [网络故障快速排查](../network/network-troubleshooting.md)。

## 5. 磁盘、挂载、LVM

```bash
lsblk -f
df -hT
df -ih
findmnt
pvs
vgs
lvs
```

找一级大目录：

```bash
sudo du -xhd1 / 2>/dev/null | sort -h
```

继续下钻：

```bash
sudo du -xhd1 /var 2>/dev/null | sort -h
```

需要扩容直接看 [Linux 磁盘与 LVM 扩容](linux-lvm-disk-expansion.md)。

## 6. SSH root 登录：应急最短方案

> 允许 root 密码登录风险较高，只建议初始化或应急。修改前保留当前已登录终端，新终端验证成功后再退出旧连接。

先设置 root 密码：

```bash
sudo passwd root
```

Ubuntu / Debian 常用方式：

```bash
sudo mkdir -p /etc/ssh/sshd_config.d
printf 'PermitRootLogin yes\nPasswordAuthentication yes\n' | sudo tee /etc/ssh/sshd_config.d/00-root-login.conf
sudo sshd -t
sudo systemctl reload ssh
```

RHEL / Rocky / CentOS 重载服务通常是：

```bash
sudo systemctl reload sshd
```

确认最终生效值：

```bash
sudo sshd -T -C user=root,host=localhost,addr=127.0.0.1 | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '
```

公钥已经验证后，建议把 root 改成只允许密钥：

```bash
printf 'PermitRootLogin prohibit-password\nPubkeyAuthentication yes\n' | sudo tee /etc/ssh/sshd_config.d/00-root-login.conf
sudo sshd -t
```

再 reload SSH 服务。

## 7. SSH 免密：最常用一条命令

管理端没有 Key 时：

```bash
ssh-keygen -t ed25519
```

下发：

```bash
ssh-copy-id root@192.168.1.100
```

验证：

```bash
ssh root@192.168.1.100
```

macOS 没有 `ssh-copy-id` 时：

```bash
brew install ssh-copy-id
```

需要批量管理多台 Linux，直接看 [Linux 批量运维速查](linux-batch-operations.md)。

## 8. 文件、用户、软件：只记高频

文件：

```bash
ls -lah
find /path -type f -name '*.log'
cp -a source destination
mv source destination
tar -czf backup.tar.gz /path
tar -xzf backup.tar.gz
```

用户和权限：

```bash
whoami
id
getent passwd <user>
sudo -l
chmod 600 <file>
chown <user>:<group> <file>
```

软件安装：

```bash
# Ubuntu / Debian
sudo apt update
sudo apt install <package>

# RHEL / Rocky / CentOS / 部分麒麟
sudo dnf install <package>
```

内网离线安装不要在这里展开，直接看 [Linux 离线软件安装速查](linux-offline-package-management.md)。

## 9. 新主机建议固定检查顺序

```
系统版本
  ↓
CPU / 内存 / Load
  ↓
磁盘 / inode / LVM
  ↓
IP / 路由 / DNS / 端口
  ↓
失败服务 / 日志
  ↓
SSH 与运维账号
  ↓
再开始安装或变更
```

## 官方资料

* iproute2：https://www.kernel.org/pub/linux/utils/net/iproute2/
* systemd：https://systemd.io/
* OpenSSH：https://www.openssh.com/manual.html
* Ubuntu Server：https://documentation.ubuntu.com/server/
* Red Hat Enterprise Linux：https://docs.redhat.com/en/documentation/red\_hat\_enterprise\_linux/
