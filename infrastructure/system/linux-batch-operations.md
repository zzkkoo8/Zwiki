# Linux 批量运维速查

用于从 Windows、Linux 或 macOS 批量管理 Linux 主机。只记最常用方案：**临时执行用 SSH；重复、批量、需要分组和控制风险时用 Ansible。**

## 直接选方案

| 场景 | 最简方案 |
| --- | --- |
| 临时操作 2～10 台 | SSH + PowerShell/Shell 循环 |
| 经常管理多台 Linux | Ansible |
| Windows 长期批量运维 | Windows SSH 到 Linux 控制机运行 Ansible；WSL 适合个人测试 |
| Linux / macOS 长期运维 | 直接运行 Ansible |
| 需要 Web UI、定时、审批 | 在 Ansible 上增加 Semaphore / AWX / Rundeck |

以下假设有 10 台 Linux：`192.168.1.101` ～ `192.168.1.110`。

## 1. Ansible 最快用法

### 1.1 Inventory 直接写账号密码

临时环境、测试环境需要最快跑起来时，可以直接写密码。

`inventory.ini`：

```ini
[linux]
node01 ansible_host=192.168.1.101
node02 ansible_host=192.168.1.102
node03 ansible_host=192.168.1.103
node04 ansible_host=192.168.1.104
node05 ansible_host=192.168.1.105
node06 ansible_host=192.168.1.106
node07 ansible_host=192.168.1.107
node08 ansible_host=192.168.1.108
node09 ansible_host=192.168.1.109
node10 ansible_host=192.168.1.110

[linux:vars]
ansible_user=root
ansible_password=CHANGE_ME
```

如果使用普通用户 + sudo：

```ini
[linux:vars]
ansible_user=ops
ansible_password=CHANGE_ME
ansible_become=true
ansible_become_method=sudo
ansible_become_password=CHANGE_ME
```

这是**最简单但不安全**的方式，只适合本地临时文件：

```bash
chmod 600 inventory.ini
```

不要把含密码的 Inventory 提交到 Git。长期使用改成 SSH Key 或 `ansible-vault`。

### 1.2 先验证 SSH，不依赖 Python

`raw` 模块可以在目标 Linux 没有 Python 时工作：

```bash
ansible linux -i inventory.ini -m ansible.builtin.raw -a 'hostname; command -v python3 || true; python3 --version 2>/dev/null || true'
```

只要 SSH、账号和密码正常，就能看到每台主机结果。

### 1.3 Python 正常后测试 Ansible

```bash
ansible linux -i inventory.ini -m ansible.builtin.ping
```

全部返回 `SUCCESS` 后再执行批量任务。

## 2. 目标机没有 Python

Ansible 大多数 Linux 模块需要目标机存在受支持的 Python；`raw` 是常用引导手段。

### RPM 系：RHEL / Rocky / CentOS / 部分麒麟

```bash
ansible linux -i inventory.ini -m ansible.builtin.raw -a 'dnf install -y python3' -b
```

旧系统只有 YUM：

```bash
ansible linux -i inventory.ini -m ansible.builtin.raw -a 'yum install -y python3' -b
```

### Debian / Ubuntu

```bash
ansible linux -i inventory.ini -m ansible.builtin.raw -a 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3' -b
```

安装后：

```bash
ansible linux -i inventory.ini -m ansible.builtin.ping
```

## 3. Python 版本太低

先查看控制端 Ansible 和远端 Python：

```bash
ansible --version
```

```bash
ansible linux -i inventory.ini -m ansible.builtin.raw -a 'python3 --version 2>/dev/null || python --version 2>/dev/null || true'
```

截至 2026-09，`ansible-core 2.21` 的目标 Linux Python 支持范围是 **3.9～3.14**。不同 Ansible 版本要求不同，升级前查看官方支持矩阵：

- https://docs.ansible.com/projects/ansible/latest/reference_appendices/release_and_maintenance.html

如果系统自带 Python 太老，例如 Python 3.7，**不要直接替换系统 Python**。优先并行安装一个新版本，例如：

```text
/usr/bin/python3       # 系统原 Python，保持不动
/usr/bin/python3.11    # 新装给 Ansible 使用
```

然后在 Inventory 指定：

```ini
[linux:vars]
ansible_python_interpreter=/usr/bin/python3.11
```

测试：

```bash
ansible linux -i inventory.ini -m ansible.builtin.ping
```

内网主机无法在线安装时，按 [Linux 离线软件安装速查](linux-offline-package-management.md) 在同版本、同架构联网环境下载 Python 和依赖，再复制进内网安装。

## 4. 常用批量命令

查看运行时间：

```bash
ansible linux -i inventory.ini -m ansible.builtin.command -a 'uptime'
```

查看系统、磁盘和内存：

```bash
ansible linux -i inventory.ini -m ansible.builtin.shell -a 'cat /etc/os-release; df -hT; free -h'
```

控制并发为 5：

```bash
ansible linux -i inventory.ini -m ansible.builtin.command -a 'uptime' -f 5
```

只操作一台：

```bash
ansible node01 -i inventory.ini -m ansible.builtin.command -a 'uptime'
```

复制文件：

```bash
ansible linux -i inventory.ini \
  -m ansible.builtin.copy \
  -a 'src=./check.sh dest=/tmp/check.sh mode=0755'
```

直接下发并执行本地脚本：

```bash
ansible linux -i inventory.ini \
  -m ansible.builtin.script \
  -a './check.sh'
```

安装软件：

```bash
ansible linux -i inventory.ini \
  -b \
  -m ansible.builtin.package \
  -a 'name=tmux state=present'
```

## 5. 有变更的任务：先 1 台，再分批

`check.yml`：

```yaml
---
- name: Linux batch check
  hosts: linux
  gather_facts: false
  serial: 2

  tasks:
    - name: Check uptime
      ansible.builtin.command: uptime
      changed_when: false
```

先测试 1 台：

```bash
ansible-playbook -i inventory.ini check.yml --limit node01
```

确认后执行全部：

```bash
ansible-playbook -i inventory.ini check.yml
```

`serial: 2` 表示每批只处理 2 台。升级、重启、配置修改等任务建议固定使用这种方式。

## 6. Windows 最简批量命令

Windows 11 自带 OpenSSH Client 的情况下，PowerShell 可以直接使用 SSH。

先生成 10 台主机列表：

```powershell
101..110 | ForEach-Object { "192.168.1.$_" } | Set-Content .\hosts.txt
```

顺序执行：

```powershell
Get-Content .\hosts.txt | ForEach-Object {
    ssh "root@$_" "hostname; uptime"
}
```

PowerShell 7 并发执行：

```powershell
Get-Content .\hosts.txt | ForEach-Object -Parallel {
    ssh "root@$_" "hostname; uptime"
} -ThrottleLimit 5
```

如果任务开始涉及安装软件、修改配置、分组、失败重试，不要继续堆 PowerShell 脚本，切换到 Ansible。

> Windows 原生不是 Ansible Control Node。生产环境更建议使用专用 Linux 控制机；WSL 可用于个人测试和临时使用。

## 7. Linux / macOS 临时不用 Ansible

`hosts.txt` 每行一个 IP：

```bash
while IFS= read -r host; do
  ssh "root@$host" 'hostname; uptime'
done < hosts.txt
```

并发 5 台：

```bash
xargs -P 5 -I {} ssh root@{} 'hostname; uptime' < hosts.txt
```

这适合一次性检查；重复任务仍用 Ansible。

## 8. 其他工具什么时候用

| 工具 | 适用场景 |
| --- | --- |
| `pssh` / `parallel-ssh` / `pdsh` | 只需要并发 SSH 命令，比 Ansible 更轻 |
| Semaphore | 想给 Ansible 加简单 Web UI、计划任务和执行记录 |
| AWX | 团队化 Ansible 管理，权限、凭据、作业模板要求较高 |
| Rundeck | 更偏 Runbook、跨步骤作业编排 |
| SaltStack / Puppet | 大规模持续配置管理；少量主机通常没必要 |

## 推荐操作顺序

```text
SSH / raw 验证连接
        ↓
确认或补齐 Python
        ↓
ansible ping
        ↓
--limit 先跑 1 台
        ↓
serial 分批执行
        ↓
全量验证
```

## 官方资料

只在需要确认版本或深入参数时查看：

- Ansible 安装与节点要求：https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html
- Ansible `raw` 模块：https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/raw_module.html
- Ansible Python 支持矩阵：https://docs.ansible.com/projects/ansible/latest/reference_appendices/release_and_maintenance.html
- Ansible Inventory：https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html
- Windows OpenSSH：https://learn.microsoft.com/windows-server/administration/openssh/openssh-overview
