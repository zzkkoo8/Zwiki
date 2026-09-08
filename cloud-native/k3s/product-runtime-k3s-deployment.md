# 产品运行底座：K3s 集群部署与故障排查手册

本文用于牧云（CloudWalker）K3s 集群的部署前检查、部署执行、安装后验收，以及断电/重启后的故障排查。

> 核心原则：**优先看总检查表。每一项只保留“检查 / 验证命令、正常反馈 / 判定、修正命令 / 处理”三类信息；修正后重复执行同一条检查命令。**
>
> 本文检查项已按内部《[牧云] 集群版 管理端安装部署（配置要求）》逐项覆盖，并保留 K3s 官方要求的补充检查。产品版本、资源计算器、安装介质和专项 SOP 的要求优先。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | K3s / Kubernetes / 产品运行底座 |
| 适用场景 | 部署前检查、部署执行、安装后验收、断电重启后故障排查 |
| 支持架构 | x86_64 / arm64 |
| 核心顺序 | 硬件 → 系统 → 网络 → 安装工具 → K3s → Node → Pod/PVC → Service → 产品 |
| 安全原则 | 先检查、再判定、后修正；禁止批量重启、批量删除、未知磁盘格式化和在线修文件系统 |
| 最后核对 | 2026-09-08 |

---

# 1. 部署前总检查表

安装前先完成本表。任意关键项失败时，先修当前项，不继续后续部署。

**命令规范：**

- 表内命令可直接复制到 Bash 执行。
- 需要现场 IP、域名或文件路径时，通过 `read` 交互输入，不使用无法直接执行的尖括号占位符。
- 表内命令不使用 Shell 管道符，避免 GitBook Markdown 表格转义后复制出错。
- 没有跨发行版、跨环境都安全的修正方式时，明确标记“无安全通用命令”。
- K3s 尚未安装时，不能以 6443、2379、2380、10250 端口是否能连接作为网络是否合格的依据；部署前只检查基础网络、策略和端口冲突。

| 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| CPU 架构 | `uname -m` | x86_64 主机输出 `x86_64`；ARM64 通常输出 `aarch64`；必须与安装介质一致 | **无安全通用修改命令**。更换匹配 CPU 架构的安装介质 |
| CPU / 内存规格 | `nproc; free -h` | 满足当前产品资源计算器对应带机量要求 | **无软件修正命令**。扩容 CPU / 内存或调整节点规格 |
| 磁盘容量规划 | `lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS; df -hT / /var` | 系统盘、数据盘容量满足当前产品资源规划；数据盘与系统盘规划清晰 | **无安全通用修改命令**。按资源规划扩容或增加独立数据盘 |
| 内核 / OS | `uname -r; cat /etc/os-release` | 满足当前产品版本支持范围；源 SOP 建议 CentOS 7.6+、Ubuntu 20.04+，最终以当前版本支持列表为准 | **无安全通用修改命令**。升级或更换受支持 OS / Kernel |
| cgroup | `if mountpoint -q /sys/fs/cgroup; then echo 'PASS: cgroup mounted'; else echo 'FAIL: cgroup not mounted'; fi; stat -fc %T /sys/fs/cgroup` | 输出 `PASS`，且能识别 cgroup 文件系统 | **无跨发行版通用修正命令**。按当前 OS 的 cgroup 配置方式处理并重启后复查 |
| ARM `lrcpc` | `if [ "$(uname -m)" = "aarch64" ]; then if grep -qw lrcpc /proc/cpuinfo; then echo 'PASS: lrcpc'; else echo 'FAIL: lrcpc missing'; fi; else echo 'SKIP: not ARM64'; fi` | x86_64 输出 `SKIP`；产品要求 `lrcpc` 的 ARM64 节点必须输出 `PASS` | **无软件修正命令**。更换兼容 CPU / 平台，或确认当前产品版本专项兼容方案 |
| Page Size | `getconf PAGESIZE` | 标准路径通常为 `4096`；源 SOP 要求 `< 64 KiB`，若输出 `65536` 必须走 64 KiB Page Size 专项兼容流程 | **禁止强改 Page Size**。按产品专项方案处理 |
| 主机名格式 | `hostname; h=$(hostname); if [[ "$h" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then echo 'PASS: hostname format'; else echo 'FAIL: hostname format'; fi` | 所有节点唯一，只使用小写字母、数字和 `-`，格式检查输出 `PASS` | `read -rp '输入新主机名: ' NEW_HOSTNAME; if [[ "$NEW_HOSTNAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then hostnamectl set-hostname "$NEW_HOSTNAME"; else echo 'ERROR: 主机名格式不合法'; fi` |
| DNS | `if grep -E '^nameserver[[:space:]]+' /etc/resolv.conf; then :; else echo 'FAIL: nameserver missing'; fi; read -rp '输入环境中应可解析的域名: ' TEST_DOMAIN; getent hosts "$TEST_DOMAIN"` | 存在有效 nameserver；目标域名能返回 IP | **无安全通用修改命令**。按当前 NetworkManager、systemd-resolved 或 netplan 配置方式修正 DNS |
| 时间 / NTP | `timedatectl status; if command -v chronyc >/dev/null 2>&1; then chronyc tracking; fi` | 所有节点时区一致，系统时间同步正常 | systemd-timesyncd：`timedatectl set-ntp true`；chrony 配置正确后：`if systemctl list-unit-files chronyd.service >/dev/null 2>&1; then systemctl restart chronyd; else systemctl restart chrony; fi` |
| Swap | `swapon --show; grep -iE '^[^#].*[[:space:]]swap[[:space:]]' /etc/fstab` | 按产品 SOP，`swapon --show` 无输出，`/etc/fstab` 无启用的 swap 项 | 临时关闭：`swapoff -a`。持久关闭需人工注释 `/etc/fstab` 中对应 swap 行 |
| firewalld | `if command -v firewall-cmd >/dev/null 2>&1; then systemctl is-active firewalld; else echo 'firewalld: not installed'; fi` | 按产品 SOP 应为 `inactive` 或未安装 | 经变更批准后：`systemctl disable firewalld --now` |
| ufw | `if command -v ufw >/dev/null 2>&1; then ufw status; else echo 'ufw: not installed'; fi` | 按产品 SOP 应为 `Status: inactive` 或未安装 | 经变更批准后：`ufw disable` |
| SELinux | `if command -v getenforce >/dev/null 2>&1; then getenforce; else echo 'SELinux: not installed'; fi` | 按产品 SOP 应为 `Disabled` 或系统不使用 SELinux | **不提供一键修改命令**。按发行版规范修改持久配置，并在维护窗口重启后复查 |
| `/var` 空间 | `df -hT /var` | 源 SOP 要求 `/var` 可用空间 `> 50G`；若 `/var` 未独立挂载，根分区可用空间建议 `> 70G` | **无安全通用清理命令**。优先扩容；只清理人工确认无业务价值的文件 |
| inode | `df -ih / /var` | inode 有充足余量，不接近 100% | 定位大量小文件：`du --inodes -x -d1 /var 2>/dev/null`；只清理人工确认无用文件 |
| 数据盘与系统盘隔离 | `lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,PKNAME; findmnt -T /var/lib/rancher/k3s` | 产品数据盘应与系统盘不在同一个规划设备上；已有挂载时能看到真实块设备 / LV | **无安全通用修改命令**。按产品磁盘规划重新设计或迁移，禁止在线直接搬 K3s 数据 |
| K3s 数据盘挂载 | `if mountpoint -q /var/lib/rancher/k3s; then echo 'PASS: dedicated mountpoint'; findmnt /var/lib/rancher/k3s; else echo 'INFO: not mounted yet'; fi` | 手工挂载方案应输出 `PASS`；自动探盘方案在安装前可为 `INFO`，但必须满足后面的候选盘要求 | 若 `/etc/fstab` 和设备已确认正确且仅漏挂载，可执行 `mount /var/lib/rancher/k3s`；其他情况按磁盘规划处理 |
| 数据目录软链接 | `if [ ! -e /var/lib/rancher/k3s ]; then echo 'INFO: data dir not created yet'; elif [ -L /var/lib/rancher/k3s ]; then echo 'FAIL: symlink'; else echo 'PASS: not symlink'; fi` | 已存在时必须输出 `PASS`；新装自动探盘场景可输出 `INFO` | **禁止直接搬迁现有 K3s 数据**。发现软链接时按维护流程迁移到真实挂载点 |
| 文件系统 / Quota | `findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /var/lib/rancher/k3s 2>/dev/null || true` | 已挂载场景应符合产品磁盘方案；使用 XFS Project Quota 时应包含对应 quota 参数 | **无安全通用修改命令**。重新格式化、改文件系统或 quota 必须在备份、卸载和维护窗口执行 |
| `nm-cloud-setup` | `if systemctl list-unit-files nm-cloud-setup.service >/dev/null 2>&1; then systemctl is-enabled nm-cloud-setup.service nm-cloud-setup.timer; else echo 'nm-cloud-setup: not installed'; fi` | 受该 NetworkManager 问题影响的旧版 RHEL / CentOS 应为 `disabled` 或未安装 | 仅适用于受影响系统：`systemctl disable nm-cloud-setup.service nm-cloud-setup.timer`；随后按维护窗口重启 |
| tmux | `if command -v tmux >/dev/null 2>&1; then tmux -V; else echo 'WARN: tmux not installed'; fi` | 建议安装并在 tmux 会话中执行长时间部署，防止 SSH 超时导致安装中断 | 按当前 OS 包管理器安装 tmux；安装过程不要依赖不稳定终端会话 |
| 安装介质目录 | `if [ -d /root/installer ]; then echo 'PASS: /root/installer exists'; find /root/installer -maxdepth 1 -type f -printf '%f\n'; else echo 'FAIL: /root/installer missing'; fi` | 最新底座包、应用包等部署介质已上传到 `/root/installer` | `mkdir -p /root/installer`；再从当前正式交付渠道上传对应版本介质 |
| 安装介质 MD5 | `read -rp '输入待校验文件完整路径: ' FILE; read -rp '输入发布方提供的 MD5: ' EXPECTED; ACTUAL=$(md5sum "$FILE" 2>/dev/null); ACTUAL=${ACTUAL%% *}; echo "expected=$EXPECTED"; echo "actual=$ACTUAL"; [ "$ACTUAL" = "$EXPECTED" ] && echo 'PASS: MD5' || echo 'FAIL: MD5'` | 输出 `PASS: MD5` | 重新从正式交付渠道获取文件，禁止使用校验失败的安装包 |
| Ansible / 依赖工具 | `for c in ansible ansible-playbook sshpass xfs_quota; do if command -v "$c" >/dev/null 2>&1; then command -v "$c"; else echo "FAIL: $c missing"; fi; done` | 四个命令均能输出可执行路径 | 按当前安装介质 / OS 的正式安装方式补齐 Ansible、sshpass、xfs_quota 等依赖 |
| inventory 文件 | `if [ -f /root/inventory.txt ]; then sed -n '1,200p' /root/inventory.txt; else echo 'FAIL: /root/inventory.txt missing'; fi` | 存在 `[all:vars]`、`[dephost]`、`[nodes]`；部署机位于 `dephost`；其他节点位于 `nodes` | 按产品 SOP 人工修正 `/root/inventory.txt`，禁止自动猜测节点角色 |
| inventory 主机名唯一 | `awk '/^[[:space:]]*[0-9A-Fa-f:.]+[[:space:]]+/ {for(i=1;i<=NF;i++) if($i ~ /^name=/){sub(/^name=/,"",$i); count[$i]++}} END{bad=0; for(n in count){print n,count[n]; if(count[n]>1)bad=1} exit bad}' /root/inventory.txt; [ $? -eq 0 ] && echo 'PASS: inventory names unique' || echo 'FAIL: duplicate inventory name'` | 输出每个 name 一次，并显示 `PASS` | 人工修改重复的 `name=`，保证每个节点主机名唯一 |
| Ansible Host Key Checking | `if command -v ansible-config >/dev/null 2>&1; then ansible-config dump --only-changed; else echo 'FAIL: ansible-config missing'; fi` | 源 SOP 要求部署阶段关闭 Host Key Checking；输出中应能确认对应配置 | 当前终端临时使用：`export ANSIBLE_HOST_KEY_CHECKING=False`；是否持久化到配置文件按部署规范决定 |
| Ansible 节点连通 | `ansible -i /root/inventory.txt all -m command -a hostname` | 所有节点返回成功且 hostname 正确 | 修正 inventory、SSH、IP、路由、认证后重新执行 |
| SSH 密钥 | `if [ -s /root/.ssh/id_ed25519.pub ]; then echo 'PASS: ed25519 public key exists'; else echo 'FAIL: ed25519 public key missing'; fi` | 输出 `PASS` | 若尚未生成：`ssh-keygen -t ed25519` |
| inventory 明文密码 | `if grep -nE '^[[:space:]]*ansible_password[[:space:]]*=' /root/inventory.txt; then echo 'FAIL: ansible_password still enabled'; else echo 'PASS: no active ansible_password'; fi` | 完成免密后应输出 `PASS` | 完成 SSH key 分发并验证后，人工删除或注释 `ansible_password` 行 |
| SSH 免密连通 | `ansible -i /root/inventory.txt all -m command -a hostname` | 删除 / 注释 `ansible_password` 后仍全部执行成功 | 修复 authorized_keys、权限、sshd 配置或 inventory 用户设置 |
| `nslookup` | `ansible -i /root/inventory.txt all -m shell -a 'if command -v nslookup >/dev/null 2>&1; then command -v nslookup; else echo FAIL; fi'` | 所有节点均输出 `nslookup` 路径；源 SOP 的 predeploy 依赖该命令 | RPM 系通常安装 `bind-utils`；Debian / Ubuntu 通常安装 `dnsutils`。生产环境按 OS 包管理规范补齐后复查 |
| fio 工具 | `ansible -i /root/inventory.txt all -m shell -a 'if command -v fio >/dev/null 2>&1; then fio --version; else echo FAIL; fi'` | 所有节点均能输出 fio 版本 | 按当前安装介质或 OS 包管理器安装 fio |
| fio 测试脚本 | `ansible -i /root/inventory.txt all -m shell -a 'test -x /root/run_fio.sh && echo PASS || echo FAIL'` | 所有节点输出 `PASS` | 将当前产品版本批准的 `run_fio_4k.sh` 下发为 `/root/run_fio.sh` 并赋予执行权限 |
| 磁盘 IOPS | `ansible -i /root/inventory.txt all -m shell -a 'test -d /root/fio-output && find /root/fio-output -maxdepth 1 -type f -name "*write.4K.*" -print || echo FAIL'` | 生产环境必须完成当前批准的 fio 测试，并按产品资源需求阈值判定通过 | **禁止对有数据的系统盘直接做裸盘测试**。无独立空数据盘时使用测试文件方式；未达到阈值时更换 / 扩容存储 |
| 节点基础互通 | `read -rp '输入对端节点 IP/主机名: ' PEER; ping -c 3 "$PEER"` | 能收到 ICMP Reply；同时需网络侧核对产品和 K3s 端口策略 | 修正 IP、VLAN、路由、ACL、安全组或主机防火墙 |
| K3s 本机端口冲突 | `ss -lntp '( sport = :6443 or sport = :2379 or sport = :2380 or sport = :10250 )'` | 新装节点不应有未知进程占用 K3s 关键端口 | 查明占用进程后再处理；**禁止直接 kill 未识别进程** |

## 1.1 产品网络策略要求

源 SOP 明确要求以下策略。部署前应在交换机、ACL、安全组或防火墙策略平台确认；因为产品服务尚未启动，不能仅用 `nc` 的结果替代策略核对。

| 源 | 目的 | TCP 端口 | 要求 |
| --- | --- | --- | --- |
| 管理员 PC | Server Nodes | 443 | Web HTTPS |
| 管理员 PC | Server Nodes | 22 | SSH 管理 |
| Agent | Server Nodes | 50051 | 探针通信 |
| Agent | Server Nodes | 80 | 探针升级 |
| Agent | Server Nodes | 30399 | 拟态防护通信 |
| Server Nodes | Server Nodes | any | 集群和产品服务间通信 |

产品安装完成后，可从**对应源网络**执行以下命令验证目标 Server 实际监听 / 连通状态：

```bash
read -rp '输入 Server IP: ' SERVER_IP
for p in 22 80 443 50051 30399; do
  echo "=== TCP/$p ==="
  nc -zvw3 "$SERVER_IP" "$p"
done
```

> 某端口在对应服务尚未安装 / 启动时返回 `Connection refused`，只能说明没有服务监听，不能单独证明 ACL 阻断。

## 1.2 K3s 官方关键网络端口

| 协议 / 端口 | 源 → 目的 | 使用条件 |
| --- | --- | --- |
| TCP/6443 | Agent → Server | K3s Supervisor / Kubernetes API |
| TCP/2379-2380 | Server → Server | embedded etcd HA |
| UDP/8472 | 所有 Node → 所有 Node | Flannel VXLAN，禁止暴露公网 |
| TCP/10250 | 所有 Node → 所有 Node | kubelet / metrics-server 等场景 |
| UDP/51820 | 所有 Node → 所有 Node | Flannel WireGuard IPv4 |
| UDP/51821 | 所有 Node → 所有 Node | Flannel WireGuard IPv6 |
| TCP/5001 | 所有 Node → 所有 Node | Spegel embedded registry |

---

# 2. 部署执行总检查表

本节覆盖源 SOP 中安装准备、predeploy、`default.ini` 和底座安装阶段的要求。

| 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| predeploy 文件 | `if [ -f /root/utils/cluster/predeploy/predeploy-configure.yaml ]; then echo 'PASS: predeploy playbook exists'; else echo 'FAIL: predeploy playbook missing'; fi` | 输出 `PASS` | 从当前正式部署介质恢复正确版本的 utils / predeploy 文件 |
| predeploy 执行 | `ansible-playbook -i /root/inventory.txt /root/utils/cluster/predeploy/predeploy-configure.yaml --check 2>/dev/null || true` | `--check` 用于预检查；真正执行前确认客户允许该 playbook 修改配置并可能导致后续重启 | 真正执行属于配置变更：`ansible-playbook -i /root/inventory.txt /root/utils/cluster/predeploy/predeploy-configure.yaml`；按变更窗口执行 |
| predeploy 后节点回连 | `ansible -i /root/inventory.txt all -m command -a hostname` | 所有节点均能成功返回 hostname | 若 predeploy / 重启后节点不可达，先修系统、网络、SSH，不继续安装 |
| `default.ini` 文件 | `if [ -f /root/installer/ansible/inventory/default.ini ]; then echo 'PASS: default.ini exists'; else echo 'FAIL: default.ini missing'; fi` | 输出 `PASS` | 从同版本 `default.ini.example` 复制后人工填写；禁止直接照抄其他项目 IP |
| 本机 IP 与配置 IP | `ip -br addr; sed -n '/^\[master\]/,/^\[all:vars\]/p' /root/installer/ansible/inventory/default.ini` | `[master]` / `[worker]` 第一列 IP 必须是对应节点本机真实可达地址 | 人工修改错误 IP；NAT / EIP / BIP 等映射地址写到 `public_ip` |
| `public_ip` | `grep -nE '^[[:space:]]*[0-9A-Fa-f:.]+[[:space:]]+public_ip=' /root/installer/ansible/inventory/default.ini` | 有外部映射地址时填映射地址；无映射时可与本机 IP 一致 | 人工修正 `public_ip`，禁止把不存在于实际网络规划中的地址作为节点本机 IP |
| Master 数量 | `CFG=/root/installer/ansible/inventory/default.ini; n=$(awk '/^\[master\]/{f=1;next} /^\[/{f=0} f && $0 !~ /^[[:space:]]*#/ && $0 !~ /^[[:space:]]*$/ {n++} END{print n+0}' "$CFG"); echo "master_count=$n"` | 单 Server 可为 1 但无 HA；生产 HA 至少 3 个且应使用奇数。源 SOP：总节点 `<= 9` 时通常取前 3 个 Master，`> 9` 时可规划前 5 个 | 人工调整节点角色；不要通过临时删除健康 Server 凑奇数 |
| Worker 规划 | `sed -n '/^\[worker\]/,/^\[all:vars\]/p' /root/installer/ansible/inventory/default.ini` | Worker 可为 0 或任意数量；通常为除 Master 外的其余节点 | 人工按项目容量和角色规划修正 |
| `ansible_user` | `grep -nE '^[[:space:]]*ansible_user[[:space:]]*=' /root/installer/ansible/inventory/default.ini` | 与实际 SSH 登录用户一致，例如 `root` 或 `ubuntu` | 人工改成实际 SSH 用户并重新执行 Ansible 连通性检查 |
| 自动探盘参数 | `grep -nE '^[[:space:]]*k3s_installer_(do_disk_probe|require_mount|do_quota_check|change_hostname)[[:space:]]*=' /root/installer/ansible/inventory/default.ini` | 源 SOP 要求 `do_disk_probe=true`、`require_mount=true`；使用 quota 时建议 `do_quota_check=true`；无特殊要求 `change_hostname=true` | 人工修改 `default.ini`，修改后重新 grep |
| 自动探盘候选盘 | `lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS` | 候选数据盘应 `> 10G`、未挂载、无业务数据；设备名需符合 `k3s_installer_disk_probe_devices` 规划 | **禁止自动格式化未知磁盘**。先确认盘符、容量、挂载和数据归属，再决定是否启用自动探盘 |
| 自动探盘大小 / 设备 | `grep -nE '^[[:space:]]*k3s_installer_disk_probe_(limit|devices)[[:space:]]*=' /root/installer/ansible/inventory/default.ini || true` | 未显式配置时按安装器默认值；若配置，必须与现场盘符和 `>10G` 要求一致 | 人工修正 limit / devices；禁止把系统盘加入候选设备 |
| K3s 挂载点 | `grep -nE '^[[:space:]]*k3s_installer_mount_point[[:space:]]*=' /root/installer/ansible/inventory/default.ini || true` | 默认 / 规划挂载点为 `/var/lib/rancher/k3s` | 若项目无专项要求，不要随意更改；存在专项规划时按对应 SOP |
| Rancher hostname | `grep -nE '^[[:space:]]*k3s_rancher_hostname[[:space:]]*=' /root/installer/ansible/inventory/default.ini || true` | 若自定义域名，DNS 必须指向集群中计划承载入口的 Server IP | 修正 DNS 或 `k3s_rancher_hostname`，修改后执行 `getent hosts` 验证 |
| NodePort 范围 | `grep -n 'service-node-port-range=20000-50052' /root/installer/ansible/inventory/default.ini` | 源 SOP 要求包含 `service-node-port-range=20000-50052` | 人工修正 `extra_k3s_master_config` |
| `extra_k3s_config` | `grep -nE '^[[:space:]]*extra_k3s_config[[:space:]]*=' /root/installer/ansible/inventory/default.ini` | 无额外配置时源 SOP 示例为 `extra_k3s_config = ""` | 仅按当前产品专项要求增加参数，禁止无依据追加 K3s 参数 |
| Ubuntu PythonPath | `if grep -qi '^ID=ubuntu' /etc/os-release; then printf '%s\n' "${PYTHONPATH:-UNSET}"; else echo 'SKIP: not Ubuntu'; fi` | Ubuntu 源 SOP 要求安装前设置 `PYTHONPATH=/usr/lib/python3/dist-packages` | Ubuntu 当前 shell 执行：`export PYTHONPATH=/usr/lib/python3/dist-packages` |
| 安装脚本 | `if [ -x /root/installer/ansible/install.sh ]; then echo 'PASS: install.sh executable'; else echo 'FAIL: install.sh missing or not executable'; fi` | 输出 `PASS` | 从正确版本安装介质恢复脚本并确认权限；禁止混用不同版本 installer |
| K3s 安装 | `/root/installer/ansible/install.sh` | 安装器前置检查全部通过并正常完成 | 任一前置检查失败时只修失败项，**禁止绕过安装器检查强装** |

> 节点重启、自动磁盘格式化、LVM / XFS 创建等均属于高影响操作。源 SOP 中虽有相关执行步骤，本手册只保留检查和受控入口；必须在客户确认、备份和维护窗口条件下执行。

---

# 3. 安装后验收总检查表

| 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| K3s API | `kubectl get --raw='/readyz?verbose'` | API Ready；末尾通常能看到 `readyz check passed` | 先查 `journalctl -u k3s`、etcd、磁盘、时间和证书，再按根因修复 |
| Node | `kubectl get nodes -o wide` | 所有 Master / Worker 均为 `Ready`；Master 角色符合规划 | `NotReady` 先执行 `kubectl describe node` 定位对应节点，不直接重装 |
| Pod | `kubectl get pods -A -o wide` | 常驻 Pod 为 `Running/Ready`；一次性 Job 可为 `Completed` | 异常 Pod 先 `describe` / `logs`，按第 6 节处理 |
| Events | `kubectl get events -A --sort-by='.lastTimestamp'` | 无持续重复的 Warning、磁盘、网络、镜像、存储或调度错误 | 按最新重复事件定位 Node / 存储 / 网络 / 镜像根因 |
| K3s 数据目录 | `findmnt -T /var/lib/rancher/k3s; df -hT /var/lib/rancher/k3s; df -ih /var/lib/rancher/k3s` | 安装后必须挂载到规划的数据盘，容量和 inode 健康 | 修磁盘 / 挂载根因；禁止直接删除 `/var/lib/rancher/k3s` |
| CRI / containerd | `k3s crictl info; k3s crictl ps -a; k3s crictl images` | CRI 正常响应，可读取容器和镜像 | 修底层磁盘 / 网络后，再按节点角色重启 `k3s` 或 `k3s-agent` |
| PVC / PV | `kubectl get pvc -A; kubectl get pv; kubectl get storageclass` | 业务 PVC 为 `Bound`，PV 状态正常 | 修 CSI、后端存储或节点挂载；**禁止先删 PVC / PV** |
| Service / Endpoint | `kubectl get svc -A; kubectl get endpoints -A; kubectl get endpointslices -A` | 有后端的 Service 对应 Endpoint 非空 | 修 Pod、selector、port 或源 manifest / Helm / Ansible 配置 |
| 产品入口配置 | `kubectl get ingress -A; kubectl get svc -A` | 产品安装时指定的 `server.ingress` 域名 / IP 与证书、DNS、Service 入口一致 | 修 DNS、证书、Ingress 或产品安装参数；不要只改运行中的临时对象 |
| 产品业务端口 | `read -rp '输入 Server IP: ' SERVER_IP; for p in 22 80 443 50051 30399; do echo "=== TCP/$p ==="; nc -zvw3 "$SERVER_IP" "$p"; done` | 从对应源网络执行时，已启用的产品端口可达；50051 是否启用取决于产品 preset / 版本 | 修 ACL、Service / NodePort、产品 preset 或对应服务 |
| 产品模块版本 | `kubectl get pods -A -o wide` | 产品组件运行正常；模块版本还需在产品升级平台 / 当前交付渠道确认是否为要求版本 | 无通用一键命令；按产品升级流程更新到当前批准版本 |

---

# 4. 产品安装与版本相关检查

这些项目来自源 SOP 的产品安装阶段，不属于裸 K3s 本身，但属于完整交付验收的一部分。

| 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| `server.ingress` | `kubectl get ingress -A -o wide` | 安装时使用的平台对外 hostname / IP 与实际访问地址一致 | 按当前产品安装方式修正 values / 安装参数，再执行产品升级 / 重配置流程 |
| `NodePort50051` preset | `kubectl get svc -A` | 需要探针使用 50051 时，产品安装应启用对应 preset，Service / NodePort 与产品版本设计一致 | 按产品安装 / 升级参数启用 `NodePort50051`；变更前确认版本支持 |
| `PullPolicyAlways` preset | `kubectl get pods -A -o yaml` | 生产环境通常不建议启用 Always 拉取策略；测试环境按需求使用 | 按当前产品 values / preset 调整；不要在生产环境无依据启用 |
| proxy 部署形态 | `kubectl get daemonset,deployment -A; kubectl get pods -A -o wide` | 源 SOP：23.09.x 起 proxy 为 DaemonSet，无需手工调副本；更老版本若为 Deployment，应保证每个 Node 有 proxy Pod | 老版本仅在确认产品版本和部署形态后调整 Deployment 副本；**不要在 23.09.x+ DaemonSet 场景套用旧命令** |
| proxy 节点覆盖 | `kubectl get nodes -o wide; kubectl get pods -A -o wide` | 需要 proxy 的产品版本中，每个目标 Node 都有对应健康 Pod | 先查调度、资源和版本部署方式，再按产品 SOP 调整 |
| 引擎 / 模块更新 | `kubectl get pods -A -o wide` | 集群健康后，还应按当前产品版本要求确认各模块包是否为批准版本 | 从正式升级服务平台获取兼容更新包，按产品升级 SOP 执行 |

---

# 5. 数据库独占与 HugePage（可选）

仅在当前产品版本和项目容量方案要求时使用。源 SOP 建议探针数量超过约 2 万时评估数据库独占。

| 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| DB 专用节点资源 | `nproc; free -h; df -hT` | 规划 3 个 DB 节点；每个至少 8C / 16G，且磁盘性能满足产品要求 | 扩容资源或重新规划 DB 节点 |
| HugePage 当前值 | `grep -E 'HugePages_Total|HugePages_Free|Hugepagesize' /proc/meminfo` | 源 SOP 最低建议预留约 4096MB；默认 2MiB HugePage 时 `vm.nr_hugepages` 至少约 2048，具体值按项目容量评估 | **高风险参数，不提供自动计算写入命令**。由研发 / 项目方案确认后修改 `/etc/sysctl.conf` |
| HugePage 配置值 | `sysctl vm.nr_hugepages` | 与已批准的 DB 内存 / shared buffer 规划一致 | 批准后使用 `sysctl -p` 应用持久配置；必要重启必须在维护窗口执行 |
| DB 节点标签 | `kubectl get nodes --show-labels` | 规划的 DB 节点包含 `run-db=true` | 对确认无误的目标节点执行 `kubectl label node NODE_NAME run-db=true --overwrite`，其中 `NODE_NAME` 需替换为实际节点名 |
| 产品 preset | `kubectl get pods -A -o wide` | 采用独占 DB + HugePage 时，产品安装参数应包含当前版本要求的 `ExclusiveDB` / `HugePage` preset | 按产品版本的 values / preset 流程修正，不直接修改数据库 Pod |

---

# 6. 断电 / 重启后故障排查总检查表

断电后产品持续故障时严格按顺序执行。**第一个失败层就是当前优先故障点；下层未恢复时，不先重启上层 Pod。**

| 顺序 | 检查项 | 检查 / 验证命令 | 正常反馈 / 判定 | 修正命令 / 处理 |
| ---: | --- | --- | --- | --- |
| 1 | 主机是否反复重启 | `uptime; last -x | head -20` | uptime 持续增长，无反复 reboot | **无安全通用命令**。检查 BMC、电源、硬件告警 |
| 2 | 磁盘设备 / 挂载 | `lsblk -f; findmnt -T /var/lib/rancher/k3s` | 规划磁盘存在且挂载正确 | 若设备健康且 fstab 正确、仅漏挂载：`mount /var/lib/rancher/k3s` |
| 3 | 磁盘空间 / inode | `df -hT / /var /var/lib/rancher/k3s; df -ih / /var /var/lib/rancher/k3s` | 空间和 inode 均有余量 | 优先扩容；只清理人工确认无用文件 |
| 4 | 文件系统 / I/O 错误 | `dmesg -T | grep -Ei 'I/O error|EXT4-fs error|XFS.*error|nvme.*error|blk_update_request' | tail -100` | 无持续 I/O / FS 错误 | **无在线通用修复命令**。先处理硬件；`fsck` / `xfs_repair` 仅在备份、卸载和维护窗口执行 |
| 5 | 网卡 / 路由 | `ip -br a; ip route` | 业务网卡 UP，IP 和路由正确 | 仅接口 DOWN 时可执行 `ip link set DEV up`，其中 `DEV` 替换为实际网卡；其他网络配置按 OS 规范修复 |
| 6 | 网关 / API 网络 | `read -rp '输入网关 IP: ' GW; ping -c 3 "$GW"; read -rp '输入 K3s Server IP: ' SERVER; nc -zvw3 "$SERVER" 6443` | 网关可达；K3s 已运行时 6443 可达 | 修 VLAN、路由、ACL、防火墙或 K3s Server 服务 |
| 7 | 时间同步 | `timedatectl status; if command -v chronyc >/dev/null 2>&1; then chronyc tracking; fi` | 时间、时区一致且同步 | 按第 1 节 NTP 修正方式处理 |
| 8 | K3s Server | `systemctl is-active k3s; systemctl status k3s --no-pager -l; journalctl -u k3s -n 200 --no-pager` | `active`，日志无持续启动失败 | **先修 1-7 项根因**；仍异常时 `systemctl restart k3s`。HA Server 必须逐台 |
| 9 | K3s Agent | `systemctl is-active k3s-agent; systemctl status k3s-agent --no-pager -l; journalctl -u k3s-agent -n 200 --no-pager` | `active` 且能连接 Server | **先修底层根因**；仍异常时 `systemctl restart k3s-agent` |
| 10 | CRI / containerd | `k3s crictl info; k3s crictl ps -a; k3s crictl images` | CRI 正常响应，可读取容器 / 镜像 | K3s 内置 containerd 通常不单独 restart；按节点角色重启 K3s 服务 |
| 11 | API / Node | `kubectl get --raw='/readyz?verbose'; kubectl get nodes -o wide` | API Ready，全部 Node `Ready` | `NotReady` 先 `kubectl describe node NODE_NAME` 定位节点根因 |
| 12 | Node 压力 | `kubectl describe node NODE_NAME` | `DiskPressure=False`、`MemoryPressure=False`、`PIDPressure=False` | DiskPressure→扩容 / 清理确认无用数据；MemoryPressure→修异常负载 / 资源；PIDPressure→定位异常进程 |
| 13 | Pod | `kubectl get pods -A -o wide` | 常驻 Pod `Running/Ready`；Job 可 `Completed` | 异常 Pod 按第 7 节处理 |
| 14 | PVC / PV | `kubectl get pvc -A; kubectl get pv; kubectl get storageclass` | PVC `Bound`，PV 正常 | 修 CSI / 后端存储 / Node 挂载；禁止先删除 PVC / PV |
| 15 | Service / Endpoint | `kubectl get svc -A; kubectl get endpoints -A; kubectl get endpointslices -A` | 有后端的 Service Endpoint 非空 | 修 Pod、selector、port 或源配置 |
| 16 | Ingress / 产品 | `kubectl get ingress -A; kubectl get pods -A -o wide` | Ingress、产品依赖和业务 Pod 正常 | 先恢复数据库 / Redis / MQ / DNS / 证书等依赖，再处理应用 |

## 单机版与集群版差异

| 场景 | 排查方式 | 恢复要求 |
| --- | --- | --- |
| 单 Server / 单机 | 同样按第 6 节从底层向上排查 | `systemctl restart k3s` 会影响整套集群，必须先修根因 |
| 多节点、单 Server | Worker 可逐台恢复，Server 是单点 | Server 重启期间 API / control-plane 不可用 |
| HA 多 Server | 每个节点执行同一检查链 | Server 必须逐台重启，每台恢复 Ready 后再处理下一台 |

---

# 7. 常见 Pod 异常总处理表

| 状态 / 现象 | 检查 / 验证命令 | 重点判定 | 修正命令 / 处理 |
| --- | --- | --- | --- |
| `Evicted` | `kubectl describe pod POD_NAME -n NAMESPACE; kubectl describe node NODE_NAME; df -hT / /var /var/lib/rancher/k3s; df -ih / /var /var/lib/rancher/k3s` | `Reason: Evicted`、DiskPressure、MemoryPressure、ephemeral-storage | **先修 Node 资源**。确认 Pod 有控制器且根因修复后再删除旧 Evicted Pod |
| `CrashLoopBackOff` | `kubectl logs POD_NAME -n NAMESPACE --all-containers --previous --tail=200; kubectl describe pod POD_NAME -n NAMESPACE` | 启动错误、配置、依赖、证书、Probe | 修配置 / 依赖；无状态 Deployment 根因修复后可 rollout restart |
| `ImagePullBackOff` / `ErrImagePull` | `kubectl describe pod POD_NAME -n NAMESPACE; kubectl get events -n NAMESPACE --sort-by='.lastTimestamp'` | 镜像不存在、认证、DNS、registry 网络 | 在 Pod 所在 Node 使用 `k3s crictl pull IMAGE` 验证；修镜像地址、registry 或 imagePullSecrets |
| `Pending` | `kubectl describe pod POD_NAME -n NAMESPACE; kubectl get pvc -n NAMESPACE; kubectl get nodes` | FailedScheduling、资源、taint / affinity、PVC | 扩容资源、修存储或调度配置；不要随意删除 taint / PVC |
| `OOMKilled` | `kubectl describe pod POD_NAME -n NAMESPACE; free -h` | 容器被 OOM 机制终止 | 按真实内存需求修改 requests / limits，或修内存泄漏 |
| `CreateContainerConfigError` | `kubectl describe pod POD_NAME -n NAMESPACE` | ConfigMap、Secret、Volume、环境变量 | 修源配置，不通过反复删 Pod 试错 |
| `FailedCreatePodSandBox` | `kubectl describe pod POD_NAME -n NAMESPACE; k3s crictl info` | CNI、pause / sandbox 镜像、containerd、DNS / registry、磁盘 | 修 CNI / 磁盘 / registry；底层恢复后按角色重启 K3s 服务 |
| PVC 挂载失败 | `kubectl describe pod POD_NAME -n NAMESPACE; kubectl get pvc -n NAMESPACE; kubectl get pv` | FailedMount、FailedAttachVolume、PVC Pending | 修 CSI、后端存储、Node 挂载；禁止删除 PVC / PV 试错 |

> `POD_NAME`、`NAMESPACE`、`NODE_NAME`、`IMAGE` 是示例变量名，不是可直接执行的真实值。现场建议优先通过 k9s 或 `kubectl get ...` 获取真实对象名后再执行对应命令。

---

# 8. k9s 只读排查速查

故障排查建议默认：

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
| Describe | `d` | 查看详情 / Events |
| Logs | `l` | 查看日志 |
| Shell | `s` | 进入容器 Shell |
| 搜索 | `/` | 过滤资源 |
| 帮助 | `?` | 以当前 k9s 版本显示的快捷键为准 |
| 退出 | `:q` / `Ctrl+C` | 退出 k9s |

危险操作：`Ctrl+D` 为 Delete，`Ctrl+K` 为立即 Kill。排障阶段优先使用 `--readonly`。

---

# 9. 典型故障：磁盘不足 → Evicted

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
产品持续异常
```

判断依据：`df` / inode 异常、Node `DiskPressure=True`，并出现 `Evicted`、`no space left on device`、sandbox 或镜像错误时，优先故障层是**节点存储**，不是 Pod。

恢复原则：

```text
扩容 / 安全释放空间
  ↓
重复 df / df -i / findmnt / Node 检查
  ↓
仅当 K3s / runtime 仍异常时按节点角色 restart
  ↓
重新执行 Node / Pod / Events 检查
```

---

# 10. 术语速查

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
| `image GC` | Image Garbage Collection；磁盘压力下清理未使用镜像 |
| `Probe` | Kubernetes startup / readiness / liveness 健康检查 |
| `quorum` | 多数派；etcd HA 保持一致性和可用性所需的多数节点 |
| `StatefulSet` | 管理有状态应用的工作负载控制器，通常具有稳定 Pod 标识和持久存储 |
| `HugePage` | Linux 大页内存机制；可减少页表开销，但会预留内存，配置错误可能影响系统可用内存 |

---

# 11. 禁止事项

1. 下层磁盘、文件系统、网络仍异常时，禁止先批量重启 Pod。
2. HA Server 禁止同时执行 `systemctl restart k3s`。
3. StatefulSet 禁止同时删除 / 重启多个副本。
4. 禁止删除 PVC / PV、数据库数据目录或 `/var/lib/rancher/k3s` 内容进行试错。
5. 禁止在已挂载、有业务数据的文件系统上直接运行 `fsck` / `xfs_repair`。
6. 禁止对未知磁盘执行 `mkfs`、`pvcreate`、批量 LVM 创建或自动格式化。
7. 禁止使用 `rm -rf` 清理未知 K3s / containerd 目录。
8. 未确认产品版本前，禁止套用旧版 proxy Deployment 扩容操作。
9. HugePage、数据库独占、系统重启、批量 predeploy 等高影响操作必须按项目方案和维护窗口执行。
10. k9s 故障排查优先使用 `k9s --readonly`。

---

# 12. 参考资料

- K3s 官方文档：https://docs.k3s.io/
- K3s System Requirements：https://docs.k3s.io/zh/installation/requirements
- K3s High Availability Embedded etcd：https://docs.k3s.io/zh/datastore/ha-embedded
- K3s CLI Tools：https://docs.k3s.io/cli
- K3s FAQ / 日志：https://docs.k3s.io/zh/faq
- Kubernetes 官方文档：https://kubernetes.io/docs/home/
- Kubernetes Node-pressure Eviction：https://kubernetes.io/zh-cn/docs/concepts/scheduling-eviction/node-pressure-eviction/
- Kubernetes Debug Applications：https://kubernetes.io/docs/tasks/debug/debug-application/
- K9s Commands：https://k9scli.io/topics/commands/
- 内部来源：《[牧云] 集群版 管理端安装部署（配置要求）》
- 内部来源：《[牧云] 集群版 管理端安装部署（chroot版）》

> 内部 Release 平台、安装介质、资源阈值和专项文档的私有链接不复制到公开知识库；以当前正式交付渠道版本为准。
