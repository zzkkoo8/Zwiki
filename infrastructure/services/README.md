# 基础服务

记录多类业务和基础设施都会依赖的通用服务组件的部署、配置、运维和故障排查。

## 收录范围

- DNS 服务：BIND、Unbound、CoreDNS 等
- 时间同步：NTP、Chrony
- 远程接入：OpenSSH、跳板与基础访问服务
- Web 与代理：Nginx、Apache、HAProxy
- 高可用：Keepalived、VIP 等
- 文件与同步：NFS、Samba、rsync
- 证书与基础 PKI 服务

## 边界

- 协议原理、路由交换、抓包和流量路径归“网络”。
- 操作系统自身服务、内核、存储、权限和系统故障归“系统”。
- Docker、Kubernetes、K3s 继续归“容器与云原生”。
- 数据库、消息队列、搜索引擎等形成稳定内容后再单独建立“中间件”分类，不混入本目录。

## 文章归类

同一服务先直接在本目录收录文章；某个组件形成三篇以上稳定内容后，再建立对应子目录。

新增文章优先使用[通用技术文章模板](../../templates/technical-article.md)、[故障排查模板](../../templates/troubleshooting.md)或[部署指南模板](../../templates/deployment-guide.md)。
