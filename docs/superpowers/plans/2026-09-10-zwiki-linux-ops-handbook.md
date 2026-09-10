# Zwiki Linux 运维速查实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不百科化、不破坏现有文章的前提下，补齐 Linux 日常值班、性能、systemd/日志和离线软件包运维速查能力。

**Architecture:** 继续以 `infrastructure/system/` 为 Linux 运维入口。`linux-ops-bootstrap.md` 保持“接机开局”定位，新增页面只承载明显独立的现场场景；已有 LVM、Ubuntu 加固、临时代理文章保持原路径。

**Tech Stack:** Markdown、Linux 原生命令、systemd/journald、rpm/dnf/yum、dpkg/apt、GitBook SUMMARY。

**Spec:** `docs/superpowers/specs/2026-09-10-zwiki-infrastructure-ops-handbook-design.md`

## Global Constraints

- Zwiki 是技术应用场景速查手册，不建设百科式知识库。
- 保留现有文章和路径，优先补充现有内容。
- 前置知识只保留完成当前操作所需的最小概念。
- 高风险操作遵循“先检查、后变更、再验证”，并说明影响范围和回退。
- 深入原理链接 Linux Kernel、Ubuntu、Red Hat/SUSE 等官方资料。
- 不修改 `gitbook-docs.yaml`。

---

### Task 1: 审计现有 Linux 内容并划清边界

**Files:**
- Read: `infrastructure/system/README.md`
- Read: `infrastructure/system/linux-ops-bootstrap.md`
- Read: `infrastructure/system/linux-lvm-disk-expansion.md`
- Read: `infrastructure/system/ubuntu22-kernel-security-hardening.md`
- Read: `infrastructure/system/linux-temporary-internet-via-macos-proxy.md`

- [ ] **Step 1: 搜索重复主题**

Run:
```bash
grep -RniE 'load average|oom|iostat|journalctl|systemctl|rpm|dnf|yum|apt|dpkg|离线包|tmux|script ' infrastructure/system
```

Expected: 明确哪些命令已在 `linux-ops-bootstrap.md` 覆盖，新增页面不重复罗列。

- [ ] **Step 2: 输出边界记录**

记录：开局命令留在 `linux-ops-bootstrap.md`；性能定位、systemd/日志、离线包管理分别独立成页；LVM/内核专题继续引用现有文档。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs: define Linux ops handbook boundaries"
```

### Task 2: 新增 Linux 性能故障速查

**Files:**
- Create: `infrastructure/system/linux-performance-troubleshooting.md`

- [ ] **Step 1: 编写最短排障链**

固定现场顺序：
```text
uptime/load → top/ps → free/vmstat → df/lsblk → iostat/pidstat/iotop → ss → journalctl/dmesg
```

必须覆盖 CPU 高、Load 高但 CPU 不高、内存不足/OOM、swap、磁盘 IO 高、磁盘满、inode 满、单进程异常。

- [ ] **Step 2: 写“必须知道”**

仅解释 Load Average、iowait、OOM、RSS/VIRT、swap、inode、`%util/await` 的运维含义，每项 1-3 句。

- [ ] **Step 3: 加官方深入链接**

至少链接 Linux Kernel Documentation 与 Red Hat/Ubuntu 性能调优官方资料，不复制长篇原理。

- [ ] **Step 4: 验证危险命令**

Run:
```bash
grep -nE 'rm -rf|kill -9|drop_caches|echo [123] > /proc/sys/vm/drop_caches' infrastructure/system/linux-performance-troubleshooting.md
```

Expected: 不出现无条件高风险处置；若提及必须带风险说明。

- [ ] **Step 5: Commit**

```bash
git add infrastructure/system/linux-performance-troubleshooting.md
git commit -m "docs: add Linux performance troubleshooting quick reference"
```

### Task 3: 新增 systemd 与日志速查

**Files:**
- Create: `infrastructure/system/linux-systemd-log-operations.md`

- [ ] **Step 1: 编写服务排查流程**

覆盖 `systemctl status/is-active/is-enabled/failed/cat/show`、`journalctl -u/-b/-p/-f/--since`、`dmesg -T`，并给出“服务未启动 → 配置错误 → 端口冲突 → 权限/目录 → 依赖 → 内核/资源”的顺序。

- [ ] **Step 2: 加安全变更流程**

所有 restart/reload 前先检查状态与配置；强调优先 `reload`，只有组件不支持时再 `restart`。

- [ ] **Step 3: 验证页面可独立使用**

Run:
```bash
grep -nE 'systemctl status|journalctl -u|journalctl -b|dmesg -T|reload|restart' infrastructure/system/linux-systemd-log-operations.md
```

Expected: 每个核心动作至少出现一次，且 restart 附带影响说明。

- [ ] **Step 4: Commit**

```bash
git add infrastructure/system/linux-systemd-log-operations.md
git commit -m "docs: add systemd and log operations quick reference"
```

### Task 4: 新增在线/离线软件包速查

**Files:**
- Create: `infrastructure/system/linux-offline-package-management.md`

- [ ] **Step 1: 编写系统识别与包格式检查**

必须先给出：
```bash
cat /etc/os-release
uname -m
rpm --eval '%{_arch}' 2>/dev/null || true
dpkg --print-architecture 2>/dev/null || true
```

覆盖 RPM 系与 Debian 系的软件包查询、下载依赖、离线安装、校验、版本/架构匹配。

- [ ] **Step 2: 加麒麟/RHEL 系注意事项**

明确麒麟 V10 等兼容 RPM 生态时仍需以实际 `ID/ID_LIKE`、架构和仓库依赖为准，禁止仅凭“像 CentOS”盲装。

- [ ] **Step 3: 加校验与回退**

至少包含 `rpm -K`、`sha256sum`、`dnf/yum history`（仅在可用时）、`dpkg --audit`、`apt-cache policy` 等验证方法。

- [ ] **Step 4: Commit**

```bash
git add infrastructure/system/linux-offline-package-management.md
git commit -m "docs: add Linux offline package management quick reference"
```

### Task 5: 更新系统入口并验证

**Files:**
- Modify: `infrastructure/system/README.md`
- Modify: `SUMMARY.md`

- [ ] **Step 1: 入口页只增加场景导航**

将三个新页面放入“常用速查”区域，不在 README 重复正文。

- [ ] **Step 2: 更新 SUMMARY**

仅新增真实存在的三个页面；不移动现有条目。

- [ ] **Step 3: 验证链接**

Run:
```bash
for f in \
  infrastructure/system/linux-performance-troubleshooting.md \
  infrastructure/system/linux-systemd-log-operations.md \
  infrastructure/system/linux-offline-package-management.md; do test -f "$f" || exit 1; done

grep -nE 'linux-performance-troubleshooting|linux-systemd-log-operations|linux-offline-package-management' SUMMARY.md infrastructure/system/README.md
```

Expected: 三个文件存在并同时在分类入口和 SUMMARY 可定位。

- [ ] **Step 4: Commit**

```bash
git add infrastructure/system/README.md SUMMARY.md
git commit -m "docs: link Linux operations quick references"
```
