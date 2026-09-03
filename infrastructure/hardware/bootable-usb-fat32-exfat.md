# 制作 FAT32 + exFAT 双分区服务器启动 U 盘（macOS / Windows）

当服务器安装介质必须使用 FAT/FAT32 分区启动，但安装包中存在大于 4 GB 的单文件时，可以把同一个 U 盘划分为两个分区：第一个 FAT32 分区负责启动，第二个 exFAT 分区负责存放大文件。服务器从 FAT32 分区启动进入 Linux 安装环境后，再挂载 exFAT 分区，并通过安装脚本支持的 `BIN_MOUNT_POINT` 指向大文件所在目录。

本文给出 **macOS** 和 **Windows 10/11** 两套制作方法，服务器端使用方法相同。

> 本文以 `safeline-2-software-installer.bin` 为例。FAT32 单文件大小上限约为 4 GB，因此不能直接存放超过该限制的安装包；exFAT 支持大文件，但不能假设服务器固件能够直接从 exFAT 启动。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | 服务器 / U 盘启动介质 |
| 制作端 | macOS、Windows 10/11 |
| 启动端 | BIOS/UEFI 服务器，Linux 安装环境 |
| 分区方案 | MBR + FAT32 `SYSTEM` + exFAT `EXFAT_PART` |
| 文档状态 | 实操方案，目标服务器仍需按机型验证启动兼容性 |
| 最后验证 | 2026-09-03 |
| 来源 | 现场操作方案、UEFI Specification、Microsoft DiskPart / Windows Insider 文档 |

## 1. 方案结构

```text
U 盘
├── 分区 1：FAT32  SYSTEM
│   └── 启动文件、install.sh、除大文件外的安装文件
└── 分区 2：exFAT  EXFAT_PART
    ├── safeline-2-software-installer.bin
    └── safeline-2-software-installer.bin.password
```

文件放置规则：

- `SYSTEM`：存放原安装介质中除以下两个文件以外的所有文件。
- `EXFAT_PART`：存放：
  - `safeline-2-software-installer.bin`
  - `safeline-2-software-installer.bin.password`

将 `.bin` 和 `.password` 放在同一数据分区，避免安装脚本查找路径不一致。

## 2. 原理与适用边界

### 2.1 为什么不能全部放 FAT32

FAT32 的单文件大小上限约为 4 GB。即使 U 盘总容量为 64 GB、128 GB 或更大，只要某一个文件超过 FAT32 单文件限制，就无法正常复制到该分区。

### 2.2 为什么启动分区仍使用 FAT32

UEFI 可移动介质启动通常依赖 FAT 文件系统中的 EFI 启动文件。exFAT 适合存放大文件，但服务器 BIOS/UEFI 固件不一定具备 exFAT 启动能力。

因此将两个职责分离：

```text
FAT32：负责固件启动兼容性
exFAT：负责存放 >4 GB 安装文件
```

### 2.3 为什么示例使用 MBR

本方案使用 MBR，主要考虑不同代际服务器和 Legacy BIOS/UEFI 混合环境的兼容性。

如果目标服务器厂商明确要求 GPT/UEFI，应按设备要求改用 GPT，并重新验证启动行为，不应机械套用本文的 MBR 参数。

### 2.4 分区大小如何选择

macOS 示例沿用现场方案：

```text
SYSTEM      60%
EXFAT_PART  剩余空间
```

Windows 示例为了兼容不同 Windows 10/11 版本以及不同格式化工具行为，默认使用：

```text
SYSTEM      30000 MB
EXFAT_PART  剩余空间
```

这里的 `30000 MB` 不是 FAT32 文件系统自身的容量上限，而是兼容性较好的保守值。较老 Windows 内置工具通常不允许创建超过约 32 GB 的新 FAT32 卷；Microsoft 已在较新的 Windows 11 命令行格式化功能中将 FAT32 格式化上限逐步提升到 2 TB，但具体能力取决于当前 Windows 版本和更新通道。

因此生产操作建议：

1. `SYSTEM` 只要能容纳除大 `.bin` 外的启动文件即可。
2. 30 GB 足够时，优先使用 30000 MB，兼容性最好。
3. 确实需要更大的 FAT32 `SYSTEM` 时，应先在当前 Windows 版本实测格式化能力，或直接使用 macOS 方案。

---

## 3. macOS 制作方法

### 3.1 确认 U 盘设备

查看磁盘：

```bash
diskutil list
```

找到 U 盘对应的物理磁盘，例如：

```text
/dev/disk2
```

进一步核实：

```bash
diskutil info /dev/disk2 | egrep 'Device / Media Name|Disk Size|Protocol|Internal'
```

重点确认：

- 容量与 U 盘一致。
- `Protocol` 通常为 USB。
- `Internal` 应为 `No`。

> **高风险操作：** 后面的 `partitionDisk` 和 `eraseDisk` 会清空整个目标磁盘。U 盘重新插拔后 `/dev/diskN` 编号可能变化，每次都必须重新确认。

### 3.2 创建 FAT32 + exFAT 双分区

确认目标 U 盘确实为 `/dev/disk2` 后执行：

```bash
sudo diskutil partitionDisk /dev/disk2 MBR FAT32 SYSTEM 60% exFAT EXFAT_PART R
```

参数含义：

| 参数 | 含义 |
| --- | --- |
| `/dev/disk2` | U 盘物理磁盘 |
| `MBR` | MBR 分区表 |
| `FAT32 SYSTEM 60%` | FAT32 启动分区，卷标 `SYSTEM` |
| `exFAT EXFAT_PART R` | exFAT 数据分区，使用剩余空间 |

创建后检查：

```bash
diskutil list /dev/disk2
```

访达中通常会看到：

```text
SYSTEM
EXFAT_PART
```

### 3.3 复制安装文件

将除以下两个文件外的全部安装介质文件复制到 `SYSTEM`：

```text
safeline-2-software-installer.bin
safeline-2-software-installer.bin.password
```

将这两个文件复制到 `EXFAT_PART` 根目录。

检查大文件：

```bash
ls -lh /Volumes/EXFAT_PART/safeline-2-software-installer.bin*
```

推荐生成 SHA256 校验文件：

```bash
(cd /Volumes/EXFAT_PART && shasum -a 256 safeline-2-software-installer.bin) > /Volumes/SYSTEM/safeline-2-software-installer.bin.sha256
```

完成后安全弹出：

```bash
diskutil eject /dev/disk2
```

---

## 4. Windows 制作方法

推荐使用 Windows 自带的 **PowerShell + DiskPart**，无需安装第三方分区软件。

> `clean` 会立即删除所选磁盘现有分区。以下示例中的 `Disk 2` 只是示例，必须根据实际 U 盘重新确认。

### 4.1 确认 U 盘编号

以管理员身份打开 PowerShell：

```powershell
Get-Disk | Sort-Object Number | Format-Table Number,FriendlyName,BusType,PartitionStyle,@{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}}
```

重点确认：

- `BusType` 为 USB。
- 容量与 U 盘一致。
- `FriendlyName` 与 U 盘型号基本一致。

进入 DiskPart 再次确认：

```text
diskpart
list disk
select disk 2
detail disk
```

只有在 `detail disk` 显示的设备确实为目标 U 盘时才继续。

### 4.2 使用 DiskPart 创建双分区

以下示例假设 U 盘为 `Disk 2`，`SYSTEM` 设置为 30000 MB。

管理员 CMD 或 PowerShell 中运行：

```text
diskpart
```

然后逐条执行：

```text
list disk
select disk 2
detail disk
clean
convert mbr
create partition primary size=30000
format fs=fat32 quick label=SYSTEM
active
assign letter=S
create partition primary
format fs=exfat quick label=EXFAT_PART
assign letter=E
list partition
list volume
exit
```

预期结构：

```text
S:  FAT32  SYSTEM       约 30 GB
E:  exFAT  EXFAT_PART   剩余空间
```

说明：

- `clean`：删除 U 盘现有分区信息。
- `convert mbr`：使用 MBR 分区表。
- `size=30000`：创建约 30 GB 的 FAT32 启动分区。
- `active`：为 Legacy BIOS/MBR 启动提供活动分区标记；纯 UEFI 环境通常不依赖该标记。如果该命令在某些可移动介质上报错，可先跳过并按服务器实际启动方式验证。
- 第二个 `create partition primary` 未指定大小，因此使用全部剩余空间。

### 4.3 图形界面验证

按：

```text
Win + X → 磁盘管理
```

确认同一个 U 盘存在两个主分区：

```text
SYSTEM      FAT32
EXFAT_PART  exFAT
```

也可以在 PowerShell 检查：

```powershell
Get-Volume | Where-Object FileSystemLabel -in 'SYSTEM','EXFAT_PART' | Format-Table DriveLetter,FileSystemLabel,FileSystem,Size,SizeRemaining
```

### 4.4 复制安装文件

最简单的方法是在资源管理器中复制：

- `S:\`：放除 `.bin` 和 `.password` 外的所有文件。
- `E:\`：放 `.bin` 和 `.password`。

如果原安装介质已经解压到 `C:\install-media`，也可以使用：

```cmd
robocopy C:\install-media S:\ /E /XF safeline-2-software-installer.bin safeline-2-software-installer.bin.password
copy /Y C:\install-media\safeline-2-software-installer.bin E:\
copy /Y C:\install-media\safeline-2-software-installer.bin.password E:\
```

确认文件：

```powershell
Get-Item E:\safeline-2-software-installer.bin,E:\safeline-2-software-installer.bin.password | Format-Table Name,Length
```

### 4.5 生成 Linux 可直接校验的 SHA256 文件

PowerShell 执行：

```powershell
$File='E:\safeline-2-software-installer.bin'
$Hash=(Get-FileHash $File -Algorithm SHA256).Hash.ToLower()
"$Hash  safeline-2-software-installer.bin" | Set-Content -Encoding ascii S:\safeline-2-software-installer.bin.sha256
```

服务器启动后可直接使用：

```bash
sha256sum -c /media/sdc1/safeline-2-software-installer.bin.sha256
```

复制完成后，在任务栏中安全弹出 U 盘。

---

## 5. 服务器启动后的公共操作

无论 U 盘由 macOS 还是 Windows 制作，服务器端步骤相同。

### 5.1 识别 U 盘和两个分区

进入 Linux 安装环境后，不要默认 U 盘一定是 `/dev/sdc`。

执行：

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

以下步骤假设识别结果为：

```text
/dev/sdc1  SYSTEM
/dev/sdc2  EXFAT_PART
```

实际设备名不同时，后续命令必须同步替换。

确认文件系统：

```bash
blkid /dev/sdc1
blkid /dev/sdc2
```

### 5.2 挂载两个分区

先检查是否已经自动挂载：

```bash
findmnt -S /dev/sdc1
findmnt -S /dev/sdc2
```

如果未挂载：

```bash
mkdir -p /media/sdc1 /media/sdc2
mount -t vfat /dev/sdc1 /media/sdc1
mount -t exfat /dev/sdc2 /media/sdc2
```

如果以普通用户操作 exFAT，可按需要使用：

```bash
mount -t exfat /dev/sdc2 /media/sdc2 -o uid=$(id -u),gid=$(id -g),umask=022
```

安装环境通常直接使用 root，此时无需额外指定 `uid/gid`。

验证：

```bash
findmnt /media/sdc1
findmnt /media/sdc2
df -hT | grep -E '/media/sdc[12]'
```

### 5.3 exFAT 挂载失败

如果出现：

```text
unknown filesystem type 'exfat'
```

先尝试：

```bash
modprobe exfat
mount -t exfat /dev/sdc2 /media/sdc2
```

如果仍失败，说明当前安装环境缺少可用的 exFAT 支持。此时不要格式化分区或继续安装，应更换支持 exFAT 的安装环境，或重新设计第二分区文件系统。

### 5.4 校验大文件

```bash
ls -lh /media/sdc2/safeline-2-software-installer.bin*
```

存在 SHA256 文件时：

```bash
cd /media/sdc2
sha256sum -c /media/sdc1/safeline-2-software-installer.bin.sha256
```

正常结果：

```text
safeline-2-software-installer.bin: OK
```

校验失败时不要继续安装，应重新复制安装包。

### 5.5 确认 install.sh 支持 BIN_MOUNT_POINT

```bash
cd /media/sdc1
grep -n 'BIN_MOUNT_POINT' ./install.sh
```

有匹配结果：可以继续使用双分区方案。

无匹配结果：当前脚本版本可能不支持通过环境变量指定安装包目录，不应直接继续。

### 5.6 确认系统安装目标盘

```bash
lsblk -o NAME,TRAN,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
```

本文示例假设：

```text
sda = 服务器目标系统盘
sdc = 启动 U 盘
```

必须根据实际容量和型号确认，不要仅根据盘符猜测。

### 5.7 执行安装

```bash
cd /media/sdc1
BIN_MOUNT_POINT=/media/sdc2 ./install.sh sda
```

或者：

```bash
export BIN_MOUNT_POINT=/media/sdc2
./install.sh sda
```

不要使用下面这种方式后直接启动子进程：

```bash
BIN_MOUNT_POINT=/media/sdc2
./install.sh sda
```

因为未 `export` 的普通 Shell 变量通常不会传递给 `install.sh` 子进程。

> **高风险操作：** `./install.sh sda` 可能重新分区、格式化或覆盖 `sda`。执行前必须确认 `sda` 是目标系统盘，不是 U 盘或其他数据盘。

---

## 6. 常见问题

### 6.1 可以从 SYSTEM 启动，但服务器看不到 EXFAT_PART

执行：

```bash
lsblk -f
blkid
```

固件阶段不需要读取 `EXFAT_PART`。只要 Linux 启动后能够识别并挂载第二分区即可。

如果第二分区存在但不能挂载，重点检查 exFAT 驱动支持。

### 6.2 服务器完全无法从 U 盘启动

依次确认：

1. BIOS/UEFI 是否允许 USB Boot。
2. 是否选择正确的 UEFI/Legacy 启动项。
3. `SYSTEM` 是否为第一个 FAT32 分区。
4. 启动文件是否完整复制到 `SYSTEM` 根目录结构中。
5. 服务器是否明确要求 GPT 或特定启动模式。
6. Windows 制作时可确认 MBR `SYSTEM` 分区是否已设置 `active`；纯 UEFI 机器通常不依赖该标记。

### 6.3 install.sh 找不到 .bin

```bash
ls -lh /media/sdc2/safeline-2-software-installer.bin
printf '%s\n' "$BIN_MOUNT_POINT"
grep -n 'BIN_MOUNT_POINT' /media/sdc1/install.sh
```

确认：

- `/media/sdc2` 已挂载。
- `.bin` 和 `.password` 文件名未改变。
- 当前安装脚本支持 `BIN_MOUNT_POINT`。
- 环境变量使用同行赋值或 `export` 传给脚本。

### 6.4 Windows 的 FAT32 格式化报卷太大

Windows 版本和格式化入口存在差异：

- 较老 Windows 版本和部分 GUI/命令行工具仍可能限制新建 FAT32 卷大小。
- Microsoft 已在较新的 Windows 11 命令行格式化功能中逐步把 FAT32 格式化上限提升到 2 TB。

遇到报错时优先：

1. 使用本文的 `SYSTEM=30000 MB` 兼容方案。
2. 确认除 `.bin` 外的启动文件能放入 `SYSTEM`。
3. 剩余空间全部给 exFAT。
4. 如果 `SYSTEM` 必须更大，可在当前 Windows 版本验证新的命令行 `format` 能力，或使用 macOS 方案。

不要把 FAT32 与 exFAT 的职责颠倒，否则可能造成服务器无法启动。

---

## 7. 备选方案：两个 U 盘

如果目标服务器或安装环境对单 U 盘双分区兼容性不好，可以使用两个 U 盘：

```text
U 盘 1：FAT32，仅负责启动
U 盘 2：exFAT，仅存放 .bin 和 .password
```

进入 Linux 后挂载第二个 U 盘，再把 `BIN_MOUNT_POINT` 指向第二个 U 盘的挂载目录。

该方案增加一个物理介质，但结构更简单，也能避开部分旧服务器对多分区可移动介质处理不一致的问题。

不建议默认把大文件拆成多个小文件，除非安装脚本明确支持分片或安装前存在可靠的重组流程。

---

## 8. 恢复 U 盘为普通单分区

### 8.1 macOS

重新确认 U 盘编号：

```bash
diskutil list
```

确认后恢复单个 FAT32 分区：

```bash
sudo diskutil eraseDisk FAT32 CT /dev/disk2
```

验证：

```bash
diskutil list /dev/disk2
```

> `eraseDisk` 会删除整个 U 盘上的全部分区和文件。

### 8.2 Windows

管理员终端执行：

```text
diskpart
list disk
select disk 2
detail disk
clean
convert mbr
create partition primary
format fs=exfat quick label=CT
assign
exit
```

恢复为普通数据 U 盘时，exFAT 对大容量设备最省事。

如果明确需要 FAT32，可根据当前 Windows 版本和 U 盘容量尝试：

```text
format fs=fat32 quick label=CT
```

如果提示卷太大，则缩小 FAT32 分区、使用支持大 FAT32 格式化的当前 Windows 命令行能力，或在 macOS 上恢复。

---

## 9. 最短操作流程

```text
macOS
  diskutil list
  ↓
  diskutil partitionDisk → FAT32 SYSTEM + exFAT EXFAT_PART

Windows
  Get-Disk / diskpart list disk
  ↓
  clean + convert mbr
  ↓
  FAT32 SYSTEM（兼容示例约 30 GB）+ exFAT EXFAT_PART

共同步骤
  ↓
SYSTEM：除 .bin/.password 外的全部启动文件
EXFAT_PART：.bin + .password
  ↓
服务器从 SYSTEM 启动
  ↓
lsblk / blkid 确认 U 盘两个分区
  ↓
mount SYSTEM + EXFAT_PART
  ↓
sha256sum 校验大文件
  ↓
grep 确认 install.sh 支持 BIN_MOUNT_POINT
  ↓
确认 sda 是服务器目标系统盘
  ↓
BIN_MOUNT_POINT=/media/sdc2 ./install.sh sda
```

## 相关资料

- UEFI Specification：<https://uefi.org/specifications>
- UEFI Media Access / File System：<https://uefi.org/specs/UEFI/2.11/13_Protocols_Media_Access.html>
- Microsoft DiskPart：<https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskpart>
- Microsoft `create partition primary`：<https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/create-partition-primary>
- Microsoft `format`：<https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/format>
- Windows 11 FAT32 命令行格式化上限调整（Windows Insider）：<https://blogs.windows.com/windows-insider/2026/04/10/announcing-windows-11-insider-preview-build-26220-8165-beta-channel/>
