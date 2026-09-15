# 双网卡 + VPN 指定流量分流（Windows / macOS）

用于电脑同时连接**有线网络 + 手机 USB 网络/热点 + 企业 VPN**的场景：普通流量继续走有线网卡，只把 VPN 公网端点固定走手机网络；VPN 建立后，企业内网流量再走 VPN 虚拟网卡。

当前案例：

- **G1：有线网卡**：系统默认出口。
- **G2：手机 USB 网络 / 热点**：只负责访问 VPN 公网端点。
- **G3：VPN 虚拟网卡**：VPN 建立后承载企业内网流量。
- **VPN 公网端点**：`42.236.61.166:7444`。
- **VPN 内网**：`10.7.0.0/16`，目标包括 `10.7.216.249-254`。

> IP 路由不按端口选择出口。这里实际配置的是 `42.236.61.166/32`，不是单独的 `:7444`。

## 1. 正确流量链路

```text
普通公网流量
终端 ──> G1 有线网卡 ──> 默认网关 ──> Internet

VPN 建隧道流量
终端 ──> 42.236.61.166/32 ──> G2 手机网络 ──> Internet ──> VPN Server

VPN 建立后的内网流量
终端 ──> 10.7.0.0/16 ──> G3 VPN 虚拟网卡 ──> VPN 隧道 ──> 10.7.216.249-254
```

依赖关系：

```text
G2 的 42.236.61.166/32 路由正常
        ↓
VPN 客户端才能连接公网端点
        ↓
VPN 建立并创建 G3
        ↓
VPN 注入 10.7.0.0/16 或更精确路由
        ↓
10.7.216.249-254 可达
```

**不要把 `10.7.0.0/16` 手工指向 G2。** G2 只负责 VPN 公网端点，企业内网应由 VPN 客户端创建的 G3 路由承载。

## 2. 判断原则

路由优先看**最长前缀**：

```text
42.236.61.166/32  >  0.0.0.0/0
10.7.0.0/16       >  0.0.0.0/0
```

所以默认路由即使走有线，只要存在正确的 `42.236.61.166/32` 主机路由，VPN Server 仍会固定走手机网络。

同样前缀长度时再比较 Metric / 接口优先级。Windows 可直接设置接口 Metric；macOS 通常通过 Network Service Order 决定多个默认出口的优先级。

---

# Windows

以下查询命令普通终端即可运行；修改路由和 Metric 请使用**管理员 PowerShell / 管理员 CMD**。

## 3. Windows：先检查，不修改

### PowerShell

查看网卡、IP、网关和接口优先级：

```powershell
Get-NetAdapter | Sort-Object ifIndex | Format-Table ifIndex, Name, Status, LinkSpeed
Get-NetIPConfiguration
Get-NetIPInterface -AddressFamily IPv4 |
    Sort-Object InterfaceMetric |
    Format-Table ifIndex, InterfaceAlias, ConnectionState, AutomaticMetric, InterfaceMetric
```

查看默认路由：

```powershell
Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' |
    Format-Table InterfaceIndex, InterfaceAlias, NextHop, RouteMetric, InterfaceMetric
```

查看到 VPN Server 的真实选路：

```powershell
Find-NetRoute -RemoteIPAddress 42.236.61.166
Test-NetConnection 42.236.61.166 -DiagnoseRouting -InformationLevel Detailed
```

VPN 建立后查看到内网主机的真实选路：

```powershell
Find-NetRoute -RemoteIPAddress 10.7.216.249
Test-NetConnection 10.7.216.249 -DiagnoseRouting -InformationLevel Detailed
```

目标状态：

```text
0.0.0.0/0            → G1 有线网卡
42.236.61.166/32      → G2 手机网卡
10.7.0.0/16 或更精确 → G3 VPN 虚拟网卡
```

### CMD

```cmd
ipconfig /all
route print -4
netsh interface ipv4 show interfaces
netsh interface ipv4 show route
```

重点看：

```cmd
route print 42.236.61.166
route print 10.*
tracert -d 42.236.61.166
tracert -d 10.7.216.249
```

`tracert`/ICMP 可能被 VPN 或防火墙过滤，失败不能单独证明 VPN 不通，必须同时看实际路由和业务连接。

## 4. Windows：确保默认流量仍走有线

假设：

```text
有线网卡：Ethernet
手机网卡：Ethernet 2
```

PowerShell：

```powershell
Set-NetIPInterface -InterfaceAlias 'Ethernet'   -AddressFamily IPv4 -InterfaceMetric 10
Set-NetIPInterface -InterfaceAlias 'Ethernet 2' -AddressFamily IPv4 -InterfaceMetric 50
```

设置 `InterfaceMetric` 后 Windows 会关闭该接口的 Automatic Metric。Metric 越小，接口优先级越高。

验证：

```powershell
Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
    Format-Table InterfaceAlias, NextHop, RouteMetric, InterfaceMetric
```

CMD 也可设置：

```cmd
netsh interface ipv4 set interface "Ethernet" metric=10
netsh interface ipv4 set interface "Ethernet 2" metric=50
```

不要为了修 VPN 删除有线默认路由。正确做法是让 G1 保持默认优先，再用 `/32` 路由覆盖 VPN 公网端点。

## 5. Windows：把 VPN Server 固定走手机网络

### 5.1 PowerShell

先确定手机网卡实际名称：

```powershell
Get-NetAdapter | Sort-Object ifIndex
Get-NetIPConfiguration
```

假设手机网卡为 `Ethernet 2`：

```powershell
$VpnServer   = '42.236.61.166'
$MobileAlias = 'Ethernet 2'
$Mobile      = Get-NetIPConfiguration -InterfaceAlias $MobileAlias
$MobileIfIndex = $Mobile.InterfaceIndex
$MobileGateway = $Mobile.IPv4DefaultGateway.NextHop

$Mobile | Format-List InterfaceAlias, InterfaceIndex, IPv4Address, IPv4DefaultGateway
```

先检查是否已有旧路由：

```powershell
Get-NetRoute -DestinationPrefix "$VpnServer/32" -ErrorAction SilentlyContinue
```

没有时新增：

```powershell
New-NetRoute -DestinationPrefix "$VpnServer/32" -InterfaceIndex $MobileIfIndex -NextHop $MobileGateway -RouteMetric 1
```

`New-NetRoute` 默认会把路由写入活动和持久存储。手机 USB 网卡重插后 ifIndex 或网关可能变化，故障时要重新检查，不要直接相信旧值。

如果存在错误的旧 `/32`，先确认后删除：

```powershell
Get-NetRoute -DestinationPrefix "$VpnServer/32" |
    Format-Table DestinationPrefix, NextHop, InterfaceIndex, InterfaceAlias, RouteMetric, PolicyStore

Remove-NetRoute -DestinationPrefix "$VpnServer/32" -Confirm:$false
```

再重新执行 `New-NetRoute`。

验证：

```powershell
Find-NetRoute -RemoteIPAddress 42.236.61.166
Test-NetConnection 42.236.61.166 -DiagnoseRouting -InformationLevel Detailed
```

如果 VPN 使用的是 TCP/7444，可额外测试：

```powershell
Test-NetConnection 42.236.61.166 -Port 7444 -InformationLevel Detailed
```

如果 VPN 实际使用 UDP 或专有协议，TCP 7444 测试不能替代 VPN 客户端本身的连接测试。

### 5.2 CMD

先获取 G2 的接口索引和网关：

```cmd
route print -4
netsh interface ipv4 show interfaces
ipconfig /all
```

记下：

```text
<MOBILE_GATEWAY>
<MOBILE_IFINDEX>
```

先临时验证：

```cmd
route add 42.236.61.166 mask 255.255.255.255 <MOBILE_GATEWAY> metric 1 if <MOBILE_IFINDEX>
```

确认 VPN 能正常建立后，改成持久路由：

```cmd
route delete 42.236.61.166 mask 255.255.255.255
route /p add 42.236.61.166 mask 255.255.255.255 <MOBILE_GATEWAY> metric 1 if <MOBILE_IFINDEX>
```

检查：

```cmd
route print 42.236.61.166
tracert -d 42.236.61.166
```

## 6. Windows：VPN 建立后检查 G3

先连接 VPN，再执行：

```powershell
Get-NetAdapter | Sort-Object ifIndex

Get-NetRoute -AddressFamily IPv4 |
    Where-Object {
        $_.DestinationPrefix -like '10.7.*' -or
        $_.DestinationPrefix -eq '42.236.61.166/32'
    } |
    Format-Table DestinationPrefix, NextHop, InterfaceIndex, InterfaceAlias, RouteMetric

Find-NetRoute -RemoteIPAddress 10.7.216.249
Test-NetConnection 10.7.216.249 -DiagnoseRouting -InformationLevel Detailed
```

判断：

```text
42.236.61.166 → 手机网卡 G2       正常
10.7.216.249  → VPN 虚拟网卡 G3  正常
10.7.216.249  → 有线/手机默认路由 异常
```

如果 VPN 已连接但没有 `10.7.0.0/16` 或更精确的内网路由，优先查 VPN 下发的 split-tunnel/路由策略，不要把内网网段手工指到手机网关。

## 7. Windows：恢复

删除本次 `/32` 分流：

PowerShell：

```powershell
Remove-NetRoute -DestinationPrefix '42.236.61.166/32' -Confirm:$false
```

CMD：

```cmd
route delete 42.236.61.166 mask 255.255.255.255
```

恢复自动 Metric：

```powershell
Set-NetIPInterface -InterfaceAlias 'Ethernet'   -AddressFamily IPv4 -AutomaticMetric Enabled
Set-NetIPInterface -InterfaceAlias 'Ethernet 2' -AddressFamily IPv4 -AutomaticMetric Enabled
```

---

# macOS

macOS 现场重点：

1. 有线 Network Service 排在手机网络之前，保证默认出口仍是有线。
2. 给 `42.236.61.166/32` 配更精确的手机网络路由。
3. VPN 建立后确认 `10.7.0.0/16` 走 `utunX` 或 VPN 客户端创建的虚拟接口。

## 8. macOS：先检查，不修改

查看网络服务、硬件端口和 BSD Device：

```bash
networksetup -listnetworkserviceorder
networksetup -listallhardwareports
ifconfig
```

查看 IPv4 路由表和默认出口：

```bash
netstat -rn -f inet
route -n get default
```

查看 VPN Server 真实出口：

```bash
route -n get 42.236.61.166
```

重点看：

```text
gateway:
interface:
```

VPN 建立后检查内网目标：

```bash
route -n get 10.7.216.249
scutil --nwi
```

正常时 `10.7.216.249` 应走 `utun0`、`utun1` 等隧道接口，或 VPN 客户端自己的虚拟接口。

## 9. macOS：确保默认出口是有线

先看当前服务顺序：

```bash
networksetup -listnetworkserviceorder
```

如果有线排在手机网络之后，可调整：

```bash
sudo networksetup -ordernetworkservices \
    "<WIRED_SERVICE>" \
    "<MOBILE_SERVICE>" \
    "Wi-Fi" \
    "<OTHER_SERVICE>"
```

`-ordernetworkservices` 应按当前机器的实际服务列表填写完整顺序，不能直接照抄示例漏掉已有服务。

验证：

```bash
route -n get default
```

`interface:` 应是现场对应的有线 BSD Device。

## 10. macOS：确定手机接口和网关

先映射 Network Service 和 BSD Device：

```bash
networksetup -listnetworkserviceorder
networksetup -listallhardwareports
```

假设手机网络接口是 `<MOBILE_IF>`，如 `en7`。

DHCP 网络可读取网关：

```bash
ipconfig getoption <MOBILE_IF> router
```

也可查看服务信息：

```bash
networksetup -getinfo "<MOBILE_SERVICE>"
```

记下：

```text
<MOBILE_IF>
<MOBILE_GATEWAY>
<MOBILE_SERVICE>
```

## 11. macOS：先临时验证 `/32`

```bash
sudo route -n add -host 42.236.61.166 <MOBILE_GATEWAY>
```

若已有错误旧路由：

```bash
sudo route -n delete -host 42.236.61.166
sudo route -n add -host 42.236.61.166 <MOBILE_GATEWAY>
```

验证：

```bash
route -n get 42.236.61.166
```

应看到：

```text
gateway:   <MOBILE_GATEWAY>
interface: <MOBILE_IF>
```

`route add` 适合现场验证；系统重启、网络服务重载或链路重连后可能失效。

## 12. macOS：持久化到手机 Network Service

先检查该服务已有 additional routes：

```bash
networksetup -getadditionalroutes "<MOBILE_SERVICE>"
```

如果确认没有其他需要保留的附加路由，可写入：

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

重要：`-setadditionalroutes` 是**设置整张 additional routes 列表**，不是单纯追加。若原来已经有静态路由，必须把原有条目与新条目一起完整写回，否则会覆盖旧配置。

手机热点 DHCP 网关如果发生变化，也要重新修正这条持久路由。

清空该服务的 additional routes：

```bash
sudo networksetup -setadditionalroutes "<MOBILE_SERVICE>"
```

执行前先确认该服务没有其他需要保留的静态路由。

## 13. macOS：VPN 建立后检查 G3

```bash
route -n get default
route -n get 42.236.61.166
route -n get 10.7.216.249
netstat -rn -f inet | egrep 'default|42\.236\.61\.166|10\.7\.'
scutil --nwi
```

目标状态：

```text
default        → 有线接口
42.236.61.166  → 手机接口
10.7.216.249   → utunX / VPN 接口
```

如果 `42.236.61.166` 已正确走手机但 VPN 仍无法建立，继续查手机公网、VPN 客户端日志、服务端和 `7444` 对应协议是否可达。

如果 VPN 已建立但 `10.7.216.249` 仍走默认路由，查 VPN 下发路由或 split-tunnel 策略，不要继续修改手机路由。

## 14. 最短排错流程

Windows：

```text
1. Get-NetRoute / route print -4
2. 确认 0.0.0.0/0 → 有线 G1
3. Find-NetRoute 42.236.61.166
4. 不走手机 → 添加 42.236.61.166/32 → G2
5. 再拨 VPN
6. Find-NetRoute 10.7.216.249
7. 不走 G3 → 查 VPN 路由下发
```

macOS：

```text
1. route -n get default
2. 确认 default → 有线
3. route -n get 42.236.61.166
4. 不走手机 → 添加 /32 主机路由
5. 再拨 VPN
6. route -n get 10.7.216.249
7. 不走 utunX/VPN → 查 VPN 路由下发
```

## 15. 常见错误

| 错误 | 后果 | 正确做法 |
| --- | --- | --- |
| 把默认路由改成手机 | 所有公网流量都绕手机 | 默认仍用有线，只给 VPN Server 配 `/32` |
| 把 `10.7.0.0/16` 指向手机 | 企业内网绕过 VPN | 内网网段应由 G3/VPN 路由承载 |
| 只看 `ping` | ICMP 被过滤时误判 | 看最佳路由 + 实际业务连接 |
| VPN 显示“已连接”就结束检查 | 隧道可能建立但没内网路由 | 继续检查 `10.7.216.249` 的实际出口 |
| Windows 固定记住旧 ifIndex | USB 重插后可能变化 | 故障时重查 ifIndex 和网关 |
| macOS 直接覆盖 additional routes | 删除已有静态路由 | 先查询，再完整写回 |

## 16. 现场采集模板

Windows：

```text
有线接口名 / ifIndex：
有线 IP / 网关：
手机接口名 / ifIndex：
手机 IP / 网关：
VPN 接口名 / ifIndex：
默认路由实际出口：
42.236.61.166 实际出口：
10.7.216.249 实际出口：
```

macOS：

```text
有线 Network Service / BSD Device：
有线 IP / 网关：
手机 Network Service / BSD Device：
手机 IP / 网关：
VPN utun / 虚拟接口：
default 实际出口：
42.236.61.166 实际出口：
10.7.216.249 实际出口：
```

## 17. 参考

- Microsoft `route`：https://learn.microsoft.com/windows-server/administration/windows-commands/route_ws2008
- Microsoft `Get-NetRoute`：https://learn.microsoft.com/powershell/module/nettcpip/get-netroute
- Microsoft `New-NetRoute`：https://learn.microsoft.com/powershell/module/nettcpip/new-netroute
- Microsoft `Set-NetIPInterface`：https://learn.microsoft.com/powershell/module/nettcpip/set-netipinterface
- Microsoft `Test-NetConnection`：https://learn.microsoft.com/powershell/module/nettcpip/test-netconnection
- macOS 本机帮助：`man route`、`man networksetup`、`networksetup -help`
