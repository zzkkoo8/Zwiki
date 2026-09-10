# Helm 日常运维速查

用于 Kubernetes 中查看 Helm Release、核对 values、升级前预览、升级后验证以及必要时回退。本文以 Helm 3 常见操作为主。

## 快速检查

```bash
helm version
helm list -A
helm status <release> -n <namespace>
helm get values <release> -n <namespace> -a
helm get manifest <release> -n <namespace>
helm history <release> -n <namespace>
```

## 必须知道

- **Chart**：应用部署模板包。
- **Release**：某个 Chart 在集群中的一次安装实例。
- **Values**：渲染模板的输入配置。
- **Revision**：Release 每次 install/upgrade 形成的历史版本。

生产变更最重要的是：**先确认当前 Release、values 和历史，再渲染/预览，再 upgrade，最后用 Helm + kubectl 双重验证。**

## 1. 找 Release

```bash
helm list -A
```

指定 namespace：

```bash
helm list -n <namespace>
```

查看状态：

```bash
helm status <release> -n <namespace>
```

## 2. 查看当前 Values

仅看用户设置值：

```bash
helm get values <release> -n <namespace>
```

包含计算后的全部值：

```bash
helm get values <release> -n <namespace> -a
```

输出可能包含密码、Token、内部地址等敏感信息，不要直接提交到公开 Wiki/Issue。

## 3. 查看实际 Manifest

```bash
helm get manifest <release> -n <namespace>
```

用于确认当前 Release 实际向 Kubernetes 提交了哪些资源。

## 4. 查看历史

```bash
helm history <release> -n <namespace>
```

升级或 rollback 前必须先确认当前 revision、历史 revision 和状态。

## 5. 本地渲染 Chart

```bash
helm template <release> <chart>
```

带 values：

```bash
helm template <release> <chart> -f values.yaml
```

指定 namespace：

```bash
helm template <release> <chart> -n <namespace> -f values.yaml
```

`helm template` 只做本地模板渲染，不代表集群 API、CRD、权限或运行时一定通过。

## 6. 升级前固定检查

```bash
helm status <release> -n <namespace>
helm history <release> -n <namespace>
helm get values <release> -n <namespace> -a
```

然后至少做一种预览：

```bash
helm template <release> <chart> -n <namespace> -f values.yaml
```

或根据当前 Helm 版本使用 `helm upgrade --dry-run`：

```bash
helm upgrade <release> <chart> -n <namespace> -f values.yaml --dry-run
```

注意：dry-run 输出可能包含渲染后的 Secret 数据，应按敏感信息处理。

## 7. Upgrade：变更操作

执行前确认：

```text
□ 当前 context/namespace 正确
□ Release 名称正确
□ 当前 values 已保存/可追溯
□ Chart 版本明确
□ template/dry-run 无明显异常
□ 数据库/CRD 等升级兼容性已确认
□ 有可执行回退路径
```

执行示例：

```bash
helm upgrade <release> <chart> -n <namespace> -f values.yaml
```

升级后：

```bash
helm status <release> -n <namespace>
helm history <release> -n <namespace>
kubectl get pods -n <namespace> -o wide
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

涉及 Deployment：

```bash
kubectl rollout status deployment/<name> -n <namespace>
```

Helm 显示 deployed 不等于业务完全健康，还要检查 Pod Ready、Service/Ingress 和业务探测。

## 8. Rollback：高影响变更

先查看：

```bash
helm history <release> -n <namespace>
helm status <release> -n <namespace>
```

确认目标 revision 后：

```bash
helm rollback <release> <revision> -n <namespace>
```

随后：

```bash
helm status <release> -n <namespace>
helm history <release> -n <namespace>
kubectl get pods -n <namespace>
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

**风险**：Helm rollback 只处理 Helm 管理的 Kubernetes 资源历史，不保证数据库 schema、外部存储、消息格式或其他外部依赖自动回退。执行前必须确认应用自己的回退要求。

## 9. 查看 Chart 信息

本地/仓库 Chart：

```bash
helm show chart <chart>
helm show values <chart>
```

仓库：

```bash
helm repo list
helm repo update
helm search repo <keyword>
```

升级生产前不要只写 `chart:latest` 思路，明确 Chart 版本并保留可追溯记录。

## 10. Release 看起来正常但 Pod 异常

Helm 用于发布状态，运行时继续用 kubectl：

```bash
helm status <release> -n <namespace>
kubectl get pods -n <namespace> -o wide
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> --all-containers --tail=200
```

继续参考 [Kubernetes 故障排查速查](kubernetes-troubleshooting.md)。

## 11. 不建议现场直接做的事

```text
helm uninstall <release>
helm rollback <release> <revision>
helm upgrade --force ...
```

都不是“服务异常”的默认修复动作。尤其 uninstall 可能删除 Helm 管理资源；PVC/外部数据是否保留取决于 Chart 和资源策略。必须先看 manifest、历史和业务数据保护策略。

## 深入学习

- Helm CLI：https://helm.sh/docs/helm/helm/
- helm status：https://helm.sh/docs/helm/helm_status/
- helm get values：https://helm.sh/docs/helm/helm_get_values/
- helm history：https://helm.sh/docs/helm/helm_history/
- helm upgrade：https://helm.sh/docs/helm/helm_upgrade/
- helm rollback：https://helm.sh/docs/helm/helm_rollback/
- helm template：https://helm.sh/docs/helm/helm_template/

## 反馈与修改

本文只维护 Helm 值班高频操作；Chart 开发、模板函数全集等开发类知识直接使用 Helm 官方文档。