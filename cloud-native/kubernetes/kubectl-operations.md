# kubectl 日常运维速查

用于 Kubernetes 集群日常查看资源、日志、事件、进入 Pod、端口转发以及受控 rollout/scale。K3s 发行版特有命令见 [K3s 日常运维速查](../k3s/k3s-operations.md)。

## 快速检查

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get deploy,statefulset,daemonset -A
kubectl get svc,ingress -A
kubectl get pvc,pv -A
kubectl get events -A --sort-by=.lastTimestamp
```

## 必须知道

只记住这几条关系即可开始排障：

```text
Deployment / StatefulSet / DaemonSet → Pod → Container
Service → Pod（通常通过 label selector）
Ingress → Service
PVC → PV / StorageClass
```

因此业务不通时不要只盯 Pod：控制器、Service/EndpointSlice、Ingress 和存储都可能是问题点。

## 1. Namespace / Context

```bash
kubectl config current-context
kubectl config get-contexts
kubectl get ns
```

指定 namespace：

```bash
kubectl get pods -n <namespace>
```

全局：

```bash
kubectl get pods -A
```

切 context/默认 namespace 会影响后续命令目标，操作生产前先确认：

```bash
kubectl config current-context
kubectl config view --minify
```

## 2. Pod

```bash
kubectl get pods -A -o wide
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace>
```

多容器 Pod：

```bash
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.containers[*].name}'
kubectl logs <pod> -n <namespace> -c <container>
```

前一个已退出容器日志：

```bash
kubectl logs <pod> -n <namespace> -c <container> --previous
```

实时日志：

```bash
kubectl logs -f <pod> -n <namespace> -c <container>
```

## 3. 进入 Pod

```bash
kubectl exec -it <pod> -n <namespace> -- sh
```

多容器：

```bash
kubectl exec -it <pod> -n <namespace> -c <container> -- sh
```

镜像有 Bash 时可用 `bash`。进入容器用于诊断，不要把手工改容器内文件当长期修复，Pod 重建后通常会丢失。

## 4. Deployment / StatefulSet / DaemonSet

```bash
kubectl get deploy,statefulset,daemonset -A
kubectl describe deployment <name> -n <namespace>
kubectl get deployment <name> -n <namespace> -o yaml
```

查看 Deployment 对应 Pod：

```bash
kubectl get pods -n <namespace> --show-labels
```

需要精确关联时先看 selector：

```bash
kubectl get deployment <name> -n <namespace> -o jsonpath='{.spec.selector.matchLabels}'
```

## 5. Service / EndpointSlice / Ingress

```bash
kubectl get svc -A
kubectl describe svc <service> -n <namespace>
kubectl get endpointslice -n <namespace> -l kubernetes.io/service-name=<service>
kubectl get ingress -A
kubectl describe ingress <ingress> -n <namespace>
```

Service 有 selector 但 EndpointSlice 没有后端时，优先检查 Service selector 与 Pod labels 是否匹配、Pod 是否 Ready。

## 6. Event

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

单 namespace：

```bash
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

Event 有生命周期且可能被清理，不应把“现在没有 event”理解为从未发生过问题。

## 7. CPU / 内存

集群已安装 Metrics Server 时：

```bash
kubectl top nodes
kubectl top pods -A
kubectl top pod <pod> -n <namespace> --containers
```

没有 Metrics API 时 `kubectl top` 会失败，这不代表节点没有资源指标，只代表 kubectl 当前拿不到 metrics.k8s.io 数据。

## 8. YAML / 字段来源

```bash
kubectl get <resource> <name> -n <namespace> -o yaml
kubectl explain deployment.spec.template.spec.containers.resources
```

查看当前对象和准备提交 YAML 的差异：

```bash
kubectl diff -f <file.yaml>
```

`kubectl diff` 是变更前非常有价值的检查步骤。

## 9. Port Forward

临时从本机访问 Pod：

```bash
kubectl port-forward -n <namespace> pod/<pod> 8080:<container-port>
```

Service：

```bash
kubectl port-forward -n <namespace> service/<service> 8080:<service-port>
```

默认只监听本机回环地址，适合临时诊断，不是生产暴露服务的方法。

## 10. 复制文件

```bash
kubectl cp <namespace>/<pod>:/path/to/file ./file
kubectl cp ./file <namespace>/<pod>:/path/to/file
```

`kubectl cp` 通常依赖容器内 `tar`；精简镜像没有 tar 时可能失败。

## 11. Rollout：变更操作

先检查：

```bash
kubectl rollout status deployment/<name> -n <namespace>
kubectl rollout history deployment/<name> -n <namespace>
kubectl get deployment <name> -n <namespace> -o yaml
```

### Restart

```bash
kubectl rollout restart deployment/<name> -n <namespace>
kubectl rollout status deployment/<name> -n <namespace>
```

**影响**：会触发工作负载 Pod 逐步重建。执行前确认副本数、PDB、容量和业务是否允许滚动替换。重启不能替代根因分析。

### Undo

先看历史：

```bash
kubectl rollout history deployment/<name> -n <namespace>
```

确认目标 revision 后：

```bash
kubectl rollout undo deployment/<name> -n <namespace> --to-revision=<REVISION>
```

**影响**：会再次触发 rollout；配置、数据库兼容性等并不保证随 Deployment revision 自动回退。

## 12. Scale：变更操作

先看当前：

```bash
kubectl get deployment <name> -n <namespace>
```

再调整：

```bash
kubectl scale deployment/<name> -n <namespace> --replicas=<N>
```

**影响**：缩容会终止 Pod；扩容会增加资源需求。若由 HPA/GitOps/Operator 管理，手工值可能被控制器覆盖。

## 13. Edit / Apply：变更操作

优先先保存/查看当前资源和 GitOps 权威源。

```bash
kubectl edit <resource> <name> -n <namespace>
```

声明式文件：

```bash
kubectl diff -f <file.yaml>
kubectl apply -f <file.yaml>
```

生产环境若由 Helm/GitOps 管理，不建议用 `kubectl edit` 制造无法追踪的长期漂移；应回到 Helm values/Git 仓库修改。

## 14. 删除资源：高风险

删除前至少确认 owner/controller：

```bash
kubectl get pod <pod> -n <namespace> -o jsonpath='{.metadata.ownerReferences}'
```

不要把：

```text
kubectl delete
kubectl delete --force --grace-period=0
```

作为“Pod 有问题”的默认第一步。尤其 StatefulSet、数据库和无控制器 Pod，要先确认数据和重建行为。

## 深入学习

- kubectl 官方参考：https://kubernetes.io/docs/reference/kubectl/
- kubectl Cheat Sheet：https://kubernetes.io/docs/reference/kubectl/quick-reference/
- Kubernetes Service：https://kubernetes.io/docs/concepts/services-networking/service/
- EndpointSlice：https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/

## 反馈与修改

本文只保留高频 kubectl 操作；完整资源字段和命令参数使用 `kubectl explain` 与 Kubernetes 官方文档查询。