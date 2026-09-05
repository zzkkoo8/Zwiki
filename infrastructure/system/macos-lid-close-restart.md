# macOS 合盖后崩溃重启排查

适用于 MacBook Pro 在合上屏幕后进入睡眠、再次开盖或睡眠期间发生崩溃、自动重启，并出现“电脑因出现问题而重新启动”等现象。本文同时覆盖 Apple Silicon 的 DCP 路径，以及 Intel + Apple T2 机型的 EFI / BridgeOS / Touch Bar 路径。

## 文档信息

- **技术领域**：macOS / 电源管理 / Kernel Panic
- **适用范围**：MacBook Pro；覆盖 Apple Silicon 与 Intel + Apple T2 机型
- **典型机型**：2022 MacBook Pro 13-inch M2；2020 MacBook Pro 13-inch Intel（MacBookPro16,3）
- **风险等级**：只读排查低风险；修改 `pmset`、重置 SMC 为中风险；DFU Restore 为高风险
- **文档状态**：已验证，含 MacBookPro16,3 实测案例
- **最后验证**：2026-09-05
- **主要来源**：Apple Support、macOS `pmset` / `log` 手册、脱敏实测日志、Apple Community 案例

## 1. 现象与判断原则

正常情况下，MacBook 合盖会进入睡眠，而不是关机或重启。若开盖后重新出现 Apple Logo、登录后提示“电脑因出现问题而重新启动”，通常应按 **睡眠/唤醒路径崩溃** 排查，而不是先改电源参数。

Apple 官方指出，意外重启常见原因包括已安装的软件、外接设备以及硬件故障；推荐顺序是更新系统、断开外设、安全模式隔离、Apple Diagnostics，必要时再进行系统或固件级恢复。

Apple Silicon 机型的一类社区案例会出现：

```text
DCP PANIC
No device added after powering on the rails
AppleDCPDPTXPowerController
```

Intel + T2 机型则可能出现另一类特征：

```text
Sleep Wake failure in EFI
Failure code:: 0x00000000 0x0000001f
panic ... ADPParamFIFO::programFIFO ...
ADP FIFO still busy after 1000ms
```

这些字符串可以显著缩小故障层，但**不能只凭单条日志直接判定必须换屏幕、Touch Bar、主板或传感器**。最终应结合本机 panic、睡眠/唤醒日志、外设状态、SMC/T2 固件处理结果和 Apple Diagnostics 判断。

## 2. 安全边界

排查阶段优先使用只读命令。不要一开始执行以下网络常见“偏方”：

- 不要直接修改 `hibernatemode`、删除 sleep image 或批量改 `pmset` 参数。
- 不要把 `sudo pmset -a lidwake 0` 当作修复方案；它主要控制开盖唤醒，并不能证明或修复进入睡眠时的 Kernel Panic。
- Apple Silicon 不需要按 Intel 时代的方法手动重置 SMC；Apple 官方建议直接重启 Mac。
- Intel + T2 机型可以按 Apple 官方流程重置 SMC，但应先保留日志，避免把可复现证据清掉后再猜原因。
- 不要根据 `Previous shutdown cause` 的单个数字直接下硬件结论；应结合 panic 报告和睡眠/唤醒日志。
- 未备份重要数据前，不执行抹盘、DFU Restore、重装系统等破坏性操作。
- `DFU Revive` 与 `DFU Restore` 不是同一操作：优先考虑不抹数据的 Revive；Restore 会抹除设备。

## 3. 一次性采集基础信息

先确认机型、芯片、当前 macOS 版本以及最近一次启动时间：

```bash
system_profiler SPHardwareDataType
sw_vers
uname -a
uptime
```

重点记录：

- `Model Name` / `Model Identifier`
- `Chip` 或 `Processor Name`
- 是否带 Apple T2（Intel 2018–2020 MacBook Pro 常见）
- macOS 版本和 Build
- 是否每次合盖都复现，还是放置数分钟/数小时才复现
- 电池供电与接电源时是否都复现
- 是否连接扩展坞、外接显示器、USB/Thunderbolt 设备

Intel 机型可进一步确认 T2：

```bash
system_profiler SPiBridgeDataType 2>/dev/null
```

## 4. 先确认是不是 Kernel Panic

### 4.1 查看崩溃报告目录

```bash
ls -lt /Library/Logs/DiagnosticReports/ | head -30
```

不要只看顶层目录。Intel + T2 机型的关键 panic 可能在：

```text
/Library/Logs/DiagnosticReports/ProxiedDevice-Bridge/
```

快速寻找最近的 `.panic`、`.ips`、`.diag`：

```bash
find /Library/Logs/DiagnosticReports \
  -type f \( -name '*.panic' -o -name '*.ips' -o -name '*.diag' \) \
  -mtime -7 -print 2>/dev/null | tail -100
```

按关键词定位：

```bash
grep -RliE \
  'panic|sleep.?wake|DCP|AppleDCP|IOPMrootDomain|ADPParamFIFO|Sleep Wake failure in EFI|dfrd' \
  /Library/Logs/DiagnosticReports 2>/dev/null | tail -50
```

如果找到近期报告，可先看前 120 行：

```bash
sed -n '1,120p' /Library/Logs/DiagnosticReports/<报告文件>
```

重点搜索：

```text
panicString
DCP PANIC
AppleDCP
AppleDCPDPTXPowerController
Sleep/Wake hang detected
Sleep Wake failure in EFI
ADPParamFIFO
ADP FIFO still busy after 1000ms
dfrd
IOPMrootDomain
ProxiedDevice-Bridge
Thunderbolt
USB
GPU
```

### 4.2 判断

- **存在明确 `panicString` / `DCP PANIC`**：按 Kernel Panic 路径继续。
- **存在 `Sleep Wake failure in EFI` + BridgeOS panic**：优先检查 Intel + T2 / Touch Bar / 固件设备链路。
- **存在 `Sleep/Wake hang detected`**：重点排查睡眠/唤醒状态机、外设和第三方驱动。
- **完全没有 panic 报告**：继续查统一日志和关机/重启事件，避免把正常关机、断电或用户操作误判为 Kernel Panic。

## 5. 查看睡眠/唤醒历史

`pmset` 自带睡眠/唤醒历史，是此问题最有价值的只读命令之一：

```bash
pmset -g log | tail -200
```

只看常见关键事件：

```bash
pmset -g log | \
  grep -Ei 'sleep|wake|darkwake|failure|panic|shutdown|restart|clamshell' | \
  tail -300
```

查看当前电源管理配置：

```bash
pmset -g
pmset -g custom
pmset -g sched
```

查看是否有应用或后台进程持有电源断言：

```bash
pmset -g assertions
```

判断重点：

- 合盖时间附近是否出现 `Clamshell Sleep`。
- 随后是否正常 `Wake` / `DarkWake`。
- 是否紧跟 `Failure during sleep`、`Sleep Wake failure in EFI`、`Restart`。
- 是否有某个进程长期持有 `PreventSystemSleep` / `PreventUserIdleSystemSleep`。
- Intel + T2 机型是否出现 `EC.Hid-DFR`、`AppleTopCaseHIDEventDriver` 等异常。

`pmset -g assertions` 主要用于解释“为什么不睡眠/频繁唤醒”，不能单独证明 Kernel Panic 根因。

## 6. 从 macOS Unified Log 找证据

查看最近 24 小时与 panic、睡眠/唤醒相关的系统日志：

```bash
log show --last 24h --style compact \
  --predicate 'eventMessage CONTAINS[c] "panic" OR eventMessage CONTAINS[c] "sleep wake" OR eventMessage CONTAINS[c] "Previous shutdown cause"' \
  | tail -300
```

Intel + T2 机型建议把 BridgeOS / DFR 也纳入：

```bash
log show --last 24h --style compact --info \
  --predicate 'eventMessage CONTAINS[c] "Bridge OS" OR eventMessage CONTAINS[c] "ProxiedDevice-Bridge" OR eventMessage CONTAINS[c] "Hid-DFR" OR eventMessage CONTAINS[c] "ADPParamFIFO" OR eventMessage CONTAINS[c] "Sleep Wake failure in EFI"' \
  | tail -400
```

如果问题刚刚复现，可把范围缩到 1 小时：

```bash
log show --last 1h --style compact --info \
  --predicate 'eventMessage CONTAINS[c] "sleep" OR eventMessage CONTAINS[c] "wake" OR eventMessage CONTAINS[c] "panic" OR eventMessage CONTAINS[c] "DCP" OR eventMessage CONTAINS[c] "Bridge"' \
  | tail -400
```

需要提交给 Apple 或进一步离线分析时，可以收集最近一段时间的统一日志：

```bash
mkdir -p ~/Desktop/mac-sleep-debug
sudo log collect --last 2h --output ~/Desktop/mac-sleep-debug/system_logs.logarchive
```

> `log collect` 会收集大量系统诊断信息。对外发送前应确认其中没有不希望共享的隐私数据。

## 7. 检查外接设备与扩展坞

Apple 官方明确建议：意外重启排查时先断开外设，再逐个接回验证。

先记录当前 USB / Thunderbolt 设备：

```bash
system_profiler SPUSBDataType
system_profiler SPThunderboltDataType
```

测试方法：

1. 完全关机。
2. 断开扩展坞、Type-C Hub、外接显示器、USB 网卡、移动硬盘、采集卡等设备。
3. 只保留充电器，开机后重复“合盖 → 等待 → 开盖”。
4. 如果不再重启，每次只接回一个设备复测。

如果仅在连接某个扩展坞或显示器时出现 `DCP` / Thunderbolt 相关 panic，应优先检查该外设、线缆、固件和驱动，而不是先改系统睡眠参数。

如果日志显示 `ProxiedDevice-Bridge` / `ADPParamFIFO`，同时 Thunderbolt 明确为 `No device connected`，则外接扩展坞不是该次故障的首要嫌疑。

## 8. 检查第三方系统扩展与驱动

现代 macOS 更多使用 System Extension；老软件可能仍安装 Kernel Extension。

查看 System Extension：

```bash
systemextensionsctl list
```

查看已加载内核扩展：

```bash
kmutil showloaded
```

只关注第三方项时可辅助过滤：

```bash
kmutil showloaded 2>/dev/null | grep -v 'com.apple'
```

高优先级排查对象：

- VPN / 网络过滤器
- 杀毒、EDR、安全软件
- NTFS / 文件系统驱动
- USB 网卡、扩展坞、DisplayLink 类显示驱动
- 虚拟化软件
- 远程控制或长期持有睡眠断言的软件
- 老版本硬件管理工具

若故障始于安装或升级上述软件之后，应优先升级或使用厂商卸载程序完整移除，再复测。

但如果 panic 明确发生在 **BridgeOS / T2 的 `kernel_task`**，不能仅因为系统存在第三方 kext 就把根因归到该 kext；需要有 panic 回溯、时间关联或移除后不再复现的证据。

## 9. 更新 macOS

Apple 将“安装所有可用的软件更新”列为意外重启的首要软件排查步骤之一。

只查看可用更新：

```bash
softwareupdate --list
```

推荐通过：

```text
系统设置 → 通用 → 软件更新
```

安装该机型支持的最新稳定版 macOS 后重新测试合盖。不要为了排障主动切换到 Beta 系统。

对于 Intel + T2 机型，macOS 更新同时也是获得适配固件 / BridgeOS 更新的常规渠道，因此长期停留在较老系统时应把升级放在较高优先级。

## 10. 安全模式复现

如果普通模式合盖必现，而安全模式不复现，第三方软件、启动项、扩展或缓存的嫌疑明显上升。

### Apple Silicon

1. 关机。
2. 长按电源/Touch ID，直到出现“启动选项”。
3. 选择启动磁盘。
4. 按住 `Shift`，点击“以安全模式继续”。
5. 登录后重复合盖测试。

### Intel Mac

1. 关机。
2. 按电源键开机后立即按住 `Shift`。
3. 出现登录窗口后松开 `Shift`。
4. 登录并重复合盖测试。

判断：

- **安全模式不复现**：回到第三方软件、驱动、登录项方向。
- **安全模式仍复现**：继续做 Apple Diagnostics；若日志仍稳定出现同一 DCP / BridgeOS / EFI panic，硬件或固件概率上升。

## 11. Apple Diagnostics 硬件自检

### Apple Silicon

1. 关机并断开非必要外设。
2. 长按电源键直到出现启动选项。
3. 松开电源键。
4. 按住 `Command (⌘) + D`，进入 Apple Diagnostics。
5. 保存检测结果和 Reference Code。

### Intel Mac

1. 关机并断开非必要外设。
2. 开机后立即按住 `D`。
3. 如无法进入，可尝试 `Option + D` 使用联网诊断。
4. 保存 Reference Code。

Apple Diagnostics 没报错并不能排除所有间歇性睡眠、Touch Bar、T2 或显示链路问题，但如果存在明确硬件 Reference Code，应停止继续修改系统配置并优先维修。

## 12. 按日志分类处理

### 12.1 DCP / AppleDCP / Display 相关 Panic

特征：

```text
DCP PANIC
AppleDCPDPTXPowerController
No device added after powering on the rails
```

处理顺序：

1. 更新到当前稳定版 macOS。
2. 移除所有外接显示器、扩展坞和 USB/Thunderbolt 设备复测。
3. 安全模式复测。
4. Apple Diagnostics。
5. 如果在**无外设 + 安全模式/纯净系统**下仍稳定复现，将 panic 文件一并提交 Apple 支持。

社区中存在最终通过显示组件、固件/ROM 处理后恢复的案例，但维修动作不能仅凭报错字符串决定。

### 12.2 `Sleep/Wake hang detected` / `IOPMrootDomain`

优先检查：

```bash
pmset -g log | tail -300
pmset -g assertions
systemextensionsctl list
```

随后执行：

- 断开外设。
- 更新 macOS 和第三方驱动。
- 安全模式复测。
- 移除近期新增的 VPN、文件系统、安全软件、虚拟化和外设驱动。

### 12.3 只有接扩展坞/显示器才崩溃

重点检查：

- Type-C / Thunderbolt Hub
- 外接显示器和转接器
- DisplayLink 或厂商显示驱动
- 充电器与 PD 供电
- 线缆

必须用“全部拔掉 → 单个接回”的方式隔离。

### 12.4 安全模式正常、普通模式崩溃

这通常比“直接重装系统”更有定位价值。逐项排除：

- 登录项
- 后台服务
- System Extension
- 第三方 kext
- 外设配套软件

不要一次删除大量软件，否则会失去因果关系。

### 12.5 纯净系统仍稳定复现

如果已经满足：

- 无任何外设；
- 当前稳定版 macOS；
- 安全模式仍复现；
- 或抹盘/重装后、尚未恢复第三方软件就复现；
- panic 日志持续指向同一 DCP / Sleep-Wake / BridgeOS / 硬件路径；

则不建议继续通过修改 `pmset` 掩盖故障，应转 Apple Store / 授权服务商进一步检查显示组件、Touch Bar / T2、传感器、主板和固件。

### 12.6 Intel + T2：`ADPParamFIFO` / BridgeOS / Touch Bar 路径

这是 2020 Intel MacBook Pro（带 T2 / Touch Bar）需要单独识别的一类故障。

典型证据组合：

```text
Sleep Wake failure in EFI
Failure code:: 0x00000000 0x0000001f
Panic log received from Bridge OS
ProxiedDevice-Bridge/panic-full-....ips
panic ... ADPParamFIFO::programFIFO ...
ADP FIFO still busy after 1000ms
EC.Hid-DFR (Maintenance)
```

其中 `DFR` 指 Dynamic Function Row，即 Touch Bar 相关路径。`ADPParamFIFO` 出现在 BridgeOS panic 中时，说明 **T2/BridgeOS 设备控制链路在睡眠/唤醒或状态切换过程中发生通信超时**。在带 Touch Bar 的机型上，Touch Bar / DFR 是高优先级嫌疑，但单凭这条 panic 仍无法区分：

- T2 / BridgeOS 固件状态异常；
- Touch Bar 控制器或其通信链路异常；
- Touch Bar 硬件 / 排线问题；
- 逻辑板上的相关硬件故障。

#### 2026-09-05 实测案例

环境：

```text
MacBook Pro (13-inch, 2020, Two Thunderbolt 3 ports)
Model Identifier: MacBookPro16,3
Intel Core i5 / 16 GB
macOS Monterey 12.7.6 (21H1320)
Apple T2 / BridgeOS 8.6 (21P6074)
```

证据链：

1. `pmset` 记录合盖进入 `Clamshell Sleep`。
2. 随后出现 `SMC shutdown cause: -20`。
3. 紧接着出现：

   ```text
   Failure during sleep: 0x0000001F :
   EFI/Bootrom Failure after last point of entry to sleep
   ```

4. 多次生成：

   ```text
   Sleep Wake failure in EFI
   Failure code:: 0x00000000 0x0000001f
   ```

5. macOS 重启后多次接收到：

   ```text
   /Library/Logs/DiagnosticReports/ProxiedDevice-Bridge/panic-full-....ips
   Panic log received from Bridge OS 8.6 (21P6074)
   ```

6. 最新 BridgeOS panic 明确为：

   ```text
   panic ... ADPParamFIFO::programFIFO(IOMemoryMap *):
   ADP FIFO still busy after 1000ms
   ```

7. 同一时间段多次出现：

   ```text
   Wake reason: EC.Hid-DFR (Maintenance)
   AppleDeviceManagementHIDEventService::setWakeReason Error
   ```

8. 当时 Thunderbolt 显示 `No device connected`，USB 仅看到内建 Apple T2 / Touch Bar / 键盘触控板等设备，因此没有证据把该次故障归因于外接扩展坞。
9. 系统虽存在第三方 System Extension / kext，但 panic 发生在 BridgeOS 的 `kernel_task`，现有证据不足以把它们认定为直接根因。
10. 当时 `standby=0`、`hibernatemode=0` 已经生效，仍可稳定复现，因此“关闭 standby”对这类 BridgeOS `ADPParamFIFO` panic 不是有效根治方案。

**结论：**该案例已经从“泛化的睡眠故障”收敛为 **Intel Mac 的 T2 / BridgeOS 设备通信异常，Touch Bar / DFR 路径高度可疑**。从现有日志不能再进一步断言一定是哪一个实体部件损坏，因此应先执行固件/SMC/系统层验证，再决定是否维修硬件。

#### 推荐处理顺序

1. **先备份数据。**
2. 若此前人为改过大量 `pmset` 参数，先恢复默认值并重启：

   ```bash
   sudo pmset restoredefaults
   pmset -g custom
   ```

   > 恢复默认值可能重新启用系统自动睡眠；使用远程控制或长期挂机软件时先评估影响。

3. **按 Apple 官方流程重置 T2 机型 SMC：**

   - 关机；
   - 按住左侧 `Control` + 左侧 `Option` + 右侧 `Shift` 7 秒；
   - 不松开这三个键，再按住电源键 7 秒；
   - 全部松开，等待几秒后开机。

4. 升级到该机型支持的最新稳定版 macOS，再复测。不要使用 Beta。
5. 断开所有外设，并退出 `caffeinate`、远程控制、长期阻止睡眠的工具；安全模式再次合盖测试。
6. 运行 Apple Diagnostics。
7. 如果仍稳定出现相同 `ProxiedDevice-Bridge` + `ADPParamFIFO` panic，可在**完整备份后**把 T2 固件处理提升为进阶步骤：
   - 优先使用 Apple 官方 **Revive Mac**，它用于恢复固件且正常情况下不抹除数据；
   - 只有 Revive 无法解决、且已经有完整备份时才考虑 **Restore Mac**，因为 Restore 会抹除设备。
8. 如果 SMC 重置、系统升级、无外设、安全模式、Apple Diagnostics / Firmware Revive 后仍复现同一 panic，应停止继续修改 `pmset`，转 Apple Store / 授权服务商检查 **Touch Bar / DFR / T2 通信链路及逻辑板相关硬件**。

## 13. `pmset` 临时规避：只用于验证，不作为首选修复

部分 Sleep/Wake hang 社区案例通过关闭 `standby` 暂时规避深度睡眠切换。

先保存当前配置：

```bash
pmset -g custom > ~/Desktop/pmset-before.txt
```

只有当前 `standby` 为 `1`，并且日志显示问题发生在 Standby/深睡眠切换后，才考虑临时测试：

```bash
sudo pmset -a standby 0
```

风险：

- 可能增加合盖后的待机耗电。
- 只是绕过某个睡眠阶段，不能证明根因已经修复。
- 不同 macOS / 机型支持的参数并不完全一致。

测试完成后恢复系统默认电源配置：

```bash
sudo pmset restoredefaults
```

然后重新检查：

```bash
pmset -g custom
```

如果关闭 `standby` 才不崩溃，应保留日志并继续定位或送修，而不是长期把它当成最终方案。

> **实测反例：**MacBookPro16,3 的 BridgeOS `ADPParamFIFO` 案例中，`standby=0`、`hibernatemode=0` 已经生效仍会在合盖时重启，因此这类 panic 不应继续围绕 standby 参数反复试错。

## 14. 最短排查流程

现场快速执行：

```bash
# 1. 机型和系统
system_profiler SPHardwareDataType
sw_vers

# 2. 顶层诊断报告
ls -lt /Library/Logs/DiagnosticReports/ | head -30

# 3. 递归查关键 panic（T2 的 panic 可能在 ProxiedDevice-Bridge 子目录）
grep -RliE \
  'Sleep Wake failure in EFI|ADPParamFIFO|DCP PANIC|AppleDCP|IOPMrootDomain|dfrd' \
  /Library/Logs/DiagnosticReports 2>/dev/null | tail -30

# 4. 睡眠/唤醒历史
pmset -g log | \
  grep -Ei 'clamshell|sleep|wake|failure|panic|shutdown|restart' | \
  tail -300

# 5. 电源配置和阻止睡眠的进程
pmset -g custom
pmset -g assertions

# 6. 第三方系统扩展
systemextensionsctl list
kmutil showloaded 2>/dev/null | grep -v 'com.apple'

# 7. 外设信息
system_profiler SPUSBDataType
system_profiler SPThunderboltDataType
```

快速分流：

```text
合盖后重启
  ↓
是否有明确 panic / Sleep Wake Failure？
  ├─ 否 → Unified Log / shutdown cause / 电源与应用排查
  └─ 是
      ↓
Apple Silicon + DCP PANIC
  → 显示/DCP/外设路径
      ↓
Intel + T2 + Sleep Wake failure in EFI
  → 检查 ProxiedDevice-Bridge
      ↓
ADPParamFIFO + Hid-DFR / dfrd
  → T2 / BridgeOS / Touch Bar-DFR 路径
      ↓
备份 → SMC 重置 → 最新稳定版 macOS → 无外设/安全模式
      ↓
Apple Diagnostics → 必要时 Firmware Revive
      ↓
仍为同一 panic → Apple 硬件维修
```

## 15. 建议提交给 Apple 的证据包

至少保留：

```text
1. Mac 型号、序列信息（对外分享时隐藏序列号）
2. macOS 版本和 Build
3. 复现步骤与大致时间
4. /Library/Logs/DiagnosticReports 中对应 panic/ips/diag 文件
5. Intel + T2 机型同时保留 ProxiedDevice-Bridge 下的 panic-full-*.ips
6. pmset -g log 的故障时间段
7. 是否连接充电器、扩展坞和外接显示器
8. 安全模式是否复现
9. Apple Diagnostics Reference Code
10. SMC 重置、系统升级、Firmware Revive 后是否仍复现
```

## 16. 参考资料

- Apple Support: [If your Mac restarted because of a problem](https://support.apple.com/en-sg/102382)
- Apple Support: [If your Mac sleeps or wakes unexpectedly](https://support.apple.com/en-sg/guide/mac-help/mchlp2995/mac)
- Apple Support: [Start up your Mac in safe mode](https://support.apple.com/guide/mac-help/start-up-your-mac-in-safe-mode-mh21245/mac)
- Apple Support: [Use Apple Diagnostics to test your Mac](https://support.apple.com/en-us/102550)
- Apple Support: [Mac computers with the Apple T2 Security Chip](https://support.apple.com/en-sg/103265)
- Apple Support: [Reset the SMC of your Mac](https://support.apple.com/en-us/102605)
- Apple Support: [How to revive or restore Mac firmware](https://support.apple.com/en-sg/108900)
- macOS manual: [`pmset(1)`](https://keith.github.io/xcode-man-pages/pmset.1.html)
- macOS manual: [`log(1)`](https://keith.github.io/xcode-man-pages/log.1.html)
- Apple Community: [Continuous panic crashes on MBP 2019 13" — ADPParamFIFO example](https://discussions.apple.com/thread/253600917)
- Apple Community: [2020 Intel MacBook Pro / dfrd / Touch Bar restart discussion](https://discussions.apple.com/thread/254407216)
- Apple Community: [M2 MacBook Air kernel panics when lid is closed or entering sleep](https://discussions.apple.com/thread/255787294)
- Apple Community: [2022 M2 MacBook losing connection to built-in display when sleeping](https://discussions.apple.com/thread/255636529)

> 社区内容仅用于补充故障模式和关键词，修复决策以 Apple 官方流程和本机日志证据为准。
