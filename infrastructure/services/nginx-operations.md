# Nginx 日常运维速查

Nginx 日常变更只记一个顺序：**备份 → `nginx -t` → reload → 本机验证 → 看日志。** 5xx、upstream、超时等故障见 [Nginx 故障排查速查](nginx-troubleshooting.md)。

## 1. 先跑这一组

```bash
nginx -v
nginx -t
systemctl status nginx --no-pager
ss -lntp | grep nginx
curl -I http://127.0.0.1/
tail -n 100 /var/log/nginx/error.log
```

查看完整展开配置：

```bash
nginx -T
```

`nginx -T` 会展开 include，排查“到底加载了哪个配置”非常实用；共享输出前注意脱敏域名、证书路径和内部地址。

## 2. 修改配置的标准动作

先备份实际要改的文件：

```bash
cp -a /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak-$(date +%F-%H%M%S)
```

修改后：

```bash
nginx -t
systemctl reload nginx
systemctl status nginx --no-pager
curl -I http://127.0.0.1/
tail -n 100 /var/log/nginx/error.log
```

`nginx -t` 失败就不要 reload。

常规配置变更优先 `reload`，不要把 `restart` 当默认动作。只有二进制/模块升级、进程异常或官方步骤明确要求时再 restart。

## 3. 日志和监听

```bash
ss -lntp | grep nginx
journalctl -u nginx -n 100 --no-pager
tail -n 100 /var/log/nginx/access.log
tail -n 100 /var/log/nginx/error.log
```

实际日志位置以配置为准：

```bash
nginx -T 2>&1 | grep -E 'access_log|error_log'
```

## 4. 反向代理最小配置

```nginx
server {
    listen 80;
    server_name app.example.com;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://127.0.0.1:8080;
    }
}
```

生效：

```bash
nginx -t
systemctl reload nginx
```

先直接测试后端，确认不是应用问题：

```bash
curl -v --connect-timeout 3 http://127.0.0.1:8080/
```

复杂 `location` / `proxy_pass` URI 拼接规则直接看官方文档，不在 Zwiki 重写。

## 5. upstream 最小配置

```nginx
upstream app_backend {
    server 192.0.2.11:8080;
    server 192.0.2.12:8080;
}

server {
    listen 80;

    location / {
        proxy_pass http://app_backend;
    }
}
```

逐个后端测试：

```bash
curl -v --connect-timeout 3 http://192.0.2.11:8080/
curl -v --connect-timeout 3 http://192.0.2.12:8080/
```

## 6. HTTPS 快速检查

查看证书配置：

```bash
nginx -T 2>&1 | grep -E 'ssl_certificate|ssl_certificate_key|listen .*ssl'
```

本地证书有效期：

```bash
openssl x509 -in /path/to/cert.pem -noout -subject -issuer -dates
```

在线站点证书：

```bash
openssl s_client -connect app.example.com:443 -servername app.example.com </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

本机验证 HTTPS 虚拟主机：

```bash
curl -vk --resolve app.example.com:443:127.0.0.1 https://app.example.com/
```

`-k` 仅用于排障；正式验收要再验证完整证书链。

## 7. 常见判断

| 现象 | 先检查 |
| --- | --- |
| Nginx active 但端口没监听 | `nginx -t`、`nginx -T`、`error.log` |
| 502 / 504 | 直接 `curl` 后端，再看 upstream 和超时 |
| 改配置不生效 | `nginx -T` 确认加载的实际文件 |
| HTTPS 域名不对 | SNI、证书域名、`server_name` |
| 客户端 IP 不对 | 上游代理、`X-Forwarded-For`、RealIP 信任范围 |

不要无条件信任公网客户端自己提交的 `X-Forwarded-For`。

## 官方资料

- Nginx 文档：https://nginx.org/en/docs/
- Reverse Proxy：https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/
- HTTP Load Balancing：https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/
- PROXY Protocol：https://docs.nginx.com/nginx/admin-guide/load-balancer/using-proxy-protocol/
