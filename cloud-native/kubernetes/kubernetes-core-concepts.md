# Kubernetes / K3s 核心组件关系速查

用于现场看到 `Pod`、`Deployment`、`DaemonSet`、`Service` 等术语时，快速判断“它是什么、谁管理谁、故障该看哪一层”。

先记住一句话：

> **程序运行在 Container 里；Container 放在 Pod 里；Pod 通常由 Deployment / DaemonSet / StatefulSet 管；Service 找到一组 Pod；Ingress 把外部 HTTP/HTTPS 流量转给 Service；Node 就是运行这些 Pod 的服务器。**

只想查命令时看 [kubectl 日常运维速查](kubectl-operations.md)；出现业务异常时看 [Kubernetes 故障排查速查](kubernetes-troubleshooting.md)。

## 1. 一张图先看懂关系

```text
                        Kubernetes / K3s Cluster
                                  │
                 ┌────────────────┴────────────────┐
                 │                                 │
           Control Plane                         Node
          管理和调度集群                     一台实际服务器
                 │                                 │
                 │                           kubelet / 容器运行时
                 │                                 │
        ┌────────┼─────────┐                       Pod
        │        │         │                        │
  Deployment  DaemonSet  StatefulSet             Container
        │
    ReplicaSet
        │
       Pod
        │
    Container
```

业务访问通常走：

```text
用户 / 浏览器
     ↓
Ingress / LoadBalancer
     ↓
Service
     ↓
EndpointSlice
     ↓
Pod
     ↓
Container Port
```

配置和存储通常这样接入：

```text
ConfigMap / Secret ─→ Pod / Container
PVC ─→ PV ─→ 实际磁盘或存储 ─→ Pod
```

## 2. 最常见术语

| 名称 | 通俗理解 | 主要作用 |
| --- | --- | --- |
| Cluster | 整个 Kubernetes 集群 | 管理多台服务器和应用 |
| Node | 一台服务器 | 提供 CPU、内存、磁盘和网络 |
| Pod | Kubernetes 最小运行单元 | 承载一个或多个 Container |
| Container | 真正运行的程序 | 例如 Proxy、WebAPI、Nginx |
| Deployment | 普通应用的管理员 | 管副本、升级、回滚、故障重建 |
| ReplicaSet | Deployment 的副本执行层 | 保证指定数量的 Pod 存在 |
| DaemonSet | 每台指定服务器跑一份 | 常用于 Proxy、Agent、监控、网络组件 |
| StatefulSet | 有固定身份的 Pod 管理器 | 常用于数据库、分布式存储 |
| Service | Pod 的稳定访问入口 | 给变化的 Pod 提供固定访问方式 |
| Ingress | HTTP/HTTPS 入口规则 | 按域名、路径把流量转给 Service |
| Namespace | 集群内逻辑分组 | 分类和隔离不同业务资源 |
| ConfigMap | 普通配置 | 把配置提供给 Pod |
| Secret | 敏感配置对象 | 保存密码、Token、证书等数据 |
| PVC / PV | 存储申请 / 实际存储 | 给 Pod 提供持久化数据空间 |
| Job / CronJob | 一次性 / 定时任务 | 执行完成后退出，而不是长期服务 |

日常运维最重要的是先分清：**谁是管理规则，谁是真正在运行的实例。**

## 3. Pod：真正运行程序的地方

Pod 可以理解为 Kubernetes 给一个或多个容器套的一层运行外壳：

```text
Pod
 ├─ Container：主程序
 └─ Container：Sidecar（可选）
```

Pod 会被删除、重建、替换，Pod 名和 Pod IP 都可能变化，所以通常不要长期依赖某个固定 Pod。

查看：

```bash
kubectl get pods -A -o wide
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.containers[*].name}{"\n"}'
```

## 4. Deployment：我要 N 份这个应用

Deployment 本身不运行业务程序，它描述应用应该保持什么状态：

```text
Deployment
    ↓
ReplicaSet
    ↓
Pod × N
    ↓
Container
```

例如：

```bash
kubectl edit deployment cloudwalker-cloudwalker-server
kubectl edit deployment cloudwalker-cloudwalker-server-webapi
kubectl edit deployment cloudwalker-lighter-server
```

这里编辑的是 **3 个 Deployment**，不是 3 个 Pod。

如果配置：

```yaml
spec:
  replicas: 3
```

可以理解为 Deployment 要维持 3 个 Pod。某个 Pod 挂掉后，控制器会补一个新的 Pod。

Deployment 常用于：

- Web / API；
- 普通无状态业务；
- 需要滚动升级、回滚、扩缩容的服务。

查看：

```bash
kubectl get deployment -A
kubectl get replicaset -A
kubectl describe deployment <name> -n <namespace>
```

## 5. DaemonSet：我要每台指定机器一份

DaemonSet 不按 `replicas` 决定 Pod 数量，而是通常让**每台符合条件的 Node**运行一个 Pod。

例如 5 台 Node 满足条件：

```text
cloudwalker-cloudwalker-proxy DaemonSet
                │
       ┌────────┼────────┬────────┬────────┐
       ↓        ↓        ↓        ↓        ↓
     cw249    cw250    cw251    cw252    cw253
       │        │        │        │        │
    Proxy     Proxy     Proxy     Proxy     Proxy
     Pod       Pod       Pod       Pod       Pod
```

所以“每个 Proxy”实际就是：**每台符合条件的 Node 上那个独立的 Proxy Pod / Container 实例。**

典型用途：

- Proxy / Agent；
- 日志采集；
- 监控 Agent；
- CNI 网络组件；
- 存储驱动；
- 节点安全 Agent。

查看：

```bash
kubectl get daemonset -A
kubectl get pods -A -o wide
kubectl describe daemonset <name> -n <namespace>
```

### Deployment 和 DaemonSet 的区别

| | Deployment | DaemonSet |
| --- | --- | --- |
| Pod 数量 | 由 `replicas` 决定 | 由符合条件的 Node 数量决定 |
| 典型用途 | Web、API、普通业务 | 每节点 Proxy、Agent、监控、网络组件 |
| 新增一台 Node | 不一定增加 Pod | 通常会自动在新 Node 创建一个 Pod |

一句话：

```text
Deployment = 我要 N 份这个应用
DaemonSet  = 我要每台指定机器 1 份这个应用
```

## 6. StatefulSet：Pod 需要固定身份

Deployment 的多个 Pod 通常可以互相替代；StatefulSet 更强调每个 Pod 的固定身份，例如：

```text
mysql-0
mysql-1
mysql-2
```

它通常用于数据库、分布式存储以及需要稳定名字或持久化存储的服务。

StatefulSet 出问题时不要只看 Pod，还要一起确认 PVC、PV、数据副本状态。

## 7. Service 和 Ingress：流量怎么找到 Pod

Pod 会重建，IP 会变化，因此其他程序一般不应该长期直接访问某个 Pod IP。

Service 根据 Label 找到一组 Pod，并提供稳定访问入口：

```text
                 Service
                    │
          ┌─────────┼─────────┐
          ↓         ↓         ↓
        Pod-1     Pod-2     Pod-3
```

外部 HTTP/HTTPS 常见链路：

```text
浏览器
  ↓
Ingress Controller
  ↓
Ingress 规则
  ↓
Service
  ↓
EndpointSlice
  ↓
Ready Pod
```

所以“Pod 正常但网页打不开”时，还要继续检查 Service、EndpointSlice、Ingress 和入口负载均衡。

查看：

```bash
kubectl get svc,ingress -A
kubectl get endpointslice -A
```

## 8. ConfigMap / Secret：配置从哪里来

常见关系：

```text
ConfigMap ─┐
           ├─→ Pod → Container
Secret ────┘
```

它们可以通过环境变量、文件挂载等方式提供给程序。

修改 ConfigMap / Secret 后，已经运行的应用是否立即生效取决于挂载方式和程序行为，不能默认认为“改完所有 Pod 自动加载”。

## 9. PVC / PV：数据怎么持久保存

Pod 可以被重建，所以重要数据不能只放在 Pod 临时文件系统里。

```text
Pod
 ↓ 使用
PVC：应用申请一块存储
 ↓ 绑定
PV：Kubernetes 中实际可用的存储资源
 ↓
本地盘 / NFS / Longhorn / Ceph / 云盘等
```

因此：**Pod 能在其他 Node 重建，不代表数据已经高可用。**

## 10. requests / limits：每个 Container 能用多少资源

例如 Proxy DaemonSet：

```yaml
resources:
  requests:
    cpu: 250m
    memory: 1Gi
  limits:
    cpu: "4"
    memory: 4Gi
```

可以这样理解：

```text
requests = 调度时声明至少需要多少资源
limits   = 运行时最多允许使用多少资源
```

这是针对**每个对应 Container 实例**的配置。

如果有 5 个 Proxy Pod，不是 5 个总共只能用 4Gi，而是每个受该配置约束的 Proxy Container 都有自己的 `4Gi` 内存 limit。

CPU 达到 limit 时通常被限流；内存超过 limit 时，进程可能被内核杀掉，Kubernetes 中常见状态为：

```text
OOMKilled
```

即 Out Of Memory，内存超限被杀。

监控：

```bash
kubectl top pod -A --containers
watch -n 2 'kubectl top pod -A --containers | grep -i proxy'
```

## 11. 控制平面、kubelet、容器运行时是什么

Deployment、DaemonSet、Service 等都是 Kubernetes API 资源，它们背后还有真正管理集群的组件：

```text
kubectl / K9s / Helm
        ↓
   kube-apiserver
        ↓
 ┌──────┼───────────────┐
 ↓      ↓               ↓
etcd  scheduler   controller-manager
                         │
                         ↓
                       Node
                         │
                      kubelet
                         │
                         ↓
                        Pod
```

最小理解：

- **kube-apiserver**：统一 API 入口；
- **etcd**：保存集群状态；
- **scheduler**：决定新 Pod 放到哪台 Node；
- **controller-manager**：持续让实际状态靠近期望状态；
- **kubelet**：每台 Node 上的节点管理进程；
- **Container Runtime**：实际启动容器，例如 containerd；
- **CNI**：负责 Pod 网络；
- **kube-proxy 或等价实现**：参与 Service 网络转发，具体实现依集群而异。

## 12. kubectl、K9s、Helm、K3s 是什么

它们不是 Pod 类型：

| 名称 | 是什么 |
| --- | --- |
| Kubernetes | 容器编排平台 |
| K3s | 轻量化 Kubernetes 发行版，核心资源概念相同 |
| kubectl | Kubernetes 官方命令行客户端 |
| K9s | Kubernetes 终端交互界面 |
| Helm | Kubernetes 应用包和模板管理工具 |

关系：

```text
kubectl / K9s / Helm
        ↓ 操作
Kubernetes / K3s API
        ↓ 管理
Deployment / DaemonSet / Service / Pod ...
```

## 13. CloudWalker 场景直接对应

```text
cloudwalker-cloudwalker-server
cloudwalker-cloudwalker-server-webapi
cloudwalker-lighter-server
        ↓
    Deployment
        ↓
   ReplicaSet
        ↓
      Pod
        ↓
    Container

cloudwalker-cloudwalker-proxy
        ↓
    DaemonSet
        ↓
每个符合条件的 Node 上一个 Proxy Pod
        ↓
 Proxy Container / Proxy 进程
```

所以：

```bash
kubectl edit deployment cloudwalker-cloudwalker-server
```

是在修改 Deployment 的期望配置；如果修改了 Pod template，Kubernetes 通常会滚动创建新 Pod。

而：

```bash
kubectl edit daemonset cloudwalker-cloudwalker-proxy
```

是在修改这个 DaemonSet 管理的 Proxy Pod 模板，不是只改某一个现有 Pod。

## 14. 现场不知道对象是什么时

先跑：

```bash
kubectl get nodes -o wide
kubectl get deploy,statefulset,daemonset -A
kubectl get pods -A -o wide
kubectl get svc,ingress -A
kubectl get pvc,pv -A
```

想知道某个 Pod 是谁创建的：

```bash
kubectl get pod <pod> -n <namespace> -o jsonpath='{.metadata.ownerReferences}{"\n"}'
```

如果 owner 是 `ReplicaSet`，继续向上查，通常就能找到 Deployment：

```bash
kubectl get replicaset <rs-name> -n <namespace> -o jsonpath='{.metadata.ownerReferences}{"\n"}'
```

## 15. 最常见误区

- **Deployment 不是 Pod**：Deployment 是控制器，Pod 是运行实例。
- **DaemonSet 不是“一整个 Proxy”**：它会创建多个独立 Proxy Pod。
- **Service 不是业务进程**：它提供稳定访问和流量转发。
- **删除 Pod 不等于删除应用**：背后有 Deployment / DaemonSet 时通常会重新创建。
- **直接修改 Pod 通常不是长期配置**：应回到 Deployment / DaemonSet / Helm / GitOps 等权威配置修改。
- **Pod 能重建不等于数据高可用**：还要确认 PVC、PV 和后端存储。
- **Pod 正常不等于外部访问正常**：还要检查 Service、EndpointSlice、Ingress 和网络入口。

## 官方资料

- Kubernetes Concepts：https://kubernetes.io/docs/concepts/
- Workloads：https://kubernetes.io/docs/concepts/workloads/
- Pods：https://kubernetes.io/docs/concepts/workloads/pods/
- Deployments：https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- Workload Management：https://kubernetes.io/docs/concepts/workloads/controllers/
- Service：https://kubernetes.io/docs/concepts/services-networking/service/
- Ingress：https://kubernetes.io/docs/concepts/services-networking/ingress/
