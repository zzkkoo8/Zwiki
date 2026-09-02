# Ubuntu22 内核漏洞安全加固

本文用于 Ubuntu 22.04 LTS（Jammy）服务器的内核漏洞修复。目标是**只升级 GA 5.15 内核及其必要依赖**，不执行整机 `apt upgrade`，并在升级前完成包管理、启动分区、回退能力等硬性检查。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | Linux / Ubuntu / Kernel / 安全加固 |
| 适用范围 | Ubuntu 22.04 LTS Server，amd64，GA 5.15 内核 |
| 适用版本 | Ubuntu 22.04.x LTS（Jammy） |
| 文档状态 | 已验证（标准流程 + 产品镜像故障实测） |
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

禁止继续 kernel update。

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

# 8. 产品打包 Ubuntu：`/boot=vfat` 实测故障案例

## 8.1 环境

实测产品镜像：

```text
Ubuntu 22.04.5 LTS
amd64
当前运行内核：5.15.0-72-generic
UEFI
/dev/sda2 ext4 -> /
/dev/sda1 vfat/FAT16 -> /boot
```

该产品把 EFI 文件、GRUB、kernel 和 initrd 全部放在同一个 VFAT `/boot`：

```text
/dev/sda1 VFAT
└── /boot
    ├── EFI/BOOT/BOOTX64.EFI
    ├── grub/grub.cfg
    ├── vmlinuz-*
    └── initrd.img-*
```

## 8.2 安装失败现象

执行：

```bash
sudo apt-get install linux-generic
```

典型错误：

```text
Failed to create symlink to vmlinuz-...: Operation not permitted
```

同时 `update-initramfs` 可能出现：

```text
ln: failed to create hard link '/boot/initrd.img-....dpkg-bak' ...: Operation not permitted
```

随后：

```text
linux-image-<new>      iF
linux-image-generic    iU
linux-generic          iU
```

并且新 `vmlinuz` 可能已经出现，但新 `initrd.img` 不存在。

**不能因为 `linux-generic is already the newest version` 就判断升级成功。** 必须以 `dpkg --audit`、package 状态以及 reboot 后的 `uname -r` 为准。

## 8.3 根因

VFAT/FAT 不支持标准 Linux hard link / symlink 文件系统语义，而 Ubuntu 标准 `linux-image` 的 maintainer scripts、`linux-update-symlinks`、`update-initramfs` 在 kernel 安装过程中依赖这些能力。

因此该问题不是特定的 `5.15.0-187` 或 `5.15.0-190` 包损坏；只要保持当前 `/boot=vfat` 布局，后续标准 Ubuntu kernel package 仍可能重复失败。

## 8.4 产品侧处理原则

优先确认厂商/产品是否具有自己的 kernel/固件升级机制。如果有，应使用产品自己的更新链路，并由产品方确认 CVE 是否已 backport。

如果产品希望长期兼容 Ubuntu 标准 APT kernel 更新，需要在同版本测试镜像中评估将布局标准化为：

```text
root ext4 -> /boot
EFI VFAT  -> /boot/efi
```

这属于启动架构变更，需要完整验证 EFI/GRUB、kernel/initrd、业务启动和旧内核回退，不能直接在生产设备上仅修改 `/etc/fstab`。

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

---

# 10. 官方参考

- Canonical CVE-2026-43284：<https://ubuntu.com/security/CVE-2026-43284>
- Canonical CVE-2026-46300：<https://ubuntu.com/security/CVE-2026-46300>
- Ubuntu Jammy `linux-generic`：<https://packages.ubuntu.com/jammy/amd64/linux-generic>
- Ubuntu Jammy `apt-get` manpage：<https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html>
- Ubuntu Jammy `apt-offline` manpage：<https://manpages.ubuntu.com/manpages/jammy/man8/apt-offline.8.html>
- Ubuntu Kernel HWE 参考：<https://documentation.ubuntu.com/kernel/reference/hwe-kernels/>
