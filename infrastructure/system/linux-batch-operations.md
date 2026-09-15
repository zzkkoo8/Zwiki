# Linux 批量运维速查

从一台控制机批量管理 Linux，优先使用 **Ansible**。首次使用不需要逐台执行 `ssh-copy-id`：目标机已经允许 SSH 密码登录时，直接使用 `-k` 临时输入 SSH 密码即可。

推荐主线：

```text
安装 Ansible
    ↓
写 inventory.ini
    ↓
-k 使用现有 SSH 密码连接
    ↓
先验证 1 台
    ↓
小批量 / 全量执行
```

以下示例假设管理 10 台 Linux：`192.168.1.101` ～ `192.168.1.110`。

## 1. 安装 Ansible

控制机执行：

```bash
python3 -m pip install ansible
ansible --version
```

也可以直接使用发行版提供的 Ansible 包。完整安装方式以官方文档为准。

建立工作目录：

```bash
mkdir -p ~/ansible-ops
cd ~/ansible-ops
```

建议只保留这几个文件：

```text
ansible-ops/
├── ansible.cfg
├── inventory.ini
└── check.yml
```

## 2. 最小配置文件

### ansible.cfg

```ini
[defaults]
inventory = ./inventory.ini
forks = 10
timeout = 10
host_key_checking = True
```

说明：

- `forks = 10`：最多并发 10 台；
- `timeout = 10`：SSH 连接超时 10 秒；
- `host_key_checking = True`：默认保留 SSH 主机身份校验。

临时隔离测试网确实不需要校验主机指纹时，才临时改成：

```ini
host_key_checking = False
```

生产环境建议保持 `True`。

### inventory.ini

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
```

先确认 Inventory：

```bash
ansible-inventory --graph
ansible linux --list-hosts
```

## 3. 密码相同：直接 `-k`

这是现场批量运维最简单的方式，**不需要先写公钥，也不需要把密码保存到配置文件。**

先测试 1 台：

```bash
ansible node01 \
  -m ansible.builtin.raw \
  -a 'hostname; uptime' \
  -k
```

Ansible 会提示输入 SSH 密码：

```text
SSH password:
```

确认成功后执行全部主机：

```bash
ansible linux \
  -m ansible.builtin.raw \
  -a 'hostname; uptime; df -hT; free -h' \
  -k
```

`-k` 即 `--ask-pass`，适合同一批主机使用相同 SSH 密码的场景。

## 4. 普通管理员 + sudo

Inventory 改为：

```ini
[linux:vars]
ansible_user=ops
```

执行需要 sudo 的命令：

```bash
ansible linux \
  -m ansible.builtin.command \
  -a 'id' \
  -k \
  -b \
  -K
```

参数含义：

```text
-k    临时输入 SSH 登录密码
-b    使用 become/sudo 提权
-K    临时输入 sudo 密码
```

这种方式不需要永久修改目标机权限；前提是 `ops` 本来就具备 sudo 权限。

## 5. 每台密码不同

`-k` 只能方便地处理一批共用密码的主机。每台密码不同，可临时写入 Inventory：

```ini
[linux]
node01 ansible_host=192.168.1.101 ansible_user=root ansible_password=CHANGE_ME_01
node02 ansible_host=192.168.1.102 ansible_user=root ansible_password=CHANGE_ME_02
node03 ansible_host=192.168.1.103 ansible_user=root ansible_password=CHANGE_ME_03
```

保护文件：

```bash
chmod 600 inventory.ini
```

此时执行命令不需要 `-k`：

```bash
ansible linux \
  -m ansible.builtin.raw \
  -a 'hostname; uptime'
```

任务完成后删除或清理密码：

```bash
rm -f inventory.ini
```

如果配置需要长期保存，不要长期明文保存 `ansible_password`，改用 `ansible-vault`。

## 6. 目标机没有 Python

Ansible 大多数标准模块需要目标机存在 Python，但 `ansible.builtin.raw` 不需要远端 Python，因此第一次接管未知 Linux 时优先用 `raw`。

检查：

```bash
ansible linux \
  -m ansible.builtin.raw \
  -a 'hostname; command -v python3 || command -v python || true' \
  -k
```

RPM 系需要安装 Python 时：

```bash
ansible linux \
  -m ansible.builtin.raw \
  -a 'dnf -y install python3 || yum -y install python3' \
  -k
```

如果使用普通管理员账号，在命令末尾增加：

```text
-b -K
```

Debian / Ubuntu：

```bash
ansible linux \
  -m ansible.builtin.raw \
  -a 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3' \
  -k
```

安装完成后验证标准模块：

```bash
ansible linux -m ansible.builtin.ping -k
```

系统 Python 版本太低时，不要直接替换系统 Python；优先并行安装新版本，再通过 `ansible_python_interpreter` 指定。内网环境见 [Linux 离线软件安装速查](linux-offline-package-management.md)。

## 7. 高频命令

查看主机状态：

```bash
ansible linux \
  -m ansible.builtin.shell \
  -a 'hostname; uptime; df -hT; free -h' \
  -k
```

只操作一台：

```bash
ansible node01 \
  -m ansible.builtin.command \
  -a 'uptime' \
  -k
```

限制并发为 5：

```bash
ansible linux \
  -m ansible.builtin.command \
  -a 'uptime' \
  -f 5 \
  -k
```

复制文件：

```bash
ansible linux \
  -m ansible.builtin.copy \
  -a 'src=./check.sh dest=/tmp/check.sh mode=0755' \
  -k
```

执行本地脚本：

```bash
ansible linux \
  -m ansible.builtin.script \
  -a './check.sh' \
  -k
```

安装软件：

```bash
ansible linux \
  -m ansible.builtin.package \
  -a 'name=tmux state=present' \
  -k \
  -b \
  -K
```

## 8. Playbook 最小样例

`check.yml`：

```yaml
---
- name: Linux batch check
  hosts: linux
  gather_facts: false
  serial: 5

  tasks:
    - name: Check uptime
      ansible.builtin.command: uptime
      changed_when: false

    - name: Check disk
      ansible.builtin.command: df -hT
      changed_when: false
```

先验证一台：

```bash
ansible-playbook check.yml \
  --limit node01 \
  -k
```

确认后执行全部：

```bash
ansible-playbook check.yml -k
```

涉及软件安装、配置修改、服务重启等变更任务时，继续使用：

```text
--limit 1 台验证
    ↓
serial 小批量
    ↓
全量执行
    ↓
结果验证
```

## 9. 推荐现场用法

### 一次性批量检查

```bash
ansible linux \
  -m ansible.builtin.raw \
  -a 'hostname; uptime; df -hT; free -h' \
  -k
```

特点：

```text
不下发 SSH Key
不创建临时账号
不修改 sshd
密码不写配置文件
执行完即结束
```

### 重复执行的标准任务

```text
inventory.ini
    +
ansible.cfg
    +
playbook.yml
```

密码相同时继续用 `-k` / `-K` 临时输入；需要长期保存不同主机密码时再使用 `ansible-vault`。

## 官方资料

- Ansible Getting Started：https://docs.ansible.com/projects/ansible/latest/getting_started/index.html
- Inventory：https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html
- SSH Connection：https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/ssh_connection.html
- `raw` 模块：https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/raw_module.html
- Ansible Vault：https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html
