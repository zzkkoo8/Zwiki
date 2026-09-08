# Linux 运维开局常用命令

用于接手、新装或临时排查一台 Linux 主机时快速确认系统、网络、磁盘、进程和 SSH 状态。命令以 Ubuntu 22.04 为基准，多数适用于 Debian、RHEL、CentOS、Rocky Linux 等常见发行版。

> 涉及 SSH 配置修改时，建议保留当前已登录终端，在新终端验证成功后再退出旧会话，避免配置错误导致远程失联。

## 1. 开局信息采集

```bash
hostnamectl
uname -a
cat /etc/os-release
uptime
who
last -n 10
free -h
lscpu
lsblk -f
df -hT
ip -br addr
ip route
```

快速看 CPU、内存和负载：

```bash
top
```

查看占用最高的进程：

```bash
ps aux --sort=-%cpu | head
ps aux --sort=-%mem | head
```

## 2. 网络排查

### 查看 IP、路由和邻居

```bash
ip -br addr
ip route
ip neigh
```

### 查看监听端口

```bash
ss -lntup
```

只看 TCP：

```bash
ss -lntp
```

### 快速探测目标端口

```bash
nc -zv 192.168.1.100 22 80 443 8080
```

没有 `nc` 时：

```bash
timeout 3 bash -c '</dev/tcp/192.168.1.100/443' && echo open || echo closed
```

### DNS

```bash
cat /etc/resolv.conf
getent hosts example.com
```

Ubuntu 使用 systemd-resolved 时：

```bash
resolvectl status
resolvectl flush-caches
systemctl restart systemd-resolved
```

### 查看物理网卡

```bash
for i in /sys/class/net/*; do [ -e "$i/device" ] && basename "$i"; done
```

查看链路速率和状态：

```bash
ethtool eno1
```

重点关注：

```text
Speed
Duplex
Link detected
```

## 3. 磁盘、目录和 I/O

### 磁盘与挂载

```bash
lsblk -f
df -hT
mount | column -t
```

### 找大目录

查看根目录一级占用：

```bash
sudo du -xhd1 / 2>/dev/null | sort -h
```

继续向大目录下钻：

```bash
sudo du -xhd1 /var 2>/dev/null | sort -h
```

### 查看磁盘 I/O

安装工具：

```bash
sudo apt update && sudo apt install -y sysstat iotop
```

查看磁盘利用率：

```bash
iostat -xz 1
```

重点关注：

```text
%util   磁盘忙碌率
await   I/O 平均等待时间
r/s     每秒读请求
w/s     每秒写请求
aqu-sz  I/O 队列长度
```

查看高 I/O 进程：

```bash
sudo iotop -oPa
```

或：

```bash
pidstat -d 1
```

## 4. 服务、进程和日志

### systemd 服务

```bash
systemctl --failed
systemctl status ssh
systemctl status <service>
systemctl restart <service>
systemctl enable --now <service>
```

### 查看进程

```bash
ps -ef
pgrep -af <keyword>
```

### 查看日志

```bash
journalctl -xe
journalctl -u <service> -n 100 --no-pager
journalctl -u <service> -f
```

查看本次启动错误：

```bash
journalctl -b -p err --no-pager
```

内核日志：

```bash
dmesg -T | tail -n 100
```

## 5. SSH 开启 root 登录

Ubuntu 22.04 使用 OpenSSH 时，推荐通过独立 drop-in 配置，不直接反复修改发行版默认文件。

### 临时允许 root 密码登录

先给 root 设置密码：

```bash
sudo passwd root
```

写入配置：

```bash
sudo mkdir -p /etc/ssh/sshd_config.d
printf 'PermitRootLogin yes\nPasswordAuthentication yes\n' | sudo tee /etc/ssh/sshd_config.d/99-root-login.conf
```

检查配置：

```bash
sudo sshd -t
```

无输出代表语法检查通过，然后重载：

```bash
sudo systemctl reload ssh
```

确认最终生效值：

```bash
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '
```

预期包含：

```text
permitrootlogin yes
passwordauthentication yes
```

> root 密码登录风险较高。建议只用于初始化或应急，完成公钥下发并验证后改为仅允许密钥登录。

### root 改为仅允许密钥登录

```bash
printf 'PermitRootLogin prohibit-password\nPubkeyAuthentication yes\nPasswordAuthentication yes\n' | sudo tee /etc/ssh/sshd_config.d/99-root-login.conf
sudo sshd -t && sudo systemctl reload ssh
```

此时普通用户仍可使用密码认证，但 root 只能使用公钥认证。

检查：

```bash
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '
```

## 6. macOS 一键给 Linux 添加免密码 SSH

### 第一次没有 SSH Key

macOS 生成 Ed25519 密钥：

```bash
ssh-keygen -t ed25519
```

一路回车即可。公钥默认位置：

```text
~/.ssh/id_ed25519.pub
```

### macOS 原生命令，一行写入 Linux

macOS 不依赖 `ssh-copy-id`，直接使用系统自带的 `ssh`：

```bash
cat ~/.ssh/id_ed25519.pub | ssh root@192.168.1.100 'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; cat >> ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys'
```

首次会要求输入一次 Linux root 密码。

随后验证：

```bash
ssh root@192.168.1.100
```

正常情况下不再要求输入远端 root 密码。

如果希望从“无密钥”到“完成下发”一条命令执行：

```bash
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519; cat ~/.ssh/id_ed25519.pub | ssh root@192.168.1.100 'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; cat >> ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys'
```

> 建议先确认公钥登录成功，再把 root SSH 策略改成 `PermitRootLogin prohibit-password`。

## 7. 文件和目录常用操作

查看：

```bash
ls -lah
find /path -type f -name '*.log'
```

复制：

```bash
cp -a source destination
```

移动：

```bash
mv source destination
```

B 合并进 A，同路径文件保留修改时间更新的一份：

```bash
rsync -avu B/ A/
```

压缩：

```bash
tar -czf backup.tar.gz /path
```

解压：

```bash
tar -xzf backup.tar.gz
```

## 8. 用户和权限

```bash
id
whoami
getent passwd <user>
passwd -S <user>
```

查看 sudo 权限：

```bash
sudo -l
```

常用权限：

```bash
chmod 600 file
chmod 700 directory
chown user:group file
```

## 9. 软件包

Ubuntu / Debian：

```bash
apt update
apt install <package>
apt remove <package>
dpkg -l | grep <keyword>
```

RHEL / Rocky / CentOS：

```bash
dnf install <package>
dnf remove <package>
rpm -qa | grep <keyword>
```

旧版系统可能使用：

```bash
yum install <package>
```

## 10. 常用开局顺序

接手一台陌生 Linux 主机时，可以按以下顺序快速检查：

```bash
hostnamectl
cat /etc/os-release
uptime
free -h
lscpu
lsblk -f
df -hT
ip -br addr
ip route
ss -lntup
systemctl --failed
sudo du -xhd1 / 2>/dev/null | sort -h
```

如果机器存在性能问题，再追加：

```bash
top
iostat -xz 1
pidstat -d 1
journalctl -b -p err --no-pager
```
