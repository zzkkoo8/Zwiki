# macOS 合盖后崩溃重启排查

适用于 MacBook Pro（重点覆盖 2022 M2 / Apple Silicon）在合上屏幕后进入睡眠、再次开盖或睡眠期间发生崩溃、自动重启，并出现“电脑因出现问题而重新启动”等现象。

## 文档信息

| 字段 | 内容 |
| --- | --- |
| 技术领域 | macOS / 电源管理 / Kernel Panic |
| 适用范围 | MacBook Pro，重点为 Apple Silicon；Intel 机型部分命令也适用 |
| 典型机型 | 2022 MacBook Pro 13-inch M2 |
| 风险等级 | 排查低风险；修改 `pmset` 为中风险 |
| 文档状态 | 已整理，需结合故障机日志验证 |
| 最后验证 | 2026-09-05 |
| 主要来源 | Apple Support、macOS `pmset` / `log` 手册、Apple Community 案例 |

## 1. 现象与判断原则

正常情况下，MacBook 合盖会进入睡眠，而不是关机或重启。若开盖后重新出现 Apple Logo、登录后提示“电脑因出现问题而重新启动”，通常应按 **睡眠/唤醒路径崩溃** 排查，而不是先改电源参数。

Apple 官方指出，意外重启常见原因包括已安装的软件、外接设备以及硬件故障；推荐顺序是更新系统、断开外设、安全模式隔离、Apple Diagnostics，必要时重新安装 macOS。

2022 年 M2 机型的社区案例中，多次出现“合盖或执行睡眠后触发 Kernel Panic”的现象，其中一类日志包含：

```text
DCP PANIC
No device added after powering on the rails
AppleDCPDPTXPowerController
```

`DCP` 与显示控制链路有关。这类字符串可作为故障方向，但**不能只凭社区案例直接判定必须换屏幕、主板或 Lid Angle Sensor**，最终应以本机 panic 日志、纯净系统复现结果和 Apple Diagnostics 为准。

## 2. 安全边界

排查阶段优先使用只读命令。不要一开始执行以下网络常见“偏方”：

- 不要直接修改 `hibernatemode`、删除 sleep image 或批量改 `pmset` 参数。
- 不要把 `sudo pmset -a lidwake 0` 当作修复方案；它主要控制开盖唤醒，并不能证明或修复进入睡眠时的 Kernel Panic。
- Apple Silicon 不需要按 Intel 时代的方法手动重置 SMC；Apple 官方建议直接重启 Mac。
- 不要根据 `Previous shutdown cause` 的单个数字直接下硬件结论；应结合 panic 报告和睡眠/唤醒日志。
- 未备份重要数据前，不执行抹盘、DFU Restore、重装系统等破坏性操作。

## 3. 一次性采集基础信息

先确认到底是哪一款 Mac、当前 macOS 版本以及最近一次启动时间：

```bash
system_profiler SPHardwareDataType
sw_vers
uname -a
uptime
```

重点记录：

- `Model Name` / `Model Identifier`
- `Chip`（例如 Apple M2）
- macOS 版本和 Build
- 是否每次合盖都复现，还是放置数分钟/数小时才复现
- 电池供电与接电源时是否都复现
- 是否连接扩展坞、外接显示器、USB/Thunderbolt 设备

## 4. 先确认是不是 Kernel Panic

### 4.1 查看崩溃报告目录

```bash
ls -lt /Library/Logs/DiagnosticReports/ | head -30
```

快速寻找包含 panic、睡眠唤醒或显示控制信息的报告：

```bash
grep -lEi 'panic|sleep.?wake|DCP|AppleDCP|IOPMrootDomain' \
  /Library/Logs/DiagnosticReports/* 2>/dev/null | tail -20
```

如果找到近期 `.panic`、`.ips` 或相关报告，可先看前 120 行：

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
IOPMrootDomain
Thunderbolt
USB
GPU
```

### 4.2 判断

- **存在明确 `panicString` / `DCP PANIC`**：按 Kernel Panic 路径继续。
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
  grep -Ei 'sleep|wake|darkwake|failure|panic|shutdown|restart' | \
  tail -200
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

- 合盖时间附近是否出现 `Sleep`。
- 随后是否正常 `Wake` / `DarkWake`。
- 是否在 Wake 前后出现 Failure、Restart 或日志突然中断。
- 是否有某个进程长期持有 `PreventSystemSleep` / `PreventUserIdleSystemSleep`。

`pmset -g assertions` 主要用于解释“为什么不睡眠/频繁唤醒”，不能单独证明 Kernel Panic 根因。

## 6. 从 macOS Unified Log 找证据

查看最近 24 小时与 panic、睡眠/唤醒相关的系统日志：

```bash
log show --last 24h --style compact \
  --predicate 'eventMessage CONTAINS[c] "panic" OR eventMessage CONTAINS[c] "sleep wake" OR eventMessage CONTAINS[c] "Previous shutdown cause"' \
  | tail -300
```

如果问题刚刚复现，可把范围缩到 1 小时：

```bash
log show --last 1h --style compact --info \
  --predicate 'eventMessage CONTAINS[c] "sleep" OR eventMessage CONTAINS[c] "wake" OR eventMessage CONTAINS[c] "panic" OR eventMessage CONTAINS[c] "DCP"' \
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
- 老版本硬件管理工具

若故障始于安装或升级上述软件之后，应优先升级或使用厂商卸载程序完整移除，再复测。

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

安装稳定版 macOS 更新后重新测试合盖。不要为了排障主动切换到 Beta 系统。

## 10. 安全模式复现

如果普通模式合盖必现，而安全模式不复现，第三方软件、启动项、扩展或缓存的嫌疑明显上升。

Apple Silicon 进入安全模式：

1. 关机。
2. 长按电源/Touch ID，直到出现“启动选项”。
3. 选择启动磁盘。
4. 按住 `Shift`，点击“以安全模式继续”。
5. 登录后重复合盖测试。

判断：

- **安全模式不复现**：回到第三方软件、驱动、登录项方向。
- **安全模式仍复现**：继续做 Apple Diagnostics；若纯净环境仍有 DCP/Sleep-Wake panic，硬件概率上升。

## 11. Apple Diagnostics 硬件自检

Apple Silicon：

1. 关机并断开非必要外设。
2. 长按电源键直到出现启动选项。
3. 松开电源键。
4. 按住 `Command (⌘) + D`，进入 Apple Diagnostics。
5. 保存检测结果和 Reference Code。

Apple Diagnostics 没报错并不能排除所有间歇性睡眠/显示链路问题，但如果存在明确硬件 Reference Code，应停止继续修改系统配置并优先维修。

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
- panic 日志持续指向同一 DCP / Sleep-Wake / 硬件路径；

则不建议继续通过修改 `pmset` 掩盖故障，应转 Apple Store / 授权服务商进一步检查显示组件、传感器、主板和固件。

## 13. `pmset` 临时规避：只用于验证，不作为首选修复

部分 Sleep/Wake hang 社区案例通过关闭 `standby` 暂时规避深度睡眠切换：

先保存当前配置：

```bash
pmset -g custom > ~/Desktop/pmset-before.txt
```

确认本机支持并且日志显示问题发生在 Standby/深睡眠切换后，才考虑临时测试：

```bash
sudo pmset -a standby 0
```

风险：

- 可能增加合盖后的待机耗电。
- 只是绕过某个睡眠阶段，不能证明根因已经修复。
- 不同 macOS / Apple Silicon 机型支持的参数并不完全一致。

测试完成后恢复系统默认电源配置：

```bash
sudo pmset restoredefaults
```

然后重新检查：

```bash
pmset -g custom
```

如果关闭 `standby` 才不崩溃，应保留日志并继续定位或送修，而不是长期把它当成最终方案。

## 14. 最短排查流程

现场快速执行：

```bash
# 1. 机型和系统
system_profiler SPHardwareDataType
sw_vers

# 2. 是否有 panic 文件
ls -lt /Library/Logs/DiagnosticReports/ | head -30

# 3. 睡眠/唤醒历史
pmset -g log | grep -Ei 'sleep|wake|failure|panic|shutdown|restart' | tail -200

# 4. 电源配置和阻止睡眠的进程
pmset -g custom
pmset -g assertions

# 5. 第三方系统扩展
systemextensionsctl list
kmutil showloaded 2>/dev/null | grep -v 'com.apple'

# 6. 外设信息
system_profiler SPUSBDataType
system_profiler SPThunderboltDataType
```

然后按以下顺序复测：

```text
断开全部外设
  ↓
更新稳定版 macOS
  ↓
安全模式合盖测试
  ↓
Apple Diagnostics
  ↓
读取 panicString / DCP / IOPMrootDomain
  ↓
软件问题 → 升级或卸载对应驱动/扩展
外设问题 → 单设备接回定位
纯净环境仍 Panic → Apple 硬件/固件诊断
```

## 15. 建议提交给 Apple 的证据包

至少保留：

```text
1. Mac 型号、序列信息（对外分享时隐藏序列号）
2. macOS 版本和 Build
3. 复现步骤与大致时间
4. /Library/Logs/DiagnosticReports 中对应 panic/ips 文件
5. pmset -g log 的故障时间段
6. 是否连接充电器、扩展坞和外接显示器
7. 安全模式是否复现
8. Apple Diagnostics Reference Code
9. 是否在重装后的纯净系统复现
```

## 16. 参考资料

- Apple Support: [If your Mac restarted because of a problem](https://support.apple.com/en-sg/102382)
- Apple Support: [If your Mac sleeps or wakes unexpectedly](https://support.apple.com/en-sg/guide/mac-help/mchlp2995/mac)
- Apple Support: [Start up your Mac in safe mode](https://support.apple.com/guide/mac-help/start-up-your-mac-in-safe-mode-mh21245/mac)
- Apple Support: [Use Apple Diagnostics to test your Mac](https://support.apple.com/en-us/102550)
- macOS manual: [`pmset(1)`](https://keith.github.io/xcode-man-pages/pmset.1.html)
- macOS manual: [`log(1)`](https://keith.github.io/xcode-man-pages/log.1.html)
- Apple Community: [M2 MacBook Air kernel panics when lid is closed or entering sleep](https://discussions.apple.com/thread/255787294)
- Apple Community: [2022 M2 MacBook losing connection to built-in display when sleeping](https://discussions.apple.com/thread/255636529)

> 社区内容仅用于补充故障模式和关键词，修复决策以 Apple 官方流程和本机日志证据为准。
