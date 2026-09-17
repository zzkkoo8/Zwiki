# Kubernetes / K3s 核心组件关系速查

用于现场看到 `Pod`、`Deployment`、`DaemonSet`、`Service` 等术语时，快速判断“它是什么、谁管理谁、故障该看哪一层”。

先记住一句话：

> **程序最终运行在 Container 里；Container 放在 Pod 里；Pod 通常由 Deployment / DaemonSet / StatefulSet 管理；Service 找到一组 Pod；Ingress 把外部 HTTP/HTTPS 流量转给 Service；Node 就是运行这些 Pod 的服务器。**

如果只想查命令，直接看 [kubectl 日常运维速查](kubectl-operations.md)；出现业务异常时看 [Kubernetes 故障排查速查](kubernetes-troubleshooting.md)。

## 1. 先看完整关系

```text
                        Kubernetes / K3s Cluster
                                  │
                 ┌────────────────┴────────────────┐
                 │                                 │
           Control Plane                         Node
       管理、调度整个集群                    一台实际服务器
                 │                                 │
                 │                           kubelet / 容器运行时
                 │                                 │
                 │                 ┌───────────────┴───────────────┐
                 │                 │                               │
          工作负载控制器          Pod                             Pod
                 │                 │                               │
       ┌─────────┼─────────┐     Container                       Container
       │         │         │
 Deployment  DaemonSet  StatefulSet
       │
   ReplicaSet
       │
      Pod
```

业务访问通常是另一条链：

```text
用户 / 浏览器
     ↓
Ingress / LoadBalancer
     ↓
Service
     ↓
EndpointSlice
     ↓
Pod IP
     ↓
Container Port
```

配置和数据则从侧面进入 Pod：

```text
ConfigMap / Secret ───────→ Pod / Container

PVC ─→ PV ─→ 实际磁盘或存储 ─→ Pod
```

## 2. 最常见对象分别是什么

| 名称 | 通俗理解 | 主要作用 |
| --- | --- | --- |
| Cluster | 整个 Kubernetes 集群 | 管理多台服务器和上面的应用 |
| Node | 一台服务器 | 真正提供 CPU、内存、磁盘、网络 |
| Pod | Kubernetes 最小运行单元 | 承载一个或多个 Container |
| Container | 真正运行的程序 | 例如 Proxy、WebAPI、Nginx |
| Deployment | 普通应用的“管理员” | 管副本、升级、回滚、故障重建 |
| ReplicaSet | Deployment 的“副本执行层” | 保证指定数量的 Pod 存在 |
| DaemonSet | “每台指定服务器跑一份” | 节点代理、日志、监控、网络组件等 |
| StatefulSet | 有固定身份的 Pod 管理器 | 数据库、需要稳定名字/存储的服务 |
| Service | Pod 的稳定访问入口 | 给变化的 Pod 提供固定地址和负载分发 |
| Ingress | HTTP/HTTPS 入口规则 | 根据域名、路径把流量转给 Service |
| Namespace | 集群内的逻辑分组 | 隔离、分类不同环境或业务资源 |
| ConfigMap | 普通配置 | 把配置传给 Pod |
| Secret | 敏感配置对象 | 保存密码、Token、证书等配置数据 |
| PVC / PV | 存储申请 / 实际存储 | 给 Pod 提供持久化数据空间 |
| Job / CronJob | 一次性 / 定时任务 | 跑完即结束，而不是长期提供服务 |

日常运维最重要的是先分清：**谁是“配置和管理规则”，谁是真正在运行的实例。**

## 3. Pod：真正运行程序的地方

Pod 不是一台虚拟机，可以把它理解为 Kubernetes 给一个或多个容器套的一层运行外壳。

```text
Pod
 ├─ Container: 主程序
 └─ Container: Sidecar（可选）
```

例如：

```text
cloudwalker-cloudwalker-proxy-xxxxx
                 ↓
                Pod
                 ↓
          cloudwalker-proxy Container
                 ↓
             Proxy 进程
```

Pod 名字经常带随机字符，是因为 Pod 可以被删除、重建、替换。**不要把某个 Pod 名字当成长期固定资产。**

查看 Pod：

```bash
kubectl get pods -A -o wide
```

查看 Pod 中有哪些容器：

```bash
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.containers[*].name}{"\n"}'
```

## 4. Deployment：管理普通应用的一组 Pod

Deployment 本身不运行你的业务程序，它描述“应用应该保持什么状态”。

典型关系：

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

如果：

```yaml
spec:
  replicas: 3
```

可以理解为：

```text
Deployment
 ├─ Pod-1
 ├─ Pod-2
 └─ Pod-3
```

某个 Pod 挂掉后，Deployment 通过 ReplicaSet 创建新的 Pod，尽量恢复到期望的 3 个副本。

Deployment 还负责常见的：

- 扩容 / 缩容；
- 滚动升级；
- 回滚；
- Pod 异常后的自动补齐。

查看：

```bash
kubectl get deployment -A
kubectl describe deployment <name> -n <namespace>
kubectl get replicaset -A
```

## 5. DaemonSet：每台指定 Node 跑一个 Pod

DaemonSet 适合“这个程序不是按业务副本数运行，而是每台服务器都应该有一份”的场景。

例如 5 台 Node 满足调度条件：

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

所以前面看到：

```text
5/5 Ready
```

通常表示这个 DaemonSet 期望的 5 个 Pod 都已正常 Ready。

这也是“每个 Proxy”的含义：**每台符合条件的 Node 上那个独立的 Proxy Pod / Container 实例。**

典型用途包括：

- 节点 Proxy / Agent；
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

### Deployment 和 DaemonSet 最容易混淆

| | Deployment | DaemonSet |
| --- | --- | --- |
| Pod 数量由什么决定 | `replicas` | 符合条件的 Node 数量 |
| 典型用途 | Web、API、普通业务服务 | 每节点 Proxy、Agent、监控、网络组件 |
| 一台新 Node 加入 | 不一定增加 Pod | 通常自动在新 Node 创建一个 Pod |
| Pod 挂了 | 补一个 Pod | 在对应节点维持应有的 Pod |

一句话：

```text
Deployment = 我要 N 份这个应用
DaemonSet  = 我要每台指定机器 1 份这个应用
```

## 6. StatefulSet：需要稳定身份和存储的 Pod

Deployment 的多个 Pod 通常可以互相替代；StatefulSet 的 Pod 更强调“我是第几个实例”。

例如：

```text
mysql-0
mysql-1
mysql-2
```

它们通常还会绑定各自的持久化存储。

常见场景：

- 数据库；
- 分布式存储；
- 需要稳定网络身份的集群软件。

不要因为 StatefulSet 某个 Pod 异常，就像普通无状态 Pod 一样随意删除；先确认数据、PVC 和集群副本状态。

## 7. Service：给不断变化的 Pod 一个稳定入口

Pod 会重建，Pod IP 也可能变化，所以其他应用一般不应该长期直接访问某个 Pod IP。

Service 根据 Label 找到一组 Pod，并提供一个相对稳定的访问入口：

```text
                 Service
                    │
          ┌─────────┼─────────┐
          ↓         ↓         ↓
        Pod-1     Pod-2     Pod-3
```

因此排查“服务不通”时经常要看：

```text
Service
   ↓
EndpointSlice
   ↓
Ready Pod
```

查看：

```bash
kubectl get svc -A
kubectl get endpointslice -A
```

## 8. Ingress：外部 HTTP/HTTPS 怎么进来

Ingress 本身主要是路由规则，还需要 Ingress Controller 真正执行这些规则。

最常见链路：

```text
浏览器访问 https://example.com/api
             ↓
      Ingress Controller
             ↓
          Ingress 规则
             ↓
           Service
             ↓
             Pod
```

所以“外部访问失败但 Pod 正常”，不要只查 Pod，还需要继续查 Ingress、Service、EndpointSlice。

## 9. ConfigMap / Secret：程序配置从哪里来

应用镜像通常不应该把所有环境配置写死在镜像里。

```text
ConfigMap ─┐
           ├─→ Pod → Container
Secret ────┘
```

常见注入方式：

- 环境变量；
- 配置文件挂载；
- Volume。

注意：修改 ConfigMap / Secret 后，已经运行的应用是否立即生效取决于使用方式和程序行为，不能默认认为“改完配置所有 Pod 就自动加载了”。

## 10. PV / PVC：Pod 的数据怎么持久保存

Pod 可以随时重建，所以重要数据不能只依赖 Pod 自己的临时文件系统。

最容易理解的关系：

```text
Pod
 ↓ 使用
PVC（我要一块多大的盘）
 ↓ 绑定
PV（Kubernetes 中的一块存储资源）
 ↓
实际磁盘 / NFS / Longhorn / Ceph / 云盘等
```

如果业务 Pod 能在其他 Node 重建，但数据只存在原 Node 的本地目录，那么“Pod 能恢复”不等于“业务高可用”。

## 11. requests / limits：Pod 可以使用多少 CPU 和内存

例如 Proxy DaemonSet 中：

```yaml
resources:
  requests:
    cpu: 250m
    memory: 1Gi
  limits:
    cpu: "4"
    memory: 4Gi
```

这是针对**每个对应 Container 实例**的资源配置。

可以理解为：

```text
requests = 调度时声明“至少给我留多少资源”
limits   = 运行时“最多允许我用多少资源”
```

因此 5 个 Proxy Pod 并不是总共只能用 4Gi，而是每个受该配置约束的 Proxy Container 都有自己的 `4Gi` 内存 limit。

CPU 达到 limit 时通常会被限流；内存超过 limit 时，进程可能被内核杀掉，在 Kubernetes 中常见状态是：

```text
OOMKilled
```

即 Out Of Memory，内存超限被杀。

监控：

```bash
kubectl top pod -A --containers
```

持续看 Proxy：

```bash
watch -n 2 'kubectl top pod -A --containers | grep -i proxy'
```

## 12. Node、kubelet、控制平面是什么

前面的 Deployment、DaemonSet、Service 等是 Kubernetes API 资源；它们背后还有真正管理集群的系统组件。

```text
kubectl / k9s / Helm
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

- **kube-apiserver**：Kubernetes 的统一 API 入口；
- **etcd**：保存集群状态和配置；
- **scheduler**：决定新 Pod 应该放到哪台 Node；
- **controller-manager**：持续把“实际状态”拉回“期望状态”；
- **kubelet**：每台 Node 上的节点管理进程，负责让本机 Pod 真正运行；
- **Container Runtime**：实际启动容器，例如 containerd；
- **CNI**：负责 Pod 网络；
- **kube-proxy 或等价实现**：参与 Service 网络转发，具体实现依集群而异。

日常业务排障通常不需要一开始深入这些内部组件。先按：

```text
Node → Controller → Pod → Container → Service → Ingress / Storage
```

逐层检查即可。

## 13. kubectl、K9s、Helm、K3s 又是什么

这几个经常和 Kubernetes 对象混在一起，但它们不是 Pod 类型：

| 名称 | 是什么 |
| --- | --- |
| Kubernetes | 容器编排平台本身 |
| K3s | 轻量化 Kubernetes 发行版，核心 Kubernetes 概念基本相同 |
| kubectl | Kubernetes 官方命令行客户端 |
| K9s | Kubernetes 终端交互界面 |
| Helm | Kubernetes 应用包和模板管理工具 |

所以：

```text
kubectl / K9s / Helm
        ↓ 操作
Kubernetes / K3s API
        ↓ 管理
Deployment / DaemonSet / Service / Pod ...
```

## 14. CloudWalker 场景怎么对应

当前容易遇到的对象可以直接这样理解：

```text
cloudwalker-cloudwalker-server
        ↓
    Deployment
        ↓
   ReplicaSet
        ↓
      Pod
        ↓
    Container

cloudwalker-cloudwalker-server-webapi
        ↓
    Deployment
        ↓
      Pod

cloudwalker-lighter-server
        ↓
    Deployment
        ↓
      Pod

cloudwalker-cloudwalker-proxy
        ↓
    DaemonSet
        ↓
每个符合条件的 Node 上一个 Proxy Pod
        ↓
 Proxy Container / Proxy 进程
```

因此执行：

```bash
kubectl edit deployment cloudwalker-cloudwalker-server
```

是在改 Deployment 的期望配置；如果改到了 Pod template，Kubernetes 通常会滚动创建新 Pod。

执行：

```bash
kubectl edit daemonset cloudwalker-cloudwalker-proxy
```

是在改所有由这个 DaemonSet 管理的 Proxy Pod 模板，而不是只改某一个现有 Pod。

## 15. 现场不知道对象是什么时

先执行这一组：

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

如果显示 owner 是 `ReplicaSet`，继续查 ReplicaSet，通常再向上就是 Deployment：

```bash
kubectl get replicaset <rs-name> -n <namespace> -o jsonpath='{.metadata.ownerReferences}{"\n"}'
```

## 16. 最常见误区

- **Deployment 不是 Pod**：Deployment 是控制器，Pod 是运行实例。
- **DaemonSet 不是“一整个 Proxy”**：它会创建多个独立 Proxy Pod。
- **Service 不是业务进程**：它主要提供稳定访问和流量转发。
- **删除 Pod 不等于删除应用**：如果背后有 Deployment / DaemonSet，控制器通常会重新创建。
- **直接改 Pod 通常不能作为长期配置**：Pod 重建后修改可能消失，应回到 Deployment / DaemonSet / Helm / GitOps 等权威配置修改。
- **Pod 能重建不等于数据高可用**：还要确认 PVC、PV 和后端存储。
- **Pod 正常不代表外部一定能访问**：还要检查 Service、EndpointSlice、Ingress、网络和入口负载均衡。

## 官方资料

- Kubernetes Concepts：https://kubernetes.io/docs/concepts/
- Workloads：https://kubernetes.io/docs/concepts/workloads/
- Pods：https://kubernetes.io/docs/concepts/workloads/pods/
- Deployments：https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- Workload Management（含 DaemonSet / StatefulSet）：https://kubernetes.io/docs/concepts/workloads/controllers/
- Service：https://kubernetes.io/docs/concepts/services-networking/service/
- Ingress：https://kubernetes.io/docs/concepts/services-networking/ingress/
