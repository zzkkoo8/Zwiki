# Zwiki 快速修改

Zwiki 以 **GitHub `main` 为唯一事实源**。阅读在 GitBook，修改最终回到 GitHub。

## 最快入口：Edit on GitHub

Zwiki 当前已启用 GitBook 的 **Edit on GitHub/GitLab** Page Action。读者可以从页面操作菜单直接进入该页面对应的 GitHub 源文件，不需要每篇 Markdown 手工维护“编辑本文”链接。

GitBook 设置路径：

```text
Docs site
  → Customization
  → Configure
  → Page actions
  → Edit on GitHub/GitLab
```

官方说明：

- https://gitbook.com/docs/publishing-documentation/customization/extra-configuration

## 小修改怎么做

适合错别字、少量命令、链接或一句描述：

```text
GitBook 页面
    ↓
Edit on GitHub
    ↓
GitHub Web Edit
    ↓
提交修改 / PR
    ↓
合并 main
    ↓
GitBook Git Sync 自动更新
```

## 中等修改怎么做

增加章节、补案例、整理流程时：

```text
让 AI / Codex 修改 GitHub Markdown
    ↓
PR 自动审核
    ↓
合并 main
    ↓
GitBook Git Sync
```

## 只想反馈错误

不会修改时直接提交 GitHub Issue，建议包含：

```text
页面地址：
问题描述：
正确内容或建议：
验证环境：
```

## 原则

- 不在 GitBook 和 GitHub 同时维护两份不同正文；
- 不为了改几个字做大规模重构；
- 不提交密码、Token、Cookie、私钥和未脱敏客户数据；
- GitBook 的 Edit on Git 负责“快速入口”，GitHub 负责最终版本和审计历史。
