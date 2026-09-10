# 快速修改与反馈入口

Zwiki 采用 **GitHub 唯一事实源**。

GitBook 用于阅读、搜索和发布；正文修改最终必须进入 GitHub，再通过 Git Sync 发布。

## 修改入口选择

根据修改规模选择不同方式：

| 类型 | 适合场景 | 推荐方式 |
| --- | --- | --- |
| 小修改 | 错别字、命令少字符、链接修正、描述优化 | GitHub Web Edit → PR → 自动审核 |
| 中等修改 | 增加章节、优化流程、补充案例 | AI Agent 修改 GitHub Markdown → PR |
| 大规模修改 | 目录调整、批量迁移、规范变化 | 先设计方案，再批量修改 |
| 外部反馈 | 读者发现错误但不会修改 | GitHub Issue 文档纠错 |

## 快速修改流程

```text
GitBook 页面发现问题
        ↓
定位对应 GitHub Markdown
        ↓
GitHub Web Edit 或 AI 修改
        ↓
提交 PR
        ↓
AI 自动审核
        ↓
合并 main
        ↓
GitBook Git Sync 发布
```

## GitBook 页面如何定位源码

不要根据 URL 猜文件路径。

正确流程：

```text
GitBook URL
    ↓
读取页面 metadata / git.path
    ↓
确认 GitHub Markdown 源文件
    ↓
读取 SUMMARY.md 验证导航位置
    ↓
修改 GitHub 文件
```

## 三类反馈方式

### 页面体验反馈

适合：

- 内容是否有帮助；
- 阅读体验问题；
- 建议补充方向。

使用 GitBook 页面反馈。

### 文档错误反馈

适合：

- 命令错误；
- 链接失效；
- 描述过期；
- 实际环境无法验证。

提交 GitHub Issue，并填写：

```text
页面地址：
问题描述：
建议修改：
验证环境：
```

### 直接贡献修改

如果知道正确修改方式：

```text
Fork / Branch
    ↓
修改 Markdown
    ↓
Pull Request
    ↓
AI Review
    ↓
Merge
```

## 禁止事项

- 不直接修改 GitBook 正文作为最终结果；
- 不复制同一篇文章到多个目录；
- 不为了小修改创建复杂重构；
- 不提交密码、Token、Cookie、私钥等敏感信息。
