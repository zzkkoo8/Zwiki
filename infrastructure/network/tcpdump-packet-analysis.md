# tcpdump 抓包与快速判断

用于确认“包有没有从本机发出、目标有没有收到、对端有没有回包、谁发了 RST、哪里开始重传”。先完成 [网络故障快速排查](network-troubleshooting.md) 的基础检查，再用抓包缩小范围。

## 快速处理

列出接口：

```bash
tcpdump -D
ip -br addr
```

所有接口观察某目标：

```bash
tcpdump -ni any host <TARGET_IP>
```

指定接口和端口：

```bash
tcpdump -ni <IFACE> host <TARGET_IP> and port <PORT>
```

只看 TCP：

```bash
tcpdump -ni any tcp and host <TARGET_IP>
```

只看 UDP：

```bash
tcpdump -ni any udp and host <TARGET_IP>
```

保存 pcap：

```bash
tcpdump -ni any host <TARGET_IP> -w /tmp/capture.pcap
```

读取：

```bash
tcpdump -nn -r /tmp/capture.pcap
```

`-n/-nn` 可避免抓包时额外做 DNS/端口名解析，排障时通常更清晰。

## 必须知道

抓 TCP 问题时先看握手：

```text
客户端                  服务端
SYN        ----------->
           <----------- SYN,ACK
ACK        ----------->
```

现场最重要的是回答四个问题：

```text
1. 请求包有没有发出？
2. 服务端有没有收到？
3. 服务端有没有回？
4. 回包有没有到客户端？
```

在客户端和服务端同时抓同一条连接，通常比只在一侧猜测快得多。

## 1. 常用过滤模板

### 按主机

```bash
tcpdump -ni any host 192.0.2.10
```

源地址：

```bash
tcpdump -ni any src host 192.0.2.10
```

目的地址：

```bash
tcpdump -ni any dst host 192.0.2.10
```

### 按端口

```bash
tcpdump -ni any port 443
```

只看目的端口：

```bash
tcpdump -ni any dst port 443
```

### TCP / UDP

```bash
tcpdump -ni any tcp port 443
tcpdump -ni any udp port 53
```

### 多条件组合

```bash
tcpdump -ni any host 192.0.2.10 and tcp port 443
```

```bash
tcpdump -ni any '(host 192.0.2.10 or host 192.0.2.11)' and port 443
```

## 2. 只看 SYN / RST

SYN：

```bash
tcpdump -ni any 'tcp[tcpflags] & tcp-syn != 0'
```

RST：

```bash
tcpdump -ni any 'tcp[tcpflags] & tcp-rst != 0'
```

只看目标端口的 SYN/RST：

```bash
tcpdump -ni any 'tcp port <PORT> and (tcp[tcpflags] & (tcp-syn|tcp-rst) != 0)'
```

## 3. ICMP

```bash
tcpdump -ni any icmp
```

ICMP 不只是 ping。网络设备可能通过 ICMP 返回不可达、TTL 超时、分片相关错误，因此端口异常时也值得观察。

## 4. DNS

```bash
tcpdump -ni any udp port 53
```

同时包含 TCP DNS：

```bash
tcpdump -ni any port 53
```

判断请求是否发给了预期 DNS、是否有响应、响应来自哪个地址。

## 5. 保存给 Wireshark 分析

推荐限制范围和文件大小，不要无限抓：

```bash
tcpdump -ni <IFACE> host <TARGET_IP> and port <PORT> -c 5000 -w /tmp/issue.pcap
```

按大小轮转示例：

```bash
tcpdump -ni <IFACE> host <TARGET_IP> -C 100 -W 5 -w /tmp/issue.pcap
```

含义：每个文件约 100 MB，最多保留 5 个轮转文件。生产环境抓包前应确认磁盘空间。

## 6. 四种最常见判断

### SYN 发出，没有 SYN-ACK

```text
客户端：SYN → SYN → SYN 重传
服务端：完全看不到 SYN
```

优先方向：

- 中间网络/安全设备丢弃；
- 路由错误；
- 返回路径不对；
- 抓错接口/地址。

如果服务端能看到 SYN 但没有回包，转查服务端监听、防火墙和内核策略。

### SYN 后立即 RST

```text
SYN →
    ← RST,ACK
```

通常表示某一方明确拒绝连接。先确认 **RST 的源地址**，再查该主机是否监听目标端口或中间设备是否主动拒绝。

### 三次握手成功，但应用没有响应

```text
SYN → SYN,ACK → ACK 正常
随后请求发出但长时间无业务响应
```

TCP 通路已基本建立，重点转向应用、反向代理、数据库/上游处理和应用超时。

### 重复重传

出现同一序列号重复发送、Duplicate ACK 等现象时，可能是丢包、拥塞、路径 MTU、接口错误或目标处理异常。需要结合两端抓包判断包究竟在哪一段消失，不能只看到“Retransmission”就认定某台设备故障。

## 7. HTTP 明文快速观察

HTTP（非 TLS）可适当提高 payload 输出：

```bash
tcpdump -ni any -A tcp port 80 and host <TARGET_IP>
```

只在明确需要时使用，因为应用内容可能包含 Cookie、Token、账号等敏感信息。

## 8. HTTPS 为什么看不到正文

HTTPS/TLS 加密后，tcpdump 通常只能看到：

- TCP 握手；
- TLS 握手元数据的一部分；
- 包大小、时序、重传、RST/FIN；
- 未加密或可见的协议元数据（具体取决于 TLS 版本和配置）。

默认不能直接看到 HTTP 请求/响应正文。不要因为 payload 看不懂就判断网络异常。

TLS 问题可结合：

```bash
openssl s_client -connect <HOST>:443 -servername <DOMAIN>
```

## 9. 抓包安全边界

pcap 可能包含：

- 内网 IP 和网络拓扑；
- HTTP Cookie、Basic Auth、Token；
- 明文账号、业务数据；
- DNS 查询、内部域名；
- 部分 TLS 元数据。

因此：

```text
不要把生产 pcap 直接提交到 Zwiki / GitHub。
不要在无范围限制的情况下长期抓包。
共享前先确认是否包含敏感数据。
```

## 10. 常见命令组合

### 客户端访问某服务

```bash
tcpdump -ni any host <SERVER_IP> and tcp port <PORT>
```

### 服务端看客户端有没有到

```bash
tcpdump -ni any src host <CLIENT_IP> and dst port <PORT>
```

### 看谁发 RST

```bash
tcpdump -ni any 'host <PEER_IP> and tcp port <PORT> and tcp[tcpflags] & tcp-rst != 0'
```

### 只抓 1000 个包后退出

```bash
tcpdump -ni any host <TARGET_IP> -c 1000
```

## 深入学习

- tcpdump 官方项目：https://github.com/the-tcpdump-group/tcpdump
- pcap-filter 过滤语法：https://www.tcpdump.org/manpages/pcap-filter.7.html
- TCP 标准 RFC 9293：https://www.rfc-editor.org/rfc/rfc9293
- Wireshark 用户指南：https://www.wireshark.org/docs/wsug_html_chunked/

## 反馈与修改

本文只记录高频过滤和现场判断。复杂 TCP 性能、拥塞控制、TLS 解密等专题优先引用官方资料，不在速查页展开成协议教程。