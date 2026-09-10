# Kubernetes 故障排查速查

用于 Pod 异常、Service/Ingress 不通、PVC Pending、节点资源压力等常见故障。先按层级定位，不要一上来 delete/restart。

## 快速处理

固定模型：

```text
Node → Workload Controller → Pod → Container → Service → EndpointSlice → Ingress → Application
```

先执行：

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl top nodes 2>/dev/null
kubectl top pods -A 2>/dev/null
```

针对异常 Pod：

```bash
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --all-containers --tail=200
kubectl logs <pod> -n <namespace> -c <container> --previous
```

## 1. Node

```bash
kubectl get nodes
kubectl describe node <node>
kubectl get pods -A -o wide --field-selector spec.nodeName=<node>
```

重点看 Conditions：

```text
Ready
MemoryPressure
DiskPressure
PIDPressure
NetworkUnavailable
```

节点异常还需要登录宿主机检查 kubelet/container runtime、磁盘、内存、网络和系统日志。K3s 环境见 [K3s 日常运维速查](../k3s/k3s-operations.md)。

## 2. Pending

```bash
kubectl describe pod <pod> -n <namespace>
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

优先看 Events，常见方向：

- CPU/内存不足；
- nodeSelector/affinity/taint 不匹配；
- PVC 未绑定；
- 调度器约束；
- 节点不可调度。

不要通过随意降低 requests 或删除约束来“让 Pod 跑起来”，先确认约束为什么存在。

## 3. CrashLoopBackOff

```bash
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> -c <container> --previous
kubectl get pod <pod> -n <namespace> -o jsonpath='{.status.containerStatuses[*].lastState}'
```

常见方向：

```text
应用启动报错
环境变量/配置缺失
依赖服务不可用
启动/存活探针失败
OOM/资源限制
程序正常退出但 restartPolicy 触发重启
```

先看上一次容器日志，避免 Pod 重启后只看到新进程的空日志。

## 4. ErrImagePull / ImagePullBackOff

```bash
kubectl describe pod <pod> -n <namespace>
```

重点看 Events：

- image/tag 不存在；
- registry DNS/网络不可达；
- imagePullSecret 错误；
- TLS/CA/私仓配置问题；
- 拉取限流。

K3s 私仓还需检查 `/etc/rancher/k3s/registries.yaml`，见 K3s 速查。

## 5. OOMKilled

```bash
kubectl describe pod <pod> -n <namespace>
kubectl get pod <pod> -n <namespace> -o jsonpath='{range .status.containerStatuses[*]}{.name}{" reason="}{.lastState.terminated.reason}{" exit="}{.lastState.terminated.exitCode}{"\n"}{end}'
kubectl top pod <pod> -n <namespace> --containers 2>/dev/null
```

继续检查资源设置：

```bash
kubectl get pod <pod> -n <namespace> -o jsonpath='{range .spec.containers[*]}{.name}{" requests="}{.resources.requests}{" limits="}{.resources.limits}{"\n"}{end}'
```

区分：容器超过 memory limit，还是节点整体发生内存压力/OOM。不要只把 limit 调大而不查应用内存增长。

## 6. Evicted

```bash
kubectl describe pod <pod> -n <namespace>
kubectl describe node <node>
```

常见 Node Pressure：

```text
memory.available
disk / image filesystem space
inode
PID
```

Kubelet 在节点资源压力下可能主动驱逐 Pod。先处理节点资源根因；不要只删除 Evicted Pod 记录。

## 7. Readiness / Liveness / Startup Probe 失败

```bash
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> -c <container> --tail=200
kubectl get pod <pod> -n <namespace> -o yaml
```

判断：

- readiness 失败：Pod 通常不会进入 Service 可用后端；
- liveness 失败：可能触发容器重启；
- startup probe：用于保护启动较慢应用，避免过早执行 liveness/readiness。

先验证应用本身是否在探针指定的端口/path 正常，不要为了消除报警直接关探针。

## 8. Terminating 长时间卡住

```bash
kubectl describe pod <pod> -n <namespace>
kubectl get pod <pod> -n <namespace> -o yaml
```

检查：

- `terminationGracePeriodSeconds`；
- preStop hook；
- finalizers；
- 节点是否失联；
- 挂载卸载问题。

强制删除会绕过正常终止流程，可能造成仍在运行的进程、数据写入或状态不一致，不作为默认处置。

## 9. Service 不通

```bash
kubectl get svc <service> -n <namespace> -o wide
kubectl describe svc <service> -n <namespace>
kubectl get endpointslice -n <namespace> -l kubernetes.io/service-name=<service>
```

如果 EndpointSlice 是空的：

```bash
kubectl get svc <service> -n <namespace> -o jsonpath='{.spec.selector}'
kubectl get pods -n <namespace> --show-labels
```

重点检查 selector 与 Pod labels、Pod Readiness、targetPort。

如果 EndpointSlice 有地址，再从集群内部测试 Service 与 Pod IP，区分 Service 路由和应用本身。

## 10. DNS

查看 CoreDNS：

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get svc -n kube-system kube-dns
```

从已有业务 Pod 内：

```bash
kubectl exec -it <pod> -n <namespace> -- cat /etc/resolv.conf
kubectl exec -it <pod> -n <namespace> -- getent hosts <service>.<namespace>.svc.cluster.local
```

精简镜像可能没有 `getent/nslookup`，必要时使用集群允许的临时诊断 Pod，但要遵守环境安全策略。

## 11. Ingress 404 / 502

```bash
kubectl get ingress -A
kubectl describe ingress <ingress> -n <namespace>
kubectl get svc <service> -n <namespace>
kubectl get endpointslice -n <namespace> -l kubernetes.io/service-name=<service>
```

排查顺序：

```text
Host/Path → IngressClass/Controller → Service → EndpointSlice → Pod readiness/应用端口
```

404 常见于 Host/path/IngressClass 没匹配；502 常见于 controller 找得到规则但后端 Service/Pod 不可用。最终仍以具体 Ingress Controller 日志为准。

## 12. PVC Pending / Mount 失败

```bash
kubectl get pvc,pv -A
kubectl describe pvc <pvc> -n <namespace>
kubectl get storageclass
kubectl describe pod <pod> -n <namespace>
```

重点看：

- StorageClass 是否存在/默认；
- provisioner 是否正常；
- accessModes/capacity 是否匹配；
- PV nodeAffinity；
- CSI/本地存储插件日志；
- 主机目录/设备权限和挂载错误。

删除 PVC/PV 可能触发底层存储删除，必须先确认 `persistentVolumeReclaimPolicy` 和业务数据备份。

## 13. 节点维护：cordon / drain / uncordon

### 先评估

```bash
kubectl get node <node>
kubectl get pods -A -o wide --field-selector spec.nodeName=<node>
kubectl get pdb -A
```

禁止新 Pod 调度：

```bash
kubectl cordon <node>
```

`cordon` 不会主动赶走现有 Pod。

### drain 是有影响的变更

执行前确认：

```text
业务副本足够
PDB 允许驱逐
StatefulSet/本地存储风险已确认
DaemonSet 行为已确认
替代节点有足够容量
```

然后根据当前集群实际工作负载选择 drain 参数。不要从文档复制固定 `--ignore-daemonsets --delete-emptydir-data --force` 组合无条件执行；这些参数会改变保护边界。

先看帮助：

```bash
kubectl drain --help
```

维护完成：

```bash
kubectl uncordon <node>
```

## 常见状态速查

| 状态/现象 | 首查 | 常见方向 |
| --- | --- | --- |
| Pending | `describe pod` Events | 资源、调度、PVC |
| CrashLoopBackOff | `logs --previous` | 应用、配置、探针、OOM |
| ImagePullBackOff | Pod Events | registry、凭据、网络、tag |
| OOMKilled | container status/resources | memory limit / Node OOM |
| Evicted | Pod + Node describe | memory/disk/inode/PID pressure |
| Service 无后端 | EndpointSlice | selector、labels、readiness |
| Ingress 404 | Ingress describe | Host/path/class |
| Ingress 502 | Service/EndpointSlice/Pod | 后端不可用/端口错误 |
| PVC Pending | PVC Events | StorageClass/provisioner/capacity |

## 深入学习

- Kubernetes 应用排障：https://kubernetes.io/docs/tasks/debug/debug-application/
- Pod Lifecycle：https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
- Node-pressure Eviction：https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/
- Debug Services：https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
- EndpointSlice：https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- kubectl drain：https://kubernetes.io/docs/reference/kubectl/generated/kubectl_drain/

## 反馈与修改

本文保持逐层排障。具体 CNI、CSI、Ingress Controller 的实现细节形成稳定场景后再独立收录，不在通用页展开。