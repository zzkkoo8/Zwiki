# Docker

记录 Docker Engine、容器运行和 Compose 应用的部署运维文章，优先提供现场可直接使用的操作和排障入口。

## 常用速查

- [Docker 日常运维速查](docker-operations.md)：容器、日志、资源、端口、网络、Volume/Bind Mount 和 Compose 高频操作。
- [Docker 故障排查速查](docker-troubleshooting.md)：Exited/Restarting/OOMKilled、端口/DNS/挂载、磁盘爆满、镜像拉取和 API 版本冲突。

## 收录范围

- Docker Engine 安装、升级与配置
- 镜像构建、仓库和清理
- 容器生命周期、资源限制和日志
- Docker Compose 编排
- 容器网络、端口和 DNS
- Volume、Bind Mount 和数据备份
- 安全加固和权限控制
- 容器启动失败、异常退出和性能问题

## 文章归类

先将文章直接存放在本目录；形成稳定集合后，再按 `engine/`、`compose/`、`networking/`、`storage/` 或 `troubleshooting/` 拆分。

新增文章优先使用[部署指南模板](../../templates/deployment-guide.md)或[故障排查模板](../../templates/troubleshooting.md)。