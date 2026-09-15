# K3s 日常运维速查

K3s 排障先区分两层：**Pod / Service / Ingress 属 Kubernetes；`k3s`/`k3s-agent`、内置 containerd、Token、`registries.yaml` 属 K3s。** Kubernetes 通用操作见 [kubectl 日常运维速查](../kubernetes/kubectl-operations.md)。

## 1. Server 先跑这一组

```bash
k3s --version
systemctl status k3s --no-pager
journalctl -u k3s -n 200 --no-pager
k3s kubectl get nodes -o wide
k3s kubectl get pods -A -o wide
k3s crictl ps -a
```

Agent：

```bash
systemctl status k3s-agent --no-pager
journalctl -u k3s-agent -n 200 --no-pager
k3s crictl ps -a
```

## 2. 常用路径

```text
/etc/rancher/k3s/config.yaml           主配置
/etc/rancher/k3s/config.yaml.d/        配置 drop-in
/etc/rancher/k3s/k3s.yaml              kubeconfig
/etc/rancher/k3s/registries.yaml       私有仓库 / 镜像源
/var/lib/rancher/k3s/                  默认 data-dir
/var/lib/rancher/k3s/agent/images/     离线镜像目录
/var/lib/rancher/k3s/server/token      敏感：Server Token
```

实际路径可能被启动参数覆盖，先查：

```bash
systemctl cat k3s 2>/dev/null
systemctl cat k3s-agent 2>/dev/null
ps -ef | grep '[k]3s'
```

Token、Registry 密码等不要贴到 Wiki、聊天或截图。

## 3. 节点 NotReady / Agent 加不进来

Agent：

```bash
systemctl status k3s-agent --no-pager
journalctl -u k3s-agent -n 200 --no-pager
```

测试 Server 6443：

```bash
timeout 3 bash -c '</dev/tcp/<SERVER_IP>/6443'
echo $?
```

Server：

```bash
k3s kubectl get nodes -o wide
k3s kubectl describe node <node>
```

优先检查：

```text
Server 地址
6443 网络
Token
hostname 是否重复
系统时间
磁盘空间
证书报错
CNI / 节点网络
```

## 4. kubectl / crictl / ctr 怎么选

Kubernetes 资源：

```bash
k3s kubectl get pods -A
```

CRI 容器和镜像：

```bash
k3s crictl ps -a
k3s crictl images
```

containerd 底层：

```bash
k3s ctr -n k8s.io containers list
k3s ctr -n k8s.io images list
```

日常优先顺序：

```text
kubectl → crictl → ctr
```

Kubernetes 工作负载通常在 containerd 的 `k8s.io` namespace；直接用 `ctr` 时不要漏掉 `-n k8s.io`。

## 5. Pod 异常先别重启 K3s

```bash
k3s kubectl describe pod <pod> -n <namespace>
k3s kubectl logs <pod> -n <namespace> --all-containers --tail=200
k3s kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

只有证据指向 K3s 服务、containerd、kubelet 或节点层时，再考虑服务重启。

## 6. 镜像 / 离线导入

查看：

```bash
k3s crictl images
k3s ctr -n k8s.io images list
```

直接导入：

```bash
k3s ctr -n k8s.io image import /path/to/images.tar
```

也可把镜像 tar 放到：

```text
/var/lib/rancher/k3s/agent/images/
```

不同 K3s 版本对运行期间预导入支持不同，批量自动化前查看当前版本官方 Import Images 文档。

镜像问题一定要去 **Pod 实际所在节点** 检查，不要只在 Server 看镜像列表。

## 7. 私有仓库 / 镜像源

默认文件：

```text
/etc/rancher/k3s/registries.yaml
```

检查：

```bash
ls -l /etc/rancher/k3s/registries.yaml
sed -n '1,200p' /etc/rancher/k3s/registries.yaml
```

文件可能包含凭据，共享前必须脱敏。

镜像拉取失败时，在 Pod 所在节点看：

```bash
k3s kubectl describe pod <pod> -n <namespace>
tail -n 200 /var/lib/rancher/k3s/agent/containerd/containerd.log
```

修改 `registries.yaml` 后通常需要让对应节点的 K3s 服务重新读取配置。重启会影响该节点，先确认业务和集群冗余。

Server：

```bash
systemctl restart k3s
```

Agent：

```bash
systemctl restart k3s-agent
```

## 8. 磁盘不足 / Evicted

```bash
df -hT
df -ih
du -xhd1 /var/lib/rancher/k3s 2>/dev/null | sort -h
k3s crictl images
k3s kubectl describe node <node>
```

不要直接删除 `/var/lib/rancher/k3s`、containerd 数据目录或未知镜像文件。先确认占用来自镜像、日志、Local Path、PVC、快照还是其他业务数据。

宿主机继续看 [Linux 性能故障快速排查](../../infrastructure/system/linux-performance-troubleshooting.md)。

## 9. 重启 K3s 前

```bash
systemctl status k3s --no-pager 2>/dev/null || systemctl status k3s-agent --no-pager
journalctl -u k3s -n 100 --no-pager 2>/dev/null || journalctl -u k3s-agent -n 100 --no-pager
```

确认：

```text
这是节点/K3s 层问题，不只是单个 Pod
业务能否承受该节点短暂不可用
Server 是否有高可用冗余
本地持久化工作负载是否受影响
```

卸载脚本 `k3s-uninstall.sh` / `k3s-agent-uninstall.sh` 不是故障修复命令。

## 最短排障路径

```text
systemctl / journalctl
        ↓
get nodes / get pods
        ↓
Pod 问题走 kubectl
        ↓
节点问题走 crictl / containerd
        ↓
再检查配置、镜像、磁盘、Token、证书
```

## 官方资料

- K3s Quick Start：https://docs.k3s.io/quick-start
- Configuration：https://docs.k3s.io/installation/configuration
- Private Registry：https://docs.k3s.io/installation/private-registry
- Import Images：https://docs.k3s.io/add-ons/import-images
- Air-Gap Install：https://docs.k3s.io/installation/airgap
- 备份恢复：[K3s 备份与恢复速查](k3s-backup-recovery.md)
