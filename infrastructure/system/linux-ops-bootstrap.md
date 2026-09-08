# Linux 运维开局常用命令

用于接手、新装或临时排查一台 Linux 主机时快速确认系统、网络、磁盘、进程和 SSH 状态。命令以 Ubuntu 22.04 为基准，多数同样适用于 Debian、RHEL、CentOS、Rocky Linux 等常见发行版。

编写原则：

- 优先使用系统自带命令。
- 一条命令完成一件事，避免把多个独立操作挤在同一行。
- 修改 SSH 前保留当前已登录终端，新终端验证成功后再退出旧会话。
- `iostat`、`iotop`、`nc`、`ethtool`、`rsync` 等可能需要额外安装，统一放在需要时再使用。

## 1. 开局信息采集

接手一台陌生 Linux 主机，先执行：

```bash
hostnamectl
cat /etc/os-release
uname -a
uptime
who
free -h
lscpu
lsblk -f
df -hT
ip -br addr
ip route
ss -lntup
systemctl --failed
```

如果系统没有 `hostnamectl` 或 `systemctl`，通常说明不是 systemd 系统，可使用：

```bash
hostname
uname -a
```

查看最近登录：

```bash
last -n 10
```

## 2. CPU、内存和进程

### 查看实时负载

```bash
top
```

### 查看 CPU 信息

```bash
lscpu
```

### 查看内存

```bash
free -h
```

### 查看系统负载

```bash
uptime
```

### 查看 CPU 占用最高的进程

```bash
ps aux --sort=-%cpu | head
```

### 查看内存占用最高的进程

```bash
ps aux --sort=-%mem | head
```

### 查看指定进程

```bash
ps -fp <PID>
```

```bash
pgrep -af <keyword>
```

### 查看进程树

```bash
ps -ef --forest
```

## 3. 服务和日志

### 查看失败服务

```bash
systemctl --failed
```

### 查看服务状态

Ubuntu / Debian 的 SSH 服务通常叫 `ssh`：

```bash
systemctl status ssh
```

其他服务：

```bash
systemctl status <service>
```

### 启动、停止、重启和重载

```bash
systemctl start <service>
```

```bash
systemctl stop <service>
```

```bash
systemctl restart <service>
```

```bash
systemctl reload <service>
```

### 开机自启

```bash
systemctl enable <service>
```

立即启动并设置开机自启：

```bash
systemctl enable --now <service>
```

### 查看服务日志

```bash
journalctl -u <service> -n 100 --no-pager
```

实时查看：

```bash
journalctl -u <service> -f
```

### 查看本次启动错误

```bash
journalctl -b -p err --no-pager
```

### 查看内核日志

```bash
dmesg -T | tail -n 100
```

## 4. 网络排查

### 查看网卡和 IP

```bash
ip -br addr
```

### 查看路由

```bash
ip route
```

查看访问某个地址实际走哪条路由：

```bash
ip route get 192.168.1.100
```

### 查看 ARP / 邻居表

```bash
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

只看 UDP：

```bash
ss -lnup
```

### 查看已有 TCP 连接

```bash
ss -antp
```

### 测试网络连通性

```bash
ping 192.168.1.100
```

### 使用系统自带 Bash 测试 TCP 端口

```bash
timeout 3 bash -c '</dev/tcp/192.168.1.100/443'
```

查看返回码：

```bash
echo $?
```

返回 `0` 表示 TCP 建连成功。

如果已经安装 `nc`，扫描几个端口更直观：

```bash
nc -zv 192.168.1.100 22 80 443 8080
```

### DNS

查看当前配置：

```bash
cat /etc/resolv.conf
```

使用系统解析器测试：

```bash
getent hosts example.com
```

Ubuntu 22.04 使用 systemd-resolved 时：

```bash
resolvectl status
```

清理 DNS 缓存：

```bash
resolvectl flush-caches
```

重启解析服务：

```bash
systemctl restart systemd-resolved
```

### 查看物理网卡

优先使用 `/sys` 判断真实设备：

```bash
for dev in /sys/class/net/*; do
    if [ -e "$dev/device" ]; then
        basename "$dev"
    fi
done
```

如果已经安装 `ethtool`，查看链路：

```bash
ethtool eno1
```

重点关注：

```text
Speed
Duplex
Link detected
```

## 5. SSH 开启 root 登录

Ubuntu 22.04 使用 OpenSSH 时，推荐使用 `/etc/ssh/sshd_config.d/` 独立配置，不直接反复修改发行版默认文件。

Ubuntu 的 SSH 配置可能存在 `50-cloud-init.conf` 等文件。OpenSSH 对同一个参数通常采用先读到的有效值，因此这里使用排序靠前的 `00-root-login.conf`，并始终通过 `sshd -T` 检查最终实际生效值。

### 5.1 临时允许 root 密码登录

先给 root 设置密码：

```bash
sudo passwd root
```

创建配置目录：

```bash
sudo mkdir -p /etc/ssh/sshd_config.d
```

写入配置：

```bash
printf 'PermitRootLogin yes\nPasswordAuthentication yes\n' | sudo tee /etc/ssh/sshd_config.d/00-root-login.conf
```

检查 SSH 配置语法：

```bash
sudo sshd -t
```

无输出表示语法检查通过。

Ubuntu / Debian 重载 SSH：

```bash
sudo systemctl reload ssh
```

RHEL / Rocky / CentOS 通常使用：

```bash
sudo systemctl reload sshd
```

检查 root 用户最终有效配置：

```bash
sudo sshd -T -C user=root,host=localhost,addr=127.0.0.1 | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '
```

预期至少包含：

```text
permitrootlogin yes
passwordauthentication yes
```

如果最终值仍不符合预期，检查是否存在其他 SSH 配置或 `Match` 规则：

```bash
grep -RniE '^(Include|Match|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AuthenticationMethods|AllowUsers|DenyUsers)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null
```

> root 密码登录风险较高，建议只用于初始化或应急。完成公钥下发并验证后，应改回 root 仅允许密钥登录。

### 5.2 root 改为仅允许密钥登录

写入配置：

```bash
printf 'PermitRootLogin prohibit-password\nPubkeyAuthentication yes\nPasswordAuthentication yes\n' | sudo tee /etc/ssh/sshd_config.d/00-root-login.conf
```

检查语法：

```bash
sudo sshd -t
```

Ubuntu / Debian：

```bash
sudo systemctl reload ssh
```

RHEL / Rocky / CentOS：

```bash
sudo systemctl reload sshd
```

检查实际生效值：

```bash
sudo sshd -T -C user=root,host=localhost,addr=127.0.0.1 | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '
```

此时：

```text
普通用户：允许密码认证
root：禁止密码认证，只允许公钥认证
```

## 6. 给 Linux 添加 SSH 免密登录

### 6.1 本机没有 SSH Key 时先生成

推荐 Ed25519：

```bash
ssh-keygen -t ed25519
```

默认公钥：

```text
~/.ssh/id_ed25519.pub
```

### 6.2 一条命令把公钥写入 Linux

在管理端执行：

```bash
ssh-copy-id root@192.168.1.100
```

首次输入一次目标 Linux 的 root 密码，公钥会自动写入远端：

```text
/root/.ssh/authorized_keys
```

随后直接验证：

```bash
ssh root@192.168.1.100
```

正常情况下不再要求输入目标 Linux 的 root 密码。

### 6.3 指定公钥

如果本机存在多套 SSH Key：

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.1.100
```

### 6.4 macOS

macOS 如果已经存在 `ssh-copy-id`，用法完全相同：

```bash
ssh-copy-id root@192.168.1.100
```

如果提示：

```text
command not found: ssh-copy-id
```

可通过 Homebrew 安装：

```bash
brew install ssh-copy-id
```

安装完成后再执行：

```bash
ssh-copy-id root@192.168.1.100
```

建议先确认下面命令可以免密码登录：

```bash
ssh root@192.168.1.100
```

确认后再将 root SSH 策略改成：

```text
PermitRootLogin prohibit-password
```

## 7. 磁盘、文件系统和 I/O

### 查看磁盘和分区

```bash
lsblk -f
```

### 查看磁盘空间

```bash
df -hT
```

### 查看挂载

```bash
findmnt
```

### 查看根目录一级占用

```bash
sudo du -xhd1 / 2>/dev/null | sort -h
```

继续向大目录下钻：

```bash
sudo du -xhd1 /var 2>/dev/null | sort -h
```

### 查看 inode

```bash
df -ih
```

### 查看 LVM

```bash
pvs
vgs
lvs
```

### 使用系统常见工具观察 I/O

```bash
vmstat 1
```

重点看：

```text
bi    块设备读入
bo    块设备写出
wa    CPU 等待 I/O 的时间占比
```

如果需要更准确地看磁盘 `%util`、`await`：

```bash
sudo apt update
sudo apt install -y sysstat
```

```bash
iostat -xz 1
```

重点关注：

```text
%util   磁盘忙碌率
await   I/O 平均等待时间
aqu-sz  I/O 队列长度
r/s     每秒读请求
w/s     每秒写请求
```

### 查看高 I/O 进程

安装 `iotop`：

```bash
sudo apt install -y iotop
```

实时查看：

```bash
sudo iotop -oPa
```

如果已经安装 `sysstat`，也可以：

```bash
pidstat -d 1
```

查看单个进程累计 I/O：

```bash
cat /proc/<PID>/io
```

## 8. 文件和目录

### 查看文件

```bash
ls -lah
```

### 查找文件

```bash
find /path -type f -name '*.log'
```

### 复制目录

```bash
cp -a source destination
```

### 移动或重命名

```bash
mv source destination
```

### 删除

```bash
rm file
```

删除目录前建议先确认路径：

```bash
rm -r directory
```

### 压缩

```bash
tar -czf backup.tar.gz /path
```

### 解压

```bash
tar -xzf backup.tar.gz
```

### B 合并进 A

如果已经安装 `rsync`，B 中不存在于 A 的文件会复制进去；同路径文件默认按 rsync 规则同步：

```bash
rsync -av B/ A/
```

如果明确要求目标中较新的同路径文件不要被覆盖：

```bash
rsync -avu B/ A/
```

## 9. 用户和权限

### 当前用户

```bash
whoami
```

### 查看 UID、GID 和组

```bash
id
```

### 查看用户信息

```bash
getent passwd <user>
```

### 查看账户密码状态

```bash
passwd -S <user>
```

### 查看 sudo 权限

```bash
sudo -l
```

### 常用权限

```bash
chmod 600 file
```

```bash
chmod 700 directory
```

```bash
chown user:group file
```

## 10. 软件包管理

### Ubuntu / Debian

更新软件索引：

```bash
sudo apt update
```

安装：

```bash
sudo apt install <package>
```

删除：

```bash
sudo apt remove <package>
```

查询已安装软件：

```bash
dpkg -l | grep <keyword>
```

### RHEL / Rocky / CentOS

安装：

```bash
sudo dnf install <package>
```

删除：

```bash
sudo dnf remove <package>
```

查询：

```bash
rpm -qa | grep <keyword>
```

旧版系统可能仍使用：

```bash
sudo yum install <package>
```

## 11. 常见故障的开局顺序

### 系统卡顿

```bash
uptime
free -h
top
vmstat 1
df -hT
```

需要进一步分析磁盘 I/O 时：

```bash
iostat -xz 1
```

```bash
pidstat -d 1
```

### 网络不通

```bash
ip -br addr
ip route
ip route get <目标IP>
ip neigh
ping <网关IP>
ss -lntup
```

### 服务异常

```bash
systemctl status <service>
journalctl -u <service> -n 100 --no-pager
systemctl --failed
journalctl -b -p err --no-pager
```

### 磁盘满

```bash
df -hT
df -ih
lsblk -f
sudo du -xhd1 / 2>/dev/null | sort -h
```

找到大目录后继续逐层执行：

```bash
sudo du -xhd1 /var 2>/dev/null | sort -h
```

## 12. 推荐记住的核心命令

日常运维最常用的一组：

```bash
hostnamectl
cat /etc/os-release
uptime
free -h
top
ps aux --sort=-%cpu | head
ps aux --sort=-%mem | head
lsblk -f
df -hT
ip -br addr
ip route
ip route get <目标IP>
ss -lntup
systemctl --failed
journalctl -b -p err --no-pager
sudo du -xhd1 / 2>/dev/null | sort -h
```
