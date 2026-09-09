# 机房内网服务器临时通过 macOS 代理上网

当机房内网服务器不能修改 IP、默认网关或现有路由，但维护期间需要临时访问互联网下载软件包、刷新仓库元数据时，可让同网段 macOS 作为应用层代理出口。本文使用 Clash Verge/Mihomo 提供 HTTP/SOCKS 混合代理，Linux 服务器只对当前命令或当前 Shell 临时指定代理，不改变原有网络拓扑。

## 文档信息

- **技术领域**：Linux / macOS / 临时代理
- **适用范围**：隔离网、机房维护、临时软件安装与仓库访问
- **已验证环境**：macOS + Clash Verge/Mihomo；Kylin Linux Advanced Server V10 SP3
- **文档状态**：已验证
- **最后验证**：2026-09-09
- **来源**：现场实测记录

## 适用场景

典型场景：

- Linux 服务器位于内网，不能直接访问互联网。
- 服务器 IP、默认网关和路由不能修改，避免维护过程中失联。
- 维护人员的 Mac 同时连接 Wi-Fi 互联网和服务器内网。
- 只需要让 `curl`、`dnf/yum`、`wget` 等应用临时联网。

本文示例网络：

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
Linux 服务器 10.7.216.249
```

示例参数：

- macOS Wi-Fi：`en0`，负责互联网出口。
- macOS 有线网卡：`en3`，地址 `10.7.216.246/24`。
- Clash/Mihomo 混合代理：`10.7.216.246:7897`。
- Linux 服务器：`10.7.216.249`。
- Linux 默认网关保持原配置，不修改。

> 现场地址变化时，只替换本文示例 IP、网卡名和代理端口，不要照抄服务器网络参数。

## 核心原则

1. macOS 使用 Wi-Fi 正常上网，有线网卡只连接服务器内网。
2. **不要开启 macOS“互联网共享”**。
3. **不要修改服务器 IP、默认网关或系统路由**。
4. 优先对单条命令指定代理，其次才在当前 Shell 临时设置代理变量。
5. 维护结束后关闭 Clash 的 `Allow LAN`，并清除 Shell 代理变量。
6. HTTP/SOCKS 代理不是 DNS Server，普通 `nslookup`、UDP/TCP 53 查询不会自动经过 HTTP 代理。

## 1. macOS 侧准备

### 1.1 确认双网卡

查看硬件端口：

```bash
networksetup -listallhardwareports
```

查看地址：

```bash
ipconfig getifaddr en0
ipconfig getifaddr en3
```

示例预期：

```text
en0: Wi-Fi 地址，以现场实际值为准
en3: 10.7.216.246
```

### 1.2 确认路由没有被改变

确认默认路由仍走 Wi-Fi：

```bash
route -n get default
```

预期关键字段：

```text
interface: en0
```

确认访问服务器走有线网卡：

```bash
route -n get 10.7.216.249
```

预期关键字段：

```text
interface: en3
```

查看完整 IPv4 路由：

```bash
netstat -rn -f inet
```

如果 `10.7.216.0/24` 已经是 `en3` 的直连路由，不需要再添加静态路由。

### 1.3 验证 Mac 能访问服务器

```bash
ping -c 3 10.7.216.249
nc -vz -w 5 10.7.216.249 22
```

至少应确认 Mac 到服务器内网地址和 SSH 端口可达。

## 2. Clash Verge/Mihomo 配置

在 macOS 上：

1. 启动 Clash Verge/Mihomo。
2. 选择可正常访问互联网的代理节点。
3. 开启 `Allow LAN` / “允许局域网连接”。
4. 设置或确认混合代理端口，例如 `7897`。
5. 确保代理监听地址不是仅绑定 `127.0.0.1`。

检查监听：

```bash
lsof -nP -iTCP:7897 -sTCP:LISTEN
```

可接受：

```text
*:7897
0.0.0.0:7897
```

如果只看到：

```text
127.0.0.1:7897
```

则内网服务器无法连接该代理，需要检查 `Allow LAN` 和监听地址。

先在 Mac 本机验证代理：

```bash
curl -I \
  --proxy http://127.0.0.1:7897 \
  --connect-timeout 10 \
  https://www.baidu.com/
```

能返回正常 HTTP 响应头后，再测试 Linux 服务器。

## 3. Linux 服务器临时使用代理

### 3.1 先确认原网络配置

```bash
hostname
ip -br addr
ip route
```

确认服务器原 IP 和默认网关保持不变。

本文方案不要求修改这些配置。

### 3.2 检查服务器到 Mac

```bash
ping -c 3 10.7.216.246
```

检查代理端口：

```bash
timeout 5 bash -c '</dev/tcp/10.7.216.246/7897'
echo $?
```

返回 `0` 表示 TCP 端口可连接。

系统有 `nc` 时也可以：

```bash
nc -vz -w 5 10.7.216.246 7897
```

### 3.3 推荐：单条命令使用代理

这是最安全的方式，不会留下全局代理配置。

```bash
curl -I \
  --proxy http://10.7.216.246:7897 \
  --connect-timeout 10 \
  --max-time 30 \
  https://www.baidu.com/
```

需要查看详细连接过程：

```bash
curl -v \
  --proxy http://10.7.216.246:7897 \
  --connect-timeout 10 \
  --max-time 30 \
  https://www.baidu.com/ \
  -o /dev/null
```

### 3.4 当前 Shell 临时设置代理

需要连续执行多条联网命令时：

```bash
export http_proxy='http://10.7.216.246:7897'
export https_proxy='http://10.7.216.246:7897'
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export no_proxy='localhost,127.0.0.1,10.7.216.0/24'
export NO_PROXY="$no_proxy"
```

检查：

```bash
env | grep -iE '^(http|https|no)_proxy='
```

验证：

```bash
curl -I --connect-timeout 10 --max-time 30 https://www.baidu.com/
```

不要把临时代理写入：

```text
/etc/profile
/etc/environment
/root/.bashrc
/etc/dnf/dnf.conf
```

## 4. DNF/YUM 临时联网

只读查看仓库：

```bash
dnf --setopt=proxy=http://10.7.216.246:7897 repolist
```

查看软件包：

```bash
dnf --setopt=proxy=http://10.7.216.246:7897 info 软件包名
```

刷新元数据：

```bash
dnf --setopt=proxy=http://10.7.216.246:7897 makecache
```

使用 `yum` 的系统：

```bash
yum --setopt=proxy=http://10.7.216.246:7897 repolist
yum --setopt=proxy=http://10.7.216.246:7897 makecache
```

软件安装、系统升级和仓库变更仍应按正常变更流程执行；代理连通只说明网络具备访问条件。

## 5. chroot 中临时使用代理

需要让 chroot 内某一条命令联网时，显式传入环境变量，不修改 chroot 的永久配置：

```bash
chroot /root/chroot_alpine /usr/bin/env \
  http_proxy=http://10.7.216.246:7897 \
  https_proxy=http://10.7.216.246:7897 \
  HTTP_PROXY=http://10.7.216.246:7897 \
  HTTPS_PROXY=http://10.7.216.246:7897 \
  no_proxy=localhost,127.0.0.1,10.7.216.0/24 \
  wget -S --spider https://www.baidu.com/
```

执行前确认 chroot 内存在需要的命令：

```bash
chroot /root/chroot_alpine test -x /usr/bin/env
chroot /root/chroot_alpine command -v wget
```

Ansible SSH、节点 Ping 和其它内网访问应加入 `no_proxy`，不要绕行 Mac 代理。

## 6. DNS 限制

HTTP/SOCKS 应用代理和 DNS Server 是两类服务。

下面这类普通 DNS 请求不会因为配置了 HTTP 代理就自动经过 Clash：

```bash
nslookup www.baidu.com 223.5.5.5
```

因此要区分两种情况：

- `curl --proxy`、DNF/YUM 通过 HTTP 代理访问域名时，目标域名可以由代理端解析。
- 不支持 HTTP/SOCKS 代理、但自身必须解析域名的程序，仍需要一个服务器可达的 DNS Server。

不要因为 `curl --proxy` 能访问网站，就判断服务器普通 DNS 已经恢复。

如果后续必须解决普通 DNS，应另行选择经过审批的内网 DNS、DNS 转发服务，或由网络侧放通指定 DNS 的 UDP/TCP 53。

## 7. 验收清单

按顺序检查：

```text
□ Mac 默认路由走 Wi-Fi
□ Mac 到服务器内网地址走有线网卡
□ Mac 能 Ping/SSH 服务器
□ Clash/Mihomo 已开启 Allow LAN
□ 代理监听 *:7897 或 0.0.0.0:7897
□ Mac 本机通过 127.0.0.1:7897 能访问互联网
□ Linux 能 Ping Mac 内网地址
□ Linux 能连接 Mac 的 7897/TCP
□ Linux 使用 curl --proxy 能获得正常 HTTP 响应
□ DNF/YUM 使用命令级代理能够读取目标仓库
□ 服务器 IP、默认网关和路由未被修改
```

2026-09-09 现场实测中，`cw249` 至 `cw253` 五台 Kylin V10 SP3 主机均可通过 `10.7.216.246:7897` 访问互联网和麒麟官方仓库，测试期间未修改服务器 IP 或默认网关。

## 8. 维护结束后撤销

### 8.1 Linux 清除当前 Shell 代理

```bash
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset no_proxy
unset NO_PROXY
```

验证：

```bash
env | grep -iE '^(http|https|no)_proxy='
```

正常应无输出。

使用 `curl --proxy` 或 `dnf/yum --setopt=proxy=...` 的单条命令本身不会留下持久代理配置。

### 8.2 macOS 停止代理出口

维护结束后执行以下任一操作：

- 关闭 Clash/Mihomo 的 `Allow LAN`。
- 停止代理内核。
- 完全退出 Clash Verge/Mihomo。

检查局域网监听是否已经关闭：

```bash
lsof -nP -iTCP:7897 -sTCP:LISTEN
```

无输出表示 TCP 7897 已不再监听。

## 9. 常见故障

### Linux 无法连接 Mac 的代理端口

Mac 检查：

```bash
ipconfig getifaddr en3
route -n get 10.7.216.249
lsof -nP -iTCP:7897 -sTCP:LISTEN
```

Linux 检查：

```bash
ip route get 10.7.216.246
ping -c 3 10.7.216.246
timeout 5 bash -c '</dev/tcp/10.7.216.246/7897'
echo $?
```

重点确认：

- Mac 有线网卡地址是否正确。
- Clash 是否开启 `Allow LAN`。
- 7897 是否监听所有接口。
- macOS 防火墙是否允许 Clash/Mihomo 入站连接。

### 能连接代理端口但打不开网站

Mac 先验证：

```bash
curl -I --proxy http://127.0.0.1:7897 https://www.baidu.com/
```

Linux 再验证：

```bash
curl -v \
  --proxy http://10.7.216.246:7897 \
  --connect-timeout 10 \
  --max-time 30 \
  https://www.baidu.com/ \
  -o /dev/null
```

常见现象：

- `Connection refused`：代理未监听、端口错误或 `Allow LAN` 未开启。
- `Connection timed out`：内网路由或 macOS 防火墙问题。
- `407 Proxy Authentication Required`：代理启用了认证。
- TLS/证书错误：检查系统时间、证书链和代理 HTTPS 处理方式，不要用 `-k` 长期掩盖问题。

### 开启 macOS“互联网共享”后内网异常

立即关闭“互联网共享”，再检查：

```bash
ipconfig getifaddr en3
route -n get 10.7.216.249
netstat -rn -f inet
```

macOS“互联网共享”可能重配共享接口地址、DHCP、NAT 和路由。对于服务器 IP、默认网关不可修改的维护场景，应使用 Clash/Mihomo 应用层代理，而不是系统互联网共享。

## 安全注意事项

- `Allow LAN` 开启后，同网段其它主机也可能尝试连接代理端口，只在维护窗口开启。
- 不把代理端口暴露到公网。
- 不为临时上网修改生产服务器 IP、默认网关或系统路由。
- 不把代理永久写入系统环境变量、DNF/YUM 配置或仓库文件。
- 不随意把不可达公网 DNS 写入 `/etc/resolv.conf`。
- 维护结束后关闭局域网代理监听并清理 Shell 变量。
