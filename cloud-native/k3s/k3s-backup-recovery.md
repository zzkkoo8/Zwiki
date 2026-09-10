# K3s 备份与恢复速查

用于 K3s datastore 备份、embedded etcd 快照、灾难恢复前检查和升级前保护。**恢复是高风险操作；先确认 datastore 类型，再按对应流程处理，不能混用。**

## 快速结论

K3s 的备份方式取决于 datastore：

```text
Embedded etcd   → k3s etcd-snapshot
SQLite          → 备份 K3s server/db 数据目录
External DB     → 使用外部数据库自己的备份/恢复机制
```

无论哪种 datastore，Server 都必须单独安全保存：

```text
/var/lib/rancher/k3s/server/token
```

该 Token 用于保护 datastore 中的敏感 bootstrap 数据。恢复时若没有使用原 Token，备份可能无法正常恢复。

## 1. 恢复前必须确认

```bash
k3s --version
systemctl status k3s --no-pager
systemctl cat k3s
ps -ef | grep '[k]3s server'
```

查看配置来源：

```bash
ls -lah /etc/rancher/k3s/
find /etc/rancher/k3s/config.yaml.d -maxdepth 1 -type f -name '*.yaml' -print 2>/dev/null | sort
```

恢复前记录：

```text
□ K3s 版本
□ Server 数量和角色
□ datastore 类型：embedded etcd / SQLite / external DB
□ data-dir 是否为默认值
□ 当前 config.yaml / drop-in
□ server token 已安全备份
□ snapshot/数据库备份存在且有完整性校验
□ registries.yaml / 自定义 CA / 证书配置已备份
□ 数据目录磁盘空间充足
□ 业务已进入允许停机/恢复的窗口
□ 多 Server 集群的恢复顺序已按当前官方文档确认
```

配置和 Token 可能包含敏感信息，备份文件不要提交到 Zwiki/GitHub。

## 2. 判断 datastore 类型

优先检查 K3s 当前启动参数和配置：

```bash
systemctl cat k3s
ps -ef | grep '[k]3s server'
```

以及：

```bash
grep -RniE 'cluster-init|datastore-endpoint|server:' /etc/rancher/k3s/config.yaml /etc/rancher/k3s/config.yaml.d 2>/dev/null
```

常见情况：

- 单 Server、未配置 external datastore/embedded etcd 时，常见为 SQLite；
- `cluster-init` 或 HA embedded etcd 环境使用 embedded etcd；
- 配置 `datastore-endpoint` 时通常使用外部数据库。

不要只根据目录里“看到了某个文件”猜 datastore；最终以运行配置和部署设计为准。

## 3. Embedded etcd：查看快照

```bash
k3s etcd-snapshot list
```

也可以：

```bash
k3s etcd-snapshot ls
```

该命令会显示当前节点可见快照及位置。K3s 的 `data-dir` 默认是 `/var/lib/rancher/k3s`，快照目录可通过 `--etcd-snapshot-dir` 改写，因此**不要在自动化里硬编码路径，优先看 `etcd-snapshot list` 和实际配置。**

官方当前示例中的默认本地快照通常位于：

```text
/var/lib/rancher/k3s/server/db/snapshots/
```

## 4. Embedded etcd：手工创建快照

先确认集群状态：

```bash
k3s kubectl get nodes -o wide
k3s kubectl get pods -A -o wide
k3s etcd-snapshot list
```

创建按需快照：

```bash
k3s etcd-snapshot save
```

自定义名称：

```bash
k3s etcd-snapshot save --name pre-change-$(date +%F-%H%M%S)
```

再次确认：

```bash
k3s etcd-snapshot list
```

按需快照不会自动遵循与计划快照完全相同的生命周期假设；生产环境应明确异地备份和保留策略，而不是只依赖节点本地文件。

## 5. 快照异地复制与校验

先从 `k3s etcd-snapshot list` 获取实际文件位置，再复制指定快照。

示例：

```bash
sha256sum /path/to/snapshot > /path/to/snapshot.sha256
```

复制到受控备份位置后再次校验：

```bash
sha256sum -c snapshot.sha256
```

同时备份 Server Token 文件，但不要在屏幕/日志中输出内容：

```bash
install -m 600 /var/lib/rancher/k3s/server/token /secure-backup/k3s-server-token
```

`/secure-backup` 必须是受控备份介质或挂载点；不要把 Token 与公开文档、普通共享目录放在一起。

快照本身也属于敏感数据，包含完整 etcd 状态以及集群 CA/私钥等敏感材料，应使用严格访问控制和加密存储。

## 6. S3 兼容对象存储

K3s 支持将 etcd snapshot 保存到 S3 兼容对象存储。生产环境优先将凭据放入受控 Secret/凭据管理系统，不把 access key/secret key 硬编码到 Wiki 示例或 Shell 历史。

查看当前可用参数：

```bash
k3s etcd-snapshot --help
k3s server --help | grep -A20 -B2 etcd-s3
```

使用对象存储时仍需要独立保护 Server Token；S3 上只有 snapshot 并不等于恢复材料完整。

## 7. SQLite 备份

K3s 官方对 SQLite 的备份核心是复制 Server 数据库目录，并保存 Server Token。

先确认确实使用 SQLite，再进入维护窗口。为了获得一致性备份，不要在高写入期间直接复制仍在变化的数据库文件；按当前 K3s 官方 Backup and Restore 指南执行受控停机/一致性备份。

默认数据库目录位于：

```text
/var/lib/rancher/k3s/server/db/
```

如果自定义了 `data-dir`，路径随之变化。

需要备份的至少包括：

```text
K3s server/db 对应数据
Server Token
K3s 配置文件/drop-in
registries.yaml / 自定义 CA 等恢复所需配置
```

## 8. External datastore

如果使用 MySQL、PostgreSQL 或外部 etcd：

```text
K3s 不负责替你完成外部数据库的一致性备份。
```

应使用数据库自身官方备份/快照流程，同时保存：

```text
Server Token
K3s 配置
外部数据库连接参数的安全备份
数据库备份/快照
```

恢复时数据库版本、schema、网络和权限也必须与 K3s 兼容。

## 9. Embedded etcd 恢复：高风险操作

**以下操作会停止 K3s 并重置 embedded etcd 集群成员关系，只能在已经确认 snapshot、Token、节点拓扑和停机窗口后执行。**

### 单 Server / 恢复入口

停止：

```bash
systemctl stop k3s
```

恢复指定 snapshot：

```bash
k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=<PATH-TO-SNAPSHOT>
```

成功日志应提示 cluster membership 已 reset，可以不带 `--cluster-reset` 正常重启。

然后：

```bash
systemctl start k3s
```

验证：

```bash
systemctl status k3s --no-pager
k3s kubectl get nodes -o wide
k3s kubectl get pods -A -o wide
k3s kubectl get events -A --sort-by=.lastTimestamp
```

### 重要警告

不要单独执行：

```text
k3s server --cluster-reset
```

而省略恢复路径，除非你的目标就是按官方定义把 etcd membership 重置为单成员；这不是普通“修复集群”的命令。

## 10. 多 Server embedded etcd 恢复

多 Server 恢复比单节点更危险。官方流程会：

1. 停止所有 Server；
2. 选择一个 Server 从 snapshot 恢复并重置 membership；
3. 先启动恢复后的 Server；
4. 其他 etcd Server 需要处理旧的本地数据库状态后重新加入。

官方当前文档在 peer Server 上包含删除旧 `server/db` 数据的步骤。该动作具有破坏性，**本文不提供可直接复制的 `rm -rf` 命令**。

执行前必须：

```text
□ 为每台 peer Server 的当前 db 目录另做备份
□ 确认恢复 Server 已正常启动
□ 确认 snapshot 与原 Server Token 匹配
□ 对照当前 K3s 版本官方 Multiple Servers 恢复步骤
□ 一台一台重新加入并验证，不并行清理所有节点
```

具体 peer 数据目录处理步骤直接使用当前官方 `k3s etcd-snapshot` Restore 文档，不从旧运维笔记复制。

## 11. 恢复到新主机

恢复到新主机时必须使用原集群 Server Token。

不要把 Token 明文写进长期脚本或 Wiki。恢复工具支持 `--token` 等方式时，应从受控凭据来源注入。

同时注意：snapshot 中包含旧 Node 资源。新主机拓扑与原集群不同的情况下，恢复后还需要核对并清理已经不存在的旧节点对象。

## 12. 恢复后验收

至少检查：

```bash
systemctl status k3s --no-pager
k3s kubectl get nodes -o wide
k3s kubectl get pods -A -o wide
k3s kubectl get events -A --sort-by=.lastTimestamp
k3s kubectl get pvc,pv -A
k3s kubectl get svc,ingress -A
```

进一步确认：

```text
控制面可用
所有预期节点 Ready
kube-system 核心 Pod 正常
业务 Pod Ready
Service/Ingress 正常
PVC/PV 数据正常
私仓拉取正常
业务实际探测通过
```

恢复完成不代表外部数据库、NFS、对象存储等外部依赖自动恢复。

## 13. 升级前保护

升级前先确认：

```bash
k3s --version
k3s kubectl get nodes -o wide
k3s kubectl get pods -A -o wide
```

embedded etcd：

```bash
k3s etcd-snapshot save --name pre-upgrade-$(date +%F-%H%M%S)
k3s etcd-snapshot list
```

同时确认 Server Token 已在安全备份中，并记录当前：

```text
K3s 版本
安装方式
配置文件
registries.yaml
节点角色
关键业务状态
```

升级步骤、版本跳跃规则和 Traefik 等随版本变化的组件兼容性，以当前 K3s Upgrade 官方文档为准，不在本文维护版本矩阵。

## 14. 快照删除 / prune

先列出：

```bash
k3s etcd-snapshot list
```

K3s 支持：

```text
k3s etcd-snapshot delete
k3s etcd-snapshot prune
```

这会删除备份材料。**不要把 prune 当磁盘空间不足的第一步**；先确认：

```text
哪些快照已有异地副本
需要保留哪些恢复点
当前 retention 策略
最近一次可验证快照
```

再按 `k3s etcd-snapshot --help` 和当前官方文档选择具体删除/保留参数。

## 深入学习

- K3s Backup and Restore：https://docs.k3s.io/datastore/backup-restore
- K3s etcd-snapshot：https://docs.k3s.io/cli/etcd-snapshot
- K3s Datastore：https://docs.k3s.io/datastore
- K3s Upgrades：https://docs.k3s.io/upgrades
- K3s Configuration：https://docs.k3s.io/installation/configuration
- K3s 日常运维：[K3s 日常运维速查](k3s-operations.md)

## 反馈与修改

本文只维护恢复决策和安全操作入口。具体版本、多 Server 拓扑、S3 参数和 external database 恢复细节以当前 K3s/数据库官方文档为准。