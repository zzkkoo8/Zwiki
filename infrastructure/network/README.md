# 网络

记录网络协议、设备配置、流量路径和故障排查文章，定位为现场速查而不是协议百科。

## 常用速查

- [网络故障快速排查](network-troubleshooting.md)：从网卡/IP、路由、ARP、DNS、端口、服务监听到防火墙/抓包逐层定位。
- [tcpdump 抓包与快速判断](tcpdump-packet-analysis.md)：常用过滤、SYN/RST、双端抓包和重传判断。

## 收录范围

- TCP/IP、ARP、ICMP、路由和 NAT
- 交换机、VLAN、链路聚合和冗余
- DNS、HTTP、TLS 等协议与网络行为
- 反向代理、负载均衡、网关和 WAF 的流量路径与网络问题
- VPN、隧道和远程接入
- tcpdump、Wireshark、连接跟踪和性能分析
- 网络中断、丢包、时延和会话异常

## 边界

- 协议原理、链路、路由交换、流量分析和网络故障归“网络”。
- DNS/NTP/Nginx/HAProxy/Keepalived 等软件的部署、配置和服务运维归“基础服务”。
- 完整协议规范优先引用 IETF RFC、IEEE 或项目官方文档，不在 Zwiki 重复维护。

## 文章归类

先将文章直接存放在本目录；同类内容达到三篇以上时，再按 `protocol/`、`switching-routing/`、`proxy-gateway/` 或 `troubleshooting/` 拆分。

新增文章优先使用[通用技术文章模板](../../templates/technical-article.md)或[故障排查模板](../../templates/troubleshooting.md)。