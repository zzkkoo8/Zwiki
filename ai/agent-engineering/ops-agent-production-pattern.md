# 运维 Agent 生产闭环

运维 Agent 最安全的演进路线不是一开始获得 root 自动执行，而是先做到“能可靠诊断”，再逐步增加受控变更。

## 推荐闭环

~~~text
告警 / 人工请求
      ↓
收集只读证据
      ↓
诊断与根因候选
      ↓
Action Plan
      ↓
再次只读验证前置条件
      ↓
Risk Gate
   ├─ 低风险 → 自动执行
   └─ 高风险 → HITL
      ↓
执行
      ↓
业务验证
      ↓
失败 → 回滚 / 人工接管
      ↓
记录 Trajectory
      ↓
有效经验沉淀为 Skill / SOP
~~~

## 第一阶段：只读诊断

优先开放：

- 系统状态；
- 日志；
- Kubernetes GET/LIST/DESCRIBE；
- 监控指标；
- 配置读取；
- Git diff；
- 网络连通性检查。

目标是先证明 Agent 能稳定获取正确证据和定位问题。

## 第二阶段：受控写操作

写操作按风险分层：

| 操作 | 建议 |
| --- | --- |
| 创建临时诊断文件 | 可自动 |
| 提交 Git feature branch | 可自动并保留审计 |
| 重启测试环境单实例 | 条件自动 |
| 修改生产配置 | HITL |
| 批量重启/网络变更 | HITL + 小批量验证 |
| 删除数据/不可逆操作 | 默认禁止 |

任何自动变更都应具备：

~~~text
precheck
change
verify
rollback
audit
~~~

## 生产主机不要直接给无限 Shell

建议把常用运维能力封装为窄接口：

~~~text
inspect_host()
get_service_status()
get_logs()
restart_service(service, host)
rollback_release(release_id)
~~~

相比让模型自由拼接 root Shell，更容易做参数校验、审计、权限和回滚。

确实需要 Shell 时，使用 Sandbox / 跳板 / 临时凭据，并限制目标主机和允许动作。

## 批量运维

批量操作必须：

~~~text
1 台验证
  ↓
小批量
  ↓
观察
  ↓
全量
~~~

Agent 要记录每台主机的结果，失败节点不要因为总体任务“多数成功”而被忽略。

## 经验沉淀

真正值得进入 Skill/知识库的是：

- 已验证的诊断步骤；
- 可复现的故障模式；
- 明确的修复前置条件；
- 验证命令；
- 回滚方式。

不要把未经验证的一次模型猜测自动写成长期经验。

## 参考资料

- [第 6 章：受控执行、验证反馈与交付准备](https://github.com/aliyun/ai-agent-handbook/blob/main/02-build/%E7%AC%AC%206%20%E7%AB%A0%20%E8%A1%8C%E5%8A%A8%EF%BC%9A%E5%8F%97%E6%8E%A7%E6%89%A7%E8%A1%8C%E3%80%81%E9%AA%8C%E8%AF%81%E5%8F%8D%E9%A6%88%E4%B8%8E%E4%BA%A4%E4%BB%98%E5%87%86%E5%A4%87.md)
- [第 14 章：Agent 安全](https://github.com/aliyun/ai-agent-handbook/blob/main/04-governance/%E7%AC%AC%2014%20%E7%AB%A0%E3%80%80Agent%20%E5%AE%89%E5%85%A8.md)
- [第 23 章：受控自进化](https://github.com/aliyun/ai-agent-handbook/blob/main/05-optimization/%E7%AC%AC%2023%20%E7%AB%A0%E3%80%80%E5%8F%97%E6%8E%A7%E8%87%AA%E8%BF%9B%E5%8C%96.md)
- [第 27 章：吉利汽车智能运维的落地实践](https://github.com/aliyun/ai-agent-handbook/blob/main/06-case-study/%E7%AC%AC27%E7%AB%A0%20%E8%BF%90%E7%BB%B4%E3%80%81%E5%AE%89%E5%85%A8%E4%B8%8E%E4%BC%81%E4%B8%9AIT/%E5%90%89%E5%88%A9%E6%B1%BD%E8%BD%A6%E6%99%BA%E8%83%BD%E8%BF%90%E7%BB%B4%E7%9A%84%E8%90%BD%E5%9C%B0%E5%AE%9E%E8%B7%B5.md)

> 本文基于上述一手资料做工程化整理与归纳，不逐字复制原文。上游 ai-agent-handbook 使用 Apache-2.0 License；具体实现和产品能力以各项目当前官方文档为准。
