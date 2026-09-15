# 双网卡 + VPN 指定流量分流（Windows / macOS）

用于以下现场场景：电脑同时连接公司有线网络和手机 USB 网络/热点，日常流量继续走有线网卡，仅把 VPN 公网端点固定从手机网络发出；VPN 建立后，再由 VPN 虚拟网卡访问内网网段。

本文以当前案例为例：

- **G1：有线网卡**：系统默认路由，普通访问优先走这里。
- **G2：手机 USB 网络 / 热点**：只负责把 VPN 公网端点 `42.236.61.166` 送到公网。
- **G3：VPN 虚拟网卡**：VPN 建立后承载 `10.7.0.0/16`，目标主机包括 `10.7.216.249-254`。
- **VPN 公网端点**：`42.236.61.166:7444`。

> 路由只按 IP/网段选择出口，不按 TCP/UDP 端口选择。因此这里配置的是 `42.236.61.166/32`，会影响所有去往该 IP 的流量，而不只是 `:7444`。

## 1. 正确的流量链路

```text
普通公网流量
终端 ──> G1 有线网卡 ──> 默认网关 ──> Internet

VPN 建隧道流量
终端 ──> 42.236.61.166/32 ──> G2 手机网络 ──> Internet ──> VPN Server

VPN 建立后的内网流量
终端 ──> 10.7.0.0/16 ──> G3 VPN 虚拟网卡 ──> VPN 隧道 ──> 10.7.216.249-254
```

核心依赖关系：

```text
G2 到 42.236.61.166 的 /32 路由正常
        ↓
VPN 客户端才能连接公网端点并建立隧道
        ↓
G3 出现并安装 10.7.0.0/16 等 VPN 路由
        ↓
10.7.216.249-254 才能访问
```

不要把 `10.7.0.0/16` 手工指向手机网卡 G2。G2 只负责 VPN 公网端点，内网目标应由 VPN 客户端生成的 G3 路由承载。

## 2. 路由选择必须知道的两条规则

第一条：**最长前缀优先**。

```text
42.236.61.166/32  >  0.0.0.0/0
10.7.0.0/16       >  0.0.0.0/0
```

因此，即使默认路由走有线，只要存在正确的 `42.236.61.166/32` 主机路由，VPN 服务器流量仍会固定走手机网络。

第二条：同样前缀长度时，再比较 Metric / 接口优先级。Windows 可直接调整接口 Metric；macOS 主要通过 Network Service Order 决定多个默认出口的优先级。

---

# Windows

以下命令建议在**管理员 PowerShell / 管理员 CMD** 中执行。

## 3. Windows：先只读检查

### 3.1 PowerShell 查看网卡、网关和路由

```powershell
Get-NetAdapter | Sort-Object ifIndex | Format-Table ifIndex, Name, InterfaceDescription, Status, LinkSpeed

Get-NetIPConfiguration

Get-NetIPInterface -AddressFamily IPv4 |
    Sort-Object InterfaceMetric |
    Format-Table ifIndex, InterfaceAlias, ConnectionState, AutomaticMetric, InterfaceMetric

Get-NetRoute -AddressFamily IPv4 |
    Sort-Object DestinationPrefix, RouteMetric |
    Format-Table DestinationPrefix, NextHop, InterfaceIndex, InterfaceAlias, RouteMetric, InterfaceMetric, PolicyStore
```

只看默认路由：

```powershell
Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' |
    Format-Table InterfaceIndex, InterfaceAlias, NextHop, RouteMetric, InterfaceMetric
```

判断到 VPN 公网端点实际选哪条路：

```powershell
Find-NetRoute -RemoteIPAddress 42.236.61.166

Test-NetConnection 42.236.61.166 -DiagnoseRouting -InformationLevel Detailed
```

VPN 建立后判断内网目标实际选哪条路：

```powershell
Find-NetRoute -RemoteIPAddress 10.7.216.249

Test-NetConnection 10.7.216.249 -DiagnoseRouting -InformationLevel Detailed
```

正确结果应满足：

```text
0.0.0.0/0           → G1 有线网卡
42.236.61.166/32     → G2 手机网卡
10.7.0.0/16 或更精确 → G3 VPN 虚拟网卡
```

### 3.2 CMD 查看

```cmd
ipconfig /all
route print -4
netsh interface ipv4 show interfaces
netsh interface ipv4 show route
```

只看相关路由：

```cmd
route print 42.236.61.166
route print 10.*
tracert -d 42.236.61.166
tracert -d 10.7.216.249
```

注意：VPN/防火墙可能不响应 ICMP 或 traceroute。`tracert` 失败不能单独证明 VPN 不通，应同时看路由选择和实际业务端口。

## 4. Windows：确认默认路由继续走有线

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

再次检查：

```powershell
Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
    Format-Table InterfaceAlias, NextHop, RouteMetric, InterfaceMetric
```

如果只使用 CMD，可执行：

```cmd
netsh interface ipv4 set interface "Ethernet" metric=10
netsh interface ipv4 set interface "Ethernet 2" metric=50
```

Metric 越小优先级越高。不要为了修复 VPN 去删除有线默认路由，正常做法是保留两张网卡的默认信息，让有线的优先级更高，再用 `/32` 主机路由覆盖 VPN 公网端点。

## 5. Windows：把 VPN 公网端点固定到手机网卡

### 5.1 PowerShell 自动取得手机网关

先把网卡名称改成现场实际名称：

```powershell
$VpnServer   = '42.236.61.166'
$MobileAlias = 'Ethernet 2'

$Mobile = Get-NetIPConfiguration -InterfaceAlias $MobileAlias
$MobileIfIndex = $Mobile.InterfaceIndex
$MobileGateway = $Mobile.IPv4DefaultGateway.NextHop

$Mobile | Format-List InterfaceAlias, InterfaceIndex, IPv4Address, IPv4DefaultGateway
```

确认 `$MobileGateway` 有值后，先检查是否已经存在旧路由：

```powershell
Get-NetRoute -DestinationPrefix "$VpnServer/32" -ErrorAction SilentlyContinue
```

如果没有路由，新增：

```powershell
New-NetRoute \
    -DestinationPrefix "$VpnServer/32" \
    -InterfaceIndex $MobileIfIndex \
    -NextHop $MobileGateway \
    -RouteMetric 1
```

PowerShell 的 `New-NetRoute` 默认会将路由写入活动和持久存储；如果手机网关、网卡名称或 ifIndex 后续变化，应重新核对，而不是假设旧持久路由仍然正确。

如果已存在错误的 `42.236.61.166/32`，先确认确实是旧配置，再删除并重建：

```powershell
Get-NetRoute -DestinationPrefix "$VpnServer/32" |
    Format-Table DestinationPrefix, NextHop, InterfaceIndex, InterfaceAlias, RouteMetric, PolicyStore

Remove-NetRoute -DestinationPrefix "$VpnServer/32" -Confirm:$false
```

然后重新执行 `New-NetRoute`。

### 5.2 CMD 添加持久 `/32` 路由

先获取手机接口索引和手机网关：

```cmd
route print -4
netsh interface ipv4 show interfaces
ipconfig /all
```

假设现场查到：

```text
手机网关      = <MOBILE_GATEWAY>
手机接口索引  = <MOBILE_IFINDEX>
```

先临时验证：

```cmd
route add 42.236.61.166 mask 255.255.255.255 <MOBILE_GATEWAY> metric 1 if <MOBILE_IFINDEX>
```

验证成功后，删除临时项，再添加持久路由：

```cmd
route delete 42.236.61.166 mask 255.255.255.255
route /p add 42.236.61.166 mask 255.255.255.255 <MOBILE_GATEWAY> metric 1 if <MOBILE_IFINDEX>
```

检查：

```cmd
route print 42.236.61.166
tracert -d 42.236.61.166
```

如果 VPN 使用 TCP/7444，还可以额外测试 TCP 建连：

```powershell
Test-NetConnection 42.236.61.166 -Port 7444 -InformationLevel Detailed
```

如果 VPN 实际使用 UDP 或专有协议，上面的 TCP 测试不能代替 VPN 客户端本身的连接测试。

## 6. Windows：VPN 拨入后验证 G3

先拨 VPN，再执行：

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

判定：

```text
42.236.61.166 仍从手机网卡出去  → 正常
10.7.216.249 从 VPN 虚拟网卡出去 → 正常
10.7.216.249 仍走有线/手机默认路由 → VPN 没有正确注入内网路由
```

如果 VPN 客户端连上后没有 `10.7.0.0/16` 或更精确的内网路由，优先检查 VPN 客户端下发策略，不要直接把 `10.7.0.0/16` 指到手机网关。

## 7. Windows：恢复/删除本次分流

PowerShell：

```powershell
Remove-NetRoute -DestinationPrefix '42.236.61.166/32' -Confirm:$false
```

CMD：

```cmd
route delete 42.236.61.166 mask 255.255.255.255
```

如需恢复 Windows 自动接口 Metric：

```powershell
Set-NetIPInterface -InterfaceAlias 'Ethernet'   -AddressFamily IPv4 -AutomaticMetric Enabled
Set-NetIPInterface -InterfaceAlias 'Ethernet 2' -AddressFamily IPv4 -AutomaticMetric Enabled
```

---

# macOS

macOS 没有 Windows 那样常用的 InterfaceMetric 管理方式。现场重点是：

1. 用 Network Service Order 保证有线是默认出口。
2. 为 `42.236.61.166/32` 建立更精确的手机网络路由。
3. VPN 建立后确认 `10.7.0.0/16` 指向 `utunX` 或 VPN 客户端创建的虚拟接口。

## 8. macOS：先只读检查

查看硬件端口、服务顺序和接口：

```bash
networksetup -listallhardwareports
networksetup -listnetworkserviceorder
ifconfig
```

查看 IPv4 路由表：

```bash
netstat -rn -f inet
```

查看当前默认出口：

```bash
route -n get default
```

查看 VPN 公网端点实际走哪张网卡：

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

正常情况下，`10.7.216.249` 的 `interface` 应是 `utun0`、`utun1` 等 VPN 虚拟接口，或 VPN 客户端自己的隧道接口。

## 9. macOS：确认默认路由走有线

先查看当前服务顺序：

```bash
networksetup -listnetworkserviceorder
```

如果有线服务没有排在手机网络之前，可调整服务顺序：

```bash
sudo networksetup -ordernetworkservices \
    "<WIRED_SERVICE>" \
    "<MOBILE_SERVICE>" \
    "Wi-Fi" \
    "<OTHER_SERVICE>"
```

`-ordernetworkservices` 应按当前机器实际服务列表填写完整顺序，不要照抄示例漏掉现有网络服务。

再次确认：

```bash
route -n get default
```

`interface:` 应指向有线网卡，例如 `en0`、`en5`、`en7` 中现场对应的有线接口。

## 10. macOS：取得手机网络接口和网关

先通过下面命令把网络服务名称映射到 BSD Device：

```bash
networksetup -listnetworkserviceorder
networksetup -listallhardwareports
```

假设手机网络对应接口为：

```text
<MOBILE_IF>=en7
```

如果该接口通过 DHCP 获取网络，可以尝试读取网关：

```bash
ipconfig getoption <MOBILE_IF> router
```

也可查看网络服务信息：

```bash
networksetup -getinfo "<MOBILE_SERVICE>"
```

确认得到手机侧网关 `<MOBILE_GATEWAY>` 后再继续。

## 11. macOS：先临时添加 `/32` 路由验证

```bash
sudo route -n add -host 42.236.61.166 <MOBILE_GATEWAY>
```

如果已有错误的旧路由：

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

`route add` 方式通常在重启、网络服务重载或链路重连后失效，适合先做现场验证。

## 12. macOS：把 `/32` 路由写入手机网络服务

macOS `networksetup` 支持给指定 Network Service 配置 additional routes。

先检查手机网络服务是否已有附加路由：

```bash
networksetup -getadditionalroutes "<MOBILE_SERVICE>"
```

如果确认当前没有需要保留的 additional routes，可写入：

```bash
sudo networksetup -setadditionalroutes \
    "<MOBILE_SERVICE>" \
    42.236.61.166 255.255.255.255 <MOBILE_GATEWAY>
```

再检查：

```bash
networksetup -getadditionalroutes "<MOBILE_SERVICE>"
route -n get 42.236.61.166
```

重要：`-setadditionalroutes` 是**设置整张附加路由列表**，不是简单追加。如果该服务原来已经配置了其他 additional routes，必须把原有条目和新条目一起完整传入，否则会覆盖原配置。

清空该网络服务的 additional routes：

```bash
sudo networksetup -setadditionalroutes "<MOBILE_SERVICE>"
```

执行前同样应确认没有其他需要保留的静态路由。

## 13. macOS：VPN 拨入后验证 G3

```bash
route -n get 42.236.61.166
route -n get 10.7.216.249
netstat -rn -f inet | egrep 'default|42\.236\.61\.166|10\.7\.'
scutil --nwi
```

判定：

```text
42.236.61.166 → 手机接口        正常
10.7.216.249  → utunX / VPN接口 正常
default       → 有线接口        正常
```

如果 `42.236.61.166` 已经正确走手机，但 VPN 仍无法建立，应转查：

```text
手机网络本身是否能访问公网
42.236.61.166:7444 对应协议是否被运营商/防火墙阻断
VPN 客户端日志
DNS/证书/账号认证
VPN 服务端状态
```

如果 VPN 已建立但 `10.7.216.249` 仍走默认路由，应检查 VPN 路由下发或 split-tunnel 策略，而不是继续修改手机网络路由。

---

# 14. 最短排错流程

Windows：

```text
1. route print -4 / Get-NetRoute
2. 确认默认 0.0.0.0/0 → 有线 G1
3. Find-NetRoute 42.236.61.166
4. 不走手机 → 添加 42.236.61.166/32 → 手机 G2
5. 再拨 VPN
6. Find-NetRoute 10.7.216.249
7. 不走 VPN G3 → 查 VPN 路由下发，不要改 G2
```

macOS：

```text
1. route -n get default
2. 确认 default → 有线
3. route -n get 42.236.61.166
4. 不走手机 → route -n add -host ... 或 networksetup -setadditionalroutes
5. 再拨 VPN
6. route -n get 10.7.216.249
7. 不走 utunX/VPN → 查 VPN 路由下发
```

## 15. 常见误区

| 误区 | 后果 | 正确做法 |
| --- | --- | --- |
| 把系统默认路由改成手机 | 所有公网流量都绕手机 | 默认仍用有线，只给 VPN Server 配 `/32` |
| 把 `10.7.0.0/16` 指向手机 | 内网流量绕过 VPN 隧道 | `10.7.0.0/16` 应由 VPN G3 承载 |
| 只看 `ping` | ICMP 被禁时容易误判 | 同时看实际路由和业务连接 |
| 只看 VPN 是否“已连接” | 隧道可能建立但无内网路由 | 再验证 `10.7.216.249` 的最佳路由 |
| Windows 只保存固定 ifIndex | USB 重插后接口索引可能变化 | 每次故障先重新查 ifIndex / 网关 |
| macOS 直接覆盖 additional routes | 可能删除原有静态路由 | 先 `-getadditionalroutes` 再完整写入 |

## 16. 现场采集结果模板

Windows：

```text
有线接口名/ifIndex：
有线 IP/网关：
手机接口名/ifIndex：
手机 IP/网关：
VPN 接口名/ifIndex：
默认路由实际出口：
42.236.61.166 实际出口：
10.7.216.249 实际出口：
```

macOS：

```text
有线 Network Service / BSD Device：
有线 IP/网关：
手机 Network Service / BSD Device：
手机 IP/网关：
VPN utun/虚拟接口：
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
