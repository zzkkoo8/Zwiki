# Docker 日常运维速查

用于 Docker Engine / Compose 环境快速查看容器、日志、资源、端口、网络和持久化数据。异常退出、网络/DNS、磁盘爆满等问题见 [Docker 故障排查速查](docker-troubleshooting.md)。

## 快速检查

```bash
docker version
docker info
docker ps -a
docker images
docker stats --no-stream
docker system df
```

Compose：

```bash
docker compose ps
docker compose logs --tail=100
```

## 必须知道

```text
image      只读镜像模板
container  镜像运行实例，删除容器不等于删除持久化数据
layer      镜像/容器分层文件系统
volume     Docker 管理的持久化数据
bind mount 宿主机目录直接挂入容器
network    Docker 虚拟网络和容器 DNS/连通关系
compose    一组服务、网络、卷的项目级编排
```

数据是否安全不能只看“容器还在不在”，先确认 Volume/Bind Mount。

## 1. 容器

```bash
docker ps
docker ps -a
docker inspect <container>
```

只看关键状态：

```bash
docker inspect -f 'status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} restart={{.RestartCount}}' <container>
```

查看启动命令：

```bash
docker inspect -f '{{json .Config.Cmd}}' <container>
docker inspect -f '{{json .Config.Entrypoint}}' <container>
```

查看环境变量时注意可能包含密码/Token：

```bash
docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' <container>
```

不要把包含敏感变量的输出直接贴到公开 Wiki。

## 2. 日志

```bash
docker logs --tail=100 <container>
docker logs --since 30m <container>
docker logs -f <container>
```

带时间戳：

```bash
docker logs -t --tail=100 <container>
```

Compose：

```bash
docker compose logs --tail=100 <service>
docker compose logs -f <service>
```

如果 `docker logs` 没有内容，检查应用是否写文件而不是 stdout/stderr，以及当前 logging driver：

```bash
docker inspect -f '{{json .HostConfig.LogConfig}}' <container>
```

## 3. 进入容器

先确认容器运行：

```bash
docker ps
```

常见：

```bash
docker exec -it <container> sh
```

镜像有 Bash 时：

```bash
docker exec -it <container> bash
```

进入容器主要用于诊断，不建议在容器里手工修改配置作为长期修复；应回到镜像、Compose 或配置管理源修改。

## 4. 容器与宿主机复制文件

容器 → 主机：

```bash
docker cp <container>:/path/to/file ./file
```

主机 → 容器：

```bash
docker cp ./file <container>:/path/to/file
```

写入运行中容器通常不是持久化配置方式，容器重建后可能丢失。

## 5. 资源使用

实时：

```bash
docker stats
```

单次：

```bash
docker stats --no-stream
```

查看资源限制：

```bash
docker inspect -f 'memory={{.HostConfig.Memory}} nano_cpus={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}}' <container>
```

CPU/内存异常同时检查宿主机，参考 [Linux 性能故障快速排查](../../infrastructure/system/linux-performance-troubleshooting.md)。

## 6. 端口

```bash
docker port <container>
docker inspect -f '{{json .NetworkSettings.Ports}}' <container>
ss -lntp
```

注意：容器内部监听 `127.0.0.1` 时，即使配置了 Docker 端口映射，也可能无法按预期从外部访问。还要检查应用实际监听地址。

## 7. 网络

```bash
docker network ls
docker network inspect <network>
```

容器 IP：

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' <container>
```

查看容器加入哪些网络：

```bash
docker inspect -f '{{json .NetworkSettings.Networks}}' <container>
```

Compose 服务通常应优先通过服务名互访，不要把动态容器 IP 写死到配置里。

## 8. Volume / Bind Mount

```bash
docker volume ls
docker volume inspect <volume>
docker inspect -f '{{json .Mounts}}' <container>
```

判断：

- `Type=volume`：Docker 管理数据位置；
- `Type=bind`：直接依赖宿主机路径、权限和 SELinux 等环境。

不要手工直接修改 Docker 内部 volume 数据目录作为常规操作；优先通过挂载到容器或应用自己的备份工具处理数据。

## 9. 镜像

```bash
docker images
docker image inspect <image>
docker history <image>
```

拉取：

```bash
docker pull <image>:<tag>
```

不要仅依赖 `latest` 判断生产版本；确认 image tag/digest 和部署配置。

## 10. 健康状态

```bash
docker inspect -f '{{json .State.Health}}' <container>
```

没有 HEALTHCHECK 的容器不会有健康状态，`Up` 只能说明主进程还在运行。

## 11. 重启单个容器

先看日志和影响：

```bash
docker logs --tail=100 <container>
docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' <container>
```

确认业务允许中断后：

```bash
docker restart <container>
```

验证：

```bash
docker ps
docker logs --since 5m <container>
```

重启只是恢复动作，不等于根因修复。

## 12. Compose 高频操作

```bash
docker compose ps
docker compose logs --tail=100
docker compose config
docker compose images
```

启动：

```bash
docker compose up -d
```

只重建单个服务：

```bash
docker compose up -d --no-deps <service>
```

如果镜像或配置变化需要强制重建，应先确认服务数据已经持久化以及依赖影响，不把 `--force-recreate` 当默认参数。

查看最终展开后的 Compose 配置：

```bash
docker compose config
```

该输出可能包含环境变量展开后的敏感值，共享前脱敏。

## 深入学习

- Docker CLI：https://docs.docker.com/reference/cli/docker/
- Docker Storage：https://docs.docker.com/engine/storage/
- Docker Volumes：https://docs.docker.com/engine/storage/volumes/
- Docker Bind Mounts：https://docs.docker.com/engine/storage/bind-mounts/
- Docker Networking：https://docs.docker.com/engine/network/
- Docker Compose：https://docs.docker.com/compose/

## 反馈与修改

本文只维护高频日常操作；完整 CLI 参数、网络驱动和存储驱动细节以 Docker 官方文档为准。