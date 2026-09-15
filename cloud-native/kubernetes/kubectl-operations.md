# kubectl 日常运维速查

用于 Kubernetes 日常查看资源、日志、事件、进入 Pod，以及受控 rollout / scale。K3s 特有操作见 [K3s 日常运维速查](../k3s/k3s-operations.md)。

## 1. 先跑这一组

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get deploy,statefulset,daemonset -A
kubectl get svc,ingress -A
kubectl get pvc,pv -A
kubectl get events -A --sort-by=.lastTimestamp
```

生产操作前先确认 Context / Namespace：

```bash
kubectl config current-context
kubectl config view --minify
```

## 2. Pod：状态、日志、进入容器

```bash
kubectl get pods -A -o wide
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --tail=200
```

多容器：

```bash
kubectl logs <pod> -n <namespace> -c <container> --tail=200
```

上一次已退出容器日志：

```bash
kubectl logs <pod> -n <namespace> -c <container> --previous
```

进入：

```bash
kubectl exec -it <pod> -n <namespace> -- sh
```

容器内手工改文件通常不是长期修复，Pod 重建后可能丢失。

## 3. Deployment / StatefulSet / DaemonSet

```bash
kubectl get deploy,statefulset,daemonset -A
kubectl describe deployment <name> -n <namespace>
kubectl get deployment <name> -n <namespace> -o yaml
```

常见关系：

```text
Deployment / StatefulSet / DaemonSet
                ↓
               Pod
                ↓
             Container
```

Pod 反复重建时先查控制器和 Event，不要只盯当前 Pod。

## 4. Service / Ingress

```bash
kubectl get svc -A
kubectl describe svc <service> -n <namespace>
kubectl get endpointslice -n <namespace> -l kubernetes.io/service-name=<service>
kubectl get ingress -A
kubectl describe ingress <ingress> -n <namespace>
```

业务不通的最短链路：

```text
Ingress → Service → EndpointSlice → Ready Pod → Container Port
```

Service 有 selector 但 EndpointSlice 没有后端时，优先检查 Pod label 和 Ready 状态。

## 5. Event / CPU / 内存

Event：

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

安装 Metrics Server 后：

```bash
kubectl top nodes
kubectl top pods -A
```

`kubectl top` 失败只说明当前拿不到 Metrics API，不代表节点一定没有资源数据。

## 6. 查看 YAML / 变更前 diff

```bash
kubectl get <resource> <name> -n <namespace> -o yaml
kubectl explain <resource>.<field>
kubectl diff -f <file.yaml>
```

生产变更优先先 `diff`，再 `apply`：

```bash
kubectl diff -f <file.yaml>
kubectl apply -f <file.yaml>
```

如果资源由 Helm、GitOps 或 Operator 管理，应回到对应权威源修改，不长期使用 `kubectl edit` 制造漂移。

## 7. Rollout / Restart / Undo

先看状态：

```bash
kubectl rollout status deployment/<name> -n <namespace>
kubectl rollout history deployment/<name> -n <namespace>
```

滚动重启：

```bash
kubectl rollout restart deployment/<name> -n <namespace>
kubectl rollout status deployment/<name> -n <namespace>
```

回退：

```bash
kubectl rollout history deployment/<name> -n <namespace>
kubectl rollout undo deployment/<name> -n <namespace> --to-revision=<REVISION>
```

执行前确认副本数、PDB、容量和业务是否允许滚动替换。Deployment 回退也不代表数据库或外部配置自动回退。

## 8. Scale

```bash
kubectl get deployment <name> -n <namespace>
kubectl scale deployment/<name> -n <namespace> --replicas=<N>
```

如果有 HPA / GitOps / Operator，手工副本数可能被重新覆盖。

## 9. 临时访问和复制文件

Port Forward：

```bash
kubectl port-forward -n <namespace> service/<service> 8080:<service-port>
```

复制文件：

```bash
kubectl cp <namespace>/<pod>:/path/to/file ./file
kubectl cp ./file <namespace>/<pod>:/path/to/file
```

`kubectl cp` 通常依赖容器内 `tar`。

## 10. 删除资源前

先确认资源 owner：

```bash
kubectl get pod <pod> -n <namespace> -o jsonpath='{.metadata.ownerReferences}'
```

不要把 `kubectl delete` 或强制删除作为 Pod 异常的默认第一步。StatefulSet、数据库、无控制器 Pod 尤其要先确认数据和重建行为。

## 常用排障顺序

```text
Context / Namespace
        ↓
Controller
        ↓
Pod / Container
        ↓
Event / Logs
        ↓
Service / EndpointSlice
        ↓
Ingress / Storage
```

更系统的故障定位见 [Kubernetes 故障排查速查](kubernetes-troubleshooting.md)。

## 官方资料

- kubectl Cheat Sheet：https://kubernetes.io/docs/reference/kubectl/quick-reference/
- kubectl Reference：https://kubernetes.io/docs/reference/kubectl/
- Service：https://kubernetes.io/docs/concepts/services-networking/service/
