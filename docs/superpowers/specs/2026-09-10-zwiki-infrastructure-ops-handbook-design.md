# Zwiki 技术应用场景速查手册整理设计

## 1. 目标

将 Zwiki 明确建设为“技术应用场景速查手册”，服务日常运维、部署、故障排查和现场处置，不建设百科式知识库。

核心要求：

- 保留现有文章，不删除已有有效内容。
- 尽量保持已有文件路径和 GitBook URL 稳定。
- 优先补充现有文章，确有独立场景再新增页面。
- 文章以“遇到什么问题 → 看什么 → 执行什么 → 如何判断 → 下一步做什么”为主线。
- 前置理论只保留完成当前操作所必需的最小知识。
- 全量原理、架构、协议和规范优先链接官方文档、RFC、Linux Kernel Documentation 或项目权威资料，不在 Zwiki 重复维护。

## 2. 信息架构原则

保留当前一级分类：

- `infrastructure/`：硬件、系统、网络、基础服务。
- `cloud-native/`：Docker、Kubernetes、K3s 等容器与云原生运维。
- `development/`、`ai/`、`projects/`、`wiki-ops/`：保持现有职责，不因本次任务做无关调整。

本次不为了知识体系完整而提前创建大量目录。具体主题原则上直接放在现有二级目录；同一主题形成 3 篇以上稳定文章时，再评估建立子目录。

不修改 `gitbook-docs.yaml`。仅在实际新增导航项时更新 `SUMMARY.md` 和必要的分类入口 `README.md`。

## 3. 页面定位

每篇运维文章只解决一个明确场景或一组高度相关场景。

推荐结构：

1. **什么时候用**：一句话说明使用场景。
2. **快速处理**：优先给最短、最常用的检查和处置步骤。
3. **必须知道**：只解释执行当前任务必须掌握的概念。
4. **常用命令**：可直接复制，默认优先只读、安全命令。
5. **标准排查流程**：按现场实际顺序逐层定位。
6. **常见问题**：现象 → 判断 → 原因 → 处理。
7. **风险与回退**：只有涉及变更、删除、重启、升级等风险时必须出现。
8. **深入学习**：链接官方或权威资料。

不要求所有文章机械包含全部章节；以快速解决问题为准。

## 4. 内容范围

### 4.1 Linux / 系统

保留现有：

- `linux-ops-bootstrap.md`
- `linux-lvm-disk-expansion.md`
- `linux-temporary-internet-via-macos-proxy.md`
- `ubuntu22-kernel-security-hardening.md`
- `macos-lid-close-restart.md`

优先补齐的场景：

- Linux CPU、内存、Load、OOM、磁盘 IO、进程高占用的快速定位。
- systemd 服务状态、启动失败、journal 日志和内核日志排查。
- 文件系统、inode、mount、磁盘空间与 LVM 日常检查。
- 软件包在线/离线安装、依赖、版本匹配和校验。
- SSH、用户权限、SELinux、防火墙等高频安全运维。
- 长任务防断线、tmux/script 日志保留等现场操作。

基础知识仅保留：进程、PID、文件描述符、inode、mount、Load Average、OOM、systemd 等理解命令输出必须知道的概念。

### 4.2 网络

优先补齐：

- IP、掩码、网关、路由、ARP、DNS、TCP/UDP 的最小必备知识。
- `ip`、`ss`、`ping`、`traceroute/tracepath`、`curl`、`nc`、`timeout + /dev/tcp` 等常用排查。
- “本机 → 路由 → 目标端口 → 服务监听 → 防火墙 → 应用”的标准排障流程。
- tcpdump 常用抓包过滤及 SYN、RST、重传、超时的快速判断。
- VLAN、NAT、代理、VPN、WAF 等只保留排障所需概念，详细协议链接权威资料。

### 4.3 基础服务

优先补齐：

- Nginx：配置检查、reload、反向代理、upstream、HTTPS、日志、502/504、连接异常。
- DNS/NTP：客户端和常见服务端检查、时间同步异常。
- NFS/rsync：挂载、同步、权限与常见故障。
- TLS/证书：证书有效期、链、SNI、私钥匹配和替换前验证。

Prometheus/Grafana、HAProxy、Keepalived 等只有实际形成稳定场景内容后再新增，不为目录完整而预建空页。

### 4.4 Docker

优先形成“日常操作 + 故障排查”两个入口，覆盖：

- 镜像、容器、日志、资源、端口、网络、Volume/Bind Mount、Compose。
- `ps`、`logs`、`inspect`、`stats`、`exec`、`system df` 等高频命令。
- 容器启动失败、异常退出、端口不通、DNS 异常、磁盘爆满、镜像/数据清理。
- 所有 prune/remove 类命令必须明确影响范围，不提供无提示的高风险清理流程。

### 4.5 Kubernetes / K3s

Kubernetes 通用内容优先补齐：

- Pod、Deployment、StatefulSet、DaemonSet、Service、Ingress、ConfigMap、Secret、PV/PVC 等“看懂现场”所需最小概念。
- kubectl 高频操作、日志、exec、describe、events、资源使用和 YAML 查看。
- Node → Pod → Container → Service → Ingress → 应用的逐层排障。
- Helm 的 list/status/get values/history/upgrade/rollback/template。
- K9s 的资源切换、日志、Shell、describe、namespace/context、端口转发、只读巡检、退出和翻页。

K3s 只维护发行版特有场景：

- systemd 服务、Server/Agent、containerd、Traefik、Local Path、registries、Token、证书、离线镜像。
- etcd snapshot、备份、恢复、升级和断电后的集群恢复。
- 保留现有 `product-runtime-k3s-deployment.md` 作为产品部署专题，不将其重写成通用 Kubernetes 手册。

## 5. 写作约束

- 优先原生命令和官方 CLI；第三方工具必须说明是否需要安装。
- 一条命令尽量只做一件事，避免难审计的一行长命令。
- 默认先检查、后变更、再验证。
- 高风险动作必须单独标记影响范围和回退方式。
- 不复制官方长篇说明，不维护容易过时的完整参数百科。
- 版本差异只写会直接影响执行结果的部分。
- 示例 IP、域名、路径使用明显占位值，避免混入真实敏感信息。
- 同一知识只维护一个权威 Zwiki 页面，其他页面使用相对链接引用。

## 6. 目录与导航策略

不进行大规模迁移或重命名。

预期新增页面控制在少量高价值速查页，例如：

```text
infrastructure/system/
├── linux-performance-troubleshooting.md
├── linux-systemd-log-operations.md
└── linux-offline-package-management.md

infrastructure/network/
├── network-troubleshooting.md
└── tcpdump-packet-analysis.md

infrastructure/services/
├── nginx-operations.md
└── nginx-troubleshooting.md

cloud-native/docker/
├── docker-operations.md
└── docker-troubleshooting.md

cloud-native/kubernetes/
├── kubectl-operations.md
├── kubernetes-troubleshooting.md
├── helm-operations.md
└── k9s-operations.md

cloud-native/k3s/
├── k3s-operations.md
└── k3s-backup-recovery.md
```

实际写入前必须再次检查是否能并入现有文章；若现有文章足以承载，则不新增。

## 7. 官方资料原则

“深入学习”优先使用以下来源类型：

1. 项目官方文档与官方 GitHub 仓库。
2. Linux Kernel Documentation、发行版官方文档。
3. IETF RFC。
4. CNCF / Kubernetes / Docker / K3s / Helm / Nginx 等项目官方资料。
5. Red Hat、Ubuntu、SUSE 等发行版权威运维文档。

社区博客只在官方资料无法覆盖实际场景时作为补充，不作为关键事实的唯一来源。

## 8. 验收标准

完成本轮整理后应满足：

- 现有有效文章全部保留，非必要不改路径。
- GitBook 左侧目录仍然简洁，不出现为理论完整性而创建的大量页面。
- Linux、网络、Nginx、Docker、Kubernetes/K3s 至少具备可直接处理日常场景的入口。
- 每个新增页面都能回答“什么时候用、先执行什么、怎么看结果、异常下一步查什么”。
- 必备理论明显少于实操内容；深入原理有官方/权威链接。
- 高风险命令有风险说明和回退策略。
- `SUMMARY.md` 所有链接存在，无孤立新增页面。
- Markdown 内部相对链接有效，无重复主题、重复标题和敏感信息。
- `gitbook-docs.yaml` 未因普通内容整理而修改。

## 9. 实施顺序

1. Linux / 系统基础运维速查。
2. 网络快速排障与抓包。
3. Nginx 等基础服务。
4. Docker。
5. Kubernetes / kubectl / Helm / K9s。
6. K3s 日常运维、备份恢复。
7. 更新分类入口和 `SUMMARY.md`。
8. 全仓链接、重复内容、孤立页面和危险命令审核。

每阶段优先补现有页面，再决定是否新建页面。