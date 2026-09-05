# Ubuntu22 内核漏洞安全加固

本文用于 Ubuntu 22.04 LTS（Jammy）内核漏洞修复，重点覆盖两类场景：

1. **标准 Ubuntu 22.04 Server**：按 GA 5.15 内核轨道正常升级；
2. **产品定制 Ubuntu 22.04**：EFI/VFAT 分区被直接挂载到 `/boot`，导致 Ubuntu 原生 `linux-image` 安装失败。

本文特殊场景方案已经在谛听硬件版实机完成安装、真实重启和产品业务验收，不再以推测方案作为主流程。

## 文档信息

- **技术领域**：Linux / Ubuntu / Kernel / 安全加固
- **适用范围**：Ubuntu 22.04 LTS，amd64，Jammy GA 5.15
- **重点漏洞**：CVE-2026-43284、CVE-2026-46300
- **Canonical Jammy GA 修复下限**：`5.15.0-181.191`
- **特殊场景验证**：谛听硬件版 / Advantech FWA-3270
- **修复前**：`5.15.0-72-generic`，package `5.15.0-72.79`
- **实测修复后**：`5.15.0-191-generic`，package `5.15.0-191.201`
- **最后验证**：2026-09-04
- **文档状态**：已实机验证

# 1. 结论

Ubuntu 22.04 Server 默认 GA 内核轨道为 5.15。针对本文两个 CVE，不需要为了修复漏洞主动切换 HWE 6.8；Jammy GA 5.15 只要运行 Canonical 已 backport 修复的版本即可。

本次两个 CVE 的 Jammy GA 修复下限均为：

```text
5.15.0-181.191
```

处理方式按系统形态区分：

| 场景 | 推荐方案 |
| --- | --- |
| 标准 Ubuntu，`/boot` 位于 ext4/xfs 等 Linux 文件系统 | 使用 `linux-generic` 正常升级 |
| 厂商提供自己的 kernel/固件升级包 | 优先使用厂商正式升级链 |
| 产品把 VFAT/FAT 直接挂载到 `/boot` | **禁止直接在 VFAT `/boot` 上安装内核，按第 6 章已验证特殊流程处理** |
| 暂时无法正式升级且业务不使用 IPsec/XFRM、AFS/RxRPC | 可临时屏蔽 `esp4`、`esp6`、`rxrpc`，但不能替代正式修复 |

> `uname -r` 只代表当前正在运行的 kernel。安装新 kernel 后，必须真实 reboot 并完成业务验收，才能认定修复生效。

# 2. CVE 与版本判断

本文处理：

- `CVE-2026-43284`：Dirty Frag，涉及 XFRM ESP 和 RxRPC 路径；
- `CVE-2026-46300`：Fragnesia，涉及 XFRM ESP-in-TCP 路径。

Ubuntu Jammy 使用大量 backport，**不能直接用上游 Linux kernel 小版本号判断是否修复**。

应以 Canonical package fixed version 为准：

```text
Jammy GA 5.15 fixed >= 5.15.0-181.191
```

查询当前运行内核：

```bash
uname -r
```

查询对应 Ubuntu package version：

```bash
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' "linux-image-$(uname -r)" 2>/dev/null || \
dpkg-query -W -f='${Package}\t${Version}\t${Status}\n' "linux-image-unsigned-$(uname -r)" 2>/dev/null
```

# 3. 升级前通用检查

先收集：

```bash
cat /etc/os-release
uname -a
dpkg --print-architecture
sudo dpkg --audit
apt-mark showhold
findmnt /
findmnt /boot
findmnt /boot/efi 2>/dev/null || true
lsblk -f
df -h /boot
ls -lh /boot/vmlinuz-* /boot/initrd.img-* 2>/dev/null
command -v dkms >/dev/null && dkms status || true
command -v mokutil >/dev/null && mokutil --sb-state || true
systemctl --failed --no-pager
command -v docker >/dev/null && docker ps -a || true
```

## 3.1 `dpkg --audit` 为什么必须检查

标准 Ubuntu 正常状态下：

```bash
sudo dpkg --audit
```

应无输出。

如果已有 `iF`、`iU`、`pH` 等半安装状态，新 APT 事务可能会先尝试配置旧故障包，导致问题扩大。

对于普通 Ubuntu，可以先排查并修复现有 dpkg 状态。

对于本文 `/boot=vfat` 特殊场景，如果已经明确是 kernel postinst 在 VFAT 上失败，**不要在原 VFAT `/boot` 状态下反复执行 `dpkg --configure -a`**，直接进入第 6 章。

## 3.2 `/boot` 文件系统是关键门禁

```bash
findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS /boot
```

如果 `/boot` 是：

```text
ext4
xfs
```

可继续走标准 Ubuntu 流程。

如果是：

```text
vfat
fat
msdos
```

不要直接安装 kernel package。

可用临时测试进一步确认：

```bash
sudo bash -c 't=/boot/.kernel-link-test.$$; : > "$t"; ln "$t" "$t.hard"; rc1=$?; ln -s "$t" "$t.sym"; rc2=$?; rm -f "$t" "$t.hard" "$t.sym"; echo "hardlink_rc=$rc1 symlink_rc=$rc2"'
```

在 VFAT 上通常会看到：

```text
Operation not permitted
```

# 4. 标准 Ubuntu：只升级 GA 内核

本章只适用于 `/boot` 具有正常 Linux 文件系统语义、dpkg 状态正常的普通 Ubuntu。

刷新索引：

```bash
sudo apt-get update
```

查看候选版本：

```bash
apt-cache policy linux-generic
```

模拟：

```bash
sudo apt-get -s install linux-generic
```

确认不会异常删除业务软件后正式安装：

```bash
sudo apt-get install linux-generic
```

安装后：

```bash
sudo dpkg --audit
sudo apt-get check
ls -lh /boot/vmlinuz-* /boot/initrd.img-*
sudo update-grub
```

重启前必须确认：

- 新 kernel 的 `vmlinuz` 存在；
- 新 kernel 的 `initrd.img` 存在；
- GRUB 有新 kernel 的 `linux` 和 `initrd` 行；
- 旧 kernel 仍保留；
- 有 Console/IPMI/iDRAC/iLO 等回退手段。

维护窗口重启：

```bash
sudo sync
sudo reboot
```

上线后：

```bash
uname -r
sudo dpkg --audit
sudo apt-get check
```

# 5. 特殊场景根因：VFAT `/boot`

## 5.1 实测产品布局

谛听硬件版实测：

```text
Ubuntu 22.04 LTS / amd64
UEFI
/dev/sda2 ext4       -> /
/dev/sda1 VFAT FAT16 -> /boot
```

产品把 EFI、GRUB、kernel、initrd 全部放在 260MB VFAT `/boot`：

```text
/dev/sda1 VFAT
└── /boot
    ├── EFI/BOOT/BOOTX64.EFI
    ├── grub/grub.cfg
    ├── vmlinuz-*
    └── initrd.img-*
```

GRUB 从 VFAT 直接读取带版本号的 kernel/initrd，再挂载 ext4 rootfs。

## 5.2 直接安装为什么失败

在 VFAT `/boot` 上执行 Ubuntu 原生 kernel 安装，现场出现：

```text
ln: failed to create hard link ... Operation not permitted
```

以及：

```text
Failed to create symlink to vmlinuz-...: Operation not permitted
```

随后可能出现：

```text
linux-image-<new>      iF
linux-image-generic    iU
linux-generic          iU
```

典型现象是：

```text
/boot/vmlinuz-<new>          已出现
/boot/initrd.img-<new>       未生成
```

GRUB 甚至可能出现只有 `linux /vmlinuz-<new>`、没有 `initrd` 的不完整启动项。

因此：

- `linux-generic is already the newest version` 不等于升级成功；
- `vmlinuz` 文件存在不等于升级成功；
- package 仍为 `iF/iU` 时禁止重启；
- 新 kernel 缺 `initrd` 时禁止重启。

## 5.3 现场还存在的 appliance 差异

实测设备同时存在：

- `/var/lib/apt/lists` 不存在；
- 原内核不是通过 `linux-generic` 元包持续跟踪；
- 产品网络由自身 minion 维护；
- 业务依赖 Docker、KVM、Intel 网卡、iptables 等 kernel 能力；
- GRUB 默认隐藏且 `GRUB_TIMEOUT=0`；
- VFAT 曾存在 dirty bit；
- `/boot` 总容量只有约 260MB。

因此不能只修 dpkg，还必须把启动、空间和产品业务一起纳入验收。

# 6. 特殊硬件正式修复：已验证流程

本章是本次实机验证通过的主方案。

核心思路：

```text
正常状态：
/dev/sda1 VFAT -> /boot

内核安装维护窗口：
/dev/sda1 VFAT -> 临时挂载点
/dev/sda2 ext4 -> /boot（根分区中的目录）

在 ext4 /boot 完成：
安装 kernel -> initramfs -> dpkg configure -> GRUB

然后：
只把真实版本文件回写 VFAT
-> 恢复 /dev/sda1 到 /boot
-> 在最终真实布局下再次 update-grub
-> reboot
```

> 临时 ext4 `/boot` 阶段禁止重启。

## 6.1 强制前置条件

执行前必须同时满足：

1. 已取得维护窗口；
2. 串口/IPMI等带外 Console 可用，并确认能进入 GRUB；
3. 已保存升级前网络、服务、容器、iptables/KVM/网卡基线；
4. 已确认 `/boot=/dev/sda1 vfat`、`/=/dev/sda2 ext4`；
5. 已备份 VFAT `/boot`；
6. 目标 kernel 是 Jammy GA 5.15，package version 不低于 `5.15.0-181.191`；
7. 旧 kernel 在新 kernel 完成重启验收前不得删除；
8. 不安装 HWE 6.8；
9. 不执行 `apt upgrade`、`full-upgrade`、`dist-upgrade`；
10. 回写前执行 VFAT 容量门禁，并预留至少 32MiB。

## 6.2 建立备份与基线

```bash
sudo -i
set -euo pipefail
stamp=$(date +%Y%m%d%H%M%S)
backup_dir="/var/backups/dsensor-kernel-upgrade-$stamp"
mkdir -p "$backup_dir"

uname -a > "$backup_dir/uname-before.txt"
findmnt > "$backup_dir/findmnt-before.txt"
lsblk -f > "$backup_dir/lsblk-before.txt"
dpkg -l | grep -E 'linux-(image|modules|generic)' > "$backup_dir/kernel-packages-before.txt" || true
systemctl --failed --no-pager > "$backup_dir/systemctl-failed-before.txt" || true
command -v docker >/dev/null && docker ps -a --no-trunc > "$backup_dir/docker-before.txt" || true
cp -a /etc/fstab "$backup_dir/fstab"
cp -a /etc/default/grub "$backup_dir/grub-default" 2>/dev/null || true

tar -C /boot -cf "$backup_dir/boot-vfat-before.tar" .
sha256sum "$backup_dir/boot-vfat-before.tar" > "$backup_dir/boot-vfat-before.tar.sha256"
```

确认备份存在：

```bash
test -s "$backup_dir/boot-vfat-before.tar"
sha256sum -c "$backup_dir/boot-vfat-before.tar.sha256"
```

## 6.3 VFAT dirty bit 修复

**只能在卸载状态写修复。**

```bash
sync
umount /boot
fsck.fat -a /dev/sda1
mount /boot
```

如果需要确认 dirty bit 已清除，要再次干净卸载后只读检查：

```bash
sync
umount /boot
fsck.fat -vn /dev/sda1
mount /boot
```

不要在 VFAT 已挂载时用 `fsck.fat -vn` 判断 dirty bit，因为重新挂载本身会设置 dirty 状态，容易得出错误结论。

## 6.4 使用独立临时 APT 索引

特殊 appliance 不建议为了这次 kernel 修复直接重建整个宿主 APT 状态。

建立独立 lists/cache：

```bash
apt_probe=/var/tmp/dsensor-kernel-apt
rm -rf "$apt_probe"
mkdir -p "$apt_probe/lists/partial" "$apt_probe/cache/archives/partial"
```

`apt_source` 必须指向现场已经确认可达、包含 `jammy-security` 的 source 文件。如果宿主 `/etc/apt/sources.list` 可直接使用：

```bash
apt_source=/etc/apt/sources.list
```

如果宿主 source 中包含失效的产品内网镜像，应先准备一个**临时、仅用于本次操作**且包含可达 `jammy-security` 的 source 文件，再把 `apt_source` 指向它；不要为了本次维护永久修改宿主源。

更新临时索引：

```bash
apt-get \
  -o Dir::State::lists="$apt_probe/lists" \
  -o Dir::Cache="$apt_probe/cache" \
  -o Dir::Etc::sourcelist="$apt_source" \
  -o Dir::Etc::sourceparts=- \
  -o APT::Get::List-Cleanup=0 \
  update
```

查询目标 kernel。以下以实测成功的 `5.15.0-191` 为例：

```bash
target_kernel=5.15.0-191
apt-cache -o Dir::State::lists="$apt_probe/lists" policy \
  "linux-image-$target_kernel-generic" \
  "linux-modules-$target_kernel-generic" \
  "linux-modules-extra-$target_kernel-generic"
```

如果 191 已被新版本替代，选择仓库当前最新 Jammy GA 5.15，但不得低于官方修复下限。

## 6.5 临时暴露 ext4 `/boot`

先定义路径：

```bash
vfat_boot="/var/lib/dsensor/boot-vfat-$stamp"
mkdir -p "$vfat_boot"
```

确认当前布局：

```bash
test "$(findmnt -no SOURCE /boot)" = /dev/sda1
test "$(findmnt -no FSTYPE /boot)" = vfat
test "$(findmnt -no FSTYPE /)" = ext4
```

切换：

```bash
sync
umount /boot
mount /dev/sda1 "$vfat_boot"
mkdir -p /boot
cp -aL "$vfat_boot"/. /boot/
```

确认：

```bash
test -z "$(findmnt -no SOURCE /boot 2>/dev/null || true)"
test "$(findmnt -no SOURCE "$vfat_boot")" = /dev/sda1
test "$(findmnt -no FSTYPE "$vfat_boot")" = vfat
test "$(findmnt -no FSTYPE /)" = ext4
```

此时：

- `/boot` 是根分区 ext4 中的普通目录；
- 原 VFAT 被挂在 `$vfat_boot`；
- **当前状态绝对禁止 reboot。**

> `cp -aL` 在这里的方向是 **VFAT -> ext4**，本次实测可用。后面的 ext4 -> VFAT 回写禁止使用 `cp -aL`。

### 已证伪：不要使用 `mount --move`

本机真实宿主执行：

```bash
mount --move /boot <临时目录>
```

受 mount propagation / 层级约束失败，因此正式 SOP 使用“`umount /boot` 后重新挂载 `/dev/sda1` 到临时目录”。

## 6.6 显式安装 image/modules/modules-extra

对于该 appliance，不推荐安装整个 `linux-generic` 元包。

原因：元包会额外引入 headers、firmware、microcode 等，本次安全修复没有必要扩大变更面。

使用临时 APT 索引显式安装三包：

```bash
apt-get \
  -o Dir::State::lists="$apt_probe/lists" \
  -o Dir::Cache="$apt_probe/cache" \
  -o Dir::Etc::sourcelist="$apt_source" \
  -o Dir::Etc::sourceparts=- \
  install --no-install-recommends \
  "linux-image-$target_kernel-generic" \
  "linux-modules-$target_kernel-generic" \
  "linux-modules-extra-$target_kernel-generic"
```

完成 package configure：

```bash
dpkg --configure -a
update-initramfs -u -k "$target_kernel-generic"
update-grub
dpkg --audit
apt-get check
```

要求：

```text
dpkg --audit     无输出
apt-get check    无依赖错误
```

> 如果已经经历过一次 VFAT `/boot` 直接安装失败，此步骤也用于在 ext4 `/boot` 环境中完成遗留的 kernel package configure。

## 6.7 验证新旧 kernel 和 initrd

```bash
new_kernel="$target_kernel-generic"
old_kernel="$(uname -r)"

test -s "/boot/vmlinuz-$new_kernel"
test -s "/boot/initrd.img-$new_kernel"
test -s "/boot/vmlinuz-$old_kernel"
test -s "/boot/initrd.img-$old_kernel"

grep -F "$new_kernel" /boot/grub/grub.cfg
grep -F "$old_kernel" /boot/grub/grub.cfg
ls -ld "/lib/modules/$new_kernel"
```

如果产品依赖 Intel 网卡、NVMe、RAID 等驱动，检查新 initramfs：

```bash
lsinitramfs "/boot/initrd.img-$new_kernel" | grep -E '/(igb|ixgbe|nvme|megaraid).*\.ko'
```

## 6.8 VFAT 容量门禁

回写前必须按真实 regular file 大小计算，不能只看 `du` 或凭经验估算。

```bash
regular_bytes=$(find /boot -type f -printf '%s\n' | awk '{s+=$1} END{print s+0}')
vfat_total=$(findmnt -bno SIZE "$vfat_boot")
reserve=$((32 * 1024 * 1024))

echo "regular_file_bytes=$regular_bytes"
echo "vfat_total=$vfat_total"
echo "required_with_reserve=$((regular_bytes + reserve))"

test "$((regular_bytes + reserve))" -lt "$vfat_total"
test "$(findmnt -no SOURCE "$vfat_boot")" = /dev/sda1
test "$(findmnt -no FSTYPE "$vfat_boot")" = vfat
```

容量门禁失败：

- 不删除旧 kernel；
- 不回写；
- 不重启；
- 保持现场并评估扩容 ESP 或产品永久整改。

## 6.9 回写 VFAT：只复制真实文件，不展开 symlink

再次确认备份和目标挂载：

```bash
test -s "$backup_dir/boot-vfat-before.tar"
test "$(findmnt -no SOURCE "$vfat_boot")" = /dev/sda1
test "$(findmnt -no FSTYPE "$vfat_boot")" = vfat
mountpoint -q "$vfat_boot"
```

清空 VFAT 旧目录树：

```bash
find "$vfat_boot" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
```

回写：

```bash
rsync -rltD --no-links /boot/ "$vfat_boot"/
sync
```

验证：

```bash
test -z "$(find "$vfat_boot" -type l -print -quit)"
test -s "$vfat_boot/vmlinuz-$new_kernel"
test -s "$vfat_boot/initrd.img-$new_kernel"
test -s "$vfat_boot/vmlinuz-$old_kernel"
test -s "$vfat_boot/initrd.img-$old_kernel"
grep -F "$new_kernel" "$vfat_boot/grub/grub.cfg"
df -h "$vfat_boot"
```

### 为什么必须 `--no-links`

ext4 `/boot` 会有：

```text
vmlinuz
vmlinuz.old
initrd.img
initrd.img.old
```

这些是 convenience symlink，但本产品 GRUB 不依赖它们。

现场已经证伪：

- `cp -aL` 用于 **ext4 -> VFAT** 会试图保留 hard-link 关系，报 `Operation not permitted`；
- `rsync --copy-links --no-hard-links` 会展开上述链接，重复复制大体积 kernel/initrd，最终 `No space left on device`。

因此实测有效方案是：

```bash
rsync -rltD --no-links
```

只复制带版本号的真实文件。

## 6.10 恢复真实 VFAT `/boot`，再生成最终 GRUB

```bash
umount "$vfat_boot"
mount /boot
```

确认：

```bash
test "$(findmnt -no SOURCE /boot)" = /dev/sda1
test "$(findmnt -no FSTYPE /boot)" = vfat
```

**必须在真实最终挂载布局恢复之后再次：**

```bash
update-grub
```

检查：

```bash
grep -nE 'menuentry|linux[[:space:]]|initrd[[:space:]]' /boot/grub/grub.cfg
```

新 kernel 必须同时有类似：

```text
linux  /vmlinuz-5.15.0-191-generic ...
initrd /initrd.img-5.15.0-191-generic
```

旧 kernel 启动项也必须存在。

> 临时 ext4 `/boot` 阶段生成的 `grub.cfg` 不能直接当最终配置使用。恢复 VFAT 后再执行 `update-grub`，才能生成产品真实启动视角下的 `/vmlinuz-*`、`/initrd.img-*` 路径。

## 6.11 重启前门禁

```bash
uname -r
findmnt -no TARGET,SOURCE,FSTYPE /boot
ls -lh /boot/vmlinuz-* /boot/initrd.img-*
grep -nE 'menuentry|linux[[:space:]]|initrd[[:space:]]' /boot/grub/grub.cfg
dpkg --audit
apt-get check
systemctl --failed --no-pager
command -v docker >/dev/null && docker ps --format '{{.Names}}\t{{.Status}}' || true
ip -br addr
ip route
```

只有全部通过，并确认带外 Console 和旧 kernel 回滚方法以后，才能：

```bash
sync
reboot
```

## 6.12 重启后产品级验收

```bash
uname -r
findmnt -no TARGET,SOURCE,FSTYPE /boot
dpkg --audit
apt-get check
systemctl --failed --no-pager
systemctl is-active minion hwminion ssh docker 2>/dev/null || true
command -v docker >/dev/null && docker ps --format '{{.Names}}\t{{.Status}}' || true
ip -br addr
ip route
iptables -S
command -v nft >/dev/null && nft list ruleset || true
lsmod | grep -E '^(igb|ixgbe|kvm|kvm_intel|overlay|bridge)' || true
curl -kfsS -o /dev/null -w 'https=%{http_code}\n' https://127.0.0.1/ || true
```

验收至少包括：

- `uname -r` 为目标修复 kernel；
- `/boot` 已恢复 `/dev/sda1` VFAT；
- 新旧 kernel/initrd 均存在；
- `dpkg --audit` 无输出；
- `apt-get check` 通过；
- 产品全部容器正常；
- minion/SSH/Docker 等关键服务正常；
- 管理 IP、路由、DNS 正常；
- Intel 网卡/KVM/overlay/bridge 正常；
- iptables/nftables 与产品流量处理正常；
- Web/API 等产品能力正常；
- 没有新增失败服务。

# 7. 临时缓解：只在正式升级前过渡使用

正式修复无法立即实施时，可在确认业务不依赖相关功能后，临时屏蔽：

```text
esp4
esp6
rxrpc
```

执行前检查：

```bash
for module in esp4 esp6 rxrpc; do
    echo "[$module]"
    modinfo -F filename "$module" 2>&1 || true
done

lsmod | awk 'NR == 1 || $1 ~ /^(esp4|esp6|rxrpc)$/'
ip xfrm state
ip xfrm policy
pgrep -af 'charon|starter|pluto|strongswan|libreswan|ipsec' || true
findmnt -t afs,openafs || true
```

出现以下任一情况，不执行模块屏蔽：

- 有有效 XFRM/IPsec state/policy；
- StrongSwan/Libreswan/charon/pluto 正在运行；
- AFS/OpenAFS 正在使用；
- 模块为 built-in；
- 模块已经加载且 refcount 非 0。

屏蔽配置示例：

```bash
cat >/etc/modprobe.d/99-dsensor-cve-2026-mitigation.conf <<'EOF'
install esp4 /bin/false
install esp6 /bin/false
install rxrpc /bin/false
blacklist esp4
blacklist esp6
blacklist rxrpc
EOF
chmod 0644 /etc/modprobe.d/99-dsensor-cve-2026-mitigation.conf
```

验证：

```bash
for module in esp4 esp6 rxrpc; do
    modprobe -n -v "$module"
done
```

正式修复 kernel 已启动并完成产品验收后：

```bash
rm -f /etc/modprobe.d/99-dsensor-cve-2026-mitigation.conf
```

不要主动加载变更前本来就没有使用的模块。

> 模块屏蔽不会改变 `uname -r`，版本型 HIDS/扫描器仍可能报警。它是补偿性措施，不是正式修复。

# 8. 正式升级失败恢复

## 8.1 仍处于临时 ext4 `/boot`

**禁止重启。**

如果决定放弃本次升级，使用升级前 VFAT tar 恢复原启动分区：

```bash
test "$(findmnt -no FSTYPE "$vfat_boot")" = vfat
test -s "$backup_dir/boot-vfat-before.tar"
mountpoint -q "$vfat_boot"

find "$vfat_boot" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
tar -C "$vfat_boot" -xf "$backup_dir/boot-vfat-before.tar"
sync
umount "$vfat_boot"
mount /boot
findmnt /boot
```

确认旧 kernel/initrd 和 GRUB 后再评估是否重启。

## 8.2 新 kernel 无法启动

通过串口/IPMI进入 GRUB，选择旧 kernel。

启动后保留现场：

```bash
uname -r
findmnt /boot
journalctl -b -1 -p err --no-pager
command -v docker >/dev/null && docker ps || true
ip -br addr
ip route
```

旧 kernel 完成业务回滚验收前，不删除任何 kernel 文件。

# 9. 已证伪或禁止的操作

特殊硬件场景不要采用：

- 直接在 VFAT `/boot` 上执行 `apt install linux-*`；
- 把 HWE 6.8 当作默认修复路径；
- `apt upgrade` / `full-upgrade` / `dist-upgrade` 顺带升级整机；
- 提前删除唯一旧 kernel 腾空间；
- 直接修改 `/usr/bin/linux-update-symlinks` 或跳过 maintainer scripts；
- 仅修改 `/etc/fstab` 就把产品强改成 `/boot/efi`；
- `mount --move /boot <临时目录>`：本机实测失败；
- ext4 -> VFAT 使用 `cp -aL`：本机实测 `Operation not permitted`；
- `rsync --copy-links --no-hard-links`：本机实测展开 symlink 后写满 VFAT；
- 在已挂载 VFAT 上用 `fsck.fat -vn` 判断 dirty bit；
- `user.max_user_namespaces=0` 作为本次默认缓解；
- `drop_caches`；
- 无必要执行 `update-initramfs -u -k all`；
- kernel/initrd/GRUB 未完整时 reboot；
- `apt autoremove` 清理旧 kernel。

# 10. 产品永久整改

本次方案是在不改变产品最终启动布局的前提下完成安全修复，但 `/boot=vfat` 与 Ubuntu 原生 kernel 生命周期仍存在结构性冲突。

产品后续建议改为标准 UEFI 布局：

```text
/dev/sda2 ext4
└── /boot
    ├── grub/
    ├── vmlinuz-*
    └── initrd.img-*

/dev/sda1 VFAT
└── /boot/efi
    └── EFI/...
```

产品发布前需要验证：

1. ESP 挂载 `/boot/efi`；
2. `/boot` 保持 Linux 文件系统语义；
3. `grub-install --efi-directory=/boot/efi` 与产品启动链兼容；
4. 明确由 Ubuntu GA 元包还是产品自有机制维护 kernel；
5. 软件源和 APT 索引具备可维护性；
6. 可同时保留至少两套 kernel；
7. 实机验证冷启动、旧 kernel 回滚、Intel 网卡、KVM、Docker、minion、iptables/nftables 和全部产品流量路径。

# 11. 本次实机验证结果

2026-09-04 实测最终状态：

```text
修复前运行：5.15.0-72-generic
修复后运行：5.15.0-191-generic
修复后 package：5.15.0-191.201
官方最低修复：5.15.0-181.191
```

结果：

- 测试机真实 reboot 成功；
- `/boot` 恢复为 `/dev/sda1` VFAT；
- VFAT 回写后约使用 148MB、剩余约 113MB；
- 新旧 kernel/initrd 和 GRUB 启动项均保留；
- `dpkg --audit`、`apt-get check` 通过；
- 产品 10 个业务容器正常；
- minion、hwminion、SSH、Docker 正常；
- 管理网络、默认路由、DNS 正常；
- Intel `igb`、KVM、overlay、bridge 正常；
- iptables 和产品流量处理正常；
- HTTPS 正常；
- 临时 `esp4/esp6/rxrpc` 屏蔽已撤销；
- 未发现本次 kernel 升级引入新的系统或产品故障。

这套流程已经从“推测方案”升级为**实机验证 SOP**。

# 12. 官方参考

- Canonical CVE-2026-43284：<https://ubuntu.com/security/CVE-2026-43284>
- Canonical CVE-2026-46300：<https://ubuntu.com/security/CVE-2026-46300>
- Canonical Dirty Frag：<https://ubuntu.com/blog/dirty-frag-linux-vulnerability-fixes-available>
- Canonical Fragnesia：<https://ubuntu.com/blog/fragnesia-linux-vulnerability-fixes-available>
- Ubuntu Jammy `apt-get`：<https://manpages.ubuntu.com/manpages/jammy/man8/apt-get.8.html>
- Ubuntu Kernel HWE：<https://documentation.ubuntu.com/kernel/reference/hwe-kernels/>
