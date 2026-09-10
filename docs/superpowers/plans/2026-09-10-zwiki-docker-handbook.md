# Zwiki Docker 运维速查实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 Docker 日常操作与故障排查两个稳定入口，覆盖容器、镜像、日志、资源、网络、存储、Compose 和磁盘清理。

**Architecture:** `docker-operations.md` 负责高频操作；`docker-troubleshooting.md` 负责异常现场定位。Docker 原理只解释 image/container/layer/volume/network 等执行命令时必须理解的概念。

**Tech Stack:** Docker Engine CLI、Docker Compose plugin、Markdown。

**Spec:** `docs/superpowers/specs/2026-09-10-zwiki-infrastructure-ops-handbook-design.md`

## Global Constraints

- 优先使用 Docker 官方 CLI。
- 所有删除、prune、volume 清理操作必须说明影响范围并先提供只读检查。
- 不把 Docker 官方 reference 复制成 Wiki 参数大全。
- 不修改 `gitbook-docs.yaml`。

---

### Task 1: 新增 Docker 日常操作速查

**Files:**
- Create: `cloud-native/docker/docker-operations.md`

- [ ] **Step 1: 编写高频操作入口**

必须覆盖：
```bash
docker version
docker info
docker ps -a
docker images
docker logs
docker exec
docker inspect
docker stats
docker port
docker network ls
docker volume ls
docker system df
docker compose ps
docker compose logs
```

- [ ] **Step 2: 最小解释核心对象**

只说明 image、container、layer、volume、bind mount、network、compose project 的运维区别。

- [ ] **Step 3: 加常见现场动作**

覆盖：看容器启动命令/环境变量、进入容器、复制文件、查看挂载、查看端口映射、看容器 IP、看健康状态、重启单容器、Compose 单服务重建。

- [ ] **Step 4: Commit**

```bash
git add cloud-native/docker/docker-operations.md
git commit -m "docs: add Docker operations quick reference"
```

### Task 2: 新增 Docker 故障排查速查

**Files:**
- Create: `cloud-native/docker/docker-troubleshooting.md`

- [ ] **Step 1: 固定排障路径**

```text
Docker daemon → 容器状态/退出码 → logs → inspect → 端口/网络/DNS → volume/权限 → CPU/内存 → 磁盘空间
```

覆盖容器 Exited/Restarting、OOMKilled、端口不通、DNS 异常、挂载权限、镜像拉取失败、磁盘爆满。

- [ ] **Step 2: 加磁盘排查和安全清理**

先使用：
```bash
docker system df
docker ps -a
docker images
docker volume ls
```

再说明 image/container/build cache/volume 分别如何判断能否清理。`docker system prune`、`docker volume prune`、`docker image prune -a` 必须显式标风险，不作为默认第一步。

- [ ] **Step 3: 加 Docker API 版本不兼容场景**

覆盖 Client API 高于 daemon API 的判断方法，给出 `docker version`、临时 `DOCKER_API_VERSION`、升级 daemon/降级 client 三种处置方向，并强调临时变量仅为兼容手段。

- [ ] **Step 4: 加官方深入链接**

链接 Docker Engine CLI、storage、networking、logging、prune 官方文档。

- [ ] **Step 5: 验证风险提示**

Run:
```bash
grep -nE 'system prune|volume prune|image prune|rm -f' cloud-native/docker/docker-troubleshooting.md
```

Expected: 每个删除类命令附近有影响范围/执行前检查文字。

- [ ] **Step 6: Commit**

```bash
git add cloud-native/docker/docker-troubleshooting.md
git commit -m "docs: add Docker troubleshooting quick reference"
```

### Task 3: 更新 Docker 入口和导航

**Files:**
- Modify: `cloud-native/docker/README.md`
- Modify: `SUMMARY.md`

- [ ] **Step 1: README 增加两个入口**

保留原收录范围，增加“日常操作”“故障排查”链接，不把 README 扩写成正文。

- [ ] **Step 2: 更新 SUMMARY**

将两个页面放在 Docker 节点下，不移动其他云原生页面。

- [ ] **Step 3: 验证**

Run:
```bash
test -f cloud-native/docker/docker-operations.md
test -f cloud-native/docker/docker-troubleshooting.md
grep -nE 'docker-operations|docker-troubleshooting' cloud-native/docker/README.md SUMMARY.md
```

Expected: 文件与导航全部存在。

- [ ] **Step 4: Commit**

```bash
git add cloud-native/docker/README.md SUMMARY.md
git commit -m "docs: link Docker operations quick references"
```
