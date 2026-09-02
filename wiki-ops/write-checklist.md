# Zwiki 写入前检查

本流程适用于人工、ChatGPT、Codex 或其他 AI Agent 对 Zwiki 的新增和修改操作。

## 1. 确认事实源

- GitHub `main` 是唯一事实源（SSOT）。
- GitBook 仅用于同步、展示和发布。
- 普通文章维护默认修改 GitHub Markdown，不直接在 GitBook 中维护正文。

## 2. 确认目标内容

写入前检查：

```text
□ 已确认目标分类和文件路径
□ 已搜索是否存在同主题或高度相关文章
□ 若已有文章，优先补充存量内容而不是重复新建
□ 已读取目标文章和 SUMMARY.md
□ 不会覆盖、移动、删除无关内容
□ 普通文章任务不会修改 gitbook-docs.yaml
□ 不包含密码、Token、Cookie、私钥、客户信息等敏感数据
```

可在本地仓库辅助检查：

```bash
git status
git log --oneline -5
grep -Rni "关键词" .
```

## 3. 用户提供 GitBook URL 时

例如用户直接提供：

```text
https://zwiki.gitbook.io/zwiki-docs/...
```

处理顺序：

1. 确认 URL 属于 Zwiki。
2. 获取页面路径和标题。
3. 在 `SUMMARY.md` 和 GitHub 仓库中查找对应 Markdown。
4. 确认唯一源文件后再修改。
5. 如果存在多个候选文件或无法确认，停止写入并向用户确认，不得猜测。
6. 修改 GitHub 源 Markdown，由 GitBook Git Sync 自动发布。

## 4. 新增文章

新增文章时：

1. 使用现有最匹配的一级分类；没有实际内容时不要提前创建空分类。
2. 文件名使用小写英文和连字符，例如 `check-disk-io-usage.md`。
3. 使用 `templates/` 中最接近的模板。
4. 新增文章后更新 `SUMMARY.md` 索引。
5. 仅在分类入口需要变化时修改对应 `README.md`。

## 5. 修改存量文章

修改已有文章时：

1. 保持文件路径不变，除非用户明确要求移动或重命名。
2. 只修改目标章节及必要的上下文。
3. 不重写无关章节。
4. 路径和导航未变化时，不修改 `SUMMARY.md`。

## 6. 脚本、配置和图片附件

附件应与文章一起进入 GitHub 版本控制。推荐结构：

```text
linux/
├── ubuntu22-kernel-security-hardening.md
└── assets/
    └── ubuntu22-kernel-security-hardening/
        ├── kernel-upgrade.sh
        └── grub-example.conf
```

Markdown 使用相对路径引用：

```md
- [内核升级脚本](assets/ubuntu22-kernel-security-hardening/kernel-upgrade.sh)
- [GRUB 配置示例](assets/ubuntu22-kernel-security-hardening/grub-example.conf)
```

图片同样使用相对路径：

```md
![网络拓扑](assets/waf-transparent-bridge/topology.png)
```

脚本附件在文章中应说明用途、适用环境、风险、验证方法和必要的回退方式。大型安装包、ISO、大日志和大型二进制文件不建议直接进入 Wiki 仓库，可放在 GitHub Release 或对象存储，并在文章中引用。

## 7. 写入前最终确认

执行写入前只需确认三件事：

> **找对文章、只改必要内容、确保可以通过 Git 历史恢复。**
