# K3s 日常运维速查

用于 K3s Server/Agent 状态、日志、节点加入、containerd 镜像、私有仓库和内置组件的日常检查。Pod、Service、Ingress 等 Kubernetes 通用操作见 [kubectl 日常运维速查](../kubernetes/kubectl-operations.md) 和 [Kubernetes 故障排查速查](../kubernetes/kubernetes-troubleshooting.md)。

## 快速检查

Server 节点：

```bash
k3s --version
systemctl status k3s --no-pager
journalctl -u k3s -n 200 --no-pager
k3s kubectl get nodes -o wide
k3s kubectl get pods -A -o wide
k3s crictl ps -a
k3s ctr -n k8s.io containers list
```

Agent 节点：

```bash
systemctl status k3s-agent --no-pager
journalctl -u k3s-agent -n 200 --no-pager
k3s crictl ps -a
k3s ctr -n k8s.io containers list
```

## 必须知道

- **Server**：运行 Kubernetes Server/控制面相关组件；K3s Server 默认也可调度业务 Pod。
- **Agent**：主要运行 kubelet、container runtime 和业务工作负载，不运行控制面。
- **Kubernetes 通用问题与 K3s 特有问题分开查**：Pod/Service/Ingress 机制属于 Kubernetes；systemd 服务、内置 containerd、`registries.yaml`、K3s Token 等属于 K3s。
- **containerd namespace**：Kubernetes 工作负载通常位于 `k8s.io` namespace；直接使用 `ctr` 时要注意 namespace，否则可能出现“明明有镜像/容器但 ctr 看不到”。

## 1. 常用路径

默认安装常见路径：

```text
/etc/rancher/k3s/config.yaml
    K3s 主配置文件

/etc/rancher/k3s/config.yaml.d/*.yaml
    配置 drop-in，按文件名顺序加载

/etc/rancher/k3s/k3s.yaml
    Server 默认 kubeconfig

/etc/rancher/k3s/registries.yaml
    containerd 私有仓库/镜像源配置

/var/lib/rancher/k3s/
    默认 K3s data-dir

/var/lib/rancher/k3s/agent/images/
    离线/预导入镜像目录

/var/lib/rancher/k3s/server/token
    Server Token；备份恢复关键敏感文件

/var/lib/rancher/k3s/server/node-token
    节点加入使用的 Token；敏感文件
```

如果安装时指定了 `--data-dir`、`--config` 或环境变量，实际路径可能不同。先检查 systemd 和运行参数：

```bash
systemctl cat k3s 2>/dev/null
systemctl cat k3s-agent 2>/dev/null
ps -ef | grep '[k]3s'
```

## 2. 查看最终配置来源

```bash
ls -lah /etc/rancher/k3s/
```

查看主配置时注意 Token、Registry 凭据等敏感值：

```bash
sed -n '1,240p' /etc/rancher/k3s/config.yaml
```

如果存在 drop-in：

```bash
find /etc/rancher/k3s/config.yaml.d -maxdepth 1 -type f -name '*.yaml' -print 2>/dev/null | sort
```

K3s 默认会读取 `config.yaml` 和 `config.yaml.d/*.yaml`。同一个 key 在多个文件出现时可能被后加载文件覆盖，因此排查配置不生效不能只看一个文件。

## 3. Server 服务异常

```bash
systemctl status k3s --no-pager
journalctl -u k3s -n 200 --no-pager
journalctl -u k3s --since '-30 min' --no-pager
```

再看 Kubernetes 层：

```bash
k3s kubectl get nodes -o wide
k3s kubectl get pods -A -o wide
k3s kubectl get events -A --sort-by=.lastTimestamp
```

常见方向：

```text
配置参数错误
证书/Token 问题
data-dir 磁盘满或文件系统异常
datastore 不可用
containerd 异常
网络/CNI 问题
系统资源不足
```

宿主机资源继续参考 [Linux 性能故障快速排查](../../infrastructure/system/linux-performance-troubleshooting.md)。

## 4. Agent 无法加入 / NotReady

Agent：

```bash
systemctl status k3s-agent --no-pager
journalctl -u k3s-agent -n 200 --no-pager
```

检查到 Server 6443/TCP：

```bash
timeout 3 bash -c '</dev/tcp/<SERVER_IP>/6443'
echo $?
```

返回 `0` 仅表示 TCP 建连成功。

Server 侧：

```bash
k3s kubectl get nodes -o wide
k3s kubectl describe node <node>
```

优先检查：

```text
Server 地址是否正确
6443 是否可达
Token 是否来自正确集群
节点 hostname 是否唯一
系统时间是否异常
证书错误
节点网络/CNI
Agent 数据盘空间
```

Token 属敏感凭据，不要把 `/var/lib/rancher/k3s/server/node-token` 内容贴入 Wiki、聊天截图或日志报告。

## 5. K3s 自带 kubectl / crictl / ctr

Kubernetes：

```bash
k3s kubectl get nodes
k3s kubectl get pods -A
```

CRI 容器：

```bash
k3s crictl ps
k3s crictl ps -a
k3s crictl images
```

containerd：

```bash
k3s ctr namespaces list
k3s ctr containers list
k3s ctr -n k8s.io containers list
k3s ctr -n k8s.io images list
```

`k3s ctr containers list` 使用当前/default containerd namespace；Kubernetes 管理的工作负载和镜像通常应使用：

```bash
k3s ctr -n k8s.io ...
```

日常排查 Kubernetes Pod 状态优先 `kubectl` / `crictl`，`ctr` 更偏底层 containerd 诊断。

## 6. K3s 常见内置组件

默认安装中常见：

```text
Traefik                 Ingress Controller
ServiceLB               K3s 内置 Service type=LoadBalancer 实现
Local Path Provisioner  本地路径 StorageClass
CoreDNS                 集群 DNS
Metrics Server          资源指标（默认安装通常包含）
containerd              默认容器运行时
```

这些组件都可能通过安装参数被禁用或替换，先看实际集群：

```bash
k3s kubectl get pods -n kube-system -o wide
k3s kubectl get svc -n kube-system
k3s kubectl get storageclass
k3s kubectl get helmchart -n kube-system 2>/dev/null
```

不要因为文档说“默认有 Traefik”就假定现场一定启用。

## 7. containerd 镜像

查看：

```bash
k3s crictl images
k3s ctr -n k8s.io images list
```

查看 Pod 实际调度节点：

```bash
k3s kubectl get pod <pod> -n <namespace> -o wide
```

镜像问题必须在 **Pod 所在节点** 检查该节点 containerd，而不是只在 Server 上看。

## 8. 离线镜像导入

K3s 支持把镜像 tarball 放入：

```text
/var/lib/rancher/k3s/agent/images/
```

例如：

```bash
mkdir -p /var/lib/rancher/k3s/agent/images
cp /path/to/images.tar /var/lib/rancher/k3s/agent/images/
```

确认导入结果：

```bash
k3s ctr -n k8s.io images list
```

较新的 K3s 版本支持运行期间触发预导入；旧版本可能只在启动时处理镜像目录，因此自动化前应按当前 K3s 版本查看官方 Import Images 的版本条件。

也可直接使用 containerd 导入：

```bash
k3s ctr -n k8s.io image import /path/to/images.tar
```

`k8s.io` namespace 很重要，否则 kubelet 可能看不到导入的镜像。

## 9. 私有仓库 / 镜像源

默认配置：

```text
/etc/rancher/k3s/registries.yaml
```

只读检查：

```bash
ls -l /etc/rancher/k3s/registries.yaml
sed -n '1,240p' /etc/rancher/k3s/registries.yaml
```

注意该文件可能含用户名、密码、证书路径，不要把原文提交到公开仓库。

K3s 启动时读取该文件并生成 containerd 配置。使用镜像源或私仓的每个需要拉取镜像的节点都应有对应配置。

镜像拉取失败时，除 Pod Event 外继续看 **Pod 所在节点** 的 containerd 日志：

```bash
tail -n 200 /var/lib/rancher/k3s/agent/containerd/containerd.log
```

修改 `registries.yaml` 后，通常需要让该节点的 K3s 服务重新读取配置并重新生成 containerd 配置。**重启 `k3s` / `k3s-agent` 会影响该节点控制面或工作负载管理，应先确认集群冗余和业务影响。**

Server：

```bash
systemctl restart k3s
```

Agent：

```bash
systemctl restart k3s-agent
```

随后验证：

```bash
systemctl status k3s --no-pager 2>/dev/null || systemctl status k3s-agent --no-pager
k3s crictl images
```

## 10. Pod 异常不要直接重启 K3s

如果只是一个 Pod 异常，优先：

```bash
k3s kubectl describe pod <pod> -n <namespace>
k3s kubectl logs <pod> -n <namespace> --all-containers --tail=200
k3s kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

只有确认问题位于 K3s 服务/containerd/kubelet 节点层，且了解业务影响后，才考虑重启 K3s 服务。

标准 Kubernetes 排障见 [Kubernetes 故障排查速查](../kubernetes/kubernetes-troubleshooting.md)。

## 11. 磁盘空间不足

```bash
df -hT
df -ih
du -xhd1 /var/lib/rancher/k3s 2>/dev/null | sort -h
k3s crictl images
```

节点 `DiskPressure` / Pod `Evicted` 时：

```bash
k3s kubectl describe node <node>
k3s kubectl get pods -A -o wide --field-selector spec.nodeName=<node>
```

不要直接删除 `/var/lib/rancher/k3s`、containerd 数据目录或未知镜像文件。先识别是镜像、日志、快照、Local Path 数据还是业务 PVC。

## 12. 证书/Token

查看证书相关命令帮助：

```bash
k3s certificate --help
k3s token --help
```

证书和 Token 都属于集群敏感数据；任何轮换、替换前先完成 datastore + server token 备份，并参考当前 K3s 官方证书/Token 文档。

节点 Token / Server Token 不在速查页展示内容值。

## 13. 不要把卸载当修复手段

K3s 安装脚本可能提供：

```text
k3s-uninstall.sh
k3s-agent-uninstall.sh
```

它们是卸载工具，不是服务异常的默认修复命令。卸载可能删除 K3s 本地状态和组件，执行前必须使用对应版本官方文档核对数据影响并完成备份。

## 深入学习

- K3s Quick Start：https://docs.k3s.io/quick-start
- K3s Configuration：https://docs.k3s.io/installation/configuration
- K3s Private Registry：https://docs.k3s.io/installation/private-registry
- K3s Import Images：https://docs.k3s.io/add-ons/import-images
- K3s Air-Gap Install：https://docs.k3s.io/installation/airgap
- K3s Server CLI：https://docs.k3s.io/cli/server
- K3s Agent CLI：https://docs.k3s.io/cli/agent
- Kubernetes 通用排障：[Kubernetes 故障排查速查](../kubernetes/kubernetes-troubleshooting.md)

## 反馈与修改

本文只维护 K3s 发行版特有操作。Pod、Deployment、Service、Ingress、PVC 等通用 Kubernetes 内容只在 Kubernetes 页面维护。