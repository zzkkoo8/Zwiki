# Windows / Linux / macOS 批量运维 Linux 主机速查

用于从 Windows、Linux 或 macOS 批量向 Linux 主机执行命令、复制文件和运行运维任务。结论很简单：**临时、一次性操作优先用 OpenSSH；长期、重复、可审计的批量运维优先用 Ansible。**

## 文档信息

- **技术领域**：Linux 批量运维、OpenSSH、Ansible
- **适用范围**：Windows 11、常见 Linux、macOS 作为运维端；Linux 作为被控端
- **适用规模**：约 2～1000 台；本文示例为 10 台
- **推荐方案**：SSH 做临时操作，Ansible 做标准化批量运维
- **文档状态**：已验证方案
- **最后验证**：2026-09-15
- **来源**：Ansible 官方文档、Microsoft Learn

## 1. 方案怎么选

| 场景 | 推荐方案 | 说明 |
| --- | --- | --- |
| 临时检查 2～10 台 | OpenSSH + Shell / PowerShell 循环 | 无需额外平台，最快 |
| 经常管理 10～1000 台 | Ansible | 无 Agent、Inventory 分组、支持幂等、并发和 Playbook |
| Windows 临时批量执行 | PowerShell + OpenSSH | Windows 原生即可完成 |
| Windows 长期使用 Ansible | 专用 Linux 控制机优先；WSL/容器适合开发、小规模使用 | Windows 原生不能直接作为 Ansible Control Node |
| Linux / macOS 长期批量运维 | Ansible | 原生适合作为 Control Node |
| 需要 Web UI、审批、定时任务 | Ansible + Semaphore / AWX / Rundeck | 在 Ansible 之上增加平台能力 |
| 高频实时配置管理 | SaltStack / Puppet 等 | 体系更重，10 台主机通常没必要 |

Ansible 是 Agentless 工具，控制端通过 SSH 管理 Linux 主机；被控端通常不需要安装 Ansible，但常用模块需要 Python。

> Windows 原生不能作为 Ansible Control Node。Ansible 官方允许在 Windows 下通过 WSL 或容器运行，但官方 Windows 指南明确说明 WSL 不作为生产控制端支持。正式生产批量运维更建议使用专用 Linux 控制机。

## 2. 示例环境：10 台 Linux

假设 10 台 Linux 主机地址如下：

```text
192.168.1.101
192.168.1.102
192.168.1.103
192.168.1.104
192.168.1.105
192.168.1.106
192.168.1.107
192.168.1.108
192.168.1.109
192.168.1.110
```

登录用户：

```text
ops
```

先保存成 `hosts.txt`：

```text
192.168.1.101
192.168.1.102
192.168.1.103
192.168.1.104
192.168.1.105
192.168.1.106
192.168.1.107
192.168.1.108
192.168.1.109
192.168.1.110
```

推荐提前完成 SSH Key 登录。不要把密码直接写入脚本、Inventory 或 Git 仓库。

单台验证：

```bash
ssh ops@192.168.1.101
```

## 3. Windows：PowerShell + OpenSSH

### 3.1 检查 OpenSSH

PowerShell：

```powershell
Get-Command ssh
ssh -V
```

如果未安装 OpenSSH Client，以管理员 PowerShell 执行：

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

### 3.2 顺序向 10 台主机执行命令

适用于 Windows PowerShell 5.1 和 PowerShell 7：

```powershell
Get-Content .\hosts.txt | ForEach-Object {
    ssh "ops@$_" "hostname; uptime; df -h /"
}
```

优点是简单；缺点是逐台执行，某台 SSH 卡住会拖慢整体。

### 3.3 PowerShell 7 并行执行

确认版本：

```powershell
$PSVersionTable.PSVersion
```

PowerShell 7 可使用 `ForEach-Object -Parallel`：

```powershell
Get-Content .\hosts.txt | ForEach-Object -Parallel {
    ssh "ops@$_" "hostname; uptime; df -h /"
} -ThrottleLimit 5
```

`ThrottleLimit 5` 表示最多同时处理 5 台，10 台主机会分批执行。

### 3.4 批量复制文件

```powershell
Get-Content .\hosts.txt | ForEach-Object {
    $hostName = $_
    scp .\check.sh "ops@${hostName}:/tmp/check.sh"
}
```

再批量执行：

```powershell
Get-Content .\hosts.txt | ForEach-Object -Parallel {
    ssh "ops@$_" "chmod +x /tmp/check.sh && /tmp/check.sh"
} -ThrottleLimit 5
```

### 3.5 Windows 什么时候改用 Ansible

出现以下任一情况就不要继续堆 PowerShell SSH 循环：

- 命令需要反复执行；
- 需要按测试、生产、应用类型分组；
- 需要安装软件、修改配置、管理服务；
- 需要限制每批变更主机数量；
- 需要重复执行时保持结果一致；
- 需要把运维任务放进 Git 管理。

这时应切换到 Ansible。Windows 工作站可以连接一台专用 Linux 运维机执行 Ansible；个人开发或实验环境也可以使用 WSL。

## 4. Linux：Shell SSH 与 Ansible

### 4.1 不装额外工具：SSH 循环

```bash
while IFS= read -r host; do
  ssh "ops@$host" 'hostname; uptime; df -h /'
done < hosts.txt
```

### 4.2 使用 xargs 并发

常见 Linux 可直接使用：

```bash
xargs -P 5 -I {} ssh "ops@{}" 'hostname; uptime; df -h /' < hosts.txt
```

参数：

- `-P 5`：最多并发 5 个 SSH；
- `-I {}`：用每行主机地址替换 `{}`。

临时检查够用；正式批量变更仍建议 Ansible。

## 5. macOS：SSH 与 Ansible

macOS 自带 OpenSSH，因此临时批量命令与 Linux 基本相同。

顺序执行：

```bash
while IFS= read -r host; do
  ssh "ops@$host" 'hostname; uptime; df -h /'
done < hosts.txt
```

并发执行：

```bash
xargs -P 5 -I {} ssh "ops@{}" 'hostname; uptime; df -h /' < hosts.txt
```

如果经常维护 Linux 主机，直接安装 Ansible：

```bash
brew install ansible
```

检查：

```bash
ansible --version
```

macOS 和 Linux 都是适合直接运行 Ansible 的 Control Node。

## 6. Ansible：三端统一的长期方案

Windows 如果需要使用这一套，建议把以下目录和命令放在 Linux 控制机；个人环境可以放在 WSL 中。Linux / macOS 可直接执行。

推荐目录：

```text
linux-ops/
├── inventory.ini
├── ansible.cfg
├── playbooks/
│   └── check.yml
└── files/
```

### 6.1 安装 Ansible

官方推荐的通用 Python 隔离安装方式之一是 `pipx`：

```bash
pipx install --include-deps ansible
```

也可以使用系统包管理器安装。macOS 最直接：

```bash
brew install ansible
```

安装后统一检查：

```bash
ansible --version
```

### 6.2 创建 10 台主机 Inventory

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
ansible_user=ops
```

如果 SSH 默认会自动找到正确私钥，不需要把私钥路径写进 Inventory。

验证 Inventory：

```bash
ansible-inventory -i inventory.ini --graph
```

测试连通：

```bash
ansible linux -i inventory.ini -m ansible.builtin.ping
```

### 6.3 批量执行一条命令

查看 uptime：

```bash
ansible linux -i inventory.ini -m ansible.builtin.command -a 'uptime'
```

限制最大并发为 5：

```bash
ansible linux -i inventory.ini -m ansible.builtin.command -a 'uptime' -f 5
```

`command` 不经过 Shell，能用它时优先使用它。

### 6.4 执行需要 Shell 的组合命令

```bash
ansible linux -i inventory.ini -m ansible.builtin.shell -a 'hostname; uptime; df -hT; free -h'
```

只有管道、重定向、Shell 内建功能等确实需要 Shell 时再使用 `shell`。

### 6.5 批量复制文件

```bash
ansible linux -i inventory.ini \
  -m ansible.builtin.copy \
  -a 'src=files/check.sh dest=/tmp/check.sh mode=0755'
```

### 6.6 批量执行本地脚本

无需先手动复制：

```bash
ansible linux -i inventory.ini \
  -m ansible.builtin.script \
  -a './files/check.sh'
```

### 6.7 批量安装软件

使用 `package` 模块可以屏蔽常见包管理器差异：

```bash
ansible linux -i inventory.ini \
  -b \
  -m ansible.builtin.package \
  -a 'name=vim state=present'
```

需要 sudo 密码时：

```bash
ansible linux -i inventory.ini \
  -b -K \
  -m ansible.builtin.package \
  -a 'name=vim state=present'
```

不要把 sudo 密码直接放在命令行。

## 7. 重复任务用 Playbook

一次性命令适合 ad-hoc；重复任务应写成 Playbook。

`playbooks/check.yml`：

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

    - name: Check root filesystem
      ansible.builtin.command: df -h /
      changed_when: false
```

执行：

```bash
ansible-playbook -i inventory.ini playbooks/check.yml
```

这里：

```yaml
serial: 2
```

表示 10 台主机每批只处理 2 台。软件升级、服务重启和配置变更时非常重要。

### 7.1 先测试 1 台

正式批量执行前：

```bash
ansible-playbook \
  -i inventory.ini \
  playbooks/check.yml \
  --limit node01
```

确认 node01 正常后再跑全部。

### 7.2 Check Mode

支持 Check Mode 的模块可以先预演：

```bash
ansible-playbook \
  -i inventory.ini \
  playbooks/check.yml \
  --check --diff
```

注意：并非所有模块、命令或第三方脚本都能准确模拟变更。

### 7.3 调整并发

Ansible 默认使用有限数量的 forks，可以通过 `-f` 调整：

```bash
ansible-playbook \
  -i inventory.ini \
  playbooks/check.yml \
  -f 5
```

两者区别：

- `forks / -f`：控制同时工作的进程数量；
- `serial`：控制一个 Play 每批实际处理多少台主机。

有变更风险的任务优先使用 `serial` 控制批次，而不是单纯把并发调大。

## 8. 推荐的实际操作流程

10 台主机建议固定成下面的流程：

```text
1. SSH 单台验证
        ↓
2. ansible ping 全量确认连通
        ↓
3. --limit node01 先执行 1 台
        ↓
4. 检查结果
        ↓
5. serial: 2 或 serial: 3 分批执行
        ↓
6. 全量验证
```

常用命令：

```bash
ansible linux -i inventory.ini -m ansible.builtin.ping
```

```bash
ansible linux -i inventory.ini -m ansible.builtin.command -a 'uptime' -f 5
```

```bash
ansible-playbook -i inventory.ini playbooks/check.yml --limit node01
```

```bash
ansible-playbook -i inventory.ini playbooks/check.yml
```

## 9. 安全注意事项

- 优先使用 SSH Key，不把密码写进脚本和 Git。
- 第一次连接主机时核对 SSH Host Key 指纹，不要为了省事长期关闭 Host Key Checking。
- Inventory 中不要保存明文密码。
- 必须保存敏感变量时使用 `ansible-vault` 或外部 Secret Manager。
- 删除文件、重启服务、升级系统、修改网络和防火墙前先使用 `--limit` 小范围验证。
- 生产变更建议使用 `serial` 分批执行。
- 优先使用 `command`、`copy`、`package`、`service`、`template` 等 Ansible 模块，不要把所有任务都写成 `shell`。
- 关键任务纳入 Git，保留 Inventory、Playbook 和变更历史。

## 10. 其它方案

### parallel-ssh / pssh / pdsh

适合“同时对很多机器执行相同命令”，比手写 SSH 循环方便，但不擅长复杂状态管理、幂等和长期维护。

定位：

```text
SSH 循环 < parallel-ssh / pdsh < Ansible
```

### SaltStack

适合更大规模、长期在线、需要快速远程执行和配置管理的环境。通常需要 Master/Minion 或其它常驻组件，部署复杂度明显高于 Ansible。

### Puppet

更偏持续配置管理和合规状态维护，不适合替代日常临时批量命令工具。

### Semaphore / AWX

它们不是 Ansible 的替代品，而是给 Ansible 增加 Web UI、任务模板、权限、调度、日志等能力。个人或 10 台主机场景先不用上平台。

## 11. 最终推荐

如果只记住三句话：

1. **Windows 临时批量运维：PowerShell + OpenSSH。**
2. **Linux / macOS 临时批量运维：OpenSSH；长期统一用 Ansible。**
3. **正式生产环境：把 Ansible 放在专用 Linux 运维控制机，Windows/macOS 只作为入口。**

这样可以从 10 台平滑扩展到几十、几百甚至更多主机，同时避免以后重新维护多套 Windows、Linux、macOS 脚本。

## 相关文档

- [Linux 运维开局常用命令](linux-ops-bootstrap.md)
- [Linux 在线/离线软件包管理速查](linux-offline-package-management.md)
- [Ansible：Installing Ansible](https://docs.ansible.com/projects/ansible-core/devel/installation_guide/intro_installation.html)
- [Ansible：Building an inventory](https://docs.ansible.com/projects/ansible/latest/getting_started/get_started_inventory.html)
- [Ansible：Introduction to ad hoc commands](https://docs.ansible.com/projects/ansible/latest/command_guide/intro_adhoc.html)
- [Ansible：Controlling playbook execution](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_strategies.html)
- [Microsoft：Windows OpenSSH](https://learn.microsoft.com/windows-server/administration/openssh/openssh_install_firstuse)
- [Microsoft：PowerShell 并行执行](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/parallel-execution)

## 反馈与修改

发现本文错误或需要补充时：

- 内容错误、命令错误、失效链接：通过 Zwiki 的“文档纠错”入口提交 Issue。
- 已确认修改方案：直接修改 GitHub Markdown 并提交 Pull Request。
- 小范围修正优先保持原路径，不重复创建新文章。
