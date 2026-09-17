# 多网卡 + 手机 USB + VPN / 代理分流速查（Windows / macOS / Linux）

用于以下常见办公场景：电脑同时存在**有线网卡、手机 USB 共享网络、企业 VPN、代理/TUN**，需要让不同流量稳定走不同出口，并能在手机 USB 拔插、VPN 重连后快速恢复。

## 1. 最短结论

目标链路：

```text
普通公网流量（未启用代理 TUN）
终端 -> G1 有线网卡 -> Internet

VPN 建隧道流量
终端 -> VPN 公网端点 /32 -> G2 手机 USB 网络 -> Internet -> VPN Server

VPN 建立后的企业内网流量
终端 -> 企业内网网段 -> G3 VPN 虚拟网卡 -> VPN 隧道

需要代理的公网流量
应用 -> 代理/TUN -> G1 有线底层出口
```

实施时只抓住 4 条：

1. **有线网卡保持物理默认出口。**
2. **VPN 公网端点单独配置 `/32` 主机路由，强制走手机 USB。**
3. **企业内网路由只允许由 VPN 接管，不手工指向有线或手机。**
4. **全局代理只能有一个 owner，VPN 尽量使用 split-tunnel。**

本机案例参数：

- **G1 有线**：物理默认 Internet 出口。
- **G2 手机 USB**：只负责 VPN 公网端点。
- **G3 VPN**：负责企业内网。
- **VPN 公网端点示例**：`42.236.61.166:7444`。
- **企业内网示例**：`10.7.0.0/16`。
- **TUN 示例**：Mihomo/Clash 类代理。

> 路由只按目标 IP/网段选路，不按 TCP/UDP 端口选路。所以应固定 `42.236.61.166/32`，不是单独固定 `:7444`。

## 2. 为什么 `/32` 能覆盖代理 TUN

路由优先按**最长前缀匹配**：

```text
42.236.61.166/32
        >
0.0.0.0/1、128.0.0.0/1
        >
0.0.0.0/0
```

因此即使 Mihomo/TUN 使用 `/1` 分裂默认路由接管公网，VPN Server 的 `/32` 仍会优先命中手机网络。

不要把 VPN Server 写成 `/24`、`/16` 或默认路由；只写单主机 `/32`。

## 3. Windows：推荐实施方案

以下操作使用**管理员 PowerShell**。手机 USB 常见为 RNDIS/Remote NDIS 网卡。

### 3.1 先识别当前接口，不硬编码 ifIndex

```powershell
Get-NetAdapter |
    Sort-Object ifIndex |
    Format-Table ifIndex,Name,InterfaceDescription,Status,MacAddress

Get-NetIPConfiguration
```

确认：

```text
G1 = 当前有线网卡
G2 = 当前手机 USB/RNDIS 网卡
```

不要把历史 `ifIndex` 写死到长期脚本；换 USB 口、换手机、重新枚举后索引可能变化。

### 3.2 设置物理默认出口优先级

下面按实际接口名替换：

```powershell
$WiredAlias  = '以太网 2'
$MobileAlias = '以太网 4'

$wired  = Get-NetAdapter -Name $WiredAlias
$mobile = Get-NetAdapter -Name $MobileAlias

Set-NetIPInterface -InterfaceIndex $wired.ifIndex  -AddressFamily IPv4 -AutomaticMetric Disabled -InterfaceMetric 10
Set-NetIPInterface -InterfaceIndex $mobile.ifIndex -AddressFamily IPv4 -AutomaticMetric Disabled -InterfaceMetric 500
```

验证物理默认路由：

```powershell
Get-NetIPInterface -InterfaceIndex $wired.ifIndex,$mobile.ifIndex -AddressFamily IPv4 |
    Format-Table ifIndex,InterfaceAlias,AutomaticMetric,InterfaceMetric

Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
    Format-Table InterfaceAlias,NextHop,RouteMetric,InterfaceMetric
```

预期：物理 `0.0.0.0/0` 中有线优先级明显高于手机。代理 TUN 开启后可以再用 `/1` 等更长前缀接管公网，但底层物理默认出口仍保持 G1。

### 3.3 动态读取手机网关

```powershell
$gw = (Get-NetIPConfiguration -InterfaceIndex $mobile.ifIndex).IPv4DefaultGateway.NextHop
$gw
```

必须能得到当前手机网关。不要写死历史 DHCP 网关。

### 3.4 重建 VPN Server `/32` 持久路由

```powershell
$VpnServer = '42.236.61.166'

Get-NetRoute -DestinationPrefix "$VpnServer/32" -ErrorAction SilentlyContinue |
    Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

Get-NetRoute -DestinationPrefix "$VpnServer/32" -PolicyStore PersistentStore -ErrorAction SilentlyContinue |
    Remove-NetRoute -PolicyStore PersistentStore -Confirm:$false -ErrorAction SilentlyContinue

route -p add $VpnServer mask 255.255.255.255 $gw metric 1
```

这里优先使用 `route -p` 且**不写 `if <Index>`**，让 Windows 按当前可达手机网关选接口。这样比把接口索引写死更耐受 USB 重插。

### 3.5 拨 VPN 前验证 G1 / G2

先确认物理默认路由和 VPN Server 专用路由：

```powershell
Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
    Format-Table InterfaceAlias,NextHop,RouteMetric,InterfaceMetric

Find-NetRoute -RemoteIPAddress 42.236.61.166
Get-NetRoute -DestinationPrefix '42.236.61.166/32'
```

正确结果：

```text
物理 0.0.0.0/0  -> G1 有线优先
42.236.61.166/32 -> G2 手机 USB
```

如果代理 TUN **未开启**，可再执行：

```powershell
Find-NetRoute -RemoteIPAddress 1.1.1.1
```

此时普通公网应直接走 G1。

如果代理 TUN **已开启**，`1.1.1.1` 正常可能命中 TUN，而不是直接显示 G1；这不代表路由错误。此时应确认：

```text
公网应用流量 -> TUN
TUN 的物理底层出口 -> G1
VPN Server /32 -> G2
```

如果 VPN Server 屏蔽 ICMP，`ping` 不通不能直接判定链路失败。优先看选路结果、VPN 实际登录结果，以及协议明确时的端口测试。

例如 TCP 7444：

```powershell
Test-NetConnection 42.236.61.166 -Port 7444 -InformationLevel Detailed
```

### 3.6 连接 VPN 后验证 G3

```powershell
Find-NetRoute -RemoteIPAddress 42.236.61.166
Find-NetRoute -RemoteIPAddress 10.7.216.249

Get-NetRoute -AddressFamily IPv4 |
    Where-Object {
        $_.DestinationPrefix -like '10.7.*' -or
        $_.DestinationPrefix -eq '42.236.61.166/32'
    } |
    Format-Table DestinationPrefix,NextHop,InterfaceIndex,InterfaceAlias,RouteMetric
```

正确结果：

```text
42.236.61.166 -> G2 手机 USB
10.7.216.249  -> G3 VPN 虚拟网卡
普通 Internet -> 无 TUN 时直接 G1；有 TUN 时由代理接管且底层仍为 G1
```

若 VPN 显示已连接，但 `10.7.216.249` 不走 VPN 虚拟接口，优先检查 VPN 是否下发了 `10.7.0.0/16` 或更精确内网路由。

### 3.7 手机 USB 拔插后的恢复

重插后只按这个顺序处理：

```text
1. 重新识别手机接口
2. 重新读取手机 DHCP 网关
3. 再次设置 G1/G2 Metric
4. 删除旧 VPN Server /32
5. 用新手机网关重建 /32
6. 先验证 G1/G2
7. 再连接 VPN
8. 验证 G3
```

最常见变化：

- `ifIndex` 变化；
- 手机 DHCP 网关变化；
- 新枚举网卡恢复自动 Metric；
- 旧 `/32` 仍指向旧网关。

## 4. Windows CMD 快速操作

先查询：

```cmd
ipconfig /all
netsh interface ipv4 show interfaces
route print -4
```

设置接口优先级：

```cmd
netsh interface ipv4 set interface "以太网 2" metric=10
netsh interface ipv4 set interface "以太网 4" metric=500
```

假设当前手机网关为 `10.54.23.41`：

```cmd
route delete 42.236.61.166 mask 255.255.255.255
route -p add 42.236.61.166 mask 255.255.255.255 10.54.23.41 metric 1
route print 42.236.61.166
```

原则仍然是：**手机网关运行时查询，不长期写死；尽量不要把 ifIndex 写进持久路由。**

## 5. macOS 快速实施

macOS 使用**网络服务名**做长期配置，不要长期依赖 `enX`。

### 5.1 识别服务和当前网关

```bash
networksetup -listallnetworkservices
networksetup -listnetworkserviceorder
networksetup -listallhardwareports
networksetup -getinfo "<MOBILE_SERVICE>"
```

如果已经知道手机对应 BSD Device，也可读取 DHCP 网关：

```bash
ipconfig getoption <MOBILE_IF> router
```

### 5.2 默认出口保持有线优先

```bash
sudo networksetup -ordernetworkservices \
  "<WIRED_SERVICE>" \
  "<MOBILE_SERVICE>" \
  "Wi-Fi"
```

执行前先看完整服务列表；不要漏掉本机仍需保留的其他 Network Service。

验证：

```bash
route -n get default
```

### 5.3 给 VPN Server 添加持久 `/32`

先检查已有附加路由：

```bash
networksetup -getadditionalroutes "<MOBILE_SERVICE>"
```

如果没有其他必须保留的 additional routes：

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

> `-setadditionalroutes` 会重设该服务的附加路由列表。若原来已有其他静态路由，必须一起保留。

### 5.4 VPN 前后验证

VPN 前：

```bash
route -n get default
route -n get 42.236.61.166
```

VPN 后：

```bash
route -n get 10.7.216.249
netstat -rn -f inet | egrep 'default|42\.236\.61\.166|10\.7\.'
```

预期：

```text
default        -> G1 有线
42.236.61.166  -> G2 手机网络
10.7.216.249   -> utunX / VPN 虚拟接口
```

## 6. Linux（NetworkManager）快速实施

适用于 Ubuntu/Fedora 等由 NetworkManager 管理的桌面 Linux。

### 6.1 识别当前连接

```bash
ip -br addr
nmcli device status
nmcli connection show --active
```

记录：

```text
<WIRED_CONN>
<PHONE_CONN>
<PHONE_IF>
```

读取手机网关：

```bash
nmcli -t -f IP4.GATEWAY device show <PHONE_IF>
```

### 6.2 默认出口保持有线，手机只做专用出口

```bash
sudo nmcli connection modify <WIRED_CONN> ipv4.route-metric 10
sudo nmcli connection modify <PHONE_CONN> ipv4.never-default yes ipv4.route-metric 500
```

### 6.3 添加 VPN Server `/32`

```bash
sudo nmcli connection modify <PHONE_CONN> +ipv4.routes "42.236.61.166/32 <PHONE_GW> 1"
sudo nmcli connection up <PHONE_CONN>
```

验证：

```bash
ip route get 42.236.61.166
ip route get 10.7.216.249
```

手机重插后若 NetworkManager 新建了连接，必须把 Metric、`never-default` 和 `/32` 重新应用到**当前连接**。若手机网关变化，还应先清理旧的同目标静态路由，避免 `+ipv4.routes` 累积旧条目。

## 7. 代理 / TUN / VPN 共存规则

多代理场景最重要的是避免“多个软件同时抢默认路由”。

### 规则

1. **全局代理只能有一个。** Mihomo/Clash/OpenVPN/其他 TUN 中，只允许一个软件接管全部公网。
2. **企业 VPN 优先 split-tunnel。** 只注入企业内网前缀，不抢 `0.0.0.0/0`。
3. **VPN Server 永远用 `/32`。** 它会优先于 `/1`、`/0`。
4. **有线 Metric 低，手机 Metric 高。** 没有代理时，OS 默认仍走有线。
5. **启动顺序建议：** 物理网络 -> 全局代理 -> 检查 `/32` -> 企业 VPN。
6. 新开第二个“全局模式”VPN/代理前，先关闭原全局代理或把其中一个改成 split-tunnel。

### Windows 快速检查是否打架

```powershell
Get-NetRoute -AddressFamily IPv4 |
    Where-Object {
        $_.DestinationPrefix -in @('0.0.0.0/0','0.0.0.0/1','128.0.0.0/1')
    } |
    Sort-Object DestinationPrefix,RouteMetric |
    Format-Table DestinationPrefix,InterfaceAlias,NextHop,RouteMetric
```

判断：

```text
正常：全局 /1 或等价全局路由只归一个 TUN/代理
异常：多个 VPN/TUN 同时注入全局路由，且互相覆盖
```

## 8. 手机 USB 的两个现场坑

### 8.1 老旧 USB Wi-Fi 网卡可能出现 IPv6 有、IPv4 无

实测曾出现：

```text
Wi-Fi 已关联手机热点
IPv6 正常
IPv4 DHCP 失败
最终只有 169.254.x.x APIPA
```

这说明“IPv6 能通”不能证明 IPv4 正常。VPN 公网端点如果是 IPv4，仍需要正常 DHCPv4。

现场优先方案仍是：**手机 USB RNDIS 直连**。

### 8.2 Windows 通常无法覆盖 RNDIS 的手机侧 MAC

部分 VPN 会把认证绑定到网卡 MAC。实测对 RNDIS 执行：

```powershell
Set-NetAdapterAdvancedProperty -Name '<PHONE_ALIAS>' -RegistryKeyword NetworkAddress -RegistryValue '0A1B2C3D4E5F'
```

即使注册表写入成功，实际 MAC 仍可能保持手机下发值。

原因是 RNDIS MAC 往往由手机侧 USB/RNDIS 描述提供，Windows 驱动不一定支持覆盖。

因此：

```text
优先：手机侧选择“固定/设备 MAC”（若手机支持）
其次：VPN 改为账号/证书等不依赖 MAC 的认证方式
不要：反复尝试 Windows NetworkAddress 强改 RNDIS MAC
```

## 9. 最短故障判断

严格按以下顺序，不要跳过 G2 直接修 VPN 内网：

```text
1. G1 有线是不是物理默认出口？
        ↓
2. VPN Server 有没有命中 /32？
        ↓
3. /32 下一跳是不是当前手机网关？
        ↓
4. VPN 能不能建立？
        ↓
5. VPN 是否创建虚拟接口？
        ↓
6. VPN 是否下发企业内网路由？
        ↓
7. 企业内网目标是否命中 VPN 接口？
```

常见现象：

| 现象 | 首查 | 常见原因 |
| --- | --- | --- |
| 普通上网直接跑到手机 | 物理默认路由、Metric | 手机优先级过高 |
| VPN 完全连不上 | VPN Server `/32` | VPN Server 错走有线/代理 |
| 手机重插后 VPN 失效 | 手机网关、ifIndex、持久路由 | DHCP/接口重新枚举 |
| VPN 已连接但内网不通 | `10.x` 路由 | VPN 未下发 split-tunnel 路由 |
| 内网错误走手机 | 路由表 | 手工把企业内网指向 G2 |
| 多个代理时网络抖动 | `/0`、`/1` | 多个 TUN 同时抢全局路由 |
| VPN Server ping 不通 | 实际选路、VPN 登录 | 服务端屏蔽 ICMP |

## 10. 回退

### Windows

删除专用 `/32`：

```powershell
Remove-NetRoute -DestinationPrefix '42.236.61.166/32' -Confirm:$false
```

恢复自动 Metric：

```powershell
Set-NetIPInterface -InterfaceAlias '<WIRED_ALIAS>'  -AddressFamily IPv4 -AutomaticMetric Enabled
Set-NetIPInterface -InterfaceAlias '<MOBILE_ALIAS>' -AddressFamily IPv4 -AutomaticMetric Enabled
```

### macOS

先确认该服务没有其他必须保留的 additional routes，再清空：

```bash
networksetup -getadditionalroutes "<MOBILE_SERVICE>"
sudo networksetup -setadditionalroutes "<MOBILE_SERVICE>"
```

### Linux

查看当前连接配置：

```bash
nmcli connection show <PHONE_CONN>
```

按现场需要删除对应 `ipv4.routes`，并恢复原 `ipv4.never-default` / `ipv4.route-metric`。

## 11. 风险边界

- 不硬编码历史 `ifIndex`、`enX`、`usbX`。
- 不把企业内网路由手工指向手机或有线。
- 不为了 VPN 删除有线默认路由。
- 不在多个代理/VPN 中同时开启全局模式。
- 不把 VPN Server `/32` 扩大成网段。
- 远程生产主机没有带外管理时，不直接修改默认路由和网卡 Metric。
- 修改前先记录当前路由；修改后立即验证 G1/G2，再连接 VPN 验证 G3。

## 12. 现场验收清单

```text
□ 物理默认路由中 G1 有线优先于 G2 手机
□ 无 TUN 时普通 Internet 直接走 G1；有 TUN 时代理接管公网但底层物理出口仍为 G1
□ VPN Server /32 走 G2 手机 USB
□ 手机 USB 当前网关与 /32 下一跳一致
□ VPN 建立后企业内网走 G3 VPN 虚拟接口
□ VPN Server 在 VPN 连接期间仍走 G2
□ 全局代理/TUN 只有一个 owner
□ 手机拔插后重新检查接口、网关和 /32
□ VPN 端点若不响应 ICMP，不使用 ping 作为唯一判断依据
```

## 官方参考

- Microsoft `route`：<https://learn.microsoft.com/windows-server/administration/windows-commands/route_ws2008>
- Microsoft `Get-NetRoute`：<https://learn.microsoft.com/powershell/module/nettcpip/get-netroute>
- Microsoft `Set-NetIPInterface`：<https://learn.microsoft.com/powershell/module/nettcpip/set-netipinterface>
- Microsoft `Test-NetConnection`：<https://learn.microsoft.com/powershell/module/nettcpip/test-netconnection>
- NetworkManager `nm-settings-nmcli`：<https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html>
- macOS：本机执行 `man route`、`man networksetup`、`networksetup -help`
