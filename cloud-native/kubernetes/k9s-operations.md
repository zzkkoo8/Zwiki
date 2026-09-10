# K9s 日常运维速查

用于在终端中快速浏览 Kubernetes 资源、查看日志/Describe/YAML、进入 Pod 和切换 Namespace/Context。涉及生产巡检时优先使用只读模式。

## 快速启动

普通启动：

```bash
k9s
```

指定 Namespace：

```bash
k9s -n <namespace>
```

指定 Context：

```bash
k9s --context <context>
```

指定 kubeconfig 最稳妥的通用方式：

```bash
KUBECONFIG=/path/to/kubeconfig k9s
```

### 生产只读巡检

```bash
k9s --readonly
```

官方说明中 `--readonly` 会禁用修改类命令。注意：K9s 的只读 UI 不能替代 Kubernetes RBAC；生产账号仍应遵循最小权限原则。

## 必须知道

K9s 是 kubectl 的交互式资源浏览器，不是另一套 Kubernetes API。最重要的操作模式：

```text
:资源名     跳转资源视图
/关键词      过滤当前列表
?           查看当前界面有效快捷键
Esc         返回/退出当前模式
:q          退出 K9s
```

**不同 K9s 版本、资源类型和插件会改变可用快捷键，`?` 是当前界面的最终准确信息。**

## 1. 常用资源跳转

在 K9s 中输入：

```text
:pods
:deploy
:statefulset
:daemonset
:svc
:ingress
:nodes
:pvc
:ns
:ctx
```

常用短名通常也可用，例如 `:po`、`:dp`、`:svc`；如果不确定：

```text
Ctrl-A
```

查看当前可用资源别名。

## 2. Namespace

```text
:ns
```

进入 Namespace 列表后选择目标 namespace。

也可直接跳到某 namespace 的 Pod：

```text
:pod <namespace>
```

生产操作前始终确认顶部当前 Context/Namespace，避免在错误集群执行变更。

## 3. Context

```text
:ctx
```

选择另一个 Context。

也可：

```text
:ctx <context-name>
```

**切 Context 等于切换目标集群。** 切换后先重新确认集群名、namespace 和资源，再进行任何变更。

## 4. 搜索/过滤

当前列表按名称过滤：

```text
/<keyword>
```

反向过滤：

```text
/!<keyword>
```

Label 过滤：

```text
/-l app=<label>
```

取消过滤/命令模式：

```text
Esc
```

## 5. 查看 Pod 日志

进入 Pod：

```text
:pods
```

选中目标 Pod 后，当前官方默认键位中日志通常为：

```text
l
```

多容器 Pod 会要求选择 Container。

进入日志后可用 `?` 查看当前日志视图快捷键；返回上一层通常使用 `Esc`。

如果现场版本快捷键与本文不同，以 `?` 显示为准。

## 6. Describe / YAML

选中资源后：

```text
d    Describe
v    查看资源
```

部分版本/视图还提供 YAML 专用显示键位。不要死记所有键；按 `?` 查看当前资源视图的 `Describe/View YAML` 映射最可靠。

排障优先 Describe，因为 Events、Condition、调度/挂载错误通常比直接编辑 YAML 更有价值。

## 7. 进入 Pod Shell

进入：

```text
:pods
```

选中 Pod 后按 `?` 查当前版本的 `Shell` 键位；常见默认映射为：

```text
s
```

多容器 Pod 先选择 Container。

进入 shell 后这是容器内终端。返回 K9s：

```bash
exit
```

或：

```text
Ctrl-D
```

容器内临时修改文件不会自动回写 Deployment/Helm/GitOps，Pod 重建后通常丢失。

## 8. 查看 Node

```text
:nodes
```

选中节点后优先：

```text
d    Describe
```

重点看 Conditions、资源、taint 和运行 Pod。不要把 K9s Node Shell 当作默认巡检手段；是否允许进入节点取决于 K9s feature gate 和集群安全策略。

## 9. 翻页和查看长列表

资源列表/日志是 K9s 全屏 TUI，优先使用：

```text
↑ ↓           上下移动
PgUp / PgDn   快速翻页（终端支持时）
Home / End    跳转首尾（当前终端/版本支持时）
```

如果 Win11 CMD/SSH 客户端拦截 PageUp/PageDown，按 `?` 查看 K9s 当前键位，并检查终端自身滚动快捷键。不要把终端滚屏和 K9s 列表滚动混为一回事。

## 10. Port Forward

K9s 对支持的资源提供 Port Forward 操作，但具体快捷键应以当前视图：

```text
?
```

中的 `Port-Forward` 为准，因为版本/资源/自定义键位可能不同。

开始前确认本地监听端口、目标 Pod/Service 和 namespace。Port Forward 只适合临时诊断，不是生产暴露服务的方法。

如果 K9s 当前版本/策略不提供该动作，直接使用：

```bash
kubectl port-forward -n <namespace> pod/<pod> 8080:<port>
```

## 11. 退出 K9s

官方通用方式：

```text
:q
```

或：

```text
Ctrl-C
```

如果配置了 `noExitOnCtrlC`，Ctrl-C 可能不会退出，此时使用 `:q`。

进入 Pod shell 后必须先 `exit`/Ctrl-D 回到 K9s，再退出 K9s。

## 12. 变更类操作：单独看待

生产巡检推荐：

```bash
k9s --readonly
```

非只读模式可能提供：

```text
Edit
Delete
Kill
Scale
Restart/Rollout
Port Forward
```

官方默认键位明确包含：

```text
Ctrl-D    删除资源（有确认流程）
Ctrl-K    Kill/立即删除类动作，官方说明无确认对话框
```

**Ctrl-K 属高风险快捷键，不应在生产巡检中使用。**

对于 Deployment 重启、scale、delete 等动作，先退出只读模式并确认：

```text
Context / Namespace
工作负载 owner
副本数/PDB
数据持久化
变更回退方式
```

复杂变更建议改用明确可审计的 kubectl/Helm/GitOps 操作，而不是依赖快捷键。

## 13. K9s 出现问题

查看运行信息和配置目录：

```bash
k9s info
```

查看帮助：

```bash
k9s help
```

K9s 能看到什么、能操作什么最终取决于 kubeconfig 和 Kubernetes RBAC：

```bash
kubectl auth can-i get pods -A
kubectl auth can-i delete pods -n <namespace>
```

## 深入学习

- K9s Commands：https://k9scli.io/topics/commands/
- K9s Configuration：https://k9scli.io/topics/config/
- K9s RBAC：https://k9scli.io/topics/rbac/
- K9s 官方仓库：https://github.com/derailed/k9s
- kubectl 速查：[kubectl 日常运维速查](kubectl-operations.md)

## 反馈与修改

K9s 快捷键可能随版本、资源视图和自定义配置变化。本文只维护稳定入口；具体键位永远优先以当前界面的 `?` 和官方 Commands 页面为准。