# Docker 故障排查速查

用于容器启动失败、Restarting/OOMKilled、端口不通、DNS/挂载异常、镜像拉取失败、Docker 磁盘爆满以及 Client/Daemon API 版本冲突。

## 快速处理

固定顺序：

```text
Docker daemon → 容器状态/退出码 → logs → inspect → 端口/网络/DNS → mount/权限 → CPU/内存 → Docker/宿主机磁盘
```

```bash
systemctl status docker --no-pager
docker version
docker info
docker ps -a
docker system df
```

针对容器：

```bash
docker inspect -f 'status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} error={{.State.Error}} restart={{.RestartCount}}' <container>
docker logs --tail=200 <container>
docker inspect <container>
```

## 1. Docker daemon 不正常

```bash
systemctl status docker --no-pager
journalctl -u docker -n 200 --no-pager
docker info
```

如果是 socket 权限错误：

```bash
ls -l /var/run/docker.sock
id
```

不要通过无条件 `chmod 666 /var/run/docker.sock` 解决权限问题；Docker socket 基本等价于高权限主机控制能力，应按用户组/权限策略处理。

## 2. Exited / Restarting

```bash
docker ps -a
docker inspect -f 'exit={{.State.ExitCode}} error={{.State.Error}} restart={{.RestartCount}}' <container>
docker logs --tail=200 <container>
```

常见方向：

- 主进程正常退出或崩溃；
- 启动参数/环境变量错误；
- 配置文件或 Secret 缺失；
- 挂载目录权限错误；
- 依赖服务未就绪；
- restart policy 导致故障容器持续重启。

查看启动配置：

```bash
docker inspect -f '{{json .Config.Entrypoint}} {{json .Config.Cmd}}' <container>
docker inspect -f '{{json .Mounts}}' <container>
```

## 3. OOMKilled

```bash
docker inspect -f 'oom={{.State.OOMKilled}} exit={{.State.ExitCode}}' <container>
docker stats --no-stream <container>
docker inspect -f 'memory={{.HostConfig.Memory}} swap={{.HostConfig.MemorySwap}}' <container>
journalctl -k -b --no-pager | grep -iE 'oom|out of memory|killed process'
```

确认是容器限制还是宿主机整体内存不足。不要只提高内存限制；同时查应用为何增长。

## 4. 端口不通

```bash
docker port <container>
docker inspect -f '{{json .NetworkSettings.Ports}}' <container>
ss -lntp
```

容器内检查应用监听：

```bash
docker exec <container> sh -c 'ss -lntp 2>/dev/null || netstat -lntp 2>/dev/null'
```

若镜像没有 `ss/netstat`，不要为了排障永久改镜像；可通过应用自身状态、容器网络或临时诊断容器确认。

排查关系：

```text
宿主机监听/端口映射 → Docker NAT/网络 → 容器 IP → 容器内应用监听
```

## 5. 容器 DNS / 网络异常

```bash
docker network ls
docker network inspect <network>
docker inspect -f '{{json .NetworkSettings.Networks}}' <container>
```

容器内：

```bash
docker exec <container> cat /etc/resolv.conf
docker exec <container> getent hosts <name>
```

Compose 中优先检查两个服务是否在同一项目网络、服务名是否正确。不要把容器动态 IP 写死作为长期修复。

## 6. Volume / Bind Mount 权限

```bash
docker inspect -f '{{json .Mounts}}' <container>
ls -ld <HOST_PATH>
namei -l <HOST_PATH>
getenforce 2>/dev/null
```

常见原因：

- 宿主机路径不存在或挂错；
- 容器运行 UID/GID 与主机目录权限不匹配；
- 只读挂载；
- SELinux label 不允许访问。

不要以 `chmod -R 777` 或关闭 SELinux 作为默认解决方法。

## 7. 镜像拉取失败

```bash
docker pull <image>:<tag>
docker info | sed -n '/Registry Mirrors/,+10p'
```

重点区分：

```text
DNS/网络超时
仓库认证失败
TLS/CA 错误
tag 不存在
代理/镜像源配置问题
磁盘空间不足
```

私仓认证信息不要写入 Wiki 或命令历史示例。

## 8. Docker 磁盘爆满

先只读检查：

```bash
df -hT
df -ih
docker system df
docker system df -v
docker ps -a
docker images
docker volume ls
```

按对象判断，不要一条 prune 全清：

### 停止容器

```bash
docker ps -a --filter status=exited
```

确认容器已经无用、数据已持久化后才删除指定容器：

```bash
docker rm <container>
```

### 镜像

```bash
docker images
```

确认没有当前/回退部署需要后，优先删除指定镜像：

```bash
docker image rm <image>
```

### Build cache

```bash
docker builder du
```

确认缓存可重新构建后：

```bash
docker builder prune
```

### Volume

```bash
docker volume ls
docker volume inspect <volume>
```

Volume 可能就是数据库/业务持久化数据。确认没有容器或恢复流程依赖后才考虑删除指定 volume：

```bash
docker volume rm <volume>
```

### 高风险批量 prune

下面命令会批量删除未使用对象，**不是磁盘满的默认第一步**：

```bash
docker system prune
docker image prune -a
docker volume prune
```

风险：

- `docker system prune` 默认会删除停止容器、未使用网络、悬空镜像和 build cache；使用额外参数时影响面更大；
- `docker image prune -a` 会删除未被任何容器引用的镜像，可能把生产回退镜像一起删掉；
- `docker volume prune` 会删除符合条件的未使用 Volume，误判可能导致不可恢复的数据损失。

执行前必须先用 `docker system df -v`、`docker ps -a`、`docker images`、`docker volume ls/inspect` 明确具体对象，并优先精确删除。

## 9. 日志把磁盘写满

查看 logging driver：

```bash
docker info --format '{{.LoggingDriver}}'
docker inspect -f '{{json .HostConfig.LogConfig}}' <container>
```

`json-file` 场景检查 Docker 数据目录占用时，先只读定位，不直接手工 truncate 正在使用的内部日志文件。长期方案应配置日志轮转或改用统一日志系统。

## 10. Client API 比 daemon 新

先执行：

```bash
docker version
```

重点比较 Client/Server：

```text
Version
API version
minimum version
```

现代 Docker CLI 通常会与 daemon 协商 API 版本；如果环境变量强制指定、第三方客户端过旧/过新或组件不支持协商，可能出现 API 不兼容。

检查是否有人强制设置：

```bash
env | grep '^DOCKER_API_VERSION='
```

临时兼容/诊断可指定 daemon 支持的 API：

```bash
export DOCKER_API_VERSION=<SERVER_SUPPORTED_API>
docker version
```

恢复自动协商：

```bash
unset DOCKER_API_VERSION
```

注意：设置 `DOCKER_API_VERSION` 会禁用自动版本协商，只应作为临时兼容/调试手段。长期优先选择：

```text
1. 使用与 daemon 兼容的 Docker CLI
2. 在变更窗口升级 daemon
3. 必要时降级/固定客户端版本
```

不要为了“版本一致”直接升级生产 daemon；先确认发行版、容器运行影响和回退方案。

## 11. Compose 服务异常

```bash
docker compose config
docker compose ps
docker compose logs --tail=200 <service>
docker compose images
```

先看最终展开配置和失败服务，再决定是否重建。

确认数据持久化和影响后，仅重建目标服务：

```bash
docker compose up -d --no-deps <service>
```

如果没有配置/镜像变化，单纯反复重建通常不能解决根因。

## 常见现象速查

| 现象 | 首查 | 常见方向 |
| --- | --- | --- |
| daemon 不可用 | `systemctl status docker` | 服务、socket、存储驱动 |
| Exited | `inspect` + `logs` | 启动参数、应用退出 |
| Restarting | `RestartCount` + logs | 应用持续崩溃 |
| OOMKilled | inspect + kernel log | 容器 limit / 主机内存 |
| 映射端口不通 | `docker port` + `ss` | 应用监听、NAT、网络 |
| DNS 失败 | 容器 `/etc/resolv.conf` | Docker DNS、宿主 DNS、网络 |
| Permission denied | `.Mounts` + `namei` | UID/GID、SELinux、只读挂载 |
| 磁盘满 | `docker system df -v` | image/cache/log/volume |
| client API too new | `docker version` | 客户端/daemon/强制 API 变量 |

## 深入学习

- Docker CLI：https://docs.docker.com/reference/cli/docker/
- `docker version` 与 API 协商：https://docs.docker.com/reference/cli/docker/version/
- Docker Engine API：https://docs.docker.com/reference/api/engine/
- Docker disk usage：https://docs.docker.com/reference/cli/docker/system/df/
- Docker prune：https://docs.docker.com/reference/cli/docker/system/prune/
- Docker Storage：https://docs.docker.com/engine/storage/
- Docker Networking：https://docs.docker.com/engine/network/
- Docker Logging：https://docs.docker.com/engine/logging/

## 反馈与修改

新增故障场景优先补到对应排障层级。删除/清理类命令必须保留“先只读确认、再精确删除”的原则。