# Linux 离线软件安装速查

用于内网、隔离网 Linux 安装常用软件。最稳妥的方法只有一条：**在与目标机同发行版、同大版本、同架构的联网环境下载软件和全部依赖，再整体复制到内网安装。**

## 1. 目标机先确认系统

```bash
cat /etc/os-release
uname -m
```

再确认包管理器：

```bash
command -v dnf
command -v yum
command -v apt-get
command -v rpm
command -v dpkg
```

必须匹配：

```text
发行版/兼容生态 + 大版本 + CPU 架构 + 软件包格式 + 软件源
```

不要把不同发行版的 RPM/DEB 混装，也不要因为“都是 RPM”就跨版本强装。

## 2. RPM 系：下载软件和全部依赖

适用于 RHEL、Rocky、CentOS、部分麒麟等 RPM 生态。

联网机安装下载工具：

```bash
sudo dnf install -y dnf-plugins-core
```

下载常用软件及依赖：

```bash
mkdir -p /tmp/offline-rpms

dnf download \
  --resolve \
  --alldeps \
  --destdir /tmp/offline-rpms \
  tmux rsync python3
```

旧 YUM 环境可使用：

```bash
sudo yum install -y yum-utils
mkdir -p /tmp/offline-rpms

yumdownloader \
  --resolve \
  --destdir=/tmp/offline-rpms \
  tmux rsync python3
```

生成校验：

```bash
cd /tmp/offline-rpms
sha256sum *.rpm > SHA256SUMS
```

复制整个目录到内网主机后：

```bash
cd /path/to/offline-rpms
sha256sum -c SHA256SUMS
```

优先使用 DNF/YUM 做本地依赖检查：

```bash
sudo dnf install ./*.rpm
```

旧系统：

```bash
sudo yum localinstall ./*.rpm
```

不要把下面命令作为常规方案：

```text
rpm --nodeps
rpm --force
```

## 3. Debian / Ubuntu：下载软件和依赖

联网机先更新索引：

```bash
sudo apt-get update
```

创建独立缓存目录：

```bash
sudo mkdir -p /tmp/offline-debs/partial
```

只下载、不安装：

```bash
sudo apt-get \
  -o Dir::Cache::archives=/tmp/offline-debs \
  --download-only install \
  tmux rsync netcat-openbsd python3
```

生成校验：

```bash
cd /tmp/offline-debs
sha256sum *.deb > SHA256SUMS
```

复制整个目录到内网后：

```bash
cd /path/to/offline-debs
sha256sum -c SHA256SUMS
sudo apt install ./*.deb
```

如果仍提示缺依赖，回到联网环境补齐，不要在隔离网里反复执行会联网的修复命令。

> APT 会根据下载机当前已安装状态解析依赖。要做可复用离线包，最好使用与目标机同版本、同架构的干净 VM、chroot 或容器下载。

## 4. Python 缺失或版本过低

Ansible 大多数 Linux 模块需要目标机存在受支持的 Python。

先检查：

```bash
python3 --version
```

```bash
cat /etc/os-release
uname -m
```

### 优先方案：从目标系统自己的仓库下载

RPM 系先查看可用 Python：

```bash
dnf list --showduplicates 'python3*'
```

如果仓库提供需要的版本，例如 `python3.11`，联网机下载：

```bash
mkdir -p /tmp/python-rpms

dnf download \
  --resolve \
  --alldeps \
  --destdir /tmp/python-rpms \
  python3.11
```

实际包名以当前发行版仓库为准。

Debian / Ubuntu 同理，优先使用系统官方仓库提供的 Python 包：

```bash
apt-cache policy python3
```

下载：

```bash
sudo mkdir -p /tmp/python-debs/partial

sudo apt-get \
  -o Dir::Cache::archives=/tmp/python-debs \
  --download-only install \
  python3
```

### 不要覆盖系统 Python

如果旧系统自带 Python 3.7，而 Ansible 需要更高版本，优先并行安装：

```text
/usr/bin/python3       # 系统原版本
/usr/bin/python3.11    # 新装版本
```

然后在 Ansible Inventory 指定：

```ini
ansible_python_interpreter=/usr/bin/python3.11
```

不要随意修改 `/usr/bin/python3`、`alternatives` 或系统脚本依赖的默认 Python。

### 官方仓库没有合适版本怎么办

优先顺序：

1. 目标发行版官方仓库或企业镜像；
2. 该发行版官方支持的软件流/扩展仓库；
3. 已在同版本测试机验证的兼容包；
4. 最后才考虑从 Python 官方源码编译。

Python 官方源码下载：

- https://www.python.org/downloads/source/

源码编译本身还需要 GCC、make、OpenSSL、zlib、libffi 等开发依赖，因此离线环境通常不如使用发行版软件包省事。

## 5. Python pip 包离线下载

如果要离线安装 Python 第三方库，在与目标机**相同 Python 大版本、相同架构、尽量相同系统环境**的联网机执行：

```bash
python3 -m pip download \
  -d ./wheels \
  -r requirements.txt
```

将 `wheels/` 和 `requirements.txt` 复制到内网后：

```bash
python3 -m pip install \
  --no-index \
  --find-links=./wheels \
  -r requirements.txt
```

如果某个包只有源码分发而没有匹配的 wheel，离线主机仍可能需要编译环境；最好在联网侧提前确认下载结果。

## 6. 软件包从哪里获取

优先使用这些来源：

- 当前 Linux 发行版的官方仓库或企业内部镜像；
- 软件厂商自己的官方仓库；
- Python 源码：https://www.python.org/downloads/source/
- Python 第三方包：https://pypi.org/

不建议从随机 RPM/DEB 下载站拼依赖。

麒麟 V10 等国产 RPM 系统尤其要以目标机实际的 `/etc/os-release`、架构和已配置仓库为准，不要简单当作某个 CentOS/RHEL 版本直接混装。

## 7. 多台主机怎么做

只有少量主机时：

```text
联网机下载目录
    ↓
scp / U 盘 / 文件服务器
    ↓
内网 Linux 本地安装
```

如果几十、几百台主机长期需要离线安装，不要逐台复制包，应该建立内部 YUM/DNF/APT 软件仓库或镜像源，再由 Ansible 批量安装。

批量运维参考：[Linux 批量运维速查](linux-batch-operations.md)。

## 安装前最小检查

```text
□ 系统版本一致
□ CPU 架构一致
□ 软件包格式正确
□ 依赖来自同一套兼容仓库
□ SHA-256 校验通过
□ 没有盲目替换 glibc / OpenSSL / Python / systemd 等系统关键组件
```

## 官方资料

需要深入查参数时直接看官方文档：

- Ubuntu 软件包管理：https://ubuntu.com/server/docs/how-to/software/package-management/
- Red Hat DNF：https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_software_with_the_dnf_tool/
- RPM：https://rpm.org/documentation.html
- Debian dpkg：https://manpages.debian.org/dpkg
- Python 下载：https://www.python.org/downloads/
- pip download：https://pip.pypa.io/en/stable/cli/pip_download/
