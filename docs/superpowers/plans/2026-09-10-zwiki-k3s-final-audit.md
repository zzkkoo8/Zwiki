# Zwiki K3s 与全站验收实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补齐 K3s 发行版特有运维和备份恢复速查，并完成本轮 Zwiki 基建/云原生内容的全站导航、重复、链接和风险审计。

**Architecture:** Kubernetes 通用知识继续引用 `cloud-native/kubernetes/`；K3s 页面只写发行版特有操作。最后统一检查 `SUMMARY.md`、分类 README、内部相对链接、孤立页面和危险命令，不改 GitBook 配置。

**Tech Stack:** K3s、systemd、containerd/ctr/crictl、etcd snapshot、Markdown、Git/GitBook SUMMARY。

**Spec:** `docs/superpowers/specs/2026-09-10-zwiki-infrastructure-ops-handbook-design.md`

## Global Constraints

- 保留 `cloud-native/k3s/product-runtime-k3s-deployment.md`，不把它改写成通用手册。
- K3s 页面只写发行版特有场景；Pod/Service/Ingress 等通用机制链接 Kubernetes 页面。
- 备份恢复必须明确 server token、snapshot、配置/证书等关键数据范围，并以 K3s 官方文档核验。
- restore、uninstall、reset 等高风险动作必须明确前置备份、影响范围和恢复路径。
- 全站验收不得修改 `gitbook-docs.yaml`。

---

### Task 1: 新增 K3s 日常运维速查

**Files:**
- Create: `cloud-native/k3s/k3s-operations.md`

- [ ] **Step 1: 编写快速检查入口**

必须覆盖：
```bash
systemctl status k3s
systemctl status k3s-agent
journalctl -u k3s -n 200 --no-pager
k3s kubectl get nodes -o wide
k3s kubectl get pods -A -o wide
k3s crictl ps -a
k3s ctr containers list
```

并说明 server/agent、`/etc/rancher/k3s/config.yaml`、`/var/lib/rancher/k3s/`、kubeconfig 的常见位置和用途。

- [ ] **Step 2: 覆盖 K3s 特有组件**

只写现场需要知道的 Traefik、ServiceLB、Local Path Provisioner、embedded containerd、registries.yaml；通用 K8s 机制链接 Kubernetes 页面。

- [ ] **Step 3: 覆盖节点/镜像/私仓场景**

包括节点状态、agent 无法加入、containerd 镜像查看、离线镜像导入、私有仓库配置检查。任何重启 K3s 的动作先要求确认业务影响。

- [ ] **Step 4: Commit**

```bash
git add cloud-native/k3s/k3s-operations.md
git commit -m "docs: add K3s operations quick reference"
```

### Task 2: 新增 K3s 备份恢复速查

**Files:**
- Create: `cloud-native/k3s/k3s-backup-recovery.md`

- [ ] **Step 1: 明确不同 datastore 的边界**

区分 embedded etcd、SQLite、external datastore；不同模式只给对应备份入口，不混用恢复命令。

- [ ] **Step 2: embedded etcd snapshot 操作**

覆盖 snapshot list/save、snapshot 存放位置、异地复制与校验。必须强调保存 `/var/lib/rancher/k3s/server/token`，并以当前 K3s 官方 Backup and Restore 文档核验其恢复要求。

- [ ] **Step 3: 编写恢复前检查清单**

至少包含：K3s 版本、节点角色、datastore 类型、snapshot、server token、配置文件、证书/私仓配置、数据目录磁盘空间。

- [ ] **Step 4: 写恢复与升级安全边界**

restore/cluster-reset/版本升级只提供经官方文档核验的流程；执行前要求备份当前数据并明确停机/集群影响。卸载脚本不作为故障修复默认手段。

- [ ] **Step 5: Commit**

```bash
git add cloud-native/k3s/k3s-backup-recovery.md
git commit -m "docs: add K3s backup and recovery quick reference"
```

### Task 3: 更新 K3s 入口和导航

**Files:**
- Modify: `cloud-native/k3s/README.md`
- Modify: `SUMMARY.md`

- [ ] **Step 1: 增加日常运维与备份恢复入口**

保留现有产品运行底座部署手册位置，新增两个链接，不移动/改名部署专题。

- [ ] **Step 2: 验证**

Run:
```bash
test -f cloud-native/k3s/k3s-operations.md
test -f cloud-native/k3s/k3s-backup-recovery.md
test -f cloud-native/k3s/product-runtime-k3s-deployment.md
grep -nE 'k3s-operations|k3s-backup-recovery|product-runtime-k3s-deployment' cloud-native/k3s/README.md SUMMARY.md
```

Expected: 三个入口同时存在。

- [ ] **Step 3: Commit**

```bash
git add cloud-native/k3s/README.md SUMMARY.md
git commit -m "docs: link K3s operations quick references"
```

### Task 4: 全站内容重复与定位审计

**Files:**
- Review: `infrastructure/**`
- Review: `cloud-native/**`
- Review: `SUMMARY.md`

- [ ] **Step 1: 检查新增主题是否出现重复页面**

Run:
```bash
grep -RniE '^# .*?(Linux|网络|Nginx|Docker|Kubernetes|K3s|Helm|K9s)' infrastructure cloud-native
```

Expected: 同一应用场景只有一个权威页面；交叉主题通过链接引用。

- [ ] **Step 2: 检查是否百科化**

人工审核每个新增页面：前置知识章节应明显短于“快速处理/命令/排障”正文；长篇协议/架构说明删除并替换官方链接。

- [ ] **Step 3: 检查高风险命令**

Run:
```bash
grep -RniE 'rm -rf|system prune|volume prune|image prune|kubectl delete|kubectl drain|helm rollback|cluster-reset|uninstall|lvremove|vgremove|pvremove|mkfs|reboot|shutdown|kill -9' infrastructure cloud-native
```

Expected: 每个命中点人工确认上下文包含影响范围、前置检查或回退说明；无“复制即执行”的破坏性指令。

### Task 5: 全站 Markdown 与导航验收

**Files:**
- Modify if needed: `SUMMARY.md`
- Modify if needed: affected `README.md`

- [ ] **Step 1: 检查 SUMMARY 目标文件存在**

Run:
```bash
python3 - <<'PY'
import re, pathlib, sys
p = pathlib.Path('SUMMARY.md')
text = p.read_text(encoding='utf-8')
missing=[]
for target in re.findall(r'\]\(([^)#]+\.md)(?:#[^)]+)?\)', text):
    if not pathlib.Path(target).exists():
        missing.append(target)
print('\n'.join(missing))
sys.exit(1 if missing else 0)
PY
```

Expected: exit 0，无缺失文件。

- [ ] **Step 2: 检查普通 Markdown 相对链接**

Run:
```bash
python3 - <<'PY'
import pathlib,re,sys
roots=[pathlib.Path('infrastructure'),pathlib.Path('cloud-native')]
missing=[]
for root in roots:
  for f in root.rglob('*.md'):
    text=f.read_text(encoding='utf-8')
    for link in re.findall(r'\]\(([^)]+)\)',text):
      link=link.split('#',1)[0]
      if not link or '://' in link or link.startswith('mailto:'):
        continue
      target=(f.parent/link).resolve()
      if not target.exists(): missing.append((str(f),link))
for a,b in missing: print(f'{a}: {b}')
sys.exit(1 if missing else 0)
PY
```

Expected: exit 0；若旧文档已有坏链，在不扩大范围的前提下修复相关基础设施页面。

- [ ] **Step 3: 确认 GitBook 配置未变化**

Run:
```bash
git diff main...HEAD -- gitbook-docs.yaml
```

Expected: 无输出。

- [ ] **Step 4: 最终差异审计**

Run:
```bash
git diff --stat main...HEAD
git diff --name-status main...HEAD
```

Expected: 只包含设计稿/计划、约定的速查文章、所属 README 与 SUMMARY；无已有文章的移动、删除或无关重构。

- [ ] **Step 5: Commit final fixes**

```bash
git add SUMMARY.md infrastructure cloud-native
git commit -m "docs: finalize infrastructure operations handbook audit"
```

如果无修正则不创建空提交。
