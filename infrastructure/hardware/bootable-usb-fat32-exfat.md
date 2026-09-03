# 服务器双分区启动 U 盘

用于解决“服务器需 FAT/FAT32 启动，但安装包存在 >4 GB 单文件”的场景：`SYSTEM` 使用 FAT32 启动，`EXFAT_PART` 使用 exFAT 存放大文件。本文以 `safeline-2-software-installer.bin` 为例。

> **风险：** 分区、格式化和 `./install.sh sda` 都可能清空磁盘。执行前必须按容量、型号、USB 标识确认 U 盘和目标系统盘，不能只凭 `disk2`、`Disk 2`、`sda`、`sdc` 盘符判断。

## 1. 文件放置

```text
SYSTEM (FAT32)：除以下两个文件外的全部安装文件
EXFAT_PART (exFAT)：safeline-2-software-installer.bin
                    safeline-2-software-installer.bin.password
```

FAT32 单文件上限约 4 GB；exFAT 用于大文件。示例使用 MBR 兼顾 Legacy BIOS/UEFI；目标服务器明确要求 GPT 时按厂商要求调整。

## 2. macOS 制作

先确认 U 盘：

```bash
diskutil list
diskutil info /dev/disk2 | egrep 'Device / Media Name|Disk Size|Protocol|Internal'
```

确认 `/dev/disk2` 为目标 U 盘后创建双分区：

```bash
sudo diskutil partitionDisk /dev/disk2 MBR FAT32 SYSTEM 60% exFAT EXFAT_PART R
diskutil list /dev/disk2
```

访达中应看到 `SYSTEM` 和 `EXFAT_PART`。复制文件后检查大文件并弹出：

```bash
ls -lh /Volumes/EXFAT_PART/safeline-2-software-installer.bin*
(cd /Volumes/EXFAT_PART && shasum -a 256 safeline-2-software-installer.bin) > /Volumes/SYSTEM/safeline-2-software-installer.bin.sha256
diskutil eject /dev/disk2
```

恢复普通单分区：

```bash
diskutil list
sudo diskutil eraseDisk FAT32 CT /dev/disk2
```

## 3. Windows 制作

管理员 PowerShell 先确认 U 盘编号：

```powershell
Get-Disk | Sort-Object Number | Format-Table Number,FriendlyName,BusType,PartitionStyle,@{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}}
```

再用 DiskPart 二次确认并创建双分区。以下仅假设 U 盘为 `Disk 2`：

```text
diskpart
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
list volume
exit
```

`SYSTEM=30000 MB` 是兼容性保守值，不是 FAT32 文件系统容量上限；只要能容纳除大 `.bin` 外的启动文件即可。

复制文件：`S:\` 放除 `.bin`、`.password` 外全部文件，`E:\` 放这两个大文件。命令方式：

```cmd
robocopy C:\install-media S:\ /E /XF safeline-2-software-installer.bin safeline-2-software-installer.bin.password
copy /Y C:\install-media\safeline-2-software-installer.bin E:\
copy /Y C:\install-media\safeline-2-software-installer.bin.password E:\
```

生成 SHA256：

```powershell
$File='E:\safeline-2-software-installer.bin'; $Hash=(Get-FileHash $File -Algorithm SHA256).Hash.ToLower(); "$Hash  safeline-2-software-installer.bin" | Set-Content -Encoding ascii S:\safeline-2-software-installer.bin.sha256
```

恢复普通单分区：

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

## 4. U 盘启动服务器并安装产品

无论由 macOS 还是 Windows 制作，服务器端步骤相同。先确认 U 盘和目标系统盘；以下示例假设 U 盘为 `/dev/sdc`、系统目标盘为 `/dev/sda`。

### 4.1 识别并挂载

```bash
lsblk -o NAME,TRAN,SIZE,FSTYPE,LABEL,MOUNTPOINTS,MODEL
fdisk -l
blkid /dev/sdc1
blkid /dev/sdc2
mkdir -p /media/sdc1 /media/sdc2
findmnt -S /dev/sdc1 >/dev/null || mount -t vfat /dev/sdc1 /media/sdc1
findmnt -S /dev/sdc2 >/dev/null || mount -t exfat /dev/sdc2 /media/sdc2
findmnt /media/sdc1
findmnt /media/sdc2
df -hT | grep -E '/media/sdc[12]'
```

若 `mount -t exfat` 报 `unknown filesystem type 'exfat'`：

```bash
modprobe exfat
mount -t exfat /dev/sdc2 /media/sdc2
```

仍失败则当前启动环境缺少 exFAT 支持，不要继续安装。

### 4.2 检查安装包和脚本

```bash
ls -lh /media/sdc2/safeline-2-software-installer.bin*
cd /media/sdc2 && sha256sum -c /media/sdc1/safeline-2-software-installer.bin.sha256
cd /media/sdc1
grep -n 'BIN_MOUNT_POINT' ./install.sh
```

SHA256 应返回 `OK`；`grep` 必须能确认当前 `install.sh` 支持 `BIN_MOUNT_POINT`，否则不要直接套用本方案。

### 4.3 确认目标盘并安装

```bash
lsblk -o NAME,TRAN,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
cd /media/sdc1
BIN_MOUNT_POINT=/media/sdc2 ./install.sh sda
```

如需分两步设置变量，必须 `export`：

```bash
export BIN_MOUNT_POINT=/media/sdc2
./install.sh sda
```

> **最终确认：** 执行安装前必须确认 `sda` 是服务器目标系统盘，`sdc` 是启动 U 盘。

## 5. 常见故障

| 现象 | 处理 |
| --- | --- |
| U 盘不能启动 | 检查 USB Boot、UEFI/Legacy 模式、`SYSTEM` 是否为 FAT32 第一分区、启动文件是否完整、服务器是否要求 GPT |
| Linux 看得到 `/dev/sdc2` 但挂载失败 | `modprobe exfat`；仍失败则更换支持 exFAT 的启动环境 |
| `install.sh` 找不到 `.bin` | 检查 `/media/sdc2` 是否挂载、文件名是否正确、`BIN_MOUNT_POINT` 是否同行传入或已 `export` |
| 单 U 盘双分区兼容性差 | 使用两个 U 盘：U 盘 1 FAT32 启动，U 盘 2 exFAT 存放 `.bin` 和 `.password` |

## 参考

- UEFI Specification：<https://uefi.org/specifications>
- Microsoft DiskPart：<https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskpart>
- Microsoft format：<https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/format>
