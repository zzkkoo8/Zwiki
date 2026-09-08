# Linux 磁盘与 LVM 扩容

用于快速判断根目录所在磁盘是否还有可用空间，并按实际情况扩容 LVM 逻辑卷和文件系统。

> 扩容前先确认设备名、VG、LV、文件系统和挂载点。生产环境建议先做快照或备份。不要直接复制示例中的设备名到其他主机。

## 1. 先判断有没有空间可扩

### 1.1 查看磁盘、分区、LVM 和挂载关系

```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
```

查看文件系统：

```bash
df -hT
```

确认根目录实际设备：

```bash
findmnt -no SOURCE,FSTYPE /
```

### 1.2 查看物理磁盘是否还有未分区空间

```bash
lsblk
fdisk -l
```

最直观的检查方式：

```bash
parted /dev/vda unit GiB print free
```

重点看输出中的 `Free Space`。

如果根目录在 `/dev/vda3`，而 `/dev/vda` 尾部还有未分区空间，则可以先扩 `/dev/vda3`，再扩 PV、LV 和文件系统。

如果磁盘本身没有 `Free Space`，说明这块磁盘当前没有可直接利用的未分区空间。此时需要扩大虚拟磁盘、增加新磁盘，或者迁移数据。

### 1.3 检查 LVM 的 PV 是否还有空余空间

```bash
pvs
```

重点看 `PFree`。`PFree=0` 表示 PV 中没有未分配空间。

详细查看：

```bash
pvdisplay
```

### 1.4 检查 VG 是否还有空余空间

```bash
vgs
```

重点看 `VFree`。`VFree=0` 表示 VG 没有空间可以直接分给现有 LV。

详细查看：

```bash
vgdisplay
```

### 1.5 查看 LV

```bash
lvs
```

同时查看路径和大小：

```bash
lvs -o lv_name,vg_name,lv_size,lv_path
```

### 1.6 最小检查清单

只想快速判断能不能扩容，执行：

```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
fdisk -l
pvs
vgs
lvs
df -hT
```

需要确认某块磁盘尾部是否有未分区空间：

```bash
parted /dev/vda unit GiB print free
```

## 2. 判断扩容属于哪种情况

| 情况 | 判断依据 | 处理方式 |
| --- | --- | --- |
| VG 已有空闲空间 | `vgs` 的 `VFree` 大于 0 | 直接扩 LV |
| PV 所在分区后还有空间 | `parted ... print free` 显示分区后有 `Free Space` | 扩分区 → `pvresize` → 扩 LV |
| 虚拟磁盘已扩容，但 Linux 分区没变 | 磁盘容量已经变大，PV 分区仍是原大小 | 扩分区 → `pvresize` → 扩 LV |
| PV 直接使用整块磁盘 | 例如 `/dev/vdb` 本身就是 `LVM2_member` | 磁盘扩容后直接 `pvresize /dev/vdb` |
| 原磁盘无空间，但有新磁盘 | `lsblk` 能看到新的空盘 | 新盘初始化为 PV → 加入 VG → 扩 LV |
| VG、PV、物理磁盘全部无空闲 | `VFree=0`、`PFree=0`、磁盘无 `Free Space` | 先扩物理磁盘、增加磁盘或迁移目录 |

## 3. 场景一：VG 已有空闲空间

先确认：

```bash
vgs
lvs
findmnt -no SOURCE,FSTYPE /
```

假设根 LV 是 `/dev/mapper/klas-root`。

增加 20G：

```bash
lvextend -L +20G /dev/mapper/klas-root
```

或者使用 VG 全部剩余空间：

```bash
lvextend -l +100%FREE /dev/mapper/klas-root
```

如果根文件系统是 XFS：

```bash
xfs_growfs /
```

如果是 ext4：

```bash
resize2fs /dev/mapper/klas-root
```

验证：

```bash
df -hT /
lvs
```

> `lvextend -r` 可以尝试自动扩文件系统，但运维操作中建议将 LV 扩容和文件系统扩容分开执行，便于确认每一步结果。

## 4. 场景二：磁盘有未分区空间，扩现有 LVM 分区

假设结构为：

```text
/dev/vda
└─ /dev/vda3     LVM PV
   └─ klas-root
```

先检查：

```bash
parted /dev/vda unit GiB print free
```

确认 `/dev/vda3` 后面确实存在连续的 `Free Space` 后再继续。

### 4.1 扩大分区

优先使用 `growpart`。

Ubuntu / Debian 安装：

```bash
apt update
apt install -y cloud-guest-utils
```

RHEL / Rocky / CentOS 安装：

```bash
dnf install -y cloud-utils-growpart
```

扩第 3 个分区：

```bash
growpart /dev/vda 3
```

检查：

```bash
lsblk
fdisk -l /dev/vda
```

### 4.2 扩大 PV

```bash
pvresize /dev/vda3
```

验证：

```bash
pvs
vgs
```

此时 `PFree` / `VFree` 应出现新增空间。

### 4.3 扩大 LV

使用全部剩余 VG 空间：

```bash
lvextend -l +100%FREE /dev/mapper/klas-root
```

或者只增加指定容量：

```bash
lvextend -L +20G /dev/mapper/klas-root
```

### 4.4 扩文件系统

XFS：

```bash
xfs_growfs /
```

ext4：

```bash
resize2fs /dev/mapper/klas-root
```

最终验证：

```bash
lsblk
pvs
vgs
lvs
df -hT /
```

## 5. 场景三：虚拟机平台已经把磁盘调大

例如虚拟化平台已经把 `/dev/vda` 从 50G 扩到 100G，但 Linux 内的 `/dev/vda3` 还是原大小。

先检查：

```bash
lsblk
fdisk -l /dev/vda
```

确认系统已经识别新的磁盘容量后：

```bash
growpart /dev/vda 3
```

```bash
pvresize /dev/vda3
```

```bash
vgs
```

```bash
lvextend -l +100%FREE /dev/mapper/klas-root
```

XFS：

```bash
xfs_growfs /
```

ext4：

```bash
resize2fs /dev/mapper/klas-root
```

验证：

```bash
lsblk
pvs
vgs
lvs
df -hT /
```

## 6. 场景四：PV 直接使用整块磁盘

有些主机没有在数据盘上创建分区，而是直接把整个磁盘作为 PV，例如：

```text
vdb                   LVM2_member
└─vg-data-lv          xfs
```

确认：

```bash
pvs
lsblk -f
```

如果 PV 就是 `/dev/vdb`，虚拟化平台扩大 `/dev/vdb` 后不需要 `growpart`。

系统识别到新的磁盘容量后直接执行：

```bash
pvresize /dev/vdb
```

验证：

```bash
pvs
vgs
```

然后扩 LV，例如：

```bash
lvextend -l +100%FREE /dev/mapper/vg-data-lv
```

XFS 按挂载点扩：

```bash
xfs_growfs /data
```

ext4 按 LV 设备扩：

```bash
resize2fs /dev/mapper/vg-data-lv
```

验证：

```bash
df -hT /data
```

## 7. 场景五：新增磁盘加入现有 VG

假设新增磁盘是 `/dev/vdc`。

先确认它确实是新增空盘：

```bash
lsblk -f /dev/vdc
fdisk -l /dev/vdc
```

> 后续初始化 PV 会写入 LVM 元数据，必须先确认设备选对，禁止对已有业务数据的磁盘操作。

创建 PV：

```bash
pvcreate /dev/vdc
```

加入已有 VG，例如 `klas`：

```bash
vgextend klas /dev/vdc
```

验证：

```bash
pvs
vgs
```

把 VG 全部空闲空间扩给根 LV：

```bash
lvextend -l +100%FREE /dev/mapper/klas-root
```

XFS：

```bash
xfs_growfs /
```

ext4：

```bash
resize2fs /dev/mapper/klas-root
```

验证：

```bash
lsblk
pvs
vgs
lvs
df -hT /
```

## 8. 示例：判断根盘是否已经没有可扩空间

例如：

```text
PV         VG    PSize   PFree
/dev/vda3  klas  48.41g      0

VG    VSize   VFree
klas  48.41g      0
```

这只能说明：

- PV 当前没有空闲 PE；
- VG 当前没有可直接分配给 LV 的空间。

还不能仅凭 `pvs` / `vgs` 判断物理磁盘尾部有没有未分区空间。

继续执行：

```bash
fdisk -l /dev/vda
parted /dev/vda unit GiB print free
```

如果 `/dev/vda` 也没有 `Free Space`，则当前根盘扩容路径只剩：

1. 在虚拟化平台扩大 `/dev/vda`；
2. 新增磁盘并加入原 VG；
3. 把大目录迁移到其他大容量文件系统。

## 9. 文件系统注意事项

### XFS

XFS 在线扩容：

```bash
xfs_growfs <挂载点>
```

例如：

```bash
xfs_growfs /
```

XFS 支持扩容，但不能原地缩小文件系统。因此不要规划“先把现有 XFS LV 缩小，再从 VG 中切空间”的操作。

### ext4

扩容：

```bash
resize2fs <LV设备>
```

例如：

```bash
resize2fs /dev/mapper/klas-root
```

## 10. 扩容后统一验证

```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
pvs
vgs
lvs
df -hT
findmnt
```

重点确认：

- 物理磁盘和分区大小正确；
- PV 大小已更新；
- VG 的空间分配符合预期；
- LV 已扩大；
- 文件系统容量已扩大；
- 原挂载点没有变化；
- 业务服务正常。

## 11. 常见错误

### `vgs` 显示 `VFree=0`

不能直接扩 LV。继续检查物理磁盘是否有未分区空间：

```bash
parted /dev/vda unit GiB print free
```

### 平台扩了磁盘，但 `vgs` 还是没有空间

通常还缺少：

```text
扩分区 → pvresize
```

分区式 PV 示例：

```bash
growpart /dev/vda 3
pvresize /dev/vda3
```

整盘式 PV 示例：

```bash
pvresize /dev/vdb
```

### LV 扩了，但 `df -h` 没变化

通常是文件系统还没有扩。

XFS：

```bash
xfs_growfs <挂载点>
```

ext4：

```bash
resize2fs <LV设备>
```
