# 产品运行底座：K3s 集群部署手册

本文整理产品集群版运行底座的 K3s 部署条件、部署前检查、chroot + Ansible 准备、数据盘要求、安装参数和安装后验收标准。

> 本文依据现有《牧云集群版 管理端安装部署（chroot版）》整理，并补充 K3s 官方当前系统要求。原 SOP 明确说明它只是集群标准步骤模板，仍需结合对应版本和单机版注意事项使用。因此本文不替代版本发布说明、资源计算器或产品专项 SOP。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | K3s / 产品运行底座 / 集群部署 |
| 适用范围 | 牧云（CloudWalker）集群版 K3s 底座，chroot + Ansible 安装方式 |
| 架构 | x86_64 / arm64，安装介质必须与 CPU 架构一致 |
| 文档状态 | 已按集群版部署 SOP 整理，并与 K3s 官方要求交叉核对 |
| 最后验证 | 2026-09-08 |
| 重要原则 | 所有部署前检查通过后才允许执行安装；生产环境磁盘性能未通过时禁止继续 |

---

## 1. 部署前总检查表

先完成下表，再进入 chroot、Ansible 或 K3s 安装。

| 检查项 | 检查命令 | 预期值 / 通过条件 | 不通过处理 |
| --- | --- | --- | --- |
| CPU 架构 | `uname -m` | `x86_64` 或 `aarch64/arm64`；必须与安装包、chroot 包一致 | 重新下载匹配架构的介质 |
| 内核版本 | `uname -r` | 产品 SOP：Linux Kernel `> 3.10`；实际部署必须同时满足当前产品版本支持列表 | 更换受支持 OS / Kernel |
| 操作系统 | `cat /etc/os-release` | 产品 SOP 推荐范围：CentOS 7.6–7.9、Ubuntu 20.04–22.04、kvlin v10；以当前产品发布边界为最终依据 | 禁止直接在未验证发行版生产部署 |
| ARM `lrcpc` | `lscpu \| grep -iw lrcpc` | 产品 25.03lf.x 起的 ARM 环境应能看到 `lrcpc` | 无输出时先确认 CPU/ClickHouse 兼容性，不继续安装 |
| 主机名 | `hostname` | 所有节点唯一；仅小写字母、数字、`-`，不含大写或特殊字符 | 修改 hostname 并重新登录确认 |
| DNS | `cat /etc/resolv.conf`；`getent hosts <可解析域名>` | 至少存在可用 `nameserver`；域名能成功解析 | 修复 DNS 或按产品离线/无 DNS 专项方案处理 |
| 时间/时区 | `timedatectl` | 所有节点时区一致；`System clock synchronized: yes` 或等价 NTP 同步状态 | 配置 chrony/systemd-timesyncd/NTP |
| swap | `swapon --show` | **无输出**；`/etc/fstab` 中无启用的 swap 自动挂载项 | `swapoff -a` 并禁用持久 swap |
| firewalld | `systemctl is-active firewalld` | `inactive` / `unknown` | 停用并禁用 firewalld |
| ufw | `ufw status` | `Status: inactive` 或未安装 | `ufw disable` |
| SELinux | `getenforce` | 产品 SOP 要求 `Disabled` | 修改配置后重启并再次检查 |
| `/var` 空间 | `df -hT /var` | `/var` 可用空间 `> 50G`；若 `/var` 未独立挂载，则根分区可用空间建议 `> 70G` | 扩容或调整磁盘规划 |
| K3s 数据盘 | `findmnt -T /var/lib/rancher/k3s` | `/var/lib/rancher/k3s` 指向真实独立数据盘/逻辑卷 | 按磁盘规划重新挂载 |
| 禁止软链接 | `test -L /var/lib/rancher/k3s && echo BAD || echo OK` | 输出 `OK` | 删除软链接方案，改为真实 mount |
| 文件系统/Quota | `findmnt -no FSTYPE,OPTIONS /var/lib/rancher/k3s` | 自动挂载方案通常应为 `xfs`；启用 PV quota 时应包含 `prjquota` | 重做文件系统/挂载参数 |
| Page Size | `getconf PAGE_SIZE` | 标准路径优先 `4096`；ARM 返回 `65536` 时必须先走产品 64K Page Size 专项步骤 | **不要直接继续安装** |
| SSH | `ssh root@<node> true` | 部署节点能无交互 SSH 到所有节点，包括自己 | 配置 SSH key / known_hosts |
| 节点互通 | `ping -c 3 <peer-ip>` + 端口检查 | 所有 Server 节点互通；网络策略满足第 3 节 | 调整 ACL / 安全组 / 防火墙 |
| 磁盘 I/O | 见第 4 节 fio | **生产环境必须达到当前产品资源计算器/项目审批阈值** | 未达标禁止继续部署 |

### 1.1 关于 Page Size

原产品 SOP 同时写了“Page Size < 64K”和“ARM 为 64K 时需要额外步骤”。实际执行时不要只按 `<64K` 字面判断：

```bash
getconf PAGE_SIZE
```

建议判定：

- `4096`：标准安装路径；
- `65536`：64 KiB Page Size，必须先确认当前产品和底座版本的专项兼容步骤；
- 其他值：视为异常，先停止部署并确认兼容性。

K3s 官方当前文档指出，ARM64 的 4 KiB Page Size 强制限制主要针对较老版本 K3s；但产品安装包还叠加了 ClickHouse 等工作负载限制，因此**产品版本约束优先于裸 K3s 的通用能力**。

### 1.2 关于 ARM `lrcpc`

产品从 25.03lf.x 起引入 ClickHouse，原 SOP 特别要求 ARM 环境检查 CPU 的 `lrcpc` 特性：

```bash
lscpu | grep -iw lrcpc
```

预期：能看到 `lrcpc`。

如果没有输出，不应通过“跳过检查”继续安装，应先确认 CPU 指令集和当前产品版本兼容性。

---

## 2. 节点与高可用规划

### 2.1 Server / Master 数量

产品 SOP 的安装配置要求 Master 节点使用奇数个；除研发外建议至少 3 台。K3s 官方对 embedded etcd HA 同样要求：

- 至少 **3 个 Server 节点**；
- Server 节点数量使用**奇数**，以维持 etcd quorum；
- Worker/Agent 可按容量增加。

推荐：

```text
生产常规集群：3 Master + N Worker
较大规模集群：按产品规划增加 Worker；Master 不应无意义堆数量
```

产品 SOP 进一步建议：节点总数 `<= 9` 时通常取前 3 个节点作为 Master；节点较多时可规划 5 个 Master。最终仍应以项目容量和产品版本方案为准。

### 2.2 主机名

所有节点必须唯一。

建议格式：

```text
k3s-master-1
k3s-master-2
k3s-master-3
k3s-worker-1
```

检查：

```bash
hostname
hostnamectl status
```

预期：

- 节点间无重复；
- 只包含 `[a-z0-9-]`；
- 不使用大写字母、下划线或其他特殊字符。

---

## 3. 网络与端口

### 3.1 产品业务网络要求

来自产品集群版 SOP：

| 源 | 目的 | 协议/端口 | 用途 |
| --- | --- | --- | --- |
| 管理员 PC | Server Nodes | TCP/443 | Web HTTPS |
| 管理员 PC | Server Nodes | TCP/22 | SSH 管理 |
| Agent | Server Nodes | TCP/50051 | 探针通信 |
| Agent | Server Nodes | TCP/80 | 探针升级 |
| Agent | Server Nodes | TCP/30399 | 拟态防护通信 |
| Server Nodes | Server Nodes | 全互通 | 集群和产品服务间通信 |

### 3.2 K3s 本身必须考虑的端口

如果客户网络不能直接允许 `Server Nodes -> Server Nodes any`，至少还要根据实际 K3s 网络模式核对：

| 源 | 目的 | 协议/端口 | 说明 |
| --- | --- | --- | --- |
| 所有节点 | K3s Server | TCP/6443 | Kubernetes API / 节点注册 |
| 所有节点 | 所有节点 | UDP/8472 | Flannel VXLAN；仅 VXLAN backend 需要 |
| 所有节点 | 所有节点 | TCP/10250 | kubelet / metrics-server 等节点通信 |
| Server | Server | TCP/2379-2380 | embedded etcd HA |

注意：

- UDP/8472 不应暴露到公网；
- 若使用 WireGuard 或自定义 CNI，所需网络端口不同；
- 产品 SOP 的“Server 节点任意互通”范围比上述 K3s 最小端口更宽，**不能仅凭上表擅自收窄产品集群的内部网络策略**。

### 3.3 快速端口检查

示例：

```bash
nc -zvw3 <master-ip> 6443
nc -zvw3 <master-ip> 2379
nc -zvw3 <peer-ip> 10250
```

预期：TCP 检查返回 `succeeded` / `open`。

UDP 端口不能只依赖 `nc -u` 判断，必要时通过抓包或部署后的 Flannel 状态验证。

---

## 4. 数据盘与磁盘 I/O

这是生产部署最容易被忽略、同时对集群稳定性影响最大的检查项之一。

### 4.1 数据目录必须是实际挂载点

目标目录：

```text
/var/lib/rancher/k3s
```

检查：

```bash
findmnt -T /var/lib/rancher/k3s
lsblk -f
df -hT /var/lib/rancher/k3s
```

预期：

- 能看到独立 SOURCE，例如 `/dev/vdb1`、LVM LV 或其他真实块设备；
- 目标目录为 `/var/lib/rancher/k3s`；
- 不与系统盘使用同一个底层设备（产品 SOP 推荐独立数据盘）；
- 容量满足当前项目资源规划。

### 4.2 禁止使用软链接

检查：

```bash
if [ -L /var/lib/rancher/k3s ]; then
  echo 'FAIL: k3s data dir is symlink'
else
  echo 'PASS: k3s data dir is not symlink'
fi
```

预期：

```text
PASS: k3s data dir is not symlink
```

产品 SOP 明确指出：该目录使用软链接可能导致集群稳定性下降和文件异常丢失，严重时需要重装。

### 4.3 自动挂载参数

安装器建议配置：

```ini
k3s_installer_do_disk_probe = true
k3s_installer_require_mount = true
k3s_installer_do_quota_check = true
```

注意：自动磁盘探测可能会**格式化候选数据盘为 XFS**并启用 quota。执行前必须确认候选盘无业务数据。

### 4.4 手动挂载参考

以下操作会创建 LVM 并格式化设备，属于破坏性操作；仅对确认无数据的专用数据盘执行。

```bash
pvcreate /dev/vdb
vgcreate cloudwalker_k3s /dev/vdb
lvcreate -L 1024G --name var_lib_rancher_k3s_storage cloudwalker_k3s
mkfs.xfs /dev/cloudwalker_k3s/var_lib_rancher_k3s_storage
mkdir -p /var/lib/rancher/k3s
mount -o prjquota /dev/cloudwalker_k3s/var_lib_rancher_k3s_storage /var/lib/rancher/k3s
```

持久化挂载示例：

```fstab
/dev/mapper/cloudwalker_k3s-var_lib_rancher_k3s_storage /var/lib/rancher/k3s xfs rw,prjquota 0 2
```

验证：

```bash
findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /var/lib/rancher/k3s
```

预期类似：

```text
/dev/mapper/cloudwalker_k3s-var_lib_rancher_k3s_storage /var/lib/rancher/k3s xfs rw,...,prjquota
```

### 4.5 fio 性能测试

原 SOP 要求生产环境在部署前执行磁盘性能测试，并明确：**磁盘性能未通过，不允许进入部署。**

安全原则：

- 有独立空数据盘时，可按经过批准的脚本对专用盘测试；
- 没有独立数据盘时，禁止直接对系统整盘做破坏性测试，应使用测试文件；
- 原 SOP 没有给出统一 IOPS 数字门槛，必须以当前产品资源计算器、版本资源需求说明或项目审批阈值为准。

文件测试示例：

```bash
fallocate -l 1G /tmp/iotest.tmp
/root/run_fio.sh /tmp/iotest.tmp fio-output
```

查看结果：

```bash
grep iops /root/fio-output/*write.4K.*
```

通过条件：

```text
PASS = 当前节点 4K 随机/顺序写结果达到项目规定阈值
FAIL = 未达到阈值，或无法稳定完成测试
```

**不要把 SOP 示例中的某台测试机 IOPS 数字当成全产品通用门槛。**

---

## 5. DNS、时间、Swap、防火墙和 SELinux

### 5.1 DNS

检查：

```bash
cat /etc/resolv.conf
getent hosts <客户环境中应可解析的域名>
```

若安装流程依赖 `nslookup`：

```bash
command -v nslookup
```

预期：

- `resolv.conf` 至少有一个有效 `nameserver`；
- `getent hosts` / `nslookup` 能返回 IP；
- `nslookup` 命令存在。

原 SOP 的预配置脚本在缺少 `nslookup` 时可能失败；RPM 系通常由 `bind-utils` 提供。

### 5.2 时间同步

```bash
timedatectl
```

预期：

```text
System clock synchronized: yes
```

并保证所有节点：

- 时区一致；
- 时间差在 NTP 正常同步范围内。

### 5.3 Swap

```bash
swapon --show
grep -Ev '^\s*#|^\s*$' /etc/fstab | grep -i swap
```

预期：两条命令都不应显示启用中的 swap。

### 5.4 Firewall

```bash
systemctl is-active firewalld 2>/dev/null || true
ufw status 2>/dev/null || true
```

产品 SOP 通过条件：

```text
firewalld: inactive
ufw: Status: inactive
```

K3s 官方允许在精确开放所需端口的情况下保留主机防火墙，但产品 SOP 明确要求关闭 firewalld/ufw，因此本产品部署按更严格的产品要求执行。

### 5.5 SELinux

```bash
getenforce
```

产品 SOP 预期：

```text
Disabled
```

---

## 6. chroot + Ansible 部署机准备

建议整个安装过程在 `tmux` 中运行，防止 SSH/终端断开导致安装中断。

### 6.1 准备 chroot

x86_64 与 ARM 必须选择各自对应的 chroot 包。

示意：

```bash
cd /root
tar xvf chroot_alpine_x86_64.tgz
mv /root/chroot_alpine_x86_64 /root/chroot_alpine
```

ARM 环境使用对应的 `aarch64` chroot 包。

进入前再次确认：

```bash
uname -m
getconf PAGE_SIZE
```

### 6.2 inventory

示例：

```ini
[all:vars]
ansible_user=root

[dephost]
192.168.10.11 name=k3s-master-1

[nodes]
192.168.10.12 name=k3s-master-2
192.168.10.13 name=k3s-master-3
192.168.10.21 name=k3s-worker-1
```

要求：

- `name` 唯一；
- IP 为节点实际可达地址；
- 部署机自身也必须在 inventory 中；
- SSH 用户按实际环境配置。

### 6.3 SSH Key 和 known_hosts

进入 chroot：

```bash
chroot /root/chroot_alpine
export PATH=/bin:/usr/bin:/usr/local/bin
ssh-keygen
```

将所有节点写入 known_hosts：

```bash
ssh-keyscan 192.168.10.11 192.168.10.12 192.168.10.13 192.168.10.21 > /root/.ssh/known_hosts
```

将 chroot 内生成的 SSH 公钥加入所有节点，包括部署机自身的 `root/.ssh/authorized_keys`。

### 6.4 Ansible 连通性验收

```bash
chroot /root/chroot_alpine ansible -i /root/inventory.txt all -m ping
```

预期：每个节点都返回类似：

```text
SUCCESS => {
  "changed": false,
  "ping": "pong"
}
```

只要有一个节点失败，停止后续安装。

### 6.5 批量 DNS 检查

```bash
chroot /root/chroot_alpine ansible -i /root/inventory.txt all -m shell -a 'cat /etc/resolv.conf'
chroot /root/chroot_alpine ansible -i /root/inventory.txt all -m shell -a 'getent hosts <测试域名>'
```

预期：全部节点均能解析。

---

## 7. 节点预配置

原产品 SOP 的预配置过程可能修改系统配置并重启节点。执行前必须确认业务允许重启。

预配置前先确认 `nslookup`：

```bash
command -v nslookup
```

RPM 系统缺少时通常安装：

```bash
yum install -y bind-utils
```

执行预配置 playbook 后，应重新验证：

```bash
ansible -i /root/inventory.txt all -m ping
```

并重新检查：

```bash
hostname
getconf PAGE_SIZE
swapon --show
timedatectl
findmnt -T /var/lib/rancher/k3s
```

预期值仍应满足第 1 节。

---

## 8. 大负载场景内核调优（按需）

以下参数来自产品 SOP，定位是“海量探针/大量短连接场景”的建议调优，不是所有 K3s 集群的无条件默认值。生产变更前应评估现网连接模型和内核版本。

```ini
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 20480
net.ipv4.tcp_max_syn_backlog = 20480
net.core.netdev_max_backlog = 20480
```

应用：

```bash
sysctl --system
```

检查：

```bash
sysctl net.ipv4.tcp_tw_reuse
sysctl net.ipv4.tcp_fin_timeout
sysctl net.ipv4.ip_local_port_range
sysctl net.core.somaxconn
sysctl net.ipv4.tcp_max_syn_backlog
sysctl net.core.netdev_max_backlog
```

预期分别为：

```text
1
10
1024 65535
20480
20480
20480
```

如果业务并非大规模短连接/高并发场景，不应为了“统一参数”盲目套用。

---

## 9. 安装器 `default.ini` 关键参数

### 9.1 Master / Worker

示例：

```ini
[master]
192.168.10.11 public_ip=192.168.10.11
192.168.10.12 public_ip=192.168.10.12
192.168.10.13 public_ip=192.168.10.13

[worker]
192.168.10.21 public_ip=192.168.10.21
```

要求：

- 第一个 IP 必须是节点本机真实地址；
- NAT/EIP/BIP 等对外地址放在 `public_ip`；
- 没有映射地址时 `public_ip` 可填写本机地址。

### 9.2 建议关键变量

```ini
[all:vars]
ansible_user=root
k3s_installer_do_disk_probe = true
k3s_installer_require_mount = true
k3s_installer_do_quota_check = true
k3s_installer_change_hostname = true
extra_k3s_master_config = 'kube-apiserver-arg: "service-node-port-range=20000-50052"'
extra_k3s_config = ""
```

逐项说明：

| 参数 | 建议值 | 验收 |
| --- | --- | --- |
| `ansible_user` | 实际 SSH 用户；原 SOP 常用 `root` | Ansible ping 全部成功 |
| `k3s_installer_do_disk_probe` | `true` | 安装器能发现专用数据盘 |
| `k3s_installer_require_mount` | `true` | 数据盘未正确挂载时安装应阻断 |
| `k3s_installer_do_quota_check` | 使用 PV quota 时 `true` | XFS Project Quota 检查通过 |
| `k3s_installer_change_hostname` | 无特殊要求时 `true` | 最终主机名唯一且规范 |
| `extra_k3s_master_config` | 产品 SOP 要求扩展 NodePort Range | 安装后 API Server 正常，NodePort 范围符合产品配置 |

**磁盘自动探测会涉及格式化操作。配置 `true` 前必须确认候选设备没有数据。**

---

## 10. 安装 K3s 底座

建议在 `tmux` 会话内执行。

示例：

```bash
chroot /root/chroot_alpine /root/installer/ansible/install.sh
```

安装器开始前通常会执行环境检查。任何前置检查失败都应先修复，不建议绕过安装器检查。

---

## 11. 安装后验收

### 11.1 Node 状态

```bash
kubectl get nodes -o wide
```

预期：

- 所有 Master/Server：`STATUS=Ready`；
- 所有 Worker/Agent：`STATUS=Ready`；
- Master 能看到 control-plane/etcd 等角色；
- 无 `NotReady` 节点。

### 11.2 系统 Pod

```bash
kubectl get pods -A -o wide
```

预期：

- 持续运行服务为 `Running`；
- 一次性 Job 可为 `Completed`；
- 无持续 `CrashLoopBackOff`、`ImagePullBackOff`、`CreateContainerError`；
- 无长期 `Pending`。

### 11.3 API Ready

```bash
kubectl get --raw='/readyz?verbose'
```

预期末尾：

```text
readyz check passed
```

若当前 K3s/Kubernetes 版本不支持该输出，则至少保证 `kubectl get nodes`、`kubectl get pods -A` 和 API 查询均稳定成功。

### 11.4 数据目录

```bash
findmnt -T /var/lib/rancher/k3s
df -hT /var/lib/rancher/k3s
test -L /var/lib/rancher/k3s && echo FAIL || echo PASS
```

预期：

- 仍挂载在规划的数据盘；
- 剩余空间符合容量规划；
- 输出 `PASS`，不是软链接。

### 11.5 时间、DNS、Swap

```bash
timedatectl
swapon --show
getent hosts <测试域名>
```

预期：

- 时间已同步；
- swap 无输出；
- DNS 可解析。

### 11.6 集群异常事件

```bash
kubectl get events -A --sort-by='.lastTimestamp'
```

预期：不存在持续重复出现的资源不足、磁盘、网络、镜像或调度错误。

---

## 12. 数据库独占与 HugePage（可选）

原产品 SOP 建议在探针数量超过约 2 万的场景评估数据库独占部署。该配置不是 K3s 基础安装必选项。

规划数据库专用节点时，原 SOP 要求至少：

```text
8 CPU / 16 GB RAM
较好的磁盘性能
```

HugePage 示例：

```ini
vm.nr_hugepages = 2048
```

其中默认 2 MiB HugePage 下，`2048` 约为 4 GiB。

验证：

```bash
cat /proc/meminfo | grep Huge
```

注意：HugePage 会直接预留内存。原 SOP 明确提示该参数重要且有风险；不能机械照抄，应根据数据库独占方式、总内存和 shared buffer 规划确定。

---

## 13. 禁止事项

以下情况禁止继续安装：

1. CPU 架构与安装介质不匹配；
2. ARM 产品版本要求 `lrcpc`，但 CPU 检查不通过；
3. ARM 为 64 KiB Page Size，尚未完成专项兼容确认；
4. 节点 hostname 重复或不符合命名规则；
5. DNS / 时间同步异常；
6. swap 仍启用；
7. 产品要求下 firewalld / ufw / SELinux 尚未按规范处理；
8. `/var/lib/rancher/k3s` 使用软链接；
9. 专用数据盘未正确挂载；
10. 生产环境 fio 未达到当前项目批准阈值；
11. Ansible 无法 `ping` 通任一节点；
12. Master 数量不符合 HA 规划；
13. Server 节点间网络策略不满足集群通信；
14. 自动磁盘探测尚未确认候选盘无数据。

---

## 14. 最短部署 Gate

建议现场严格按 Gate 推进：

```text
Gate 1：OS / CPU / hostname / Page Size
  ↓ 全部 PASS
Gate 2：DNS / NTP / swap / firewall / SELinux
  ↓ 全部 PASS
Gate 3：数据盘 / XFS / quota / fio
  ↓ 生产 IOPS PASS
Gate 4：SSH / Ansible / 节点网络
  ↓ all ping SUCCESS
Gate 5：default.ini 人工复核
  ↓ Master/Worker/IP/磁盘参数正确
Gate 6：执行 K3s Installer
  ↓ install success
Gate 7：Node / Pod / API / 数据目录验收
  ↓ 全部 PASS
允许安装产品应用
```

任何 Gate 失败，只修复当前 Gate，禁止“先往后装再一起处理”。

---

## 15. 断电 / 重启后全链路故障排查与恢复

适用于机房断电、宿主机异常重启后，产品页面或业务持续异常的场景。排查顺序固定为：

```text
硬件 / 磁盘
  ↓
Linux / 网络 / 时间
  ↓
K3s 服务 / containerd
  ↓
API / Node
  ↓
Pod / PVC
  ↓
Service / Ingress
  ↓
产品应用
```

**第一个异常层就是优先故障定位点。先修根因，再考虑重启 Pod 或 K3s。**

K3s 是标准 Kubernetes 发行版，本文中的 `kubectl get / describe / logs / events` 与标准 K8s 用法一致；K3s 也可使用 `k3s kubectl`。`systemctl restart k3s`、`k3s crictl` 等属于 K3s 主机侧命令。

### 15.1 操作安全边界

- 排查阶段优先使用只读命令；k9s 建议使用 `k9s --readonly`。
- k9s 的 `Ctrl+D` 是 **Delete**，`Ctrl+K` 是 **Kill / 立即删除**，排查时不要误触。
- HA 集群的 Server/Master **禁止同时重启**，必须逐台处理，每台恢复 `Ready` 后再处理下一台。
- StatefulSet（PostgreSQL、TiKV、MinIO、Redis 等）禁止同时重启多个副本。
- `PVC/PV`、数据库数据目录、`/var/lib/rancher/k3s` 不允许通过“删除重建”方式碰运气恢复。
- 文件系统报错时禁止直接对已挂载设备执行 `fsck` / `xfs_repair`；必须进入维护窗口、备份并卸载后处理。

### 15.2 从主机到底座逐层检查

| 层级 | 检查命令 | 正常反馈 / 判定 | 异常后的修正命令 | 修正后验证 |
| --- | --- | --- | --- | --- |
| 重启事实 | `uptime; last -x \| head -20` | 启动时间与断电恢复时间一致；无持续重复 reboot | 若反复重启，先查 BMC/电源/硬件；**无安全通用一键修复命令** | `uptime` 持续增长，无再次 reboot |
| 磁盘与挂载 | `lsblk -f; findmnt -T /var/lib/rancher/k3s; df -hT / /var /var/lib/rancher/k3s; df -ih / /var /var/lib/rancher/k3s` | 规划磁盘存在、数据目录已挂载；空间和 inode 未耗尽 | 若设备健康且 `/etc/fstab` 已确认正确、仅挂载丢失：`mount /var/lib/rancher/k3s`；空间不足优先扩容，不执行未知目录批量删除 | 再执行 `findmnt`、`df -hT`、`df -ih` |
| 磁盘 / 文件系统错误 | `dmesg -T \| grep -Ei 'I/O error|EXT4-fs error|XFS.*error|nvme.*error|blk_update_request' \| tail -100` | 无持续 I/O / 文件系统错误 | 若存在 I/O/FS 错误：停止继续重启 Pod；先更换/修复硬盘。文件系统修复仅在**卸载 + 备份 + 维护窗口**执行，例如 XFS：`xfs_repair <device>`；ext4：`fsck -f <device>` | 挂载后重新执行 `dmesg`、`findmnt`、`df`，确认无新错误 |
| 网卡与路由 | `ip -br a; ip route; ping -c 3 <gateway>; nc -zvw3 <server-ip> 6443` | 业务网卡 UP、默认/业务路由正确；网关及 K3s API 可达 | 仅网卡被置 DOWN 时：`ip link set <nic> up`；网络服务异常且确认允许中断时：`systemctl restart NetworkManager` 或对应网络服务 | 重跑 `ip -br a`、`ip route`、`ping`、`nc` |
| 时间同步 | `timedatectl` | 时区正确；`System clock synchronized: yes` 或等价状态 | `timedatectl set-ntp true`；chrony 环境可执行 `systemctl restart chronyd` | `timedatectl`; `chronyc tracking 2>/dev/null || true` |
| K3s Server 服务 | `systemctl is-active k3s; systemctl status k3s --no-pager -l; journalctl -u k3s -n 200 --no-pager` | `active`；日志无持续启动失败 | **先修磁盘/网络/时间后**：`systemctl restart k3s`。HA Server 逐台执行 | `systemctl is-active k3s`; `kubectl get nodes -o wide` |
| K3s Worker/Agent | `systemctl is-active k3s-agent; systemctl status k3s-agent --no-pager -l; journalctl -u k3s-agent -n 200 --no-pager` | `active`；能连接 Server | **先修底层故障后**：`systemctl restart k3s-agent` | `systemctl is-active k3s-agent`; 在 Server 上执行 `kubectl get nodes -o wide` |
| containerd / CRI | `k3s crictl info; k3s crictl ps -a; k3s crictl images` | CRI 可响应；容器和镜像列表可读取 | K3s 内置 containerd 通常不单独重启；修复磁盘/网络后重启该节点 `k3s` 或 `k3s-agent` 服务 | `k3s crictl info`; `k3s crictl ps -a` |
| K3s / containerd 日志 | `tail -200 /var/lib/rancher/k3s/agent/containerd/containerd.log 2>/dev/null; journalctl -u k3s -n 200 --no-pager 2>/dev/null; journalctl -u k3s-agent -n 200 --no-pager 2>/dev/null` | 无持续 `no space left`、I/O、DNS、registry、sandbox 等错误 | 按日志对应根因修复；不要只靠重复 restart 掩盖错误 | 重查相同日志，确认错误不再持续新增 |
| API / Node | `kubectl get --raw='/readyz?verbose'; kubectl get nodes -o wide` | API Ready；全部节点 `Ready` | `NotReady` 先定位对应节点；修复节点底层后，仅重启该节点的 `k3s` / `k3s-agent` | `kubectl get nodes -o wide` 全部 `Ready` |
| Node 压力 | `kubectl describe node <node>` | Conditions 中 `DiskPressure=False`、`MemoryPressure=False`、`PIDPressure=False` | DiskPressure→扩容/释放已确认无用空间；MemoryPressure→降低异常负载或调整资源；PIDPressure→定位异常进程。修根因后等待 Node 状态恢复 | `kubectl describe node <node>` 查看 Conditions |
| Pod | `kubectl get pods -A -o wide; kubectl describe pod <pod> -n <ns>; kubectl logs <pod> -n <ns> --all-containers --tail=200` | 常驻 Pod 为 `Running/Ready`；Job 可 `Completed` | 按 15.3 对应状态修复，不批量删除 Pod | `kubectl get pods -A -o wide` |
| PVC / PV | `kubectl get pvc -A; kubectl get pv; kubectl get storageclass` | PVC 为 `Bound`；PV 状态正常 | 先修 CSI/后端存储/节点挂载；**不要先删除 PVC/PV** | 再执行 `kubectl get pvc -A; kubectl get pv` |
| Service | `kubectl get svc -A; kubectl get endpoints -A; kubectl get endpointslices -A` | Service 对应 Endpoints 非空（无后端的服务除外） | 标签/端口配置确有错误时，优先修 Helm/Ansible/manifest 源配置；临时核验可 `kubectl edit svc <svc> -n <ns>` | `kubectl get endpoints <svc> -n <ns> -o wide` |
| 产品应用 | `kubectl logs <pod> -n <ns> --all-containers --tail=200` | 无持续数据库、Redis、MQ、证书、DNS、依赖连接错误 | 先恢复依赖；无状态 Deployment 可在确认根因修复后执行 `kubectl rollout restart deployment/<name> -n <ns>` | `kubectl rollout status deployment/<name> -n <ns>` + 业务验证 |

> `kubectl top node` / `kubectl top pod -A` 可辅助判断 CPU/内存压力；若集群未安装或未恢复 metrics-server，命令不可用本身不能直接判定业务故障。

### 15.3 常见 Pod 状态：检查与修正

#### Evicted

含义：Pod 被 kubelet 驱逐。断电后最常见原因之一是节点磁盘、inode 或内存压力。

检查：

```bash
kubectl describe pod <pod> -n <ns>
kubectl describe node <node>
df -hT / /var /var/lib/rancher/k3s
df -ih / /var /var/lib/rancher/k3s
```

判定：重点查看 `Reason: Evicted`、`DiskPressure`、`MemoryPressure`、`ephemeral-storage`。

修正：**先恢复节点资源**。确认 Pod 由控制器管理：

```bash
kubectl get pod <pod> -n <ns> -o jsonpath='{.metadata.ownerReferences[*].kind}{"\n"}'
```

若根因已经修复，且 Pod 明确属于 Deployment/StatefulSet/DaemonSet/Job 等控制器，旧的 Evicted 对象可按需清理：

```bash
kubectl delete pod <pod> -n <ns>
```

验证：

```bash
kubectl get pods -n <ns> -o wide
kubectl describe node <node>
```

#### CrashLoopBackOff

含义：容器反复启动失败，Kubernetes 正在退避重试。

检查：

```bash
kubectl logs <pod> -n <ns> --all-containers --previous --tail=200
kubectl describe pod <pod> -n <ns>
```

修正：先修配置、证书、依赖服务、启动参数或探针。无状态 Deployment 修复完成后可：

```bash
kubectl rollout restart deployment/<name> -n <ns>
kubectl rollout status deployment/<name> -n <ns>
```

StatefulSet 不批量 rollout；确认副本角色和数据安全后，只处理单个异常 Pod。

#### ImagePullBackOff / ErrImagePull

检查：

```bash
kubectl describe pod <pod> -n <ns>
kubectl get events -n <ns> --sort-by='.lastTimestamp'
```

登录该 Pod 所在 Node 后，可直接验证运行时能否拉镜像：

```bash
k3s crictl pull <image>
```

修正：恢复 DNS、镜像仓库网络、镜像地址或 `imagePullSecrets`。根因修复后 kubelet 会继续重试；必要时再删除由控制器管理的异常 Pod 触发重建。

#### Pending

检查：

```bash
kubectl describe pod <pod> -n <ns>
kubectl get pvc -n <ns>
kubectl get nodes
```

判定：查看 `FailedScheduling`、资源不足、taint/affinity、PVC 未绑定。

修正：补足资源、恢复存储或修正调度配置。不要为了让 Pod 跑起来直接删除未知 taint 或 PVC。

#### OOMKilled

`OOM` = Out Of Memory，表示容器或主机可用内存不足；`OOMKilled` 表示进程被内核 OOM 机制终止。

检查：

```bash
kubectl describe pod <pod> -n <ns>
kubectl top pod <pod> -n <ns> 2>/dev/null || true
free -h
```

修正：确认真实内存需求后调整 Helm/Ansible/manifest 中的 `resources.requests/limits`，或修复内存泄漏。不要只靠无限增大 limit 掩盖问题。

#### CreateContainerConfigError / FailedCreatePodSandBox

检查：

```bash
kubectl describe pod <pod> -n <ns>
kubectl get events -n <ns> --sort-by='.lastTimestamp'
```

- `CreateContainerConfigError`：重点查 ConfigMap、Secret、Volume、环境变量。
- `FailedCreatePodSandBox`：重点查 CNI、pause/sandbox 镜像、containerd、DNS/registry、节点磁盘。

修正后验证：

```bash
kubectl get pod <pod> -n <ns> -o wide
kubectl describe pod <pod> -n <ns>
```

### 15.4 k9s 只读排查速查

建议现场先进入只读模式：

```bash
k9s --readonly
```

| 操作 | 命令 / 快捷键 |
| --- | --- |
| Pod | `:po` / `:pod` |
| Node | `:node` |
| StatefulSet | `:sts` |
| Deployment | `:deploy` |
| PVC | `:pvc` |
| Events | `:events` |
| Describe | `d` |
| Logs | `l` |
| 搜索 / 过滤 | `/` |
| 当前版本帮助 | `?` |
| 返回 / 取消过滤 | `Esc` |
| 退出 | `:q` / `Ctrl+C` |

警告：正常模式中 `Ctrl+D` 为 Delete，`Ctrl+K` 为立即 Kill；不要把它们当成翻页键。

### 15.5 典型实测：磁盘不足 → Evicted → 镜像缺失

典型链路：

```text
节点磁盘不足
  → DiskPressure
  → kubelet 驱逐 Pod
  → image GC 清理未使用镜像
  → Pod 显示 Evicted / FailedCreatePodSandBox / ImagePullBackOff
  → 产品持续异常
```

检查顺序：

```bash
kubectl get pods -A -o wide
kubectl describe pod <异常Pod> -n <ns>
kubectl describe node <异常Node>

# 登录异常 Node
df -hT / /var /var/lib/rancher/k3s
df -ih / /var /var/lib/rancher/k3s
du -xhd1 /var/lib/rancher/k3s 2>/dev/null | sort -h
k3s crictl images
journalctl -u k3s -n 200 --no-pager 2>/dev/null
journalctl -u k3s-agent -n 200 --no-pager 2>/dev/null
```

判定：如果 `df`/inode 已耗尽，Node 出现 `DiskPressure`，同时 Events/日志出现 `Evicted`、`no space left on device`、镜像或 sandbox 拉取失败，则优先故障层为**节点存储**，不是 Pod 本身。

修正顺序：

1. 扩容数据盘，或只清理由人工确认无业务价值的文件；禁止直接删除 `/var/lib/rancher/k3s` 下未知内容。
2. `df -hT`、`df -ih` 确认空间恢复，`findmnt` 确认数据盘正常。
3. 若运行时仍异常：Worker 执行 `systemctl restart k3s-agent`；Server 执行 `systemctl restart k3s`。
4. HA Server 必须逐台重启；每台都等到重新 `Ready` 后再处理下一台。
5. 返回集群验证：

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by='.lastTimestamp'
```

**已经扩容的节点应逐台执行检查；只有服务/运行时仍异常的节点才需要 restart，不建议无差别同时重启所有 K3s 节点。**

### 15.6 最终定位规则

```text
硬件异常        → 修硬件，不碰 Pod
磁盘/FS 异常    → 修磁盘/挂载/文件系统
网络/时间异常   → 修系统基础环境
K3s/CRI 异常    → 修对应节点 K3s 服务
Node 压力异常   → 修 Node 资源
PVC 异常        → 修 CSI/存储
Pod 异常        → 查日志/配置/依赖
Service 异常    → 查 Endpoint/Selector/Port
以上全正常      → 进入产品业务自身排障
```

不要跳层。**下层未恢复时，上层重启通常只能暂时改变现象，不能消除根因。**

### 15.7 术语速查

| 术语 | 含义 |
| --- | --- |
| `OOM / OOMKilled` | Out Of Memory；内存不足，进程被内核终止 |
| `DiskPressure` | kubelet 判断节点磁盘空间或 inode 达到驱逐压力阈值 |
| `Evicted` | Pod 被 kubelet 主动驱逐，不等同于应用自身崩溃 |
| `CrashLoopBackOff` | 容器反复启动失败，Kubernetes 延迟后继续重试 |
| `ImagePullBackOff` | 镜像拉取失败并进入退避重试 |
| `CRI` | Container Runtime Interface；Kubernetes 与 containerd 等运行时的接口 |
| `CNI` | Container Network Interface；Pod 网络接口规范 |
| `CSI` | Container Storage Interface；Kubernetes 存储插件接口 |
| `PVC / PV` | PersistentVolumeClaim / PersistentVolume；持久卷申请 / 持久卷 |
| `inode` | 文件系统用于记录文件元数据的索引节点；inode 耗尽时即使仍有容量也无法新建文件 |
| `quorum` | 多数派；etcd HA 维持一致性和可写能力所需的多数节点 |

---

## 16. 参考资料

- K3s 官方：System Requirements — https://docs.k3s.io/zh/installation/requirements
- K3s 官方：High Availability Embedded etcd — https://docs.k3s.io/zh/datastore/ha-embedded
- K3s 官方：FAQ / 日志位置 — https://docs.k3s.io/zh/faq
- K3s 官方：Advanced Options / systemd 服务日志 — https://docs.k3s.io/zh/advanced
- Kubernetes 官方：Node-pressure Eviction — https://kubernetes.io/zh-cn/docs/concepts/scheduling-eviction/node-pressure-eviction/
- K9s 官方：Commands — https://k9scli.io/topics/commands/
- 内部来源：《牧云集群版 管理端安装部署（chroot版）》

> 原 SOP 中涉及内部 Release 平台、内部附件和专项文档的链接未复制到公开知识库。安装介质、产品资源阈值、64K Page Size 专项步骤等应从当前交付渠道获取最新版本。
