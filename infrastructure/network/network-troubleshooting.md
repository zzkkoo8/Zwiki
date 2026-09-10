# 网络故障快速排查

用于 Linux 主机出现“IP 不通、端口不通、域名可解析但访问失败、只有某台机器不通、连接超时”等问题时逐层定位。

## 快速处理

固定从本机向外查：

```text
网卡/IP → 路由 → ARP/邻居 → DNS → TCP/UDP 端口 → 本机/目标服务监听 → 防火墙/NAT → 抓包
```

```bash
ip -br addr
ip -s link
ip route
ip route get <TARGET_IP>
ip neigh
cat /etc/resolv.conf
getent hosts <DOMAIN>
ss -lntup
ping -c 4 <TARGET_IP>
```

测试 TCP 端口优先使用已有工具：

```bash
nc -zv -w 3 <TARGET_IP> <PORT>
```

没有 `nc` 时，Bash 可测试 TCP 建连：

```bash
timeout 3 bash -c '</dev/tcp/<TARGET_IP>/<PORT>'
echo $?
```

返回 `0` 代表 TCP 建连成功，不代表上层协议一定正常。

HTTP/HTTPS：

```bash
curl -v --connect-timeout 3 http://<HOST>:<PORT>/
curl -vk --connect-timeout 3 https://<HOST>:<PORT>/
```

`-k` 只适合定位 TLS 问题，会跳过证书校验，不能作为正式访问方式。

## 必须知道

- **IP/掩码**：决定哪些目标被视为本地二层网络，掩码错误会导致流量走错路径。
- **默认网关/路由**：决定非直连目标下一跳；`ip route get` 比只看路由表更适合判断实际路径。
- **ARP/邻居表**：IPv4 本地网段需要把目标/网关 IP 解析成 MAC；`FAILED/INCOMPLETE` 常指向二层、VLAN、网关或邻居不可达。
- **DNS**：只负责名字到地址的解析。DNS 正常不代表端口或应用正常。
- **TCP**：有握手和连接状态，超时/RST 的含义不同；端口测试只判断传输层。
- **UDP**：无连接握手，单纯“没响应”不能直接证明端口关闭。
- **NAT**：会修改源/目的地址或端口；排障时要明确抓包点看到的是 NAT 前还是 NAT 后地址。
- **VLAN**：二层逻辑隔离。主机发出的以太帧是否带 VLAN Tag 取决于主机/交换机端口配置，不能仅凭“跨网段”判断 VLAN 故障。

## 1. 本机网卡和地址

```bash
ip -br link
ip -br addr
ip -s link
```

重点确认：

```text
接口是否 UP
IP/掩码是否正确
RX/TX 是否增长
是否存在 errors/dropped
```

物理网卡有 `ethtool` 时：

```bash
ethtool <IFACE>
```

看 `Link detected`、Speed、Duplex。

## 2. 路由是否正确

```bash
ip route
ip route get <TARGET_IP>
```

`ip route get` 重点看：

```text
via       实际下一跳
dev       实际出口网卡
src       本机选择的源 IP
```

如果目标应走专用网卡却走默认网关，优先处理路由/策略路由，而不是先查应用。

策略路由环境：

```bash
ip rule
ip route show table all
```

## 3. 本地网段 / 网关的邻居状态

```bash
ip neigh
ip neigh show <TARGET_IP>
```

常见状态：

- `REACHABLE/STALE`：邻居条目存在，不代表业务一定通。
- `INCOMPLETE/FAILED`：ARP/NDP 解析失败，优先查二层链路、VLAN、交换机端口、目标是否在线。

## 4. DNS

```bash
cat /etc/resolv.conf
getent hosts <DOMAIN>
```

systemd-resolved 环境：

```bash
resolvectl status
resolvectl query <DOMAIN>
```

如果有 `dig`：

```bash
dig <DOMAIN>
dig @<DNS_SERVER> <DOMAIN>
```

判断：

```text
域名不能解析 → 查 DNS 配置/服务器
域名能解析，IP 端口仍不通 → 转入路由/端口/服务排查
解析到错误 IP → 查 DNS 记录、缓存、hosts
```

同时检查：

```bash
grep -vE '^\s*(#|$)' /etc/hosts
```

## 5. 目标端口

TCP：

```bash
nc -zv -w 3 <TARGET_IP> <PORT>
```

无 nc：

```bash
timeout 3 bash -c '</dev/tcp/<TARGET_IP>/<PORT>'
```

HTTP：

```bash
curl -v --connect-timeout 3 http://<TARGET_IP>:<PORT>/
```

HTTPS 指定 Host/SNI 时可用域名直接请求；如果必须绕过 DNS 定向到某 IP：

```bash
curl -v --resolve <DOMAIN>:443:<TARGET_IP> https://<DOMAIN>/
```

这比直接用 HTTPS IP 更适合检查依赖 SNI/Host 的虚拟主机。

## 6. 服务端是否真的监听

在目标主机：

```bash
ss -lntup
ss -lntp | grep ':<PORT> '
```

重点区分：

```text
127.0.0.1:<PORT>    只监听本机
0.0.0.0:<PORT>      监听所有 IPv4 地址
[::]:<PORT>         IPv6/可能同时接受 IPv4，取决于系统配置
指定业务 IP:<PORT>  只监听该地址
```

服务存在但没有监听时，继续查 systemd/应用日志，不要先改防火墙。

## 7. 防火墙和 NAT

主机侧先识别实际使用哪套框架：

```bash
command -v nft
command -v firewall-cmd
command -v iptables
```

只读查看：

```bash
nft list ruleset 2>/dev/null
firewall-cmd --state 2>/dev/null
firewall-cmd --list-all 2>/dev/null
iptables -S 2>/dev/null
iptables -t nat -S 2>/dev/null
```

不要同时随意修改 nftables、firewalld、iptables；它们可能存在管理层/兼容层关系，先确认规则真正由谁维护。

## 8. traceroute / tracepath

有 `tracepath` 时：

```bash
tracepath <TARGET_IP>
```

有 `traceroute` 时：

```bash
traceroute -n <TARGET_IP>
```

某一跳 `* * *` 不一定代表该节点故障，设备可能只是不回复 TTL exceeded/ICMP。判断应结合最终目标是否可达和抓包结果。

## 9. 典型症状怎么判断

| 现象 | 首查 | 常见方向 |
| --- | --- | --- |
| IP 都 ping 不通 | `ip route get`、`ip neigh`、抓包 | 路由、二层、ICMP 被过滤 |
| IP 可达，端口超时 | `ss`、`nc`、抓包 | 防火墙丢弃、服务未监听、路径丢包 |
| 端口立即 `Connection refused` | 服务端 `ss -lntp` | 对端返回 RST，通常该地址/端口没有接受连接 |
| DNS 正常但访问失败 | 直接测解析出的 IP/端口 | 与 DNS 无关，继续查传输层/应用 |
| SYN 发出一直无 SYN-ACK | 两端 tcpdump | 中间丢弃、返回路径错误、防火墙 silent drop |
| SYN 后立刻 RST | 服务端监听/负载均衡 | 目标明确拒绝或中间设备主动拒绝 |
| HTTP connect 成功但读超时 | `curl -v`、服务日志 | 应用/上游处理慢，不是 TCP 建连问题 |
| 同网段只有某一台不通 | `ip neigh`、交换机/WAF/主机抓包 | 主机路由/防火墙/ARP、设备策略、目标服务 |

## 10. 只有某一台主机不通

按对比法最快：

在正常主机和异常主机分别采集：

```bash
ip -br addr
ip route
ip route get <TARGET_IP>
ip neigh show <TARGET_IP>
ss -s
```

异常机发起连接时抓包：

```bash
tcpdump -ni any host <TARGET_IP>
```

判断：

```text
看不到 SYN → 本机应用/路由/安全策略问题
看到 SYN 发出、没返回 → 网络路径或目标侧
看到 SYN 和 SYN-ACK，但连接仍失败 → 本机回包处理、RST 或上层应用
目标侧完全看不到 SYN → 中间网络/安全设备/路由
```

详细抓包见 [tcpdump 抓包与快速判断](tcpdump-packet-analysis.md)。

## 深入学习

- Linux `ip` / iproute2：https://man7.org/linux/man-pages/man8/ip.8.html
- Linux `ss`：https://man7.org/linux/man-pages/man8/ss.8.html
- TCP 标准 RFC 9293：https://www.rfc-editor.org/rfc/rfc9293
- DNS 基础 RFC 1034：https://www.rfc-editor.org/rfc/rfc1034
- VLAN IEEE 802.1Q 概览：https://1.ieee802.org/tsn/802-1q/

## 反馈与修改

本文只维护通用排障路径。Nginx、Kubernetes、WAF、VPN 等组件的专有问题应在对应组件页面处理，再链接回本文的网络层检查。