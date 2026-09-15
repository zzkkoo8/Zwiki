# Docker 日常运维速查

用于快速查看容器、日志、资源、端口、网络和持久化数据。异常退出、DNS、磁盘爆满等问题见 [Docker 故障排查速查](docker-troubleshooting.md)。

## 1. 先跑这一组

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

## 2. 容器状态和日志

```bash
docker ps -a
docker inspect <container>
docker logs --tail=100 <container>
docker logs -f <container>
```

只看关键状态：

```bash
docker inspect -f 'status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} restart={{.RestartCount}}' <container>
```

如果容器退出，先看 `ExitCode`、`OOMKilled` 和日志，不要先重启。

## 3. 进入容器 / 复制文件

进入：

```bash
docker exec -it <container> sh
```

有 Bash 时：

```bash
docker exec -it <container> bash
```

复制：

```bash
# 容器 → 主机
docker cp <container>:/path/to/file ./file

# 主机 → 容器
docker cp ./file <container>:/path/to/file
```

容器内手工修改通常不会成为长期配置，最终应回到镜像、Compose 或配置文件源修改。

## 4. CPU / 内存 / 端口

```bash
docker stats
docker port <container>
ss -lntp
```

资源限制：

```bash
docker inspect -f 'memory={{.HostConfig.Memory}} nano_cpus={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}}' <container>
```

CPU/内存问题同时检查宿主机，见 [Linux 性能故障快速排查](../../infrastructure/system/linux-performance-troubleshooting.md)。

## 5. 持久化数据先看 Mount

```bash
docker inspect -f '{{json .Mounts}}' <container>
docker volume ls
```

判断：

```text
Type=volume   Docker 管理的 Volume
Type=bind     宿主机目录直接挂载
```

删除或重建容器前先确认数据到底在 Volume、Bind Mount，还是只存在容器可写层。

查看 Volume：

```bash
docker volume inspect <volume>
```

## 6. 网络

```bash
docker network ls
docker network inspect <network>
docker inspect -f '{{json .NetworkSettings.Networks}}' <container>
```

Compose 服务间优先通过**服务名**访问，不要把动态容器 IP 写死到配置。

端口已映射但外部仍不通时，同时检查：

```text
应用在容器内监听的地址/端口
Docker 端口映射
宿主机监听
防火墙/安全组
```

## 7. 重启容器

先看日志：

```bash
docker logs --tail=100 <container>
```

确认允许短暂中断后：

```bash
docker restart <container>
```

验证：

```bash
docker ps
docker logs --since 5m <container>
```

重启只是恢复动作，不等于根因修复。

## 8. Compose 高频命令

```bash
docker compose ps
docker compose logs --tail=100
docker compose config
docker compose images
```

启动/更新：

```bash
docker compose up -d
```

只处理一个服务且不主动启动依赖：

```bash
docker compose up -d --no-deps <service>
```

停止：

```bash
docker compose stop
```

`docker compose down` 会删除项目容器和网络；是否删除 Volume 取决于参数。执行前确认数据位置，不把 `down -v` 当日常命令。

## 9. 镜像与磁盘

```bash
docker images
docker system df
docker image inspect <image>
```

生产部署不要只依赖 `latest`，确认实际 tag 或 digest。

清理前先看占用和引用关系。`docker system prune` 会删除未使用对象，不应作为磁盘不足时的第一条命令。

## 官方资料

- Docker CLI：https://docs.docker.com/reference/cli/docker/
- Docker Storage：https://docs.docker.com/engine/storage/
- Docker Networking：https://docs.docker.com/engine/network/
- Docker Compose：https://docs.docker.com/compose/
