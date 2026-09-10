# Linux 在线/离线软件包管理速查

用于内网、隔离网主机安装常用软件时，先确认系统和架构，再在匹配的联网环境下载软件及依赖，校验后离线安装。不要仅凭“看起来像 CentOS/Ubuntu”混装软件包。

## 快速处理

### 目标机先确认系统

```bash
cat /etc/os-release
uname -m
rpm --eval '%{_arch}' 2>/dev/null || true
dpkg --print-architecture 2>/dev/null || true
```

再确认当前包管理器：

```bash
command -v dnf
command -v yum
command -v rpm
command -v apt-get
command -v dpkg
```

必须至少匹配：

```text
发行版/兼容生态 + 大版本 + CPU 架构 + 软件包格式 + 依赖仓库
```

推荐在**与目标机同发行版、同大版本、同架构**的联网主机、虚拟机或 chroot/container 环境下载依赖，然后整体搬入内网。

## 必须知道

- **RPM 与 DEB 不能混装**：RHEL/Rocky/CentOS/部分麒麟使用 RPM 生态；Ubuntu/Debian 使用 DEB。
- **包格式相同也不代表兼容**：glibc、OpenSSL、Python、systemd 等基础依赖版本不同，仍可能安装失败或运行异常。
- **DNF/APT 负责依赖解析，rpm/dpkg 更底层**：离线安装优先让高层包管理器读取本地包并检查依赖，不建议无视依赖强装。
- **麒麟 V10 等兼容发行版**：必须以目标机 `/etc/os-release` 的 `ID`、`ID_LIKE`、版本、仓库和架构为准，不能简单按“CentOS 7/8”猜测。

## 1. RPM 系：查询与验证

查看系统：

```bash
cat /etc/os-release
rpm --eval '%{_arch}'
rpm --version
```

查看包是否安装：

```bash
rpm -q <package>
rpm -qa | grep -i <keyword>
```

查看包信息：

```bash
rpm -qi <package>
rpm -qf /path/to/file
```

查看本地 RPM 元数据：

```bash
rpm -qpi ./package.rpm
rpm -qpR ./package.rpm
```

校验 RPM 签名/摘要：

```bash
rpm -K ./package.rpm
```

另外建议对交付目录保存 SHA-256：

```bash
sha256sum *.rpm > SHA256SUMS
sha256sum -c SHA256SUMS
```

## 2. RPM 系：联网侧下载软件和依赖

### DNF 环境

安装下载插件（不同发行版包名可能有差异）：

```bash
dnf install dnf-plugins-core
```

创建目录：

```bash
mkdir -p /tmp/offline-rpms
```

下载目标包及依赖：

```bash
dnf download --resolve --alldeps --destdir /tmp/offline-rpms <package>
```

如果目标系统启用了特定 repo，联网下载环境也必须使用相同或兼容 repo。先确认：

```bash
dnf repolist
dnf info <package>
```

### 旧 YUM 环境

部分系统使用 `yum-utils` 提供 `yumdownloader`：

```bash
yum install yum-utils
mkdir -p /tmp/offline-rpms
yumdownloader --resolve --destdir=/tmp/offline-rpms <package>
```

在实际发行版中先确认命令是否存在，不要为了使用某条文档命令强行替换系统包管理器。

## 3. RPM 系：离线安装

将整个 RPM 目录复制到目标机后先校验：

```bash
cd /path/to/offline-rpms
sha256sum -c SHA256SUMS
rpm -K ./*.rpm
```

有 DNF 时优先：

```bash
dnf install ./*.rpm
```

旧 YUM：

```bash
yum localinstall ./*.rpm
```

如果依赖不完整，先回联网侧补齐，不建议使用 `rpm --nodeps` 绕过依赖检查。

查看历史（系统支持时）：

```bash
dnf history
yum history
```

安装后验证：

```bash
rpm -q <package>
<command> --version
```

## 4. Debian / Ubuntu：查询与验证

系统和架构：

```bash
cat /etc/os-release
dpkg --print-architecture
```

已安装包：

```bash
dpkg -l | grep -i <keyword>
apt-cache policy <package>
```

查看 DEB 信息和依赖：

```bash
dpkg-deb -I ./package.deb
```

检查包数据库状态：

```bash
dpkg --audit
```

无输出通常表示没有发现半安装/未配置完成的软件包。

## 5. Debian / Ubuntu：联网侧下载

### 只下载单个包

```bash
apt-get download <package>
```

这只下载指定包，不等价于打包完整依赖。

### 下载安装所需依赖

最稳妥方式是在与目标机**同 Ubuntu/Debian 版本、同架构、相同软件源状态**的干净环境中执行下载。

先更新索引：

```bash
sudo apt-get update
```

创建专用缓存目录：

```bash
mkdir -p /tmp/offline-debs/partial
```

仅下载、不安装：

```bash
sudo apt-get -o Dir::Cache::archives=/tmp/offline-debs --download-only install <package>
```

注意：APT 会根据下载机当前已安装状态解析依赖。如果要建立可复用离线库，最好使用干净 VM/chroot/container，确保环境与目标机一致，避免某些依赖因下载机已安装而没有被保存。

生成校验：

```bash
cd /tmp/offline-debs
sha256sum ./*.deb > SHA256SUMS
```

## 6. Debian / Ubuntu：离线安装

复制目录后：

```bash
cd /path/to/offline-debs
sha256sum -c SHA256SUMS
```

APT 可用时优先让它解析本地包：

```bash
sudo apt install ./*.deb
```

如果完全没有可用仓库且本地依赖已全部准备好，也可以：

```bash
sudo dpkg -i ./*.deb
```

随后检查：

```bash
dpkg --audit
apt-cache policy <package>
<command> --version
```

如果 `dpkg -i` 报依赖缺失，不要直接执行会联网的修复命令；先记录缺失依赖，在联网侧补齐对应 DEB。

## 7. 麒麟 V10 / 国产 RPM 系统

先采集：

```bash
cat /etc/os-release
uname -m
rpm --eval '%{_arch}'
rpm -E '%{rhel}' 2>/dev/null || true
dnf repolist 2>/dev/null || yum repolist 2>/dev/null
```

重点看：

```text
ID
ID_LIKE
VERSION_ID
架构（x86_64/aarch64 等）
已启用仓库
基础库版本
```

原则：

1. 优先使用同版本麒麟官方仓库或企业内镜像源。
2. 其次使用已经在该系统实测过的兼容仓库。
3. 不因为 `rpm` 包能解包，就认为 RHEL/CentOS/Rocky 的任意版本 RPM 都可直接安装。
4. Python、OpenSSL、glibc、kernel、systemd 等基础组件尤其不能跨发行版盲装。

## 8. 安装前统一检查清单

```text
□ /etc/os-release 已记录
□ CPU 架构一致
□ 软件包格式正确（RPM/DEB）
□ 软件版本适配目标系统
□ 依赖包来自相同或兼容仓库
□ SHA-256 校验通过
□ RPM 包签名/摘要检查通过（RPM 场景）
□ 已确认安装是否会升级/替换系统关键依赖
□ 有回退包或快照/备份
```

查看 RPM 安装计划时，不确认前不要输入 `y`；DNF/YUM 会展示将安装、升级或移除的包。

Ubuntu/Debian 同理，先看 APT 计划：

```bash
apt-get -s install ./package.deb
```

## 9. 安装失败如何处理

### RPM

查看依赖：

```bash
rpm -qpR ./package.rpm
```

查看事务历史：

```bash
dnf history 2>/dev/null || yum history 2>/dev/null
```

不要把下面命令作为常规修复：

```text
rpm --nodeps
rpm --force
```

它们会绕过依赖或覆盖保护，容易把系统留在不可维护状态。

### DEB

```bash
dpkg --audit
dpkg -l | grep '^..r\|^..U\|^..F\|^..H'
tail -n 100 /var/log/dpkg.log
```

有联网仓库时可按 APT 提示修复依赖；隔离网环境应先把缺失包补齐再继续。

## 回退

软件安装/升级前先确认旧版本包是否可获得。涉及系统关键组件时优先做虚拟机快照、系统备份或在测试机验证。

RPM 系可通过历史确认事务：

```bash
dnf history
```

不要假设所有事务都能安全自动 `undo`；内核、数据库、配置迁移等需按组件自己的回退流程处理。

Debian/Ubuntu 可通过：

```bash
apt-cache policy <package>
```

确认仓库是否仍保留旧版本，再按该软件的兼容要求降级。不要把强制降级作为通用命令。

## 深入学习

- Ubuntu Server 软件包管理：https://ubuntu.com/server/docs/how-to/software/package-management/
- Ubuntu Server 软件管理教程：https://ubuntu.com/server/docs/tutorial/managing-software/
- Red Hat RHEL 9 DNF 软件管理：https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_software_with_the_dnf_tool/
- RPM 项目：https://rpm.org/documentation.html
- Debian dpkg 手册：https://manpages.debian.org/dpkg

## 反馈与修改

本文维护通用离线包流程。某个产品需要固定软件清单、指定仓库或完整离线介质时，应建立该产品自己的部署文档，并链接本文的系统匹配与校验规则。