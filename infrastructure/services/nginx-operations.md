# Nginx 日常运维速查

用于 Nginx 配置检查、平滑重载、反向代理、upstream、HTTPS、日志和监听状态的日常操作。故障状态码和逐层定位见 [Nginx 故障排查速查](nginx-troubleshooting.md)。

## 快速处理

```bash
nginx -v
nginx -V
nginx -t
systemctl status nginx --no-pager
ss -lntp
ps -ef | grep '[n]ginx'
```

配置变更固定顺序：

```text
确认目标配置 → 备份 → nginx -t → reload → status → curl/业务验证 → error.log
```

```bash
cp -a /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak-$(date +%F-%H%M%S)
nginx -t
systemctl reload nginx
systemctl status nginx --no-pager
curl -I http://127.0.0.1/
tail -n 100 /var/log/nginx/error.log
```

如果改的是其他 include 文件，应备份实际修改文件，而不是机械只备份 `nginx.conf`。

## 必须知道

- **`http`**：HTTP 全局配置上下文，可定义日志、upstream、通用代理策略等。
- **`server`**：一个虚拟主机，通常由 `listen` 和 `server_name` 决定接收哪些请求。
- **`location`**：在 server 内根据 URI 等规则选择具体处理逻辑。
- **`upstream`**：定义一组后端服务，供 `proxy_pass` 等指令引用。
- **reload**：主进程校验并加载新配置，旧 worker 通常会处理完现有连接后退出；比 restart 更适合作为常规配置变更生效方式。

## 1. 版本、编译参数和配置路径

```bash
nginx -v
nginx -V
```

`nginx -V` 可看到编译参数、模块以及常见配置路径。

查看完整展开后的配置：

```bash
nginx -T
```

`nginx -T` 会把 include 的配置一起输出，排查“到底加载了哪个文件”非常有用。输出中可能包含内部域名、证书路径等信息，共享前注意脱敏。

## 2. 配置语法检查

任何 reload/restart 前先：

```bash
nginx -t
```

成功通常包含：

```text
syntax is ok
test is successful
```

如果失败，不要 reload，按报错文件和行号修正。

指定配置文件时：

```bash
nginx -t -c /path/to/nginx.conf
```

## 3. 进程和服务状态

```bash
systemctl status nginx --no-pager
systemctl is-active nginx
ps -ef | grep '[n]ginx'
```

常见模型：一个 master + 多个 worker。进程模型细节不在本文展开；现场只需要确认 master/worker 是否存在以及是否反复退出。

日志：

```bash
journalctl -u nginx -n 100 --no-pager
```

## 4. 平滑 reload

优先：

```bash
nginx -t
systemctl reload nginx
```

然后：

```bash
systemctl status nginx --no-pager
journalctl -u nginx --since '-5 min' --no-pager
```

如果不是 systemd 管理，可使用：

```bash
nginx -s reload
```

不要在不清楚服务管理方式时同时混用多个启动方式，否则容易出现 PID、权限或重复实例问题。

## 5. 监听端口

```bash
ss -lntp | grep nginx
```

确认监听地址：

```text
127.0.0.1:PORT   仅本机
0.0.0.0:PORT     所有 IPv4 地址
[::]:PORT        IPv6/可能兼容 IPv4
指定IP:PORT      只监听该地址
```

如果 Nginx active 但目标端口未监听，先查配置和 error.log。

## 6. access.log / error.log

默认常见路径：

```bash
tail -n 100 /var/log/nginx/access.log
tail -n 100 /var/log/nginx/error.log
```

以实际配置为准：

```bash
nginx -T 2>&1 | grep -E 'access_log|error_log'
```

实时观察：

```bash
tail -f /var/log/nginx/error.log
```

排障时先看 error.log，再结合 access.log 的状态码、upstream 地址和响应时间字段；如果当前日志格式没有这些字段，不要为了排障临时大改生产日志格式。

## 7. 反向代理最小示例

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

变更后：

```bash
nginx -t
systemctl reload nginx
```

注意 `proxy_pass` 是否带 URI 会影响转发路径拼接规则，复杂场景直接参考 Nginx 官方 Reverse Proxy 文档，不在本文列全规则。

## 8. upstream 最小示例

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

查看配置实际加载：

```bash
nginx -T 2>&1 | grep -nE 'upstream|proxy_pass|server '
```

测试每个后端不要只测 Nginx：

```bash
curl -v --connect-timeout 3 http://192.0.2.11:8080/
curl -v --connect-timeout 3 http://192.0.2.12:8080/
```

## 9. 检查真实客户端 IP

反向代理/WAF/负载均衡链路中，先确认实际来源和信任边界。常见请求头：

```text
X-Forwarded-For
X-Real-IP
```

不要无条件信任公网客户端直接提交的 `X-Forwarded-For`。如果使用 Nginx RealIP 或 PROXY protocol，应只信任明确的上游代理地址，并参考官方配置。

查看是否配置 RealIP / PROXY protocol：

```bash
nginx -T 2>&1 | grep -E 'real_ip|set_real_ip_from|proxy_protocol'
```

## 10. HTTPS 证书快速检查

查看配置：

```bash
nginx -T 2>&1 | grep -E 'ssl_certificate|ssl_certificate_key|listen .*ssl'
```

查看证书有效期：

```bash
openssl x509 -in /path/to/cert.pem -noout -subject -issuer -dates
```

检查在线站点证书和 SNI：

```bash
openssl s_client -connect app.example.com:443 -servername app.example.com </dev/null
```

只看服务证书：

```bash
openssl s_client -connect app.example.com:443 -servername app.example.com </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

证书替换前先确认私钥和证书匹配、证书链完整；替换后执行 `nginx -t`、reload 和在线验证。

## 11. 本机验证虚拟主机

HTTP 指定 Host：

```bash
curl -v -H 'Host: app.example.com' http://127.0.0.1/
```

HTTPS 指定域名解析到本机：

```bash
curl -vk --resolve app.example.com:443:127.0.0.1 https://app.example.com/
```

`-k` 仅用于排障；正式验收还应在不加 `-k` 的情况下验证证书信任链。

## 12. restart 什么时候用

常规配置变更优先 reload。只有以下情况才考虑 restart：

- reload 不支持或失败且原因已确认；
- 二进制/动态模块升级要求重启；
- 进程状态异常，官方恢复步骤要求重启。

执行前确认是否有冗余实例/负载均衡承接流量：

```bash
nginx -t
systemctl restart nginx
systemctl status nginx --no-pager
```

`restart` 可能造成连接中断，不应作为“配置生效”的默认命令。

## 深入学习

- Nginx Beginner’s Guide：https://nginx.org/en/docs/beginners_guide.html
- Nginx 官方指令参考：https://nginx.org/en/docs/
- Nginx Reverse Proxy：https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/
- Nginx HTTP Load Balancing：https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/
- Nginx PROXY Protocol：https://docs.nginx.com/nginx/admin-guide/load-balancer/using-proxy-protocol/
- OpenSSL 文档：https://docs.openssl.org/

## 反馈与修改

本文只维护高频操作。HTTP/TLS 完整原理、location 全部匹配规则和所有 directive 参数以官方文档为准。