# 产品运行底座：K3s 集群部署与故障排查手册

本文用于产品 K3s 集群的部署前检查、安装后验收，以及断电/重启后的故障排查。执行原则只有一个：**优先看总检查表，按层级顺序排查；每一项只保留检查/验证命令、判定标准和修正命令。修正后直接重复同一列检查命令确认结果。**

> 适用范围：牧云（CloudWalker）K3s 集群版，x86_64 / arm64。产品版本约束、资源计算器、安装介质和专项 SOP 的要求优先于本文通用建议。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | K3s / Kubernetes / 产品运行底座 |
| 适用场景 | 部署前检查、安装后验收、断电重启后故障排查 |
| 核心原则 | 从硬件 → 系统 → K3s → Node → Pod/PVC → Service → 产品逐层定位 |
| 安全原则 | 先检查、再判定、后修正；修正后重复检查；禁止批量重启、批量删除或直接修文件系统 |
| 最后验证 | 2026-09-08 |

---

# 1. 部署前总检查表

安装前先完成本表。任意关键项失败时，先修当前项，不继续后续安装。修正后直接重新执行“检查 / 验证命令”。

**命令规范：**

- 表中的检查命令均可直接复制到 Bash 终端执行。
- 需要现场 IP、域名或文件路径时，命令会先通过 `read` 交互式询问，不再使用 `<server-ip>`、`<测试域名>` 这类无法直接执行的占位符。
- 修正操作如果不存在跨发行版、跨环境都安全的一键命令，会明确写为“无安全通用命令”，不为了凑命令加入高风险操作。
- 部署前 K3s 服务尚未启动，因此**不能用 `nc` 连接 6443、2379、2380、10250 是否成功来判断新集群网络是否合格**。部署前只检查节点基础互通、主机端口冲突和外部 ACL / 防火墙策略；服务端口连通性放到安装后验收。

| 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| CPU 架构 | `uname -m` | 产品支持的 x86_64 主机应输出 `x86_64`；ARM64 主机通常输出 `aarch64`。必须与安装介质架构一致 | **无安全通用修改命令**。更换与 CPU 架构匹配的安装介质 |
| CPU / 内存 | `nproc; free -h` | 不低于当前产品版本的资源规划；裸 K3s 官方最低值仅作为底座基线，不能替代产品资源要求 | **无软件修正命令**。扩容 CPU / 内存或调整节点规格 |
| 内核 / OS | `uname -r; cat /etc/os-release` | Linux 内核和发行版必须位于当前产品版本支持范围内 | **无安全通用修改命令**。升级或更换受支持的 OS / Kernel，完成后重新检查 |
| cgroup | `mountpoint -q /sys/fs/cgroup && echo 'PASS: cgroup 已挂载' || echo 'FAIL: cgroup 未挂载'; stat -fc %T /sys/fs/cgroup` | 输出 `PASS`；并能识别 cgroup 文件系统。K3s 依赖可用的 cgroup | **无跨发行版通用修正命令**。按当前 OS 的 cgroup 配置方式处理后重启并复查 |
| ARM `lrcpc` | `if [ "$(uname -m)" = "aarch64" ]; then grep -qw lrcpc /proc/cpuinfo && echo 'PASS: lrcpc' || echo 'FAIL: 缺少 lrcpc'; else echo 'SKIP: 非 ARM64'; fi` | x86_64 输出 `SKIP`；当前产品要求 `lrcpc` 的 ARM64 节点必须输出 `PASS` | **无软件修正命令**。CPU 不具备该特性时更换兼容硬件或确认当前产品版本的兼容方案 |
| Page Size | `getconf PAGESIZE` | 标准路径通常为 `4096`；若输出 `65536`，必须确认当前产品版本的 64 KiB Page Size 专项兼容要求 | **禁止通过系统参数强改 Page Size**。按产品专项兼容方案处理 |
| 主机名 | `hostname; h=$(hostname); [[ "$h" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] && echo 'PASS: hostname 格式正确' || echo 'FAIL: hostname 格式错误'` | 主机名唯一；按产品命名规范使用小写字母、数字和 `-`；格式检查输出 `PASS` | `read -rp '输入新主机名: ' NEW_HOSTNAME; [[ "$NEW_HOSTNAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] && hostnamectl set-hostname "$NEW_HOSTNAME" || echo 'ERROR: 主机名格式不合法'` |
| DNS | `grep -E '^nameserver[[:space:]]+' /etc/resolv.conf || echo 'FAIL: 未配置 nameserver'; read -rp '输入环境中应可解析的域名: ' TEST_DOMAIN; getent hosts "$TEST_DOMAIN"` | 至少存在一个有效 nameserver；`getent hosts` 能返回目标域名 IP | **无安全通用修改命令**。DNS 写法取决于 NetworkManager、systemd-resolved、netplan 等实际网络栈；按当前 OS 网络规范修改，避免远程执行错误配置导致失联 |
| 时间 / NTP | `timedatectl status; if command -v chronyc >/dev/null 2>&1; then chronyc tracking; fi` | 所有节点时区一致；`System clock synchronized: yes`，或 chrony 显示已正常同步 | systemd-timesyncd 环境可执行 `timedatectl set-ntp true`；chrony 环境确认配置正确后执行 `systemctl restart chronyd 2>/dev/null || systemctl restart chrony` |
| Swap | `swapon --show; grep -iE '^[^#].*[[:space:]]swap[[:space:]]' /etc/fstab || true` | 按当前产品 SOP，`swapon --show` 应无输出，`/etc/fstab` 不应存在启用的 swap 挂载项 | 临时关闭：`swapoff -a`。持久关闭需人工修改 `/etc/fstab` 中对应 swap 项，避免脚本误改其他挂载配置 |
| firewalld | `if command -v firewall-cmd >/dev/null 2>&1; then systemctl is-active firewalld; else echo 'firewalld: not installed'; fi` | 按当前产品 SOP 应输出 `inactive`，或系统未安装 firewalld | 经变更批准后执行 `systemctl disable firewalld --now` |
| ufw | `if command -v ufw >/dev/null 2>&1; then ufw status; else echo 'ufw: not installed'; fi` | 按当前产品 SOP 应输出 `Status: inactive`，或系统未安装 ufw | 经变更批准后执行 `ufw disable` |
| SELinux | `if command -v getenforce >/dev/null 2>&1; then getenforce; else echo 'SELinux: not installed'; fi` | 按当前产品 SOP 应输出 `Disabled`，或系统不使用 SELinux | **不提供一键修改命令**。按发行版规范修改 SELinux 持久配置，并在维护窗口重启后重新执行检查命令 |
| `nm-cloud-setup`（旧版 RHEL / CentOS） | `systemctl is-enabled nm-cloud-setup.service nm-cloud-setup.timer 2>/dev/null || true` | 对受该 NetworkManager 已知问题影响的旧版 RHEL / CentOS，应为 `disabled` 或 `not-found` | 仅适用于受影响系统：`systemctl disable nm-cloud-setup.service nm-cloud-setup.timer`；官方要求随后重启节点，生产环境必须安排维护窗口 |
| 根分区 / `/var` 空间 | `df -hT / /var` | 文件系统挂载正常，剩余容量满足当前产品资源规划；不得接近满盘 | **无安全通用清理命令**。优先扩容；如需清理，只删除人工确认无业务价值的文件，禁止直接 `rm -rf` 未知目录 |
| inode | `df -ih / /var` | inode 使用率保持合理余量，不得接近 100% | 先定位大量小文件目录：`du --inodes -x -d1 /var 2>/dev/null`；只清理人工确认无用的文件 |
| K3s 数据盘挂载 | `if mountpoint -q /var/lib/rancher/k3s; then echo 'PASS: 独立挂载点'; findmnt /var/lib/rancher/k3s; else echo 'FAIL: /var/lib/rancher/k3s 不是独立挂载点'; fi` | 按产品磁盘规划应输出 `PASS`，并显示规划的数据盘 / LV 挂载到 `/var/lib/rancher/k3s` | **先确认设备和 `/etc/fstab` 完全正确**。仅属于“配置已正确但未挂载”时执行 `mount /var/lib/rancher/k3s`；其他情况按磁盘规划处理 |
| K3s 数据目录软链接 | `if [ ! -e /var/lib/rancher/k3s ]; then echo 'FAIL: 数据目录不存在'; elif [ -L /var/lib/rancher/k3s ]; then echo 'FAIL: 数据目录是软链接'; else echo 'PASS: 数据目录存在且不是软链接'; fi` | 输出 `PASS` | **禁止直接搬迁现有 K3s 数据**。若发现软链接，按维护流程备份并迁移到真实挂载点 |
| 文件系统 / Quota | `findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /var/lib/rancher/k3s` | SOURCE、TARGET、FSTYPE、挂载参数与当前产品磁盘方案一致；使用 XFS Project Quota 时应看到对应 quota 参数 | **无安全通用修改命令**。涉及重新格式化、改文件系统或 quota 时必须在备份、卸载和维护窗口条件下按专项 SOP 处理 |
| fio 工具 | `if command -v fio >/dev/null 2>&1; then fio --version; else echo 'FAIL: fio 未安装'; fi` | 能输出 fio 版本 | 按当前 OS 包管理器安装 fio。**实际磁盘性能测试必须使用当前产品版本批准的 fio 脚本和阈值，本文不提供通用裸盘压测命令** |
| SSH 免交互连通 | `read -rp '输入待检查节点 IP/主机名: ' NODE; ssh -o BatchMode=yes -o ConnectTimeout=5 "root@$NODE" true` | 命令无输出并返回成功；部署节点需要能按产品安装方式连接全部目标节点 | 已确认允许 root SSH 且需配置密钥时：`read -rp '输入待配置节点 IP/主机名: ' NODE; ssh-copy-id "root@$NODE"` |
| 节点基础互通 | `read -rp '输入对端节点 IP/主机名: ' PEER; ping -c 3 "$PEER"` | 能收到对端 ICMP Reply；同时还必须人工确认交换机、ACL、安全组满足 K3s 所需端口策略 | 修正 IP、VLAN、路由、ACL、安全组或主机防火墙；**无跨网络环境通用修改命令** |
| K3s 端口冲突 | `ss -lntp '( sport = :6443 or sport = :2379 or sport = :2380 or sport = :10250 )'` | 新装节点在安装 K3s 前不应有未知进程占用这些端口；如果本机已运行 K3s，则按现有集群状态判断 | 查明占用进程后再决定迁移端口或停止冲突服务；**禁止直接 kill 未识别进程** |
| Master / Server 数量 | `read -rp '输入 default.ini 完整路径: ' CFG; n=$(awk '/^\[master\]/{f=1;next} /^\[/{f=0} f && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/ {n++} END{print n+0}' "$CFG"); echo "master_count=$n"; [ "$n" -ge 3 ] && [ $((n % 2)) -eq 1 ] && echo 'PASS: Master 数量为奇数且不少于 3' || echo 'FAIL: Master 数量不符合 HA 要求'` | embedded etcd HA：Master / Server 至少 3 个且为奇数；非 HA 单 Server 场景不套用该判定 | 修改部署规划或 `default.ini` 中的节点角色。**不要通过临时删除健康 Server 来“凑奇数”** |

### K3s 官方关键网络端口

以下端口按当前 K3s 官方 System Requirements 校正。是否需要开放取决于实际网络后端和功能，不应全部机械放开。

| 协议 / 端口 | 源 → 目的 | 使用条件 |
| --- | --- | --- |
| TCP/6443 | Agent → Server | K3s Supervisor / Kubernetes API，所有集群都需要 |
| TCP/2379-2380 | Server → Server | 仅 embedded etcd HA 需要 |
| UDP/8472 | 所有 Node → 所有 Node | 仅 Flannel VXLAN backend 需要；禁止暴露公网 |
| TCP/10250 | 所有 Node → 所有 Node | 使用 metrics-server / kubelet API 时需要 |
| UDP/51820 | 所有 Node → 所有 Node | 仅 Flannel WireGuard IPv4 需要 |
| UDP/51821 | 所有 Node → 所有 Node | 仅 Flannel WireGuard IPv6 需要 |
| TCP/5001 | 所有 Node → 所有 Node | 仅启用 embedded distributed registry（Spegel）时需要 |
| TCP/6443 | 所有 Node → 所有 Node | 仅 Spegel 场景额外要求节点间可达 |

> 部署前若需要验证 ACL / 安全组，应该在网络设备或策略平台上核对规则；对尚未启动 K3s 的目标主机执行 `nc -z <IP> 6443` 得到 `Connection refused` 并不能说明网络不通，只能说明当时没有服务监听该 TCP 端口。

---

# 2. 部署执行总检查表

| 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| chroot 架构 | `uname -m; getconf PAGE_SIZE` | 与 chroot / 安装介质一致 | 更换对应架构 chroot 包 |
| inventory | `cat /root/inventory.txt` | 所有节点 IP、name、角色正确，name 唯一 | 人工编辑 inventory |
| Ansible 连通 | `chroot /root/chroot_alpine ansible -i /root/inventory.txt all -m ping` | 所有节点 `SUCCESS` / `pong` | 修正 SSH、known_hosts、IP、路由 |
| 批量 DNS | `chroot /root/chroot_alpine ansible -i /root/inventory.txt all -m shell -a 'getent hosts <测试域名>'` | 所有节点都返回 IP | 修正对应节点 DNS |
| 数据盘安装参数 | `grep -E 'k3s_installer_(do_disk_probe|require_mount|do_quota_check)' <default.ini>` | 与现场磁盘方案一致 | 人工修改 `default.ini`；启用自动探盘前必须确认候选盘无数据 |
| Master / Worker | `grep -A20 -E '^\[master\]|^\[worker\]' <default.ini>` | 节点归属、IP、public_ip 正确 | 人工修改 `default.ini` |
| NodePort 范围 | `grep -n 'service-node-port-range' <default.ini>` | 与产品要求一致 | 人工修改 `extra_k3s_master_config` |
| 安装前 Gate | 重新执行第 1 节全部关键检查 | 全部 PASS | 只修失败项；全部 PASS 后再安装 |
| 执行安装 | `chroot /root/chroot_alpine /root/installer/ansible/install.sh` | 安装器正常完成，无失败节点 | 根据安装器失败项修复；**禁止绕过前置检查强装**；完成后进入第 3 节验收 |

> 自动磁盘探测、格式化、LVM 创建等属于破坏性操作。本文不提供可直接复制执行的批量格式化命令；必须先确认候选盘无业务数据并完成变更审批。

---

# 3. 安装后验收总检查表

| 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| API Ready | `kubectl get --raw='/readyz?verbose'` | 末尾 `readyz check passed` 或 API 查询持续成功 | 先查 `journalctl -u k3s`，再按根因修复；不要直接重装 |
| Node | `kubectl get nodes -o wide; kubectl describe node <异常node>` | 所有节点 `Ready`；异常节点 Conditions 可定位根因 | `NotReady` 先处理节点底层问题 |
| Pod | `kubectl get pods -A -o wide; kubectl describe pod <pod> -n <ns>; kubectl logs <pod> -n <ns> --all-containers --tail=200` | 常驻 Pod `Running/Ready`；Job 可 `Completed`；异常 Pod 能通过 describe/logs 定位 | 对异常 Pod 按第 5 节处理 |
| Events | `kubectl get events -A --sort-by='.lastTimestamp'` | 无持续重复错误 | 根据最新 Warning 事件定位 Node / 存储 / 网络 / 镜像 |
| 数据目录 | `findmnt -T /var/lib/rancher/k3s; df -hT /var/lib/rancher/k3s; df -ih /var/lib/rancher/k3s` | 挂载正确，空间与 inode 健康 | 按第 4 节“磁盘/挂载”处理 |
| CRI / containerd | `k3s crictl info; k3s crictl ps -a` | CRI 可正常响应 | 修底层磁盘/网络后再按角色重启 `k3s` / `k3s-agent` |
| PVC / PV | `kubectl get pvc -A; kubectl get pv; kubectl get storageclass` | 业务 PVC 为 `Bound`，PV 状态正常 | 修 CSI / 后端存储 / 节点挂载；**禁止先删 PVC/PV** |
| Service / Endpoint | `kubectl get svc -A; kubectl get endpoints -A; kubectl get endpointslices -A` | 有后端的 Service 对应 Endpoint 非空 | 修 Pod 标签 / selector / port / 后端 Pod；优先修 Helm/Ansible/manifest 源配置 |
| 时间 / DNS / Swap | `timedatectl; swapon --show; getent hosts <测试域名>` | 时间同步、swap 关闭、DNS 正常 | 参考第 1 节对应修正命令 |

---

# 4. 断电 / 重启后故障排查总检查表

断电后产品故障，严格按下表顺序执行。**第一个失败层就是当前优先故障点。下层未恢复时，不要先重启上层 Pod。** 修正后重新执行同一行“检查 / 验证命令”。

| 顺序 | 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| ---: | --- | --- | --- | --- |
| 1 | 主机是否反复重启 | `uptime; last -x \| head -20` | uptime 持续增长，无反复 reboot | **无安全通用命令**；查 BMC、电源、硬件告警 |
| 2 | 磁盘设备 / 挂载 | `lsblk -f; findmnt -T /var/lib/rancher/k3s` | 规划磁盘存在且挂载正确 | 若设备健康且 fstab 正确、仅挂载丢失：`mount /var/lib/rancher/k3s` |
| 3 | 磁盘空间 | `df -hT / /var /var/lib/rancher/k3s; du -xhd1 /var/lib/rancher/k3s 2>/dev/null \| sort -h` | 无 100%，保留足够业务余量；可定位主要占用目录 | 优先扩容；仅删除人工确认无用文件 |
| 4 | inode | `df -ih / /var /var/lib/rancher/k3s; du --inodes -x -d1 /var 2>/dev/null \| sort -n` | inode 未耗尽；可定位大量小文件目录 | 仅清理确认无用的小文件 |
| 5 | 磁盘 / 文件系统错误 | `dmesg -T \| grep -Ei 'I/O error|EXT4-fs error|XFS.*error|nvme.*error|blk_update_request' \| tail -100; findmnt -T /var/lib/rancher/k3s; df -hT /var/lib/rancher/k3s` | 无持续 I/O / FS 错误，挂载与空间正常 | **无在线通用修复命令**；停止上层重启，先处理硬件。`fsck/xfs_repair` 仅在备份、卸载、维护窗口执行 |
| 6 | 网卡 / IP / 路由 | `ip -br a; ip route` | 业务网卡 UP，IP 和路由正确 | 仅接口被置 DOWN 时：`ip link set <nic> up`；其他网络配置按系统网络规范修复 |
| 7 | 网关 / API 网络 | `ping -c 3 <gateway>; nc -zvw3 <server-ip> 6443` | 网关、API 地址可达 | 修正 VLAN/路由/ACL/防火墙 |
| 8 | 时间同步 | `timedatectl; chronyc tracking 2>/dev/null || true` | 时间、时区一致且同步 | `timedatectl set-ntp true`；chrony：`systemctl restart chronyd` |
| 9 | K3s Server 服务 | `systemctl is-active k3s; systemctl status k3s --no-pager -l; journalctl -u k3s -n 200 --no-pager; kubectl get nodes -o wide` | `k3s` 为 `active`，日志无持续启动失败；对应节点 `Ready` | **先修 1-8 项根因**，仍异常时：`systemctl restart k3s`；HA Server 必须逐台 |
| 10 | K3s Worker 服务 | `systemctl is-active k3s-agent; systemctl status k3s-agent --no-pager -l; journalctl -u k3s-agent -n 200 --no-pager`；Server 上执行 `kubectl get nodes -o wide` | `k3s-agent` 为 `active` 且对应 Node `Ready` | **先修底层根因**，仍异常时：`systemctl restart k3s-agent` |
| 11 | CRI / containerd | `k3s crictl info; k3s crictl ps -a; k3s crictl images` | CRI 正常响应，可读取容器 / 镜像 | K3s 内置 containerd 通常不单独 restart；修根因后按角色重启 `k3s` / `k3s-agent` |
| 12 | containerd / K3s 日志 | `tail -200 /var/lib/rancher/k3s/agent/containerd/containerd.log 2>/dev/null; journalctl -u k3s -n 200 --no-pager 2>/dev/null; journalctl -u k3s-agent -n 200 --no-pager 2>/dev/null` | 无持续 `no space left`、I/O、registry、DNS、sandbox 错误 | 按日志对应根因修复；禁止用反复 restart 掩盖问题 |
| 13 | API | `kubectl get --raw='/readyz?verbose'` | API Ready | 查 Server 日志、etcd、磁盘、时间、证书；修根因后再逐台处理 Server |
| 14 | Node 状态 | `kubectl get nodes -o wide; kubectl describe node <异常node>` | 全部 `Ready`；异常 Node 能从 Conditions/Events 定位 | 按异常节点底层问题处理 |
| 15 | Node 压力 | `kubectl describe node <node>` | `DiskPressure=False`、`MemoryPressure=False`、`PIDPressure=False` | DiskPressure→扩容/清理确认无用数据；MemoryPressure→降低异常负载/调整资源；PIDPressure→定位异常进程 |
| 16 | Pod 总体状态 | `kubectl get pods -A -o wide` | 常驻 Pod `Running/Ready`；Job 可 `Completed` | 异常 Pod 按第 5 节总表处理 |
| 17 | Pod Events / 日志 | `kubectl describe pod <pod> -n <ns>; kubectl logs <pod> -n <ns> --all-containers --tail=200` | 无持续启动、挂载、依赖错误 | 按具体错误修配置/依赖；不要先批量删 Pod |
| 18 | PVC / PV | `kubectl get pvc -A; kubectl get pv; kubectl get storageclass` | PVC `Bound`，PV 正常 | 修 CSI / 后端存储 / 节点挂载；**禁止先删除 PVC/PV** |
| 19 | Service / Endpoint | `kubectl get svc -A; kubectl get endpoints -A; kubectl get endpointslices -A` | 有后端的 Service Endpoint 非空 | 修 Pod、selector、port；优先修改 Helm/Ansible/manifest 源配置 |
| 20 | Ingress | `kubectl get ingress -A; kubectl describe ingress <name> -n <ns>; curl -kI https://<业务入口>` | backend / address / event 正常，业务入口返回预期 HTTP 响应 | 修 Ingress 规则、Service、证书或入口控制器配置 |
| 21 | 产品应用 | `kubectl logs <pod> -n <ns> --all-containers --tail=200; kubectl rollout status deployment/<name> -n <ns> 2>/dev/null || true` | 无持续 DB/Redis/MQ/DNS/证书/依赖连接错误；Deployment rollout 正常 | 先恢复依赖；确认是无状态 Deployment 且根因已修复时：`kubectl rollout restart deployment/<name> -n <ns>` |

### 单机版与集群版差异

排查顺序一致，区别只在恢复风险：

| 场景 | 排查方式 | 恢复要求 |
| --- | --- | --- |
| 单 Server / 单机 | 同样按第 4 节从底层向上排查 | `systemctl restart k3s` 会直接影响整套集群，必须先修根因 |
| 多节点、单 Server | Worker 可逐台恢复；Server 是单点 | Server 重启期间 API/control-plane 不可用 |
| HA 多 Server | 每个节点都执行同一检查链 | **Server 必须逐台重启，每台恢复 Ready 后再处理下一台，禁止同时重启** |

---

# 5. 常见 Pod 异常总处理表

修正后重复执行同一行“检查 / 验证命令”，不再单独维护验证列。

| 状态 / 现象 | 检查 / 验证命令 | 重点判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| `Evicted` | `kubectl describe pod <pod> -n <ns>; kubectl describe node <node>; df -hT / /var /var/lib/rancher/k3s; df -ih / /var /var/lib/rancher/k3s; kubectl get pods -n <ns> -o wide` | `Reason: Evicted`、DiskPressure、MemoryPressure、ephemeral-storage | **先修 Node 资源**。确认有控制器：`kubectl get pod <pod> -n <ns> -o jsonpath='{.metadata.ownerReferences[*].kind}{"\n"}'`；根因修复且确认可重建后：`kubectl delete pod <pod> -n <ns>` |
| `CrashLoopBackOff` | `kubectl logs <pod> -n <ns> --all-containers --previous --tail=200; kubectl describe pod <pod> -n <ns>; kubectl rollout status deployment/<name> -n <ns> 2>/dev/null || true` | 启动报错、配置、依赖、证书、Probe | 修配置/依赖；无状态 Deployment 可：`kubectl rollout restart deployment/<name> -n <ns>` |
| `ImagePullBackOff` / `ErrImagePull` | `kubectl describe pod <pod> -n <ns>; kubectl get events -n <ns> --sort-by='.lastTimestamp'; kubectl get pod <pod> -n <ns> -o wide` | 镜像不存在、认证、DNS、registry 网络 | 在 Pod 所在 Node 验证：`k3s crictl pull <image>`；修镜像地址、registry 网络或 `imagePullSecrets` |
| `Pending` | `kubectl describe pod <pod> -n <ns>; kubectl get pvc -n <ns>; kubectl get nodes; kubectl get pod <pod> -n <ns> -o wide` | FailedScheduling、资源不足、taint/affinity、PVC 未绑定 | 扩容资源、修存储或调度配置；**不要随意删除 taint / PVC** |
| `OOMKilled` | `kubectl describe pod <pod> -n <ns>; kubectl top pod <pod> -n <ns> 2>/dev/null || true; free -h` | 容器被 OOM 机制终止；修正后不再出现 `OOMKilled` | 确认真正内存需求后修改 Helm/manifest 的 requests/limits，或修内存泄漏 |
| `CreateContainerConfigError` | `kubectl describe pod <pod> -n <ns>; kubectl get pod <pod> -n <ns> -o wide` | ConfigMap、Secret、Volume、环境变量错误 | 修对应 ConfigMap/Secret/Volume 或源配置 |
| `FailedCreatePodSandBox` | `kubectl describe pod <pod> -n <ns>; kubectl get events -n <ns> --sort-by='.lastTimestamp'; k3s crictl info; kubectl get pod <pod> -n <ns> -o wide` | CNI、pause/sandbox 镜像、containerd、DNS/registry、磁盘 | 修 CNI/磁盘/registry；底层恢复后按角色重启 `k3s` / `k3s-agent` |
| PVC 挂载失败 | `kubectl describe pod <pod> -n <ns>; kubectl get pvc -n <ns>; kubectl get pv; kubectl get pod <pod> -n <ns> -o wide` | FailedMount / FailedAttachVolume / PVC Pending；修正后 PVC `Bound`、Pod `Ready` | 修 CSI、后端存储、Node 挂载；**不要删除 PVC/PV 试错** |

> StatefulSet（PostgreSQL、TiKV、MinIO、Redis 等）不要批量 rollout 或同时删除多个副本。必须先确认角色、数据副本和当前健康副本数，再一次只处理一个异常实例。

---

# 6. k9s 只读排查速查

排查时建议默认：

```bash
k9s --readonly
```

| 操作 | 快捷键 / 命令 | 作用 |
| --- | --- | --- |
| Pod | `:po` / `:pod` | 查看 Pod |
| Node | `:node` | 查看 Node |
| StatefulSet | `:sts` | 查看 StatefulSet |
| Deployment | `:deploy` | 查看 Deployment |
| Namespace | `:ns` | 切换 Namespace |
| Describe | `d` | 查看资源详情 / Events |
| Logs | `l` | 查看日志 |
| Shell | `s` | 进入容器 Shell |
| 搜索 | `/` | 过滤资源 |
| 帮助 | `?` | 查看当前版本完整快捷键 |
| 退出 | `:q` / `Ctrl+C` | 退出 k9s |

**危险快捷键：**

- `Ctrl+D`：Delete，需要确认；
- `Ctrl+K`：Kill / 立即删除；
- 故障排查阶段优先使用 `k9s --readonly`，避免误操作。

---

# 7. 断电后典型案例：磁盘不足 → Evicted

典型故障链：

```text
节点磁盘不足 / inode 紧张
  ↓
DiskPressure
  ↓
kubelet 驱逐 Pod（Evicted）
  ↓
image GC 可能清理未使用镜像
  ↓
FailedCreatePodSandBox / ImagePullBackOff
  ↓
产品持续故障
```

只按这一组命令排，修正后仍重复执行同一组命令验证：

```bash
# 集群侧定位异常 Pod / Node
kubectl get pods -A -o wide
kubectl describe pod <异常Pod> -n <ns>
kubectl describe node <异常Node>

# 登录异常 Node
df -hT / /var /var/lib/rancher/k3s
df -ih / /var /var/lib/rancher/k3s
findmnt -T /var/lib/rancher/k3s
du -xhd1 /var/lib/rancher/k3s 2>/dev/null | sort -h
k3s crictl images
journalctl -u k3s -n 200 --no-pager 2>/dev/null
journalctl -u k3s-agent -n 200 --no-pager 2>/dev/null
```

判定：如果 `df` / inode 异常，同时 Node 为 `DiskPressure=True`，并出现 `Evicted`、`no space left on device`、sandbox 或镜像错误，则优先故障层为**节点存储**，不是 Pod。

修复顺序：

```text
扩容 / 安全释放空间
  ↓
重复执行上面的 df + df -i + findmnt + kubectl 检查
  ↓
仅当 K3s/runtime 仍异常时，按节点角色 restart
  ↓
再次重复总检查表确认全部恢复
```

对应修正命令：

```bash
# Worker
systemctl restart k3s-agent

# Server（HA 必须逐台）
systemctl restart k3s
```

**不要因为“所有节点都扩过容”就无差别同时重启全部 K3s 节点。只有服务/runtime 仍异常的节点才需要 restart。**

---

# 8. 最终定位规则

```text
硬件异常        → 修硬件，不碰 Pod
磁盘 / FS 异常  → 修磁盘、挂载、文件系统
网络 / 时间异常 → 修系统基础环境
K3s / CRI 异常  → 修对应节点 K3s 服务
Node 压力异常   → 修 Node 资源
PVC 异常        → 修 CSI / 存储
Pod 异常        → 查日志 / 配置 / 依赖
Service 异常    → 查 Endpoint / Selector / Port
以上全部正常    → 进入产品业务自身排障
```

---

# 9. 术语速查

| 术语 | 解释 |
| --- | --- |
| `OOM / OOMKilled` | Out Of Memory；内存不足，进程被 Linux 内核 OOM 机制终止 |
| `DiskPressure` | kubelet 判断节点磁盘空间或 inode 达到压力阈值 |
| `Evicted` | Pod 被 kubelet 主动驱逐，不等于应用自行崩溃 |
| `CrashLoopBackOff` | 容器反复启动失败，Kubernetes 进入退避重试 |
| `ImagePullBackOff` | 镜像拉取失败后进入退避重试 |
| `CRI` | Container Runtime Interface；Kubernetes 与 containerd 等运行时之间的接口 |
| `CNI` | Container Network Interface；Pod 网络插件接口规范 |
| `CSI` | Container Storage Interface；Kubernetes 存储插件接口 |
| `PVC / PV` | PersistentVolumeClaim / PersistentVolume；持久卷申请 / 持久卷 |
| `inode` | 文件元数据索引节点；inode 用尽时即使磁盘仍有容量也无法新建文件 |
| `image GC` | Image Garbage Collection；kubelet/container runtime 在磁盘压力下清理未使用镜像 |
| `Probe` | Kubernetes 健康检查，包括 startup/readiness/liveness probe |
| `quorum` | 多数派；etcd HA 保持一致性和可用性所需的多数节点 |
| `StatefulSet` | 管理有状态应用的工作负载控制器，通常具有稳定 Pod 标识和持久存储 |

---

# 10. 禁止事项

1. 下层磁盘、文件系统、网络仍异常时，禁止先批量重启 Pod。
2. HA Server 禁止同时 `systemctl restart k3s`。
3. StatefulSet 禁止同时删除 / 重启多个副本。
4. 禁止删除 PVC/PV、数据库数据目录或 `/var/lib/rancher/k3s` 内容进行试错。
5. 禁止在已挂载、有业务数据的文件系统上直接运行 `fsck` / `xfs_repair`。
6. 禁止对未知磁盘执行 `mkfs`、`pvcreate`、批量 LVM 创建或自动格式化。
7. 禁止使用 `rm -rf` 清理未知 K3s/containerd 目录。
8. k9s 故障排查优先 `k9s --readonly`。

---

# 11. 参考资料

- K3s 官方文档：https://docs.k3s.io/
- K3s System Requirements：https://docs.k3s.io/zh/installation/requirements
- K3s High Availability Embedded etcd：https://docs.k3s.io/zh/datastore/ha-embedded
- K3s CLI Tools：https://docs.k3s.io/cli
- K3s FAQ / 日志：https://docs.k3s.io/zh/faq
- Kubernetes 官方文档：https://kubernetes.io/docs/home/
- Kubernetes Node-pressure Eviction：https://kubernetes.io/zh-cn/docs/concepts/scheduling-eviction/node-pressure-eviction/
- Kubernetes Debug Applications：https://kubernetes.io/docs/tasks/debug/debug-application/
- K9s Commands：https://k9scli.io/topics/commands/
- 内部来源：《牧云集群版 管理端安装部署（chroot版）》

> 原 SOP 中涉及内部 Release 平台、安装介质、资源阈值和专项文档的私有链接不复制到公开知识库；以当前交付渠道版本为准。
