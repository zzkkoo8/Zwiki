# Zwiki Kubernetes 工具链速查实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用少量页面覆盖 Kubernetes 日常资源查看、kubectl 排障、Helm 和 K9s 高频操作，不建设 Kubernetes 概念百科。

**Architecture:** Kubernetes 通用资源与排障统一放 `cloud-native/kubernetes/`；K3s 发行版特有内容不在本计划重复。kubectl、Helm、K9s 分别作为独立速查入口。

**Tech Stack:** kubectl、Helm 3、K9s、Markdown。

**Spec:** `docs/superpowers/specs/2026-09-10-zwiki-infrastructure-ops-handbook-design.md`

## Global Constraints

- 只解释现场必须理解的 Pod/Deployment/StatefulSet/DaemonSet/Service/Ingress/ConfigMap/Secret/PV/PVC/Namespace/Node 等对象。
- 优先 `get/describe/logs/events/top` 等只读命令，再给变更动作。
- delete、rollout restart、scale、cordon/drain 等动作必须写影响范围。
- Helm upgrade/rollback 前必须包含 values/history/status 检查。
- K9s 优先补充只读巡检模式和常用快捷键。
- 不修改 `gitbook-docs.yaml`。

---

### Task 1: 新增 kubectl 日常操作速查

**Files:**
- Create: `cloud-native/kubernetes/kubectl-operations.md`

- [ ] **Step 1: 编写资源快速查看**

必须覆盖：
```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get deploy,statefulset,daemonset -A
kubectl get svc,ingress -A
kubectl get pvc,pv -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace>
kubectl exec -it <pod> -n <namespace> -- sh
```

- [ ] **Step 2: 最小解释对象关系**

用一张短文本链表示：
```text
Deployment/StatefulSet/DaemonSet → Pod → Container
Service → Pod
Ingress → Service
PVC → PV/StorageClass
```

只解释该关系对排障的意义。

- [ ] **Step 3: 加常见变更操作**

覆盖 rollout status/history/restart/undo、scale、edit/apply/diff、port-forward、cp；每个变更动作标注影响。

- [ ] **Step 4: Commit**

```bash
git add cloud-native/kubernetes/kubectl-operations.md
git commit -m "docs: add kubectl operations quick reference"
```

### Task 2: 新增 Kubernetes 逐层故障排查

**Files:**
- Create: `cloud-native/kubernetes/kubernetes-troubleshooting.md`

- [ ] **Step 1: 固定逐层排障模型**

```text
Node → Workload Controller → Pod → Container → Service → Endpoint/EndpointSlice → Ingress → Application
```

- [ ] **Step 2: 覆盖高频 Pod 状态**

至少覆盖 Pending、CrashLoopBackOff、ImagePullBackOff/ErrImagePull、OOMKilled、Evicted、Terminating 卡住、Readiness/Liveness 失败。

- [ ] **Step 3: 覆盖网络和存储**

包括 Service 无 endpoint、Ingress 404/502、DNS、CNI、PVC Pending、mount/permission 问题；只给现场诊断所需概念。

- [ ] **Step 4: 节点维护安全流程**

对 `cordon`、`drain`、`uncordon` 说明使用时机、PodDisruptionBudget/DaemonSet 等影响，禁止把 drain 写成无条件命令。

- [ ] **Step 5: Commit**

```bash
git add cloud-native/kubernetes/kubernetes-troubleshooting.md
git commit -m "docs: add Kubernetes troubleshooting quick reference"
```

### Task 3: 新增 Helm 速查

**Files:**
- Create: `cloud-native/kubernetes/helm-operations.md`

- [ ] **Step 1: 覆盖日常查询**

必须包含：
```bash
helm list -A
helm status <release> -n <namespace>
helm get values <release> -n <namespace> -a
helm get manifest <release> -n <namespace>
helm history <release> -n <namespace>
helm template <release> <chart>
```

- [ ] **Step 2: 覆盖安全升级与回退**

固定顺序：status/history/values → template 或 dry-run → upgrade → status → kubectl rollout/status/events → 必要时 rollback。

- [ ] **Step 3: Commit**

```bash
git add cloud-native/kubernetes/helm-operations.md
git commit -m "docs: add Helm operations quick reference"
```

### Task 4: 新增 K9s 速查

**Files:**
- Create: `cloud-native/kubernetes/k9s-operations.md`

- [ ] **Step 1: 覆盖启动与只读巡检**

包括普通启动、指定 kubeconfig/context/namespace，以及 `k9s --readonly` 或当前官方等价只读参数；实施时必须以最新 K9s 官方 CLI 文档核验参数。

- [ ] **Step 2: 覆盖高频交互**

至少写明：`:pods`、`:deploy`、`:svc`、`:nodes`、`:ns`、`:ctx`、日志、describe、shell、筛选、刷新、翻页/滚动、退出，以及进入 Pod 后返回 K9s 的操作。

- [ ] **Step 3: 区分只读与变更快捷键**

删除、重启、scale、edit 等动作单列风险区；不要把危险快捷键夹在普通浏览操作中。

- [ ] **Step 4: Commit**

```bash
git add cloud-native/kubernetes/k9s-operations.md
git commit -m "docs: add K9s operations quick reference"
```

### Task 5: 更新 Kubernetes 入口和导航

**Files:**
- Modify: `cloud-native/kubernetes/README.md`
- Modify: `SUMMARY.md`

- [ ] **Step 1: 增加四个入口**

README 保留现有范围说明，只增加 kubectl、排障、Helm、K9s 链接。

- [ ] **Step 2: 验证文件和导航**

Run:
```bash
for f in cloud-native/kubernetes/kubectl-operations.md cloud-native/kubernetes/kubernetes-troubleshooting.md cloud-native/kubernetes/helm-operations.md cloud-native/kubernetes/k9s-operations.md; do test -f "$f" || exit 1; done
grep -nE 'kubectl-operations|kubernetes-troubleshooting|helm-operations|k9s-operations' cloud-native/kubernetes/README.md SUMMARY.md
```

Expected: 四个页面均存在并进入导航。

- [ ] **Step 3: Commit**

```bash
git add cloud-native/kubernetes/README.md SUMMARY.md
git commit -m "docs: link Kubernetes operations quick references"
```
