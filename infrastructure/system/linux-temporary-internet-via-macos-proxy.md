# 机房内网服务器临时通过 macOS 代理上网

用于机房内网服务器**不能修改 IP、默认网关和路由**，但维护期间需要临时访问互联网的场景。方案：macOS 双网卡 + Clash Verge/Mihomo 开放局域网代理，Linux 只对当前命令或当前 Shell 临时指定代理。

## 快速参考案例

- **macOS Wi-Fi**：`en0`，正常访问互联网
- **macOS 有线网卡**：`en3`，`10.7.216.246/24`
- **Clash/Mihomo**：`10.7.216.246:7897`
- **Linux 示例主机**：`10.7.216.249`
- **原则**：不改 Linux IP、默认网关、路由；不开 macOS“互联网共享”
- **实测**：2026-09-09，`cw249`—`cw253` 五台 Kylin V10 SP3 主机均可经该代理访问互联网和麒麟官方仓库

```text
互联网
  |
macOS Wi-Fi en0
  |
Clash/Mihomo :7897
  |
macOS en3 10.7.216.246/24
  |
10.7.216.0/24 内网
  |
Linux 服务器
```

## 1. macOS 开启临时代理出口

### 1.1 检查双网卡和路由

```bash
ipconfig getifaddr en0
ipconfig getifaddr en3
route -n get default
route -n get 10.7.216.249
```

应确认：

- 默认路由走 `en0`。
- `10.7.216.249` 走 `en3`。
- `en3` 地址为 `10.7.216.246/24`。

验证 Mac 能访问服务器：

```bash
ping -c 3 10.7.216.249
nc -vz -w 5 10.7.216.249 22
```

### 1.2 Clash Verge/Mihomo

开启：

1. 正常可用的代理节点。
2. `Allow LAN` / “允许局域网连接”。
3. 混合代理端口 `7897`。

检查监听：

```bash
lsof -nP -iTCP:7897 -sTCP:LISTEN
```

应看到 `*:7897` 或 `0.0.0.0:7897`，不能只监听 `127.0.0.1:7897`。

Mac 本机验证：

```bash
curl -I --proxy http://127.0.0.1:7897 https://www.baidu.com/
```

## 2. Linux 临时上网

### 2.1 先确认原网络不变

```bash
ip -br addr
ip route
```

### 2.2 检查 Linux 到 Mac 代理

```bash
ping -c 3 10.7.216.246
nc -vz -w 5 10.7.216.246 7897
```

没有 `nc` 时：

```bash
timeout 5 bash -c '</dev/tcp/10.7.216.246/7897'
echo $?
```

返回 `0` 表示端口可达。

### 2.3 推荐：单条命令指定代理

```bash
curl -I \
  --proxy http://10.7.216.246:7897 \
  --connect-timeout 10 \
  --max-time 30 \
  https://www.baidu.com/
```

这种方式最适合临时维护，不会留下系统级代理配置。

### 2.4 多条命令临时联网

只对当前 Shell 生效：

```bash
export http_proxy='http://10.7.216.246:7897'
export https_proxy="$http_proxy"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$http_proxy"
export no_proxy='localhost,127.0.0.1,10.7.216.0/24'
export NO_PROXY="$no_proxy"
```

验证：

```bash
curl -I --connect-timeout 10 --max-time 30 https://www.baidu.com/
```

## 3. DNF/YUM 临时使用代理

```bash
dnf --setopt=proxy=http://10.7.216.246:7897 repolist
dnf --setopt=proxy=http://10.7.216.246:7897 makecache
```

使用 `yum` 的系统：

```bash
yum --setopt=proxy=http://10.7.216.246:7897 repolist
yum --setopt=proxy=http://10.7.216.246:7897 makecache
```

需要查看软件包：

```bash
dnf --setopt=proxy=http://10.7.216.246:7897 info 软件包名
```

## 4. chroot 内临时联网

仅在确有需要时使用：

```bash
chroot /root/chroot_alpine /usr/bin/env \
  http_proxy=http://10.7.216.246:7897 \
  https_proxy=http://10.7.216.246:7897 \
  no_proxy=localhost,127.0.0.1,10.7.216.0/24 \
  wget -S --spider https://www.baidu.com/
```

Ansible SSH、节点 Ping 等内网流量应通过 `no_proxy` 排除，不要绕行 Mac 代理。

## 5. 维护完成后撤销

Linux 当前 Shell：

```bash
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
env | grep -iE '^(http|https|no)_proxy='
```

正常情况下第二条命令无输出。

macOS：

1. 关闭 Clash/Mihomo 的 `Allow LAN`，或退出代理程序。
2. 检查 7897 是否已停止监听：

```bash
lsof -nP -iTCP:7897 -sTCP:LISTEN
```

## 6. 故障速查

| 现象 | 优先检查 |
| --- | --- |
| Linux 连不上 `10.7.216.246:7897` | `ping 10.7.216.246`、`nc -vz 10.7.216.246 7897`、Clash `Allow LAN`、macOS 防火墙 |
| `Connection refused` | Clash 未监听、端口错误或 `Allow LAN` 未开启 |
| `Connection timed out` | Linux 到 Mac 的内网路由或 macOS 防火墙 |
| Mac 本机代理也打不开网站 | Clash 节点或代理程序本身异常 |
| `curl --proxy` 正常但 `nslookup` 失败 | 正常现象之一；HTTP/SOCKS 代理不是 DNS Server |
| 开启“互联网共享”后内网异常 | 立即关闭“互联网共享”，重新检查 `en3` 地址和路由 |
| `407 Proxy Authentication Required` | 代理启用了认证 |

必要时查看：

```bash
# macOS
route -n get 10.7.216.249
lsof -nP -iTCP:7897 -sTCP:LISTEN

# Linux
ip route get 10.7.216.246
curl -v --proxy http://10.7.216.246:7897 https://www.baidu.com/ -o /dev/null
```

## 注意事项

- 不开启 macOS“互联网共享”；它可能重配接口地址、DHCP、NAT 和路由。
- 不修改生产服务器 IP、默认网关或系统路由。
- 不把临时代理写入 `/etc/profile`、`/etc/environment`、`/root/.bashrc` 或 `/etc/dnf/dnf.conf`。
- `Allow LAN` 仅在维护窗口开启，代理端口不要暴露到公网。
- HTTP/SOCKS 代理不能替代普通 DNS Server；不要因 `curl --proxy` 正常就判断服务器 DNS 已恢复。
