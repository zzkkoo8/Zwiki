# 双网卡 + VPN 指定流量分流（Windows / macOS）

用于以下固定场景：电脑同时连接**公司有线网络 + 中国联通手机 USB 共享网络/热点 + 企业 VPN**。

本案例有两个不能破坏的前提：

1. **VPN 公网端点只能通过联通网络连接。**
2. **企业内网只能通过 VPN 访问，不能直接从有线网络或手机网络访问。**

当前案例参数：

- **G1：有线网卡**：系统默认出口，普通 Internet 流量继续走这里。
- **G2：联通手机 USB 网络 / 热点**：只负责访问 VPN 公网端点。
- **G3：VPN 虚拟网卡**：VPN 建立后承载企业内网流量。
- **VPN 公网端点**：`42.236.61.166:7444`。
- **VPN 内网**：`10.7.0.0/16`，目标包括 `10.7.216.249-254`。

> IP 路由按目标 IP/网段选路，不按 TCP/UDP 端口选路。因此实际需要固定的是 `42.236.61.166/32`，而不是单独固定 `:7444`。

## 1. 最终必须形成的链路

```text
普通公网流量
终端 ──> G1 有线网卡 ──> 有线默认网关 ──> Internet

VPN 建隧道流量
终端 ──> 42.236.61.166/32 ──> G2 联通手机网络 ──> Internet ──> VPN Server

VPN 建立后的内网流量
终端 ──> 10.7.0.0/16 ──> G3 VPN 虚拟网卡 ──> VPN 隧道 ──> 10.7.216.249-254
```

依赖顺序：

```text
G1 有线继续承担默认路由
        ↓
给 42.236.61.166/32 建立 G2 联通手机专用路由
        ↓
VPN 客户端才能从联通网络连接 42.236.61.166:7444
        ↓
VPN 建立并创建 G3
        ↓
VPN 客户端注入 10.7.0.0/16 或更精确的企业内网路由
        ↓
10.7.216.249-254 才可达
```

**禁止把 `10.7.0.0/16` 手工指向 G1 或 G2。** 企业内网只能进入 VPN 隧道。

## 2. 最终验收状态

| 检查对象 | VPN 未连接 | VPN 已连接 | 正确结果 |
| --- | --- | --- | --- |
| 默认路由 `0.0.0.0/0` | 存在 | 存在 | G1 有线网卡 |
| `42.236.61.166/32` | 存在 | 存在 | G2 联通手机网卡 |
| `10.7.216.249` | 不应通过普通网卡可达 | 应可达 | G3 VPN 虚拟网卡 |
| 普通 Internet | 可用 | 可用 | 继续走 G1 |
| VPN Server | 可连接 | 隧道保持 | 始终从 G2 发出 |

判断路由时先看**最长前缀**：

```text
42.236.61.166/32  >  0.0.0.0/0
10.7.0.0/16       >  0.0.0.0/0
```

因此默认路由可以保持有线；只要 `42.236.61.166/32` 正确指向联通手机网关，VPN Server 就会绕过默认路由固定走 G2。

---

# Windows

修改路由和 Metric 请使用**管理员 PowerShell / 管理员 CMD**。

## 3. Windows：第一步只采集现状，不修改

建议先断开 VPN，仅保留有线和联通手机网络同时在线。这样最容易区分 G1 和 G2。

### 3.1 PowerShell 一次性采集

```powershell
$VpnServer = '42.236.61.166'
$InnerHost = '10.7.216.249'

Write-Host '=== Adapter ==='
Get-NetAdapter |
    Sort-Object ifIndex |
    Format-Table ifIndex, Name, InterfaceDescription, Status, LinkSpeed

Write-Host '=== IP / Gateway ==='
Get-NetIPConfiguration

Write-Host '=== Interface Metric ==='
Get-NetIPInterface -AddressFamily IPv4 |
    Sort-Object InterfaceMetric |
    Format-Table ifIndex, InterfaceAlias, ConnectionState, AutomaticMetric, InterfaceMetric

Write-Host '=== Default Route ==='
Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' |
    Format-Table InterfaceIndex, InterfaceAlias, NextHop, RouteMetric, InterfaceMetric, PolicyStore

Write-Host '=== VPN Server Route ==='
Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "$VpnServer/32" -ErrorAction SilentlyContinue |
    Format-Table DestinationPrefix, InterfaceIndex, InterfaceAlias, NextHop, RouteMetric, PolicyStore

Write-Host '=== Route Decision: VPN Server ==='
Find-NetRoute -RemoteIPAddress $VpnServer
Test-NetConnection $VpnServer -DiagnoseRouting -InformationLevel Detailed

Write-Host '=== Route Decision: Inner Host ==='
Find-NetRoute -RemoteIPAddress $InnerHost -ErrorAction SilentlyContinue
Test-NetConnection $InnerHost -DiagnoseRouting -InformationLevel Detailed

Write-Host '=== Persistent Routes ==='
Get-NetRoute -AddressFamily IPv4 -PolicyStore PersistentStore |
    Sort-Object DestinationPrefix |
    Format-Table DestinationPrefix, InterfaceIndex, InterfaceAlias, NextHop, RouteMetric
```

记录三个信息：

```text
G1 有线网卡名称 / ifIndex / IPv4 / 默认网关
G2 联通手机网卡名称 / ifIndex / IPv4 / 默认网关
42.236.61.166 当前实际选中的出口
```

### 3.2 CMD 一次性采集

```cmd
ipconfig /all
route print -4
netsh interface ipv4 show interfaces
netsh interface ipv4 show route
route print 42.236.61.166
route print 10.*
```

### 3.3 修改前预期

修改前常见状态是：

```text
G1 有线有默认路由
G2 联通手机也可能有默认路由
42.236.61.166 没有 /32 专用路由，当前可能错误走 G1
VPN 未连接时 10.7.216.249 不应通过普通网卡正常访问
```

如果 `42.236.61.166` 已经正确走 G2，不要重复添加路由；先确认现有规则是否持久化即可。

## 4. Windows：确保默认 Internet 继续走 G1 有线

假设现场识别结果为：

```text
G1 = Ethernet
G2 = Ethernet 2
```

设置接口优先级：

```powershell
Set-NetIPInterface -InterfaceAlias 'Ethernet'   -AddressFamily IPv4 -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias 'Ethernet 2' -AddressFamily IPv4 -InterfaceMetric 50
```

验证：

```powershell
Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
    Format-Table InterfaceAlias, NextHop, RouteMetric, InterfaceMetric
```

预期：

```text
有线 G1 的默认路由有效 Metric 更低
手机 G2 即使保留默认网关，也不成为普通流量首选出口
```

CMD 等价操作：

```cmd
netsh interface ipv4 set interface "Ethernet" metric=10
netsh interface ipv4 set interface "Ethernet 2" metric=50
```

> 不要删除 G1 默认路由。G2 也不必强制删除默认网关；只需要让 G1 成为默认优先，再用 `/32` 主机路由覆盖 VPN Server。

## 5. Windows：给 VPN Server 建立 G2 联通专用 `/32` 路由

### 5.1 PowerShell 推荐方式

把 `$MobileAlias` 改成实际联通手机网卡名称：

```powershell
$VpnServer   = '42.236.61.166'
$MobileAlias = 'Ethernet 2'

$Mobile = Get-NetIPConfiguration -InterfaceAlias $MobileAlias
$MobileIfIndex = $Mobile.InterfaceIndex
$MobileGateway = $Mobile.IPv4DefaultGateway.NextHop

$Mobile | Format-List InterfaceAlias, InterfaceIndex, IPv4Address, IPv4DefaultGateway

if (-not $MobileGateway) {
    throw '没有读取到联通手机网络默认网关，停止修改。'
}
```

检查是否已有同目标路由：

```powershell
Get-NetRoute -DestinationPrefix "$VpnServer/32" -ErrorAction SilentlyContinue |
    Format-Table DestinationPrefix, InterfaceIndex, InterfaceAlias, NextHop, RouteMetric, PolicyStore
```

如果没有，创建：

```powershell
New-NetRoute `
    -DestinationPrefix "$VpnServer/32" `
    -InterfaceIndex $MobileIfIndex `
    -NextHop $MobileGateway `
    -RouteMetric 1
```

`New-NetRoute` 默认会把路由保存到活动和持久配置；重启后仍应存在。但手机 USB 重插后网关或接口索引可能变化，所以发生故障时必须重新核对。

如果存在**明确错误**的旧 `/32`，先看清楚再删除：

```powershell
Get-NetRoute -DestinationPrefix "$VpnServer/32" |
    Format-Table DestinationPrefix, InterfaceIndex, InterfaceAlias, NextHop, RouteMetric, PolicyStore
```

确认确实错误后：

```powershell
Remove-NetRoute -DestinationPrefix "$VpnServer/32" -Confirm:$false
```

然后重新执行 `New-NetRoute`。

### 5.2 CMD 临时验证后再持久化

先查：

```cmd
route print -4
netsh interface ipv4 show interfaces
ipconfig /all
```

记录：

```text
<MOBILE_GATEWAY> = 联通手机网关
<MOBILE_IFINDEX> = 联通手机接口索引
```

先添加临时路由：

```cmd
route add 42.236.61.166 mask 255.255.255.255 <MOBILE_GATEWAY> metric 1 if <MOBILE_IFINDEX>
```

确认 VPN 能正常建立后，改成持久路由：

```cmd
route delete 42.236.61.166 mask 255.255.255.255
route /p add 42.236.61.166 mask 255.255.255.255 <MOBILE_GATEWAY> metric 1 if <MOBILE_IFINDEX>
```

`route /p add` 会把该路由保存为 Windows 持久路由。

## 6. Windows：在拨 VPN 之前先验收 G1 / G2

### 6.1 验证默认出口仍为 G1

```powershell
Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
    Format-Table InterfaceAlias, NextHop, RouteMetric, InterfaceMetric
```

可再测试一个普通公网地址：

```powershell
Find-NetRoute -RemoteIPAddress 1.1.1.1
```

预期：普通公网地址走 G1 有线。

### 6.2 验证 VPN Server 固定走 G2

```powershell
Find-NetRoute -RemoteIPAddress 42.236.61.166
Test-NetConnection 42.236.61.166 -DiagnoseRouting -InformationLevel Detailed
```

预期至少满足：

```text
DestinationPrefix = 42.236.61.166/32
InterfaceAlias    = 联通手机网卡
NextHop           = 联通手机网关
```

如果 VPN 端点确认为 TCP/7444，可测试：

```powershell
Test-NetConnection 42.236.61.166 -Port 7444 -InformationLevel Detailed
```

如果 VPN 实际使用 UDP 或专有协议，TCP 测试不能代替 VPN 客户端本身。

### 6.3 此时内网不可达是正常现象

VPN 尚未建立时：

```powershell
Find-NetRoute -RemoteIPAddress 10.7.216.249
Test-NetConnection 10.7.216.249 -DiagnoseRouting -InformationLevel Detailed
```

不要因为 `10.7.216.249` 不通就给它配置 G1/G2 静态路由。此时内网不可达符合设计。

## 7. Windows：拨入 VPN 后验收 G3

连接 VPN 后执行：

```powershell
Get-NetAdapter | Sort-Object ifIndex

Get-NetRoute -AddressFamily IPv4 |
    Where-Object {
        $_.DestinationPrefix -like '10.7.*' -or
        $_.DestinationPrefix -eq '42.236.61.166/32'
    } |
    Format-Table DestinationPrefix, NextHop, InterfaceIndex, InterfaceAlias, RouteMetric

Find-NetRoute -RemoteIPAddress 42.236.61.166
Find-NetRoute -RemoteIPAddress 10.7.216.249
Test-NetConnection 10.7.216.249 -DiagnoseRouting -InformationLevel Detailed
```

正确结果：

```text
42.236.61.166 → G2 联通手机网卡
10.7.216.249  → G3 VPN 虚拟网卡
普通 Internet → G1 有线网卡
```

如果 VPN 已显示“连接成功”，但 `10.7.216.249` 仍走 G1/G2，则问题在 VPN 内网路由下发，而不是联通 `/32` 路由。

继续检查：

```powershell
Get-NetRoute -AddressFamily IPv4 |
    Where-Object { $_.DestinationPrefix -like '10.*' } |
    Sort-Object DestinationPrefix |
    Format-Table DestinationPrefix, NextHop, InterfaceIndex, InterfaceAlias, RouteMetric
```

应看到 `10.7.0.0/16`、`10.7.216.0/24` 或更精确的目标路由绑定到 VPN 虚拟接口。

## 8. Windows：重连和重启后的检查点

手机 USB 重新插拔、热点重新连接、VPN 客户端升级、系统重启后，至少执行：

```powershell
Get-NetIPConfiguration
Get-NetRoute -DestinationPrefix '42.236.61.166/32' -ErrorAction SilentlyContinue
Find-NetRoute -RemoteIPAddress 42.236.61.166
```

同时分别查看 ActiveStore 和 PersistentStore：

```powershell
Get-NetRoute -AddressFamily IPv4 -PolicyStore ActiveStore |
    Where-Object { $_.DestinationPrefix -eq '42.236.61.166/32' }

Get-NetRoute -AddressFamily IPv4 -PolicyStore PersistentStore |
    Where-Object { $_.DestinationPrefix -eq '42.236.61.166/32' }
```

如果持久路由仍在，但手机网关或接口已变化，应删除旧 `/32` 并按当前 G2 参数重建。

---

# macOS

macOS 的目标与 Windows 完全相同：

```text
默认流量       → G1 有线
42.236.61.166  → G2 联通手机网络
10.7.0.0/16    → VPN 建立后的 G3 / utunX
```

## 9. macOS：第一步只采集现状，不修改

建议先断开 VPN，再执行：

```bash
networksetup -listnetworkserviceorder
networksetup -listallhardwareports
ifconfig
netstat -rn -f inet
route -n get default
route -n get 42.236.61.166
route -n get 10.7.216.249
scutil --nwi
```

重点记录：

```text
G1 有线 Network Service 名称、BSD Device、IP、网关
G2 联通手机 Network Service 名称、BSD Device、IP、网关
当前 default 的 interface / gateway
42.236.61.166 当前的 interface / gateway
```

不要假设 `en0`、`en5`、`en7` 分别是什么，必须根据本机输出识别。

## 10. macOS：确保默认出口为 G1 有线

查看服务顺序：

```bash
networksetup -listnetworkserviceorder
```

如果有线服务排在联通手机网络之后，可调整 Network Service Order。命令要求写出当前机器的完整服务列表，例如：

```bash
sudo networksetup -ordernetworkservices \
    "<WIRED_SERVICE>" \
    "<MOBILE_SERVICE>" \
    "Wi-Fi" \
    "<OTHER_SERVICE>"
```

不要直接照抄示例漏掉已有服务。

验证：

```bash
route -n get default
```

预期：

```text
interface: <WIRED_IF>
gateway:   <WIRED_GATEWAY>
```

## 11. macOS：确定 G2 联通手机接口和网关

映射 Network Service 与 BSD Device：

```bash
networksetup -listnetworkserviceorder
networksetup -listallhardwareports
```

假设已经识别：

```text
<MOBILE_SERVICE> = 联通手机对应的网络服务名
<MOBILE_IF>      = 对应 BSD Device，例如 en7
```

读取 DHCP 网关：

```bash
ipconfig getoption <MOBILE_IF> router
```

也可查看服务信息：

```bash
networksetup -getinfo "<MOBILE_SERVICE>"
```

必须得到：

```text
<MOBILE_GATEWAY>
<MOBILE_IF>
<MOBILE_SERVICE>
```

## 12. macOS：先用临时 `/32` 路由验证 G2

添加：

```bash
sudo route -n add -host 42.236.61.166 <MOBILE_GATEWAY>
```

如果提示已存在，先检查：

```bash
route -n get 42.236.61.166
```

确认旧规则错误后再删除并重建：

```bash
sudo route -n delete -host 42.236.61.166
sudo route -n add -host 42.236.61.166 <MOBILE_GATEWAY>
```

验证：

```bash
route -n get 42.236.61.166
```

正确结果：

```text
gateway:   <MOBILE_GATEWAY>
interface: <MOBILE_IF>
```

此时再启动 VPN 客户端。如果 VPN 可以正常连接，说明 G2 路径成立。

## 13. macOS：把 `/32` 持久化到 G2 Network Service

先检查该网络服务已有 additional routes：

```bash
networksetup -getadditionalroutes "<MOBILE_SERVICE>"
```

**`-setadditionalroutes` 会设置该服务的完整 additional route 列表。** 如果已有其他静态路由，必须一起保留，不能只写新路由覆盖旧配置。

如果当前没有其他 additional routes，可执行：

```bash
sudo networksetup -setadditionalroutes \
    "<MOBILE_SERVICE>" \
    42.236.61.166 255.255.255.255 <MOBILE_GATEWAY>
```

验证：

```bash
networksetup -getadditionalroutes "<MOBILE_SERVICE>"
route -n get 42.236.61.166
```

## 14. macOS：拨 VPN 前验收

```bash
route -n get default
route -n get 42.236.61.166
route -n get 10.7.216.249
```

预期：

```text
default         → G1 有线
42.236.61.166   → G2 联通手机
10.7.216.249    → VPN 未连时不应存在可用的企业内网隧道路由
```

不要为了让 `10.7.216.249` 暂时可达而给 G1/G2 添加 `10.7.0.0/16` 路由。

## 15. macOS：拨 VPN 后验收 G3

连接 VPN 后执行：

```bash
route -n get default
route -n get 42.236.61.166
route -n get 10.7.216.249
netstat -rn -f inet | egrep 'default|42\.236\.61\.166|10\.7\.'
scutil --nwi
```

正确结果：

```text
default         → G1 有线 BSD Device
42.236.61.166   → G2 联通手机 BSD Device
10.7.216.249    → utun0 / utun1 / VPN 客户端虚拟接口
```

如果 VPN 显示已连接，但 `10.7.216.249` 不走 `utunX` 或 VPN 虚拟接口，则优先检查 VPN 客户端是否下发企业内网路由。

## 16. macOS：手机重连后的检查点

手机热点、USB 共享网络重新连接后，DHCP 网关可能变化。执行：

```bash
ipconfig getoption <MOBILE_IF> router
networksetup -getadditionalroutes "<MOBILE_SERVICE>"
route -n get 42.236.61.166
```

如果 additional route 中仍引用旧手机网关，应重新写入正确网关。

---

# 统一故障判断

## 17. 最短排错流程

严格按顺序检查，不要跳过 G2 直接修 G3：

```text
1. G1 有线是否仍是默认出口？
        ↓ 是
2. 42.236.61.166 是否命中 /32？
        ↓ 是
3. /32 的下一跳和接口是否属于联通手机 G2？
        ↓ 是
4. VPN 客户端是否能建立隧道？
        ↓ 是
5. VPN 是否创建 G3 / utunX？
        ↓ 是
6. 是否出现 10.7.0.0/16 或更精确 VPN 路由？
        ↓ 是
7. 10.7.216.249 是否命中 G3？
```

## 18. 现象与根因

| 现象 | 首查 | 常见根因 |
| --- | --- | --- |
| 普通上网跑到手机流量 | 默认路由 / Metric / Service Order | G2 优先级高于 G1 |
| VPN 完全连不上 | `42.236.61.166/32` | VPN Server 错走有线 |
| VPN 端点走手机但仍连不上 | 7444/客户端日志/联通网络 | 端口、协议、VPN 服务端或运营商链路 |
| VPN 已连接但 `10.7.x.x` 不通 | `10.7.*` 路由 | VPN 未下发 split-tunnel 路由 |
| `10.7.x.x` 走手机网关 | 路由表 | 错误手工配置了 G2 内网路由 |
| 手机重插后 VPN 突然失效 | G2 网关、ifIndex/BSD Device | DHCP/接口参数变化，旧持久路由失效 |
| 重启后 Windows 路由行为不同 | ActiveStore / PersistentStore | 持久路由与当前接口参数不一致 |

## 19. 不应该做的操作

以下操作很容易把链路修坏：

```text
× 把 10.7.0.0/16 指向手机网关
× 把 10.7.0.0/16 指向有线网关
× 为了 VPN 删除有线默认路由
× 把整机默认路由永久切到手机热点
× 在不确认接口的情况下照抄 ifIndex / enX
× 看到 VPN 已连接就认为内网路由一定正确
× 手机网关变化后继续沿用旧 /32 持久路由
```

## 20. 恢复本次配置

### Windows

删除 VPN Server 专用 `/32`：

```powershell
Remove-NetRoute -DestinationPrefix '42.236.61.166/32' -Confirm:$false
```

或：

```cmd
route delete 42.236.61.166 mask 255.255.255.255
```

恢复自动 Metric：

```powershell
Set-NetIPInterface -InterfaceAlias '<WIRED_ALIAS>'  -AddressFamily IPv4 -AutomaticMetric Enabled
Set-NetIPInterface -InterfaceAlias '<MOBILE_ALIAS>' -AddressFamily IPv4 -AutomaticMetric Enabled
```

### macOS

删除临时 host route：

```bash
sudo route -n delete -host 42.236.61.166
```

如需清除该 Network Service 的 additional routes：

```bash
networksetup -getadditionalroutes "<MOBILE_SERVICE>"
```

确认该服务没有其他必须保留的 additional routes 后才执行：

```bash
sudo networksetup -setadditionalroutes "<MOBILE_SERVICE>"
```

---

# 现场最终检查清单

完成配置后逐项确认：

```text
□ G1 有线是普通 Internet 默认出口
□ G2 明确是中国联通手机 USB/热点网络
□ 42.236.61.166/32 明确绑定 G2 的网关/接口
□ VPN 未连接时 10.7.216.249 不通过 G1/G2 直接访问
□ VPN 可以通过 G2 建立
□ VPN 建立后出现 G3 / utunX
□ 10.7.0.0/16 或更精确内网路由绑定 G3
□ 10.7.216.249 实际选路为 G3
□ VPN 连接期间 42.236.61.166 仍走 G2，而不是被 G3 抢走
□ 普通 Internet 在 VPN 连接期间仍按设计走 G1
□ Windows 重启 / 手机重插后重新验证 ActiveStore、PersistentStore、手机网关
□ macOS 手机重连后重新验证 additional route 和当前手机网关
```

## 官方参考

- Microsoft `route`：https://learn.microsoft.com/windows-server/administration/windows-commands/route_ws2008
- Microsoft `New-NetRoute`：https://learn.microsoft.com/powershell/module/nettcpip/new-netroute
- Microsoft `Get-NetRoute`：https://learn.microsoft.com/powershell/module/nettcpip/get-netroute
- Microsoft `Set-NetIPInterface`：https://learn.microsoft.com/powershell/module/nettcpip/set-netipinterface
- Microsoft `Test-NetConnection`：https://learn.microsoft.com/powershell/module/nettcpip/test-netconnection
- macOS 本机帮助：`man route`、`man networksetup`、`networksetup -help`
