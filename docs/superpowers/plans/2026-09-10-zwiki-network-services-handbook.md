# Zwiki 网络与基础服务速查实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐网络快速定位、tcpdump 抓包、Nginx 日常操作和 Nginx 故障排查四个高频入口。

**Architecture:** 网络协议与流量定位放 `infrastructure/network/`；Nginx 软件部署、配置和运行维护放 `infrastructure/services/`。不把网络协议百科复制进服务文档。

**Tech Stack:** Markdown、iproute2、ss、ping、tracepath/traceroute、curl、nc、tcpdump、OpenSSL、Nginx。

**Spec:** `docs/superpowers/specs/2026-09-10-zwiki-infrastructure-ops-handbook-design.md`

## Global Constraints

- 场景优先，前置知识最小化。
- 网络排障优先系统自带命令；额外工具明确安装依赖。
- Nginx 变更必须先 `nginx -t`，再选择 reload/restart。
- 详细 TCP/IP、HTTP/TLS 原理只链接 RFC/官方文档。
- 不修改 `gitbook-docs.yaml`。

---

### Task 1: 新增网络故障快速排查

**Files:**
- Create: `infrastructure/network/network-troubleshooting.md`

- [ ] **Step 1: 固定排障路径**

```text
本机地址/链路 → 路由 → ARP/邻居 → DNS → TCP/UDP 端口 → 服务监听 → 防火墙/NAT → 抓包
```

必须覆盖 `ip -br addr`、`ip route`、`ip route get`、`ip neigh`、`ss`、`ping`、`getent hosts`、`curl -v`、`nc -zv`、`timeout + /dev/tcp`。

- [ ] **Step 2: 压缩必须知道的知识**

只解释 IP/掩码/网关、路由、ARP、DNS、TCP/UDP、NAT、VLAN 对现场判断的作用；每项控制在数句。

- [ ] **Step 3: 加典型症状矩阵**

至少覆盖：IP 不通、端口不通、DNS 正常但连接失败、SYN 发出无回应、RST、HTTP 超时、只有某一台主机不通。

- [ ] **Step 4: Commit**

```bash
git add infrastructure/network/network-troubleshooting.md
git commit -m "docs: add network troubleshooting quick reference"
```

### Task 2: 新增 tcpdump 抓包速查

**Files:**
- Create: `infrastructure/network/tcpdump-packet-analysis.md`

- [ ] **Step 1: 编写最常用过滤模板**

必须覆盖：接口、host、src/dst、port、TCP/UDP、SYN/RST、ICMP、保存 pcap、读取 pcap。

- [ ] **Step 2: 编写最小判断法**

用简短示意说明：SYN 无 SYN-ACK、SYN 后 RST、三次握手成功后应用无响应、重复重传分别意味着什么方向的问题。

- [ ] **Step 3: 明确抓包边界**

说明 HTTPS payload 默认不可直接读取；涉及认证信息时 pcap 属敏感数据，不应提交 Wiki。

- [ ] **Step 4: Commit**

```bash
git add infrastructure/network/tcpdump-packet-analysis.md
git commit -m "docs: add tcpdump packet analysis quick reference"
```

### Task 3: 新增 Nginx 日常操作速查

**Files:**
- Create: `infrastructure/services/nginx-operations.md`

- [ ] **Step 1: 编写快速入口**

覆盖：版本/编译参数、进程、配置路径、配置测试、启动状态、reload、监听端口、访问/错误日志、反向代理、upstream、HTTPS 证书检查。

必须包含：
```bash
nginx -v
nginx -V
nginx -t
systemctl status nginx
systemctl reload nginx
ss -lntp
```

- [ ] **Step 2: 最小解释配置层次**

只解释 `http`、`server`、`location`、`upstream` 的职责和匹配关系，不展开完整 directive 百科。

- [ ] **Step 3: 加安全变更顺序**

固定：备份目标配置 → `nginx -t` → reload → `systemctl status` → curl/业务验证 → 查 error.log。

- [ ] **Step 4: Commit**

```bash
git add infrastructure/services/nginx-operations.md
git commit -m "docs: add Nginx operations quick reference"
```

### Task 4: 新增 Nginx 故障排查

**Files:**
- Create: `infrastructure/services/nginx-troubleshooting.md`

- [ ] **Step 1: 编写逐层排障流程**

```text
进程 → 配置语法 → 监听端口 → 本机 curl → 上游连接 → DNS → TLS → 日志 → 系统资源
```

覆盖 403、404、499、502、503、504、TLS 证书异常、upstream timeout、connection refused。

- [ ] **Step 2: 每种状态码写成现场动作**

格式统一为：现象 → 首查命令 → 常见原因 → 下一步；避免 HTTP 状态码百科。

- [ ] **Step 3: 加官方链接**

深入资料链接 Nginx 官方 Beginner's Guide、Admin Guide/Reference 和 OpenSSL 官方资料；不复制配置指令全集。

- [ ] **Step 4: Commit**

```bash
git add infrastructure/services/nginx-troubleshooting.md
git commit -m "docs: add Nginx troubleshooting quick reference"
```

### Task 5: 更新入口和导航

**Files:**
- Modify: `infrastructure/network/README.md`
- Modify: `infrastructure/services/README.md`
- Modify: `SUMMARY.md`

- [ ] **Step 1: 添加四个速查入口**

README 只写一句定位和链接，不复制正文。

- [ ] **Step 2: 验证路径**

Run:
```bash
for f in infrastructure/network/network-troubleshooting.md infrastructure/network/tcpdump-packet-analysis.md infrastructure/services/nginx-operations.md infrastructure/services/nginx-troubleshooting.md; do test -f "$f" || exit 1; done
```

Expected: 全部存在。

- [ ] **Step 3: 验证导航**

Run:
```bash
grep -nE 'network-troubleshooting|tcpdump-packet-analysis|nginx-operations|nginx-troubleshooting' SUMMARY.md infrastructure/network/README.md infrastructure/services/README.md
```

Expected: 四个页面均可从 SUMMARY 和所属 README 定位。

- [ ] **Step 4: Commit**

```bash
git add infrastructure/network/README.md infrastructure/services/README.md SUMMARY.md
git commit -m "docs: link network and Nginx quick references"
```
