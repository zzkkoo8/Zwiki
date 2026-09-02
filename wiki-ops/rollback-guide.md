# Zwiki 错误回退与恢复

当 Zwiki 写入后发现文章、索引或 GitBook 配置有误时，优先从 GitHub 历史恢复。GitHub `main` 是唯一事实源，GitBook 应随 GitHub 恢复结果重新同步。

> 默认优先使用 `git revert` 或“恢复指定文件后新增恢复提交”。不建议使用 `reset --hard` 配合 `git push --force` 改写 `main` 历史。

## 1. 回退一个错误提交

先定位最近提交：

```bash
git log --oneline -10
```

查看错误提交改了什么：

```bash
git show <错误提交SHA>
```

确认后执行：

```bash
git revert <错误提交SHA>
git push origin main
```

预期结果：Git 新增一条反向提交，撤销错误变更，同时保留完整历史。GitBook 随 GitHub Git Sync 恢复。

## 2. 连续多个提交都错误

先查看历史：

```bash
git log --oneline -20
```

假设错误提交为：

```text
aaaa111 错误提交3
bbbb222 错误提交2
cccc333 错误提交1
dddd444 最后正常状态
```

通常从最新错误提交向前逐个撤销：

```bash
git revert aaaa111
git revert bbbb222
git revert cccc333
git push origin main
```

每次 `revert` 如出现冲突，应先处理冲突并确认结果，再继续下一条，不要盲目连续执行。

## 3. 只恢复某一篇文章

先查看该文件历史：

```bash
git log --oneline -- linux/example.md
```

查看正常版本：

```bash
git show <GOOD_SHA>:linux/example.md
```

恢复指定版本到工作区：

```bash
git restore --source=<GOOD_SHA> -- linux/example.md
```

检查并提交：

```bash
git diff -- linux/example.md
git add linux/example.md
git commit -m "revert: restore article"
git push origin main
```

## 4. `SUMMARY.md` 被改乱

查看其历史：

```bash
git log --oneline -- SUMMARY.md
```

恢复已知正常版本：

```bash
git restore --source=<GOOD_SHA> -- SUMMARY.md
git diff -- SUMMARY.md
git add SUMMARY.md
git commit -m "revert: restore SUMMARY navigation"
git push origin main
```

恢复后确认 `SUMMARY.md` 中引用的页面路径仍然存在。

## 5. `gitbook-docs.yaml` 被错误修改

普通文章任务不应修改该文件。如果 Site Structure 被错误修改：

```bash
git log --oneline -- gitbook-docs.yaml
git show <GOOD_SHA>:gitbook-docs.yaml
git restore --source=<GOOD_SHA> -- gitbook-docs.yaml
git diff -- gitbook-docs.yaml
```

确认无误后：

```bash
git add gitbook-docs.yaml
git commit -m "revert: restore GitBook site configuration"
git push origin main
```

随后等待或触发 GitBook Git Sync，确认公开站点结构恢复。

## 6. GitHub 正确，但 GitBook 页面显示异常

如果 GitHub `main` 中 Markdown、`SUMMARY.md` 和 `gitbook-docs.yaml` 都正确，不要为了修复展示问题再次改正文。

检查顺序：

1. 确认 GitHub `main` 最新提交内容正确。
2. 检查 GitBook Git Sync 状态和最近同步结果。
3. 等待或重新触发同步。
4. 若仍异常，再排查 GitBook 的 Site Structure、Customize 或缓存相关设置。

## 7. 在 GitHub Web 页面手动恢复

不方便使用命令行时，可以通过 GitHub 网页完成恢复：

1. 打开仓库的 **Commits** 历史。
2. 找到错误提交，先查看 **Files changed** 确认影响范围。
3. 如果 GitHub 页面提供 **Revert** 操作，可创建反向提交或 Pull Request 后合并。
4. 如果只需恢复单个文件，打开该文件的 **History**，找到最后正常版本，复制正常内容覆盖当前文件并提交一条恢复 commit。
5. 提交后检查 GitBook 是否完成同步。

网页回退和命令行回退遵循同一原则：**新增恢复提交，不强制改写 `main` 历史。**

## 8. 回退后的验收

至少检查：

```bash
git status
git log --oneline -5
```

并确认：

```text
□ 目标文章恢复正确
□ SUMMARY.md 导航正常
□ 无意外删除或移动其它文章
□ gitbook-docs.yaml 未被无关修改
□ GitBook 已同步到 GitHub 当前状态
```
