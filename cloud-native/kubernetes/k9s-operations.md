# K9s 日常运维速查

K9s 是 kubectl 的交互式资源浏览器。日常最常用的动作只有：**切 Namespace / Context、找 Pod、看日志、Describe、进 Shell、退出。**

## 1. 启动

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

生产只读巡检：

```bash
k9s --readonly
```

`--readonly` 不能替代 Kubernetes RBAC，生产账号仍应使用最小权限。

## 2. 先记住这几个键

```text
:pods       Pod 列表
:deploy     Deployment
:svc        Service
:nodes      Node
:ns         Namespace
:ctx        Context
/关键词      过滤当前列表
?           当前界面快捷键
Esc         返回 / 退出当前模式
:q          退出 K9s
```

不同 K9s 版本、资源视图和自定义配置可能改变快捷键，**不确定就按 `?`**。

## 3. 看 Pod

```text
:pods
```

选中 Pod 后，常见默认操作：

```text
l    Logs
d    Describe
s    Shell
```

如果现场键位不同，以 `?` 显示为准。

多容器 Pod 会要求选择 Container。

进入 Shell 后返回 K9s：

```bash
exit
```

不要把容器内手工修改当长期修复，Pod 重建后通常会丢失。

## 4. 切 Namespace / Context

Namespace：

```text
:ns
```

Context：

```text
:ctx
```

**切 Context 就是切集群。** 做任何变更前重新确认顶部显示的 Context 和 Namespace。

## 5. 搜索和过滤

名称过滤：

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

按 `Esc` 退出过滤模式。

## 6. Node

```text
:nodes
```

选中节点后优先 `Describe`，重点看：

```text
Conditions
CPU / Memory
Taints
Pod 数量
DiskPressure / MemoryPressure
```

节点问题继续使用 kubectl 和宿主机命令确认，不依赖 K9s 一个界面完成全部诊断。

## 7. 高风险快捷键

非只读模式可能提供：

```text
Delete
Kill
Scale
Restart / Rollout
Edit
```

生产巡检优先：

```bash
k9s --readonly
```

尤其不要误按立即删除类快捷键。复杂变更优先使用明确、可审计的 kubectl / Helm / GitOps 流程。

## 8. K9s 自身异常

```bash
k9s info
k9s help
```

检查实际 Kubernetes 权限：

```bash
kubectl auth can-i get pods -A
kubectl auth can-i delete pods -n <namespace>
```

如果 K9s 看不到资源或不能操作，先确认 kubeconfig、Context 和 RBAC。

## 最短操作路径

```text
k9s --readonly
     ↓
:ctx / :ns 确认环境
     ↓
:pods
     ↓
l 看日志 / d Describe
     ↓
必要时 s 进入 Shell
     ↓
:q 退出
```

## 官方资料

- K9s Commands：https://k9scli.io/topics/commands/
- K9s Configuration：https://k9scli.io/topics/config/
- K9s 官方仓库：https://github.com/derailed/k9s
- kubectl 操作：[kubectl 日常运维速查](kubectl-operations.md)
