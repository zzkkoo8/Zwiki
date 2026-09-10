# Nginx 故障排查速查

用于 Nginx 403/404/499/502/503/504、TLS 证书错误、upstream 超时、连接拒绝等场景。配置变更和 reload 见 [Nginx 日常运维速查](nginx-operations.md)。

## 快速处理

固定逐层检查：

```text
进程 → 配置语法 → 监听端口 → 本机 curl → upstream → DNS → TLS → access/error log → 系统资源
```

```bash
systemctl status nginx --no-pager
nginx -t
ss -lntp | grep nginx
curl -v http://127.0.0.1/
tail -n 100 /var/log/nginx/error.log
tail -n 100 /var/log/nginx/access.log
```

如果是反向代理，再直接测 upstream：

```bash
nginx -T 2>&1 | grep -nE 'upstream|proxy_pass'
curl -v --connect-timeout 3 http://<UPSTREAM_IP>:<PORT>/
```

## 1. 先确认 Nginx 自身是否正常

```bash
systemctl status nginx --no-pager
systemctl is-active nginx
nginx -t
ps -ef | grep '[n]ginx'
ss -lntp | grep nginx
```

如果 `nginx -t` 报错，按报错文件和行号处理；不要 reload 一个语法未通过的配置。

如果服务 active 但未监听预期端口：

```bash
nginx -T 2>&1 | grep -nE 'listen|server_name'
journalctl -u nginx -n 100 --no-pager
```

## 2. 本机先绕过外部网络验证

HTTP：

```bash
curl -v -H 'Host: app.example.com' http://127.0.0.1/
```

HTTPS：

```bash
curl -vk --resolve app.example.com:443:127.0.0.1 https://app.example.com/
```

判断：

```text
本机正常、外部异常 → 查网络/WAF/LB/防火墙/DNS
本机也异常 → 继续查 Nginx 配置、upstream、应用、TLS
```

网络层统一参考 [网络故障快速排查](../network/network-troubleshooting.md)。

## 3. 403 Forbidden

### 首查

```bash
tail -n 100 /var/log/nginx/error.log
nginx -T 2>&1 | grep -nE 'root |alias |deny |allow |auth_basic|autoindex'
```

### 常见原因

- 文件/目录权限不足；
- `root` / `alias` 路径错误；
- `deny/allow`、认证、WAF/访问控制限制；
- 访问目录但没有 index 且未允许目录列表；
- SELinux 阻止 Nginx 访问文件或网络资源。

### 下一步

```bash
namei -l /path/to/file
ls -ld /path /path/to /path/to/file
getenforce 2>/dev/null
```

不要为了消除 403 直接 `chmod 777` 或关闭 SELinux；先确认具体拒绝原因。

## 4. 404 Not Found

### 首查

```bash
nginx -T
curl -v -H 'Host: app.example.com' http://127.0.0.1/<PATH>
```

### 常见原因

- 请求进入了错误 `server`；
- `location` 匹配与预期不同；
- `root/alias` 路径拼接错误；
- upstream 自己返回 404；
- `proxy_pass` URI 重写行为与预期不同。

### 下一步

先看 access.log 是否由这台 Nginx 返回，再直连 upstream 对比同一路径。

## 5. 499

499 是 Nginx 常见日志状态码，表示客户端在 Nginx 返回响应前关闭了连接。它不是标准 HTTP 状态码。

### 首查

```bash
grep ' 499 ' /var/log/nginx/access.log | tail -n 50
```

### 常见方向

- 客户端/前置 LB 超时比 Nginx/后端更短；
- upstream 处理太慢；
- 用户主动取消请求；
- 网络中断。

### 下一步

同时比较客户端/LB 超时、Nginx upstream 响应时间和应用日志。不要简单把 Nginx timeout 调大掩盖后端慢问题。

## 6. 502 Bad Gateway

### 首查

```bash
tail -n 100 /var/log/nginx/error.log
nginx -T 2>&1 | grep -nE 'upstream|proxy_pass'
ss -lntp
curl -v --connect-timeout 3 http://<UPSTREAM_IP>:<PORT>/
```

### 常见错误关键词

```text
connect() failed (111: Connection refused)
no live upstreams
upstream prematurely closed connection
host not found in upstream
```

### 常见原因

- upstream 进程未启动/端口未监听；
- upstream 地址或端口写错；
- 容器/Pod 地址变化；
- 上游主动断开或进程崩溃；
- DNS 无法解析 upstream hostname；
- SELinux/防火墙阻止 Nginx 连后端。

### 下一步

从 Nginx 主机直接 curl upstream；如果直连也失败，先修后端/网络，不要继续改 Nginx timeout。

## 7. 503 Service Unavailable

### 首查

```bash
tail -n 100 /var/log/nginx/error.log
nginx -T 2>&1 | grep -nE 'limit_req|limit_conn|upstream|return 503'
```

503 可能由 Nginx 配置主动返回、限流/限连接、上游状态或外部平台产生。先确认响应到底由谁生成。

## 8. 504 Gateway Timeout

### 首查

```bash
tail -n 100 /var/log/nginx/error.log
curl -v --max-time 10 http://<UPSTREAM_IP>:<PORT>/
```

常见 error.log：

```text
upstream timed out
```

### 常见原因

- upstream 真正处理慢；
- 数据库/外部 API 慢；
- upstream 网络异常；
- `proxy_connect_timeout` / `proxy_read_timeout` 与业务不匹配。

### 下一步

先从 Nginx 主机直连后端测实际耗时，再查后端日志和依赖。只有确认业务确实需要更长处理时间后才调整 timeout。

## 9. connection refused 与 timeout 的区别

### refused

通常很快失败，常见原因：

```text
目标端口没有监听
服务刚崩溃
目标/中间设备主动 RST
```

检查：

```bash
nc -zv -w 3 <UPSTREAM_IP> <PORT>
ss -lntp
```

### timeout

等待一段时间后失败，常见方向：

```text
防火墙 silent drop
路由/返回路径异常
upstream 卡住
连接或读取超时
```

配合 tcpdump 判断 SYN/回包：

```bash
tcpdump -ni any host <UPSTREAM_IP> and port <PORT>
```

## 10. TLS / 证书异常

查看本地配置：

```bash
nginx -T 2>&1 | grep -E 'ssl_certificate|ssl_certificate_key|listen .*ssl'
```

在线握手：

```bash
openssl s_client -connect app.example.com:443 -servername app.example.com </dev/null
```

只看证书：

```bash
openssl s_client -connect app.example.com:443 -servername app.example.com </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

常见方向：

- 证书过期；
- SNI 命中了错误虚拟主机；
- 证书链不完整；
- 域名不在 SAN；
- 私钥与证书不匹配；
- 客户端不信任签发 CA；
- TLS 版本/加密套件不兼容。

正式验证不要使用 `-k` 跳过证书检查。

## 11. upstream hostname / DNS 问题

```bash
getent hosts <UPSTREAM_DOMAIN>
cat /etc/resolv.conf
```

查看 Nginx 当前配置：

```bash
nginx -T 2>&1 | grep -n <UPSTREAM_DOMAIN>
```

Nginx 对域名解析的行为与配置位置、`resolver`、版本和动态解析方式有关。遇到地址变更/容器化服务发现时应按当前 Nginx 官方 resolver/upstream 文档确认，不要假设所有 hostname 都会自动实时刷新。

## 12. 系统资源问题

```bash
uptime
free -h
df -hT
df -ih
ss -s
systemctl status nginx --no-pager
journalctl -k -b --no-pager | grep -iE 'oom|killed process'
```

典型问题：

- 磁盘满导致日志/临时文件异常；
- inode 满；
- OOM 杀掉 worker/upstream；
- 文件描述符/连接数耗尽；
- 后端整体资源饱和。

继续参考 [Linux 性能故障快速排查](../system/linux-performance-troubleshooting.md)。

## 状态码现场速查

| 现象 | 首查 | 优先方向 |
| --- | --- | --- |
| 403 | `error.log`、权限、访问控制 | 文件权限、规则、SELinux |
| 404 | Host/location/upstream 对比 | 虚拟主机、路径、后端 |
| 499 | access.log + upstream 耗时 | 客户端/LB 超时、后端慢 |
| 502 | error.log + 直连 upstream | 后端未监听、RST、DNS |
| 503 | error.log + 配置 | 限流、主动返回、服务不可用 |
| 504 | error.log + 后端耗时 | upstream 超时、依赖慢 |
| TLS 错误 | `openssl s_client` | 证书、SNI、链、协议兼容 |

## 变更与回退

如果排障确认需要改配置：

1. 只备份和修改目标文件；
2. `nginx -t`；
3. `systemctl reload nginx`；
4. 本机/业务验证；
5. 新增错误立即恢复备份配置，再次 `nginx -t` + reload。

不要把 restart 当成 502/504 的默认解决方案。

## 深入学习

- Nginx Beginner’s Guide：https://nginx.org/en/docs/beginners_guide.html
- Nginx 官方 Reference：https://nginx.org/en/docs/
- Nginx Reverse Proxy：https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/
- Nginx Load Balancing：https://docs.nginx.com/nginx/admin-guide/load-balancer/
- OpenSSL 文档：https://docs.openssl.org/
- 网络层排障：[网络故障快速排查](../network/network-troubleshooting.md)

## 反馈与修改

发现新的典型 Nginx 现场问题时优先补到对应状态码/层级，不新增“HTTP 状态码百科”。