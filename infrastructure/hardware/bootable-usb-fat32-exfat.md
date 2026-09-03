# macOS 制作 FAT32 + exFAT 双分区服务器启动 U 盘

当服务器安装介质需要使用 FAT/FAT32 分区启动，但安装包中存在大于 4 GB 的单文件时，可将同一个 U 盘划分为两个分区：第一个 FAT32 分区只负责启动，第二个 exFAT 分区存放大文件。服务器从 FAT32 分区启动后，再在 Linux 安装环境中挂载 exFAT 分区，并通过安装脚本支持的 `BIN_MOUNT_POINT` 指向大文件所在位置。

> 本文以 `safeline-2-software-installer.bin` 为例。FAT32 单文件大小上限约为 4 GB，因此不能直接存放超过该限制的安装包；UEFI 可移动介质启动则以 FAT 文件系统为标准兼容方案。第二分区使用 exFAT，是为了同时兼顾 macOS 写入和 Linux 读取大文件。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | 服务器 / U 盘启动介质 |
| 适用范围 | macOS 制作启动盘，Linux 安装环境启动 |
| 分区方案 | MBR + FAT32 `SYSTEM` + exFAT `EXFAT_PART` |
| 文档状态 | 实操方案，目标服务器仍需按机型验证启动兼容性 |
| 最后验证 | 2026-09-03 |
| 来源 | 现场操作方案、UEFI Specification、Microsoft FAT32 启动介质说明 |

## 1. 方案结构

示例 U 盘：

```text
/dev/disk2                U 盘物理磁盘（macOS）
├── disk2s1  FAT32  SYSTEM       60%   启动文件、install.sh 等
└── disk2s2  exFAT  EXFAT_PART   剩余  safeline-2-software-installer.bin
                                      safeline-2-software-installer.bin.password
```

文件放置规则：

- `SYSTEM`：存放原安装介质中除以下两个文件以外的所有文件。
- `EXFAT_PART`：只存放：
  - `safeline-2-software-installer.bin`
  - `safeline-2-software-installer.bin.password`

将 `.bin` 和 `.password` 放在同一数据分区，避免安装脚本查找大文件时路径不一致。

## 2. 原理与适用边界

### 为什么不能全部放 FAT32

FAT32 的单文件大小上限约为 4 GB。即使 U 盘本身有几十 GB 或几百 GB，只要某一个文件超过 FAT32 的单文件限制，该文件就无法正常复制进去。

### 为什么启动分区仍使用 FAT32

UEFI 规范要求固件支持 FAT 系列文件系统作为 EFI 启动文件系统，可移动介质通常从 FAT 分区中的 EFI 启动文件加载。exFAT 适合存放大文件，但不能假设服务器固件能够直接从 exFAT 启动。

因此本方案将“启动兼容性”和“大文件存储”分离：

```text
FAT32：负责启动
exFAT：负责存放 >4 GB 安装包
```

### 为什么示例使用 MBR

本方案使用 MBR，主要考虑不同代际服务器的启动兼容性。UEFI-only 设备也可能支持 GPT，但具体以服务器厂商要求和现场固件行为为准。如果目标服务器明确要求 GPT，可将分区表类型改为 GPT 后重新验证。

## 3. macOS：确认 U 盘设备

先查看所有磁盘：

```bash
diskutil list
```

找到 U 盘对应的物理磁盘，例如：

```text
/dev/disk2
```

建议继续检查设备属性：

```bash
diskutil info /dev/disk2 | egrep 'Device / Media Name|Disk Size|Protocol|Internal'
```

重点确认：

- 容量与 U 盘一致。
- `Protocol` 通常为 USB。
- `Internal` 应为 `No`。

> **高风险操作：** 后面的 `partitionDisk` 和 `eraseDisk` 会清空整个目标磁盘。不要仅凭 `/dev/disk2` 这个编号复制执行；U 盘重新插拔后编号可能变化。

## 4. macOS：创建 FAT32 + exFAT 双分区

确认目标 U 盘确实为 `/dev/disk2` 后执行：

```bash
sudo diskutil partitionDisk /dev/disk2 MBR FAT32 SYSTEM 60% exFAT EXFAT_PART R
```

参数含义：

| 参数 | 含义 |
| --- | --- |
| `/dev/disk2` | 要重建分区的 U 盘物理磁盘 |
| `MBR` | 使用 MBR 分区表 |
| `FAT32 SYSTEM 60%` | 第一个 FAT32 分区，卷标 `SYSTEM`，占 60% |
| `exFAT EXFAT_PART R` | 第二个 exFAT 分区，卷标 `EXFAT_PART`，占用剩余空间 |

`60%` 不是强制比例，只要 `SYSTEM` 足够容纳启动文件及除大文件以外的安装内容即可。

创建完成后验证：

```bash
diskutil list /dev/disk2
```

预期可以看到两个分区，并且访达中通常会同时出现：

```text
SYSTEM
EXFAT_PART
```

## 5. macOS：复制安装文件

### SYSTEM 分区

将原安装介质中除以下两个文件外的所有内容复制到 `SYSTEM`：

```text
safeline-2-software-installer.bin
safeline-2-software-installer.bin.password
```

### EXFAT_PART 分区

将这两个文件复制到 `EXFAT_PART` 根目录：

```text
safeline-2-software-installer.bin
safeline-2-software-installer.bin.password
```

复制后检查：

```bash
ls -lh /Volumes/EXFAT_PART/safeline-2-software-installer.bin*
```

### 推荐：生成 SHA256 校验文件

为了确认大文件在复制和启动后没有损坏，可在 macOS 上生成校验文件并放到 `SYSTEM`：

```bash
(cd /Volumes/EXFAT_PART && shasum -a 256 safeline-2-software-installer.bin) > /Volumes/SYSTEM/safeline-2-software-installer.bin.sha256
```

完成后安全弹出：

```bash
diskutil eject /dev/disk2
```

## 6. 服务器：从 U 盘启动后识别两个分区

进入安装环境后，不要默认 U 盘一定是 `/dev/sdc`。先检查：

```bash
lsblk -o NAME,TRAN,SIZE,FSTYPE,LABEL,MOUNTPOINTS,MODEL
fdisk -l
blkid
```

优先通过以下特征确认 U 盘：

- `TRAN` 为 `usb`。
- 容量与 U 盘一致。
- 第一分区卷标为 `SYSTEM`。
- 第二分区卷标为 `EXFAT_PART`。

以下步骤假设现场识别结果为：

```text
/dev/sdc1  SYSTEM
/dev/sdc2  EXFAT_PART
```

实际设备名不同时，后续命令必须同步替换。

可单独确认文件系统：

```bash
blkid /dev/sdc1
blkid /dev/sdc2
```

## 7. 挂载两个分区

先检查是否已经自动挂载：

```bash
findmnt -S /dev/sdc1
findmnt -S /dev/sdc2
```

如果未挂载，创建挂载点：

```bash
mkdir -p /media/sdc1 /media/sdc2
```

挂载 FAT32 启动分区：

```bash
mount -t vfat /dev/sdc1 /media/sdc1
```

挂载 exFAT 大文件分区：

```bash
mount -t exfat /dev/sdc2 /media/sdc2
```

如果需要让当前普通用户读取，可按现场环境增加：

```bash
mount -t exfat /dev/sdc2 /media/sdc2 -o uid=$(id -u),gid=$(id -g),umask=022
```

安装环境通常以 root 运行，此时不需要额外指定 `uid/gid`。

验证挂载结果：

```bash
findmnt /media/sdc1
findmnt /media/sdc2
df -hT | grep -E '/media/sdc[12]'
```

> 原方案中的 `df -hT | grep /mnt` 与实际挂载点 `/media/sdc1`、`/media/sdc2` 不一致，本文已修正。

### exFAT 挂载失败

如果出现：

```text
unknown filesystem type 'exfat'
```

先尝试加载内核模块：

```bash
modprobe exfat
mount -t exfat /dev/sdc2 /media/sdc2
```

如果仍然失败，说明当前启动环境没有可用的 exFAT 驱动。此时不要格式化分区或继续安装，应先更换支持 exFAT 的安装环境，或按目标安装环境实际支持的文件系统重新设计第二分区。

## 8. 校验大文件

确认文件存在：

```bash
ls -lh /media/sdc2/safeline-2-software-installer.bin*
```

如果前面已经生成 SHA256 文件，执行：

```bash
cd /media/sdc2
sha256sum -c /media/sdc1/safeline-2-software-installer.bin.sha256
```

预期结果：

```text
safeline-2-software-installer.bin: OK
```

校验失败时不要继续安装，应重新复制安装包。

## 9. 安装前确认 BIN_MOUNT_POINT 支持

不同版本的安装脚本可能不同。执行前先确认当前 `install.sh` 确实使用了 `BIN_MOUNT_POINT`：

```bash
cd /media/sdc1
grep -n 'BIN_MOUNT_POINT' ./install.sh
```

有匹配结果：可以继续使用本文的双分区方案。

无匹配结果：说明当前脚本版本可能不支持通过该变量指定安装包位置，不要直接假设该方案兼容当前版本。

## 10. 执行安装

再次确认系统目标盘，避免把 U 盘当作安装目标：

```bash
lsblk -o NAME,TRAN,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
```

本文示例假设真正的系统安装目标为 `sda`，U 盘为 `sdc`。

进入 FAT32 启动分区：

```bash
cd /media/sdc1
```

推荐将环境变量和脚本放在同一条命令中执行：

```bash
BIN_MOUNT_POINT=/media/sdc2 ./install.sh sda
```

也可以显式导出变量：

```bash
export BIN_MOUNT_POINT=/media/sdc2
./install.sh sda
```

> 不建议只执行 `BIN_MOUNT_POINT=/media/sdc2` 后直接运行 `./install.sh sda`。这种写法只创建当前 Shell 变量，未 `export` 时子进程通常无法继承该变量。

> **高风险操作：** `./install.sh sda` 可能重新分区、格式化或覆盖 `sda`。必须先通过 `lsblk`、磁盘容量和型号确认 `sda` 是目标系统盘，而不是 U 盘或其他数据盘。

## 11. 常见问题

### 服务器看不到 EXFAT_PART，但可以从 SYSTEM 启动

先进入 Linux 安装环境后执行：

```bash
lsblk -f
blkid
```

只要内核能识别第二个分区，固件阶段无需能够读取 exFAT；exFAT 分区只在 Linux 启动后使用。

### 服务器完全无法从 U 盘启动

依次检查：

1. BIOS/UEFI 是否允许 USB Boot。
2. 是否选择了正确的 UEFI/Legacy 启动项。
3. `SYSTEM` 是否仍为第一个 FAT32 分区。
4. 启动文件是否完整复制到 `SYSTEM`。
5. 目标服务器是否对 MBR/GPT 有明确要求。

### install.sh 找不到 .bin 文件

检查：

```bash
ls -lh /media/sdc2/safeline-2-software-installer.bin
printf '%s\n' "$BIN_MOUNT_POINT"
grep -n 'BIN_MOUNT_POINT' /media/sdc1/install.sh
```

重点确认：

- 第二分区已经挂载。
- `.bin` 和 `.password` 文件名没有改变。
- 当前安装脚本版本支持 `BIN_MOUNT_POINT`。
- 环境变量已经通过“同一行赋值”或 `export` 传入脚本。

## 12. 备选方案

如果目标服务器或安装环境对单 U 盘双分区兼容性不好，可使用两个 U 盘：

```text
U盘 1：FAT32，仅负责启动
U盘 2：exFAT，仅存放大文件
```

启动进入 Linux 后挂载第二个 U 盘，再将 `BIN_MOUNT_POINT` 指向它的挂载目录。该方案会增加一个物理介质，但逻辑更简单，也避免部分旧固件对多分区 U 盘处理异常。

不建议默认采用“把大文件切成多个小文件”的方案，除非安装脚本明确支持分片或安装前有可靠的重组流程。

## 13. 恢复 U 盘为单分区

如果后续不再需要双分区，可在 macOS 上将整个 U 盘恢复为单个 FAT32 分区。

再次通过 `diskutil list` 确认 U 盘编号后执行：

```bash
sudo diskutil eraseDisk FAT32 CT /dev/disk2
```

完成后验证：

```bash
diskutil list /dev/disk2
```

> `eraseDisk` 会删除 U 盘上的全部现有分区和文件，执行前必须确认设备编号。

## 14. 最短操作流程

```text
macOS：diskutil list 确认 U 盘
  ↓
MBR 分成 FAT32 SYSTEM + exFAT EXFAT_PART
  ↓
SYSTEM 放启动文件，EXFAT_PART 放 .bin + .password
  ↓
服务器从 SYSTEM 启动
  ↓
lsblk/blkid 识别两个 U 盘分区
  ↓
挂载 SYSTEM 和 EXFAT_PART
  ↓
校验大文件
  ↓
确认 install.sh 支持 BIN_MOUNT_POINT
  ↓
确认 sda 是目标系统盘
  ↓
BIN_MOUNT_POINT=/media/sdc2 ./install.sh sda
```

## 相关资料

- UEFI Specification 2.11：<https://uefi.org/specs/UEFI/2.11/>
- UEFI File System / Removable Media 说明：<https://uefi.org/specs/UEFI/2.11/13_Protocols_Media_Access.html>
- Microsoft：FAT32 启动 U 盘及 4 GB 单文件限制：<https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/install-windows-from-a-usb-flash-drive?view=windows-11>
