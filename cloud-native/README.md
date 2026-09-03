# 容器与云原生

本分类收纳容器运行时、容器编排和轻量 Kubernetes 发行版相关的部署、运维与故障排查内容。

## 内容入口

- [Docker](docker/README.md)：Docker Engine、镜像、容器、Compose、网络、存储和排障。
- [Kubernetes](kubernetes/README.md)：标准 Kubernetes 架构、资源对象、集群管理和故障定位。
- [K3s](k3s/README.md)：K3s 发行版特有的安装、配置、升级、备份恢复和故障排查。

## 收录原则

- Docker 独有的 Engine、Compose、镜像和容器问题放 `cloud-native/docker/`。
- Kubernetes 通用资源对象、调度、网络、存储和集群机制放 `cloud-native/kubernetes/`。
- K3s 默认组件、安装方式、数据目录和发行版特有问题放 `cloud-native/k3s/`。
- Linux 主机、内核、文件系统等宿主机本身的问题放在[基建 / 系统](../infrastructure/system/README.md)，不要在容器分类重复维护。
