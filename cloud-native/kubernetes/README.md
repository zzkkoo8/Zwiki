# Kubernetes

记录标准 Kubernetes 的日常运维和故障排查，重点是现场快速定位，不建设资源对象百科。

## 常用速查

- [kubectl 日常运维速查](kubectl-operations.md)：资源查看、日志、exec、事件、Service/EndpointSlice、rollout 和 scale。
- [Kubernetes 故障排查速查](kubernetes-troubleshooting.md)：Node → Pod → Container → Service → EndpointSlice → Ingress → 应用逐层定位。
- [Helm 日常运维速查](helm-operations.md)：Release、values、history、upgrade、rollback 和升级验证。
- [K9s 日常运维速查](k9s-operations.md)：资源切换、日志、Describe、Shell、只读巡检和常用交互。

## 收录范围

- 控制平面、节点和组件架构
- Pod、Deployment、StatefulSet、DaemonSet 和 Job
- Service、Ingress、CNI 和网络策略
- Volume、PV、PVC 和存储类
- 调度、资源限制、探针和自动伸缩
- RBAC、Secret 和集群安全
- 日志、监控、备份、升级和容量管理
- Node、Pod、Service 和业务逐层排障

完整资源定义、控制器原理和 API 字段优先查 `kubectl explain` 与 Kubernetes 官方文档，Zwiki 只保留运维必须理解的最小关系。

## 与 K3s 的边界

Kubernetes 通用机制放在本目录；K3s 安装方式、内置组件、服务管理、数据目录和发行版特有问题放在 [K3s](../k3s/README.md)。

新增文章优先使用[通用技术文章模板](../../templates/technical-article.md)或[故障排查模板](../../templates/troubleshooting.md)。