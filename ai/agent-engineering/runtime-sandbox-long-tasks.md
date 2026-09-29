# Runtime、Sandbox 与长任务

需要 Shell、文件、浏览器、异步等待或小时级任务时，必须把“Agent 怎么决策”和“任务在哪里运行”拆开。

## 责任边界

| 层 | 主要责任 |
| --- | --- |
| Harness | 下一步做什么、上下文、工具、权限、验证 |
| Runtime | 任务调度、并发、等待、超时、恢复、事件 |
| Sandbox | 文件、进程、网络、Secret 和资源隔离 |
| Environment | 实际代码库、浏览器、企业系统或工作区 |

Sandbox 不是 Runtime；Runtime 也不是 Harness。

## 推荐结构

~~~text
Client / Trigger
      ↓
Harness
      ↓
Runtime ── Task State / Checkpoint
      ↓
Executor
      ↓
Sandbox
 ├─ Shell
 ├─ Files
 ├─ Python
 └─ Browser
~~~

生产环境不要默认让 Agent 在 Harness 服务宿主机上直接运行任意 Shell。

## 长任务最小状态

至少持久化：

~~~text
task_id
session_id
status
stage
checkpoint
tool_calls
pending_approval
artifacts
retry_count
last_error
~~~

要求：

- 任务中断后可以继续；
- 重试不会重复产生高风险副作用；
- 等待审批时不占用一个永久阻塞进程；
- 超时能明确进入失败、重试或人工处理状态；
- 最终 Artifact 可重新取得。

## 同步和异步的分界

适合同步：

- 秒级查询；
- 单次 RAG；
- 少量只读工具调用。

适合异步：

- 大型代码修改；
- 批量分析；
- 长时间测试；
- 等待第三方结果；
- 人工审批；
- 多阶段运维任务。

异步任务至少提供：

~~~text
submit
status
events/progress
continue
cancel
result
~~~

## Sandbox 要限制什么

最低关注：

- 工作目录；
- 可读写文件；
- 网络出站；
- 环境变量和 Secret；
- CPU / 内存 / 磁盘；
- 执行时长；
- 是否允许提权；
- 清理策略。

对于生产运维，最好把“观察环境”和“执行变更环境”进一步分开。

## 参考资料

- [第 7 章：Agent 运行时与沙箱](https://github.com/aliyun/ai-agent-handbook/blob/main/03-run/%E7%AC%AC%207%20%E7%AB%A0%20%20Agent%20%E8%BF%90%E8%A1%8C%E6%97%B6%E4%B8%8E%E6%B2%99%E7%AE%B1.md)
- [第 8 章：Agent 状态存储与语义资产](https://github.com/aliyun/ai-agent-handbook/blob/main/03-run/%E7%AC%AC%208%20%E7%AB%A0%20Agent%20%E7%8A%B6%E6%80%81%E5%AD%98%E5%82%A8%E4%B8%8E%E8%AF%AD%E4%B9%89%E8%B5%84%E4%BA%A7.md)
- [第 10 章：Agent 异步任务与自动化流程](https://github.com/aliyun/ai-agent-handbook/blob/main/03-run/%E7%AC%AC%2010%20%E7%AB%A0%20%20Agent%20%E5%BC%82%E6%AD%A5%E4%BB%BB%E5%8A%A1%E4%B8%8E%E8%87%AA%E5%8A%A8%E5%8C%96%E6%B5%81%E7%A8%8B.md)

> 本文基于上述一手资料做工程化整理与归纳，不逐字复制原文。上游 ai-agent-handbook 使用 Apache-2.0 License；具体实现和产品能力以各项目当前官方文档为准。
