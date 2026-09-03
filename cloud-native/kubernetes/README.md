# Kubernetes

记录标准 Kubernetes 的架构、资源对象、集群管理和故障排查文章。

## 收录范围

- 控制平面、节点和组件架构
- Pod、Deployment、StatefulSet、DaemonSet 和 Job
- Service、Ingress、CNI 和网络策略
- Volume、PV、PVC 和存储类
- 调度、资源限制、探针和自动伸缩
- RBAC、Secret 和集群安全
- 日志、监控、备份、升级和容量管理
- Node、Pod、Service 和业务逐层排障

## 与 K3s 的边界

Kubernetes 通用机制放在本目录；K3s 安装方式、内置组件、服务管理、数据目录和发行版特有问题放在 [K3s](../k3s/README.md)。

新增文章优先使用[通用技术文章模板](../../templates/technical-article.md)或[故障排查模板](../../templates/troubleshooting.md)。
