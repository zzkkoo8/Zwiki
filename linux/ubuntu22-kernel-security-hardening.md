# Ubuntu22 内核漏洞安全加固

本文用于 Ubuntu 22.04 LTS（Jammy）服务器的内核漏洞修复。目标是**只升级 GA 5.15 内核及其必要依赖**，不执行整机 `apt upgrade`，并在升级前完成包管理、启动分区、回退能力等硬性检查。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | Linux / Ubuntu / Kernel / 安全加固 |
| 适用范围 | Ubuntu 22.04 LTS Server，amd64，GA 5.15 内核 |
| 适用版本 | Ubuntu 22.04.x LTS（Jammy） |
| 文档状态 | 已验证（标准流程 + 产品定制系统特殊场景实测） |
| 最后验证 | 2026-09-02 |
| 修复目标 | CVE-2026-43284、CVE-2026-46300 |
| Canonical GA 修复基线 | `linux` package version `>= 5.15.0-181.191` |
| 来源 | Canonical / Ubuntu 官方资料 + 实机测试记录 |

## 1. 结论

Ubuntu 22.04 Server 默认 GA 内核轨道为 5.15。本次漏洞无需为了安全修复主动切换 HWE 6.8；继续升级 GA 5.15 即可。

Canonical 对 Ubuntu 22.04 Jammy 的两个漏洞均给出 GA 修复基线：

```text
5.15.0-181.191
```

当前仓库 Candidate 应以目标主机执行以下命令得到的结果为准，不要把文档中的示例版本写死为长期目标：

```bash
apt-cache policy linux-generic
```

如果目标仅是升级内核，不希望把系统中其他可升级软件一起更新，推荐流程是：

```bash
sudo apt-get update
apt-cache policy linux-generic
sudo apt-get -s install linux-generic
sudo apt-get install linux-generic
```

不要把下面命令作为本文的内核升级主流程：

```bash
sudo apt upgrade
```

`apt upgrade` 面向系统已安装软件包的整体升级；本文只针对 `linux-generic` 及 APT 为它解析出的必要依赖。

> **产品定制系统例外：** 如果设备的 `/boot`、EFI、GRUB、initramfs 或 kernel 更新链被产品厂商改造，不能仅根据 `/etc/os-release` 判断它可直接使用 Ubuntu 原生 `linux-generic`。先执行第 3 章检查；若命中第 8 章特殊场景，停止标准升级，按产品兼容性或临时缓解流程处理。

---

## 2. `dpkg`、`apt` 与 `apt-get` 的关系

- `dpkg` 是底层 Debian 包管理器，负责 `.deb` 的解包、配置和状态数据库。
- `apt` / `apt-get` 位于更高层，负责软件源、依赖解析和下载，最终仍调用 `dpkg` 完成安装。
- `apt install linux-generic` 与 `apt-get install linux-generic` 在交互式安装结果上通常一致；脚本和生产 SOP 更推荐 `apt-get`，接口和输出更稳定。

### 为什么升级前要求 `dpkg --audit` 无输出

执行：

```bash
sudo dpkg --audit
```

正常结果：**无输出**。

如果出现：

```text
unpacked but not yet configured
half installed
```

或者 `dpkg -l` 中有 `iF`、`iU`、`pH` 等异常状态，说明之前的安装事务尚未完成。此时再执行 `apt-get install linux-generic`，APT 可能先尝试配置这些异常包，导致整个新内核安装再次失败。

可以先尝试：

```bash
sudo dpkg --configure -a
```

然后再次确认：

```bash
sudo dpkg --audit
```

如果仍有输出，**停止升级，先解决现有包故障**。

对于第 8 章所述 `/boot=vfat` 产品定制系统，如果 `dpkg --configure -a` 已经明确因为 hard-link / symlink 能力不足而失败，不要反复执行该命令；先停止 APT/DPKG 内核事务并进入产品特殊场景处置。

---

# 3. 环境检查与备份

本章是在线和离线升级的共同前置条件。硬检查未通过时不要继续安装新内核。

## 3.1 系统与架构

```bash
cat /etc/os-release
uname -r
dpkg --print-architecture
```

本文要求至少确认：

```text
VERSION_ID="22.04"
VERSION_CODENAME=jammy
amd64
```

`uname -r` 记录的是**当前已经启动并正在运行的内核**。安装新内核后、重启之前，它仍会显示旧版本。

## 3.2 检查包管理状态

```bash
sudo dpkg --audit
```

必须无输出。

再查看当前内核相关包：

```bash
dpkg -l | grep -E 'linux-(generic|image|modules|headers|base)'
```

检查是否有 hold：

```bash
apt-mark showhold
```

如果 `linux-generic`、`linux-image-generic`、`linux-headers-generic` 被 hold，应先确认原因，不要直接解除。

## 3.3 检查当前 GA 元包和 Candidate

```bash
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' linux-generic 2>/dev/null || true
```

```bash
apt-cache policy linux-generic linux-image-generic
```

如果当前运行 5.15，但 `linux-generic` 未安装，通常说明产品镜像曾手工安装 versioned kernel、删除过元包，或者使用定制 kernel 管理方式。确认产品允许标准 Ubuntu kernel 更新后，安装 `linux-generic` 可以重新建立 GA 内核跟踪关系。

## 3.4 检查 `/boot` 文件系统

```bash
findmnt /
findmnt /boot
findmnt /boot/efi 2>/dev/null || true
```

标准 Ubuntu kernel package 需要 `/boot` 具备 Linux 文件系统正常的 hard-link / symlink 语义。

如果看到：

```text
/boot  ...  vfat
```

**停止升级。**

本项目在产品打包 Ubuntu 22.04.5 中已实测：把 VFAT/FAT16 分区直接挂到 `/boot` 会导致标准 `linux-image` 安装失败。

进一步做 `/boot` hard-link 测试：

```bash
sudo bash -c 't=/boot/.kernel-hardlink-test.$$; : > "$t"; ln "$t" "$t.link"; rc=$?; ls -li "$t" "$t.link" 2>/dev/null || true; rm -f "$t" "$t.link"; exit $rc'
```

成功条件：命令退出码为 0，两个测试文件 inode 相同。

如果出现：

```text
Operation not permitted
```

禁止继续 kernel update，转第 8 章。

## 3.5 检查 `/boot` 空间

```bash
df -h /boot
df -Pm /boot
```

建议生产环境预留至少约 500 MiB 可用空间。不要为了腾空间直接执行 `apt autoremove`；升级和回退窗口结束前必须保留当前正在运行的旧内核。

查看现有启动文件：

```bash
ls -lh /boot/vmlinuz-* /boot/initrd.img-* 2>/dev/null
```

## 3.6 DKMS、Secure Boot 和关键业务

```bash
command -v dkms >/dev/null && dkms status || echo "DKMS not installed"
```

```bash
command -v mokutil >/dev/null && mokutil --sb-state || echo "mokutil not installed"
```

若存在 NVIDIA、ZFS、VMware、第三方网卡/RAID 等 out-of-tree module，必须确认对目标 kernel ABI 的兼容性。

记录网络和业务基线：

```bash
ip -br addr
ip route
systemctl --failed --no-pager
command -v docker >/dev/null && docker ps -a || true
```

## 3.7 升级前备份

```bash
BK="/root/kernel-upgrade-backup-$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p "$BK"
echo "$BK"
```

```bash
uname -a | sudo tee "$BK/uname-a.txt" >/dev/null
cat /etc/os-release | sudo tee "$BK/os-release.txt" >/dev/null
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' | sudo tee "$BK/dpkg-packages.txt" >/dev/null
lsblk -f | sudo tee "$BK/lsblk.txt" >/dev/null
findmnt | sudo tee "$BK/findmnt.txt" >/dev/null
ip addr | sudo tee "$BK/ip-addr.txt" >/dev/null
ip route | sudo tee "$BK/ip-route.txt" >/dev/null
sudo cp -a /etc/fstab "$BK/fstab"
sudo cp -a /etc/apt "$BK/etc-apt"
sudo cp -a /etc/default/grub "$BK/" 2>/dev/null || true
sudo cp -a /boot/grub "$BK/boot-grub" 2>/dev/null || true
command -v docker >/dev/null && docker ps -a --no-trunc | sudo tee "$BK/docker-ps.txt" >/dev/null || true
```

生成备份文件校验：

```bash
sudo find "$BK" -type f -exec sha256sum {} \; | sudo tee "$BK/SHA256SUMS" >/dev/null
```

---

# 4. 国内 APT 镜像配置（可选）

如果当前 Ubuntu 官方源访问稳定，可以跳过本章。以下只是中国大陆网络环境的镜像加速配置，不改变 Ubuntu 的 package 管理逻辑。

先备份：

```bash
sudo cp -a /etc/apt/sources.list "/etc/apt/sources.list.backup.$(date +%Y%m%d-%H%M%S)"
```

写入阿里云 Jammy 源时，必须通过配置文件写入，**不要把单独的 `deb ...` 行直接当 Shell 命令执行**：

```bash
sudo tee /etc/apt/sources.list >/dev/null <<'EOF'
deb https://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF
```

更新索引：

```bash
sudo apt-get update
```

必须无 Release、GPG 或 repository 错误。

---

# 5. 在线升级：只升级 GA 内核

本章流程独立完整。

## 5.1 刷新 APT 索引

```bash
sudo apt-get update
```

这一步只刷新仓库元数据，不安装软件。

## 5.2 查看候选版本

```bash
apt-cache policy linux-generic
```

以目标主机实际显示的 `Candidate` 为准。

## 5.3 模拟安装

```bash
sudo apt-get -s install linux-generic
```

重点检查：

- 是否安装 `linux-image-*`、`linux-modules-*`、`linux-modules-extra-*`、`linux-headers-*` 等内核相关包；
- 是否出现异常删除业务软件；
- 是否仍提示 `not fully installed or removed`；
- 是否存在依赖错误。

如果出现：

```text
N not fully installed or removed
```

停止正式安装，先执行：

```bash
sudo dpkg --audit
```

解决现有异常包。

## 5.4 正式安装

```bash
sudo apt-get install linux-generic
```

该操作只以 `linux-generic` 为安装目标，并由 APT 解析它需要的依赖；不会等同于对整机执行 `apt upgrade`。

安装完成必须确认命令退出成功。

## 5.5 安装后、重启前检查

```bash
sudo dpkg --audit
```

必须无输出。

查看内核包：

```bash
dpkg -l | grep -E 'linux-(generic|image-[0-9]|modules-[0-9])'
```

目标新版本应为 `ii`，不能是 `iF`、`iU`、`pH`。

检查新旧 kernel 与 initrd：

```bash
ls -lh /boot/vmlinuz-* /boot/initrd.img-* 2>/dev/null
```

明确刷新 GRUB：

```bash
sudo update-grub
```

查看启动项：

```bash
grep -nE '^(menuentry|submenu)|^[[:space:]]*(linux|linuxefi|initrd|initrdefi|search|set root)' /boot/grub/grub.cfg
```

必须确认：

1. 新 kernel 有对应 `vmlinuz`；
2. 新 kernel 有对应 `initrd`；
3. 旧 kernel 启动项仍存在；
4. 有 IPMI/iDRAC/iLO/KVM/VM Console 等带外回退能力。

## 5.6 重启

```bash
sudo sync
sudo reboot
```

## 5.7 验收

系统重新上线后：

```bash
uname -r
```

只有 reboot 后的 `uname -r` 才能证明新 kernel 真正生效。

确认 package：

```bash
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' "linux-image-$(uname -r)" 2>/dev/null || true
```

GA 5.15 对本次两个 CVE 的基线判断：

```bash
VER="$(dpkg-query -W -f='${Version}' "linux-image-$(uname -r)")"; dpkg --compare-versions "$VER" ge "5.15.0-181.191" && echo FIXED || echo NOT_FIXED
```

再做业务验收：

```bash
systemctl --failed --no-pager
ip -br addr
ip route
command -v docker >/dev/null && docker ps -a || true
```

并执行产品实际 HTTP/API/数据库/端口健康检查。

---

# 6. 完全离线升级：只准备 `linux-generic` 及依赖

推荐使用 Ubuntu Jammy 仓库提供的 `apt-offline`，由目标离线机生成精确下载需求，再由联网机下载 package 和 dependencies。

## 6.1 目标机准备 `apt-offline`

如果设备还能临时联网，先安装：

```bash
sudo apt-get update
sudo apt-get install apt-offline
```

之后断网。

## 6.2 离线机生成 APT 索引下载需求

```bash
mkdir -p /data/kernel-offline
sudo apt-offline set /data/kernel-offline/update.sig --update
```

把 `update.sig` 传到联网 Ubuntu 主机。

## 6.3 联网机下载索引

```bash
sudo apt-get update
sudo apt-get install apt-offline
apt-offline get update.sig --bundle update.zip
```

把 `update.zip` 传回目标离线机。

## 6.4 离线机导入索引

```bash
sudo apt-offline install update.zip
apt-cache policy linux-generic
```

## 6.5 生成仅针对 GA 内核的下载需求

```bash
sudo apt-offline set /data/kernel-offline/kernel.sig --install-packages linux-generic
```

把 `kernel.sig` 传到联网机。

## 6.6 联网机下载内核及依赖

```bash
apt-offline get kernel.sig --bundle kernel-bundle.zip
sha256sum kernel-bundle.zip > kernel-bundle.zip.sha256
```

把两个文件传回离线目标机。

## 6.7 离线机校验并导入

```bash
sha256sum -c kernel-bundle.zip.sha256
sudo apt-offline install kernel-bundle.zip
```

## 6.8 模拟离线安装

```bash
sudo apt-get -s --no-download install linux-generic
```

如果提示缺包或需要联网，停止并重新生成 `apt-offline` 下载需求。

## 6.9 正式离线安装

```bash
sudo apt-get --no-download install linux-generic
```

随后按在线流程的“安装后、重启前检查 → reboot → 验收”执行。

---

# 7. 回退

升级窗口结束前不要执行：

```bash
sudo apt autoremove
```

也不要删除 `uname -r` 当前对应的旧内核。

如果新内核启动失败，通过带外 Console 进入 GRUB，选择旧版本：

```text
Ubuntu, with Linux <old-version>
```

启动后确认：

```bash
uname -r
systemctl --failed --no-pager
ip -br addr
ip route
command -v docker >/dev/null && docker ps -a || true
```

只有确认已经使用旧 kernel 且业务正常，才评估是否删除故障的新版本。

---

# 8. 特殊场景：产品定制 Ubuntu 无法直接升级内核

本章适用于“底层是 Ubuntu 22.04，但产品厂商改造了启动分区、GRUB、initramfs、kernel 包或系统升级链”的设备。此类系统不能把普通 Ubuntu Server 的升级 SOP 直接照搬到生产环境。

核心原则：

1. **正式修复优先级最高：** 最终目标仍是运行包含 Canonical 修复的 kernel，临时措施不能替代正式补丁。
2. **先识别产品启动链：** `/boot`、EFI、GRUB、initramfs 或 kernel 管理机制存在定制时，先验证兼容性。
3. **标准升级不兼容时停止 APT 内核事务：** 不反复执行 `apt-get install linux-generic`、`dpkg --configure -a`、`update-initramfs` 或 `update-grub` 试错。
4. **无法立即升级时才使用补偿性缓解：** 对 Dirty Frag / Fragnesia，可在业务确认不依赖相关功能后临时屏蔽受影响模块。
5. **版本扫描可能继续报警：** 模块屏蔽是运行时补偿措施，不会改变 `uname -r`，不能把扫描器的版本型告警消失作为验收标准。

## 8.1 快速决策表

| 场景 | 建议动作 |
| --- | --- |
| 标准 Ubuntu，`dpkg --audit` 无输出，`/boot` 支持 hard-link/symlink | 按第 5/6 章升级 `linux-generic` |
| 产品定制系统，厂商提供 kernel/固件升级包 | 优先使用厂商升级链，并确认 CVE backport 状态 |
| 产品定制系统，`/boot=vfat` 或 hard-link 测试失败 | 不执行标准 Ubuntu kernel 安装，进入本章临时缓解评估 |
| 已尝试升级，出现 `iF/iU`、新 `vmlinuz` 有但 `initrd` 缺失 | 不重启、不继续叠加新 kernel，保留旧内核运行并进入故障处置 |
| IPsec/XFRM、AFS/RxRPC 正在使用 | 不使用模块屏蔽方案，联系产品/二线评估替代措施 |
| `esp4/esp6/rxrpc` 为 built-in 而非可卸载 `.ko` | modprobe 屏蔽方案不适用，必须优先获得修复 kernel |

## 8.2 实测案例：VFAT `/boot` 与 Ubuntu 原生 kernel package 不兼容

实测产品镜像：

```text
Ubuntu 22.04.5 LTS
amd64
当前运行内核：5.15.0-72-generic
UEFI
/dev/sda2 ext4 -> /
/dev/sda1 vfat/FAT16 -> /boot
```

产品启动链为：

```text
UEFI
  ↓
/dev/sda1 VFAT
  ↓
/boot/EFI/BOOT/BOOTX64.EFI
  ↓
/boot/grub/grub.cfg
  ↓
/boot/vmlinuz-*
/boot/initrd.img-*
  ↓
/dev/sda2 ext4 rootfs
```

该产品把 EFI、GRUB、kernel 和 initrd 全部放在同一个 VFAT `/boot`：

```text
/dev/sda1 VFAT
└── /boot
    ├── EFI/BOOT/BOOTX64.EFI
    ├── grub/grub.cfg
    ├── vmlinuz-*
    └── initrd.img-*
```

执行标准安装：

```bash
sudo apt-get install linux-generic
```

实测出现：

```text
Failed to create symlink to vmlinuz-...: Operation not permitted
```

`update-initramfs` 还可能出现：

```text
ln: failed to create hard link '/boot/initrd.img-....dpkg-bak' ...: Operation not permitted
```

随后 package 状态可能变成：

```text
linux-image-<new>      iF
linux-image-generic    iU
linux-generic          iU
```

新 `vmlinuz` 可能已经解包到 `/boot`，但新 `initrd.img` 不存在。GRUB 甚至可能生成一个只有 `linux /vmlinuz-<new>`、没有对应 `initrd` 的不完整启动项。

此时：

```bash
uname -r
```

仍显示旧内核才是正常的当前运行状态。**不能因为 `linux-generic is already the newest version` 或 `/boot/vmlinuz-<new>` 已存在就判断升级成功。**

根因是 VFAT/FAT 不具备标准 Linux hard-link / symlink 语义，而 Ubuntu `linux-image` maintainer scripts、`linux-update-symlinks`、`update-initramfs` 在 kernel 安装流程中依赖这些能力。

因此这不是某一个 `5.15.0-187`、`5.15.0-190` 包损坏；只要维持该 `/boot=vfat` 设计，Ubuntu 原生 kernel package 的同类操作仍可能重复失败。

### 已失败设备的立即处置原则

如果已经出现上述状态：

- 保持当前已验证可运行的旧 kernel；
- 不删除旧 `vmlinuz/initrd`；
- 不执行 `apt autoremove`；
- 新 kernel 没有完整 initrd 或 package 仍为 `iF/iU` 时，不要直接 reboot；
- 不通过修改 `/usr/bin/linux-update-symlinks`、跳过 maintainer script 等方式强行把 dpkg 状态改成成功；
- 先确定产品的正式 kernel/启动链修复方案，再清理失败事务。

## 8.3 无法立即升级时的临时缓解

Canonical 对 Dirty Frag 的临时缓解是阻止并卸载：

- `esp4`：IPv4 IPsec ESP；
- `esp6`：IPv6 IPsec ESP；
- `rxrpc`：AF_RXRPC，常见于 AFS 等功能。

Fragnesia 使用相同的 ESP/XFRM 攻击面，Canonical 的缓解是屏蔽 `esp4`、`esp6`；因此同时按 Dirty Frag 方案屏蔽 `esp4`、`esp6`、`rxrpc` 可以覆盖本文两个漏洞涉及的临时缓解入口。

这属于**补偿性安全措施**，不是正式内核补丁。

可能受影响：

- StrongSwan、Libreswan 等使用内核 IPsec ESP 的 VPN；
- 基于 XFRM/IPsec 的专线、SD-WAN；
- RxRPC / AFS / OpenAFS。

通常不会直接影响普通 TCP/UDP、Docker bridge/host 网络、OpenVPN、WireGuard、NFS、SMB，但仍必须做现场业务验收，不能仅按协议名称推断无影响。

本产品特殊场景不额外执行：

- `user.max_user_namespaces=0` 或同类全局 namespace 禁用，避免无必要扩大到容器/沙箱能力；
- `drop_caches`，它不是本文采用的预防性措施，且可能造成明显 I/O 和性能抖动；
- `update-grub`；
- `update-initramfs`。

### 为什么这里不执行 Canonical 官方流程中的 `update-initramfs`

Canonical 的通用临时缓解建议在写入 modprobe 配置后执行：

```bash
sudo update-initramfs -u -k all
```

目的是让屏蔽配置进入 initramfs，避免模块在 early boot 被提前加载。

但本章讨论的产品正是因为 VFAT `/boot` 导致 `update-initramfs` hard-link 操作失败，因此**不能在已知不兼容的设备上机械执行这一命令**。

代价是：本章给出的产品临时方案主要用于**当前运行周期**以及 rootfs 加载后的后续 `modprobe` 请求。若设备发生重启，必须重新检查 `esp4/esp6/rxrpc` 是否被 early boot/initramfs 加载；在产品完成 boot/initramfs 兼容性整改前，不应把该配置描述成“无条件跨重启永久生效”。

## 8.4 临时缓解执行条件

执行前必须确认：

1. 产品版本和系统版本属于已验证范围；
2. 客户/业务方接受临时关闭 IPsec ESP 和 RxRPC/AFS 能力；
3. 设备不承担 IPsec VPN、IPsec 专线、SD-WAN 或 AFS 服务；
4. 当前有稳定管理连接，并具备异常时现场或带外回退能力；
5. 先在单台设备实施并验证，不直接批量扩散；
6. 当前业务无与本变更无关的异常。

## 8.5 变更前只读检查

```bash
sudo -i

date
uname -a
cat /etc/os-release

echo '=== module files ==='
for module in esp4 esp6 rxrpc; do
    echo "[$module]"
    modinfo -F filename "$module" 2>&1 || true
done

echo '=== loaded modules ==='
lsmod | awk 'NR == 1 || $1 ~ /^(esp4|esp6|rxrpc)$/'

echo '=== XFRM state and policy ==='
ip xfrm state
ip xfrm policy

echo '=== possible IPsec processes ==='
pgrep -af 'charon|starter|pluto|strongswan|libreswan|ipsec' || true

echo '=== possible AFS mounts ==='
findmnt -t afs,openafs || true
grep -E '(^|[[:space:]])(afs|openafs)([[:space:]]|$)' /proc/mounts || true

echo '=== baseline services ==='
systemctl --failed --no-pager
command -v docker >/dev/null && docker ps --format '{{.Names}}\t{{.Status}}' || true
```

出现以下任一情况停止操作：

- `ip xfrm state` 或 `ip xfrm policy` 存在有效配置；
- 检查到 StrongSwan、Libreswan、charon、pluto 等 IPsec 进程；
- 检查到 AFS/OpenAFS 挂载；
- `modinfo -F filename` 显示目标功能为 built-in，而不是 `.ko` / `.ko.xz` / `.ko.zst` 模块；
- `lsmod` 中目标模块使用计数不为 `0`；
- 当前已有与本次操作无关的业务故障。

## 8.6 实施临时模块屏蔽

以下脚本只写入一份 modprobe 配置，并卸载**当前已经加载且未被使用**的目标模块。任一目标模块卸载或验证失败时，脚本会删除新配置并尝试恢复变更前已加载的模块。

```bash
sudo -i
bash <<'FIELD_EOF'
set -euo pipefail

modules='esp4 esp6 rxrpc'
config_file='/etc/modprobe.d/99-kernel-cve-2026-mitigation.conf'
stamp=$(date +%Y%m%d%H%M%S)
backup_dir="/var/backups/kernel-cve-2026-${stamp}"
state_file="${backup_dir}/modules.loaded"

umask 077
mkdir -p "$backup_dir"
: > "$state_file"

if [ -e "$config_file" ]; then
    echo "STOP: $config_file already exists; verify its origin before continuing." >&2
    exit 1
fi

for module in $modules; do
    filename=$(modinfo -F filename "$module")
    case "$filename" in
        *.ko|*.ko.xz|*.ko.zst) ;;
        *)
            echo "STOP: $module is not a removable module: $filename" >&2
            exit 1
            ;;
    esac

    if lsmod | awk -v name="$module" '$1 == name { found=1 } END { exit !found }'; then
        echo "$module" >> "$state_file"
        refcount=$(lsmod | awk -v name="$module" '$1 == name { print $3 }')
        if [ "$refcount" != '0' ]; then
            echo "STOP: $module is in use; refcount=$refcount" >&2
            exit 1
        fi
    fi
done

cat > "$config_file" <<'CONF_EOF'
# Temporary mitigation for Dirty Frag / Fragnesia related module paths.
# Remove this file after a validated fixed kernel is running.
install esp4 /bin/false
install esp6 /bin/false
install rxrpc /bin/false
blacklist esp4
blacklist esp6
blacklist rxrpc
CONF_EOF
chmod 0644 "$config_file"

rollback_on_error() {
    rc=$?
    trap - ERR INT TERM
    echo 'ERROR: module mitigation failed; restoring previous state.' >&2
    rm -f "$config_file"
    while IFS= read -r module; do
        [ -n "$module" ] && modprobe "$module" || true
    done < "$state_file"
    exit "$rc"
}
trap rollback_on_error ERR INT TERM

for module in $modules; do
    if lsmod | awk -v name="$module" '$1 == name { found=1 } END { exit !found }'; then
        modprobe -r "$module"
    fi
done

for module in $modules; do
    modprobe -n -v "$module" | grep -Eq '^install[[:space:]]+/bin/false([[:space:]]|$)'
    if lsmod | awk -v name="$module" '$1 == name { found=1 } END { exit !found }'; then
        echo "ERROR: $module is still loaded." >&2
        false
    fi
done

trap - ERR INT TERM
printf 'Mitigation applied.\nBackup directory: %s\n' "$backup_dir"
FIELD_EOF
```

记录脚本最后输出的备份目录。

## 8.7 变更后验证

```bash
echo '=== block configuration ==='
cat /etc/modprobe.d/99-kernel-cve-2026-mitigation.conf

echo '=== modprobe dry run ==='
for module in esp4 esp6 rxrpc; do
    modprobe -n -v "$module"
done

echo '=== loaded modules; expected header only ==='
lsmod | awk 'NR == 1 || $1 ~ /^(esp4|esp6|rxrpc)$/'

echo '=== service verification ==='
systemctl --failed --no-pager
command -v docker >/dev/null && docker ps --format '{{.Names}}\t{{.Status}}' || true
ip -br addr
ip route
```

验收标准：

- 三个 `modprobe -n -v` 均显示 `install /bin/false`；
- `lsmod` 中不存在 `esp4`、`esp6`、`rxrpc`；
- 管理网络和产品业务正常；
- Docker 容器数量、名称和健康状态与变更前一致；
- `systemctl --failed` 没有新增故障项；
- 产品自身探针、流量处理、告警、API 等关键能力完成实测。

如设备后续发生 reboot，必须重新执行：

```bash
grep -E '^(esp4|esp6|rxrpc) ' /proc/modules || echo 'affected modules are not loaded'
for module in esp4 esp6 rxrpc; do modprobe -n -v "$module"; done
```

在没有成功执行并验证 `update-initramfs` 的产品环境中，不能跳过这一项。

## 8.8 临时缓解回滚

先找到本次备份目录：

```bash
ls -ld /var/backups/kernel-cve-2026-*
```

确认时间后：

```bash
sudo -i
backup_dir='/var/backups/kernel-cve-2026-请替换为本次时间戳'
state_file="${backup_dir}/modules.loaded"
config_file='/etc/modprobe.d/99-kernel-cve-2026-mitigation.conf'

test -d "$backup_dir"
test -f "$state_file"
rm -f "$config_file"

# 只恢复变更前已经加载的模块，不额外加载原本未使用的模块
while IFS= read -r module; do
    [ -n "$module" ] && modprobe "$module"
done < "$state_file"

for module in esp4 esp6 rxrpc; do
    modprobe -n -v "$module"
done

lsmod | awk 'NR == 1 || $1 ~ /^(esp4|esp6|rxrpc)$/'
systemctl --failed --no-pager
command -v docker >/dev/null && docker ps --format '{{.Names}}\t{{.Status}}' || true
```

回滚后重新检查网络、产品主服务、探针、流量处理和告警。

## 8.9 产品长期整改

临时模块屏蔽仅用于无法立即安装修复 kernel 的过渡期。产品侧最终应完成以下工作：

1. 明确 kernel 是由 Ubuntu APT 维护，还是由产品升级包维护；
2. 如果使用厂商 kernel，明确 CVE backport 版本和升级/回滚方法；
3. 如果希望兼容 Ubuntu 标准 APT kernel，评估把启动布局标准化为：

```text
root/ext4 -> /boot
EFI/VFAT  -> /boot/efi
```

4. 在同版本测试设备完成 EFI、GRUB、kernel、initrd、业务启动和旧 kernel 回退测试；
5. 正式补丁 kernel 运行并验收通过后，再移除临时 modprobe 屏蔽配置；
6. 保存实施记录，向安全扫描/审计侧说明临时缓解不改变 kernel version，因此版本型 HIDS 可能继续报告漏洞。

> 不要直接在生产设备上只修改 `/etc/fstab` 把 `/boot` 改成 `/boot/efi`。这是启动架构整改，不是普通配置变更。

---

# 9. 常见停止条件

遇到以下任一情况时停止 kernel 安装：

- `dpkg --audit` 非空；
- 存在 `iF`、`iU`、`pH` kernel package；
- `/boot` 是 `vfat/fat/msdos`；
- `/boot` hard-link 测试失败；
- `/boot` 空间不足；
- DKMS 对目标 ABI 未确认；
- APT 模拟安装出现异常删除包；
- 新 kernel 缺少 `initrd`；
- GRUB 中没有旧 kernel 回退项；
- 没有带外 Console 回退能力。

特殊场景下，出现以下任一情况时也停止临时模块屏蔽：

- 存在有效 XFRM/IPsec state 或 policy；
- StrongSwan/Libreswan/charon/pluto 正在运行；
- AFS/OpenAFS 正在挂载；
- 目标模块为 built-in；
- 目标模块 refcount 非 0；
- 产品业务已经存在异常，无法建立可靠变更前基线。

---

# 10. 官方参考

- Canonical CVE-2026-43284：<https://ubuntu.com/security/CVE-2026-43284>
- Canonical CVE-2026-46300：<https://ubuntu.com/security/CVE-2026-46300>
- Canonical Dirty Frag 临时缓解：<https://ubuntu.com/blog/dirty-frag-linux-vulnerability-fixes-available>
- Canonical Fragnesia 临时缓解：<https://ubuntu.com/blog/fragnesia-linux-vulnerability-fixes-available>
- Ubuntu Jammy `linux-generic`：<https://packages.ubuntu.com/jammy/amd64/linux-generic>
- Ubuntu Jammy `apt-get` manpage：<https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html>
- Ubuntu Jammy `apt-offline` manpage：<https://manpages.ubuntu.com/manpages/jammy/man8/apt-offline.8.html>
- Ubuntu Kernel HWE 参考：<https://documentation.ubuntu.com/kernel/reference/hwe-kernels/>
