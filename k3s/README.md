# K3s

记录 K3s 发行版特有的安装、配置、集群运维和故障恢复文章。

## 收录范围

- Server、Agent 安装与节点加入
- 高可用、嵌入式 etcd 和外部数据库
- containerd、Traefik、ServiceLB 和 Local Path Provisioner
- 配置文件、启动参数、数据目录和日志
- 离线安装、镜像导入与私有仓库
- 证书、Token、备份、恢复和升级
- 断电重启、节点异常和集群恢复

## 与 Kubernetes 的边界

资源对象、调度、Service、Ingress 等通用概念放在 [Kubernetes](../kubernetes/README.md)；只有 K3s 的实现、默认组件或管理方式不同，才放在本目录。

新增文章优先使用[部署指南模板](../templates/deployment-guide.md)或[故障排查模板](../templates/troubleshooting.md)。
