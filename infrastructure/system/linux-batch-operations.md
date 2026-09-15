# Linux 批量运维速查

用于从一台控制机批量管理 Linux 主机。**不需要先逐台手工写 SSH 公钥。**

## 直接选方案

| 场景 | 最简方案 |
| --- | --- |
| 只执行一次短任务 | Ansible 直接用现有账号密码，任务结束删除临时 Inventory |
| 不想让后续任务继续使用 root/管理员密码 | 密码只做一次 bootstrap，自动创建临时账号 + 临时 SSH Key |
| 多人、自动化、持续一段时间批量操作 | 临时账号 + 临时 Key + 临时 sudo，结束后统一 cleanup |

如果只是自己临时执行几条命令，**直接密码认证最简单，不需要创建 Key，也不需要修改服务器权限。**

如果需要把 root/管理员密码与后续批量任务隔离，推荐下面的完整临时授权流程：

```text
已有 root / 管理员密码
        ↓
Ansible 一次性 bootstrap
        ↓
创建临时账号 ops-maint
写入一次性 SSH 公钥
临时授予 sudo
设置次日自动过期
确认/补齐 Python
        ↓
后续全部使用临时 SSH Key 批量运维
        ↓
任务完成
        ↓
cleanup：删除 sudoers、账号、公钥、控制端私钥
```

**安全底线：**第一次先 `--limit node01` 验证一台；原有管理员登录通道确认可用前，不要修改或关闭它。

以下假设管理 10 台 Linux：`192.168.1.101` ～ `192.168.1.110`。

## 1. 最短方案：直接密码批量运维

### 1.1 10 台密码相同

`inventory-bootstrap.ini`：

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

### 1.2 每台密码不同

```ini
[linux]
node01 ansible_host=192.168.1.101 ansible_user=root ansible_password=CHANGE_ME_01
node02 ansible_host=192.168.1.102 ansible_user=root ansible_password=CHANGE_ME_02
node03 ansible_host=192.168.1.103 ansible_user=root ansible_password=CHANGE_ME_03
```

其余主机按同样格式继续写。

如果是普通管理员账号 + sudo：

```ini
[linux:vars]
ansible_user=admin
ansible_password=CHANGE_ME
ansible_become=true
ansible_become_method=sudo
ansible_become_password=CHANGE_ME
```

临时明文 Inventory 只放控制机本地：

```bash
chmod 600 inventory-bootstrap.ini
```

不要提交到 Git。需要长期保存时改用 `ansible-vault`。

目标机没有 Python 也能先用 `raw`：

```bash
ansible linux -i inventory-bootstrap.ini \
  -m ansible.builtin.raw \
  -a 'hostname; id; command -v python3 || true'
```

如果只是一次短任务，直接执行即可：

```bash
ansible linux -i inventory-bootstrap.ini \
  -m ansible.builtin.shell \
  -a 'hostname; uptime; df -hT; free -h'
```

执行完成后删除临时密码文件：

```bash
rm -f inventory-bootstrap.ini
```

这种方式**不会在目标服务器留下额外账号或 SSH Key**。

## 2. 推荐方案：自动创建临时运维账号和 Key

适合不希望后续批量任务继续携带 root/管理员密码的场景。

### 2.1 控制机生成一次性 SSH Key

Linux / macOS 控制机执行：

```bash
umask 077
mkdir -p .keys
ssh-keygen -q \
  -t ed25519 \
  -N '' \
  -C "zwiki-temp-ops-$(date +%Y%m%d-%H%M%S)" \
  -f .keys/ops-maint
```

生成：

```text
.keys/ops-maint       临时私钥
.keys/ops-maint.pub   临时公钥
```

这把 Key 只用于本次批量运维，不复用为长期管理密钥。

### 2.2 一次性 Bootstrap

创建 `bootstrap.yml`：

```yaml
---
- name: Bootstrap temporary operations access
  hosts: linux
  gather_facts: false

  vars:
    temp_user: ops-maint
    temp_pubkey: "{{ lookup('file', playbook_dir + '/.keys/ops-maint.pub') }}"

  tasks:
    - name: Create temporary user, key, sudo and Python
      ansible.builtin.raw: |
        set -eu

        user={{ temp_user | quote }}
        pubkey={{ temp_pubkey | quote }}
        expire="$(date -d '+1 day' +%F)"

        if id "$user" >/dev/null 2>&1; then
          usermod -s /bin/bash "$user"
          chage -E "$expire" "$user"
        else
          useradd -m -s /bin/bash -e "$expire" "$user"
        fi

        home="$(getent passwd "$user" | cut -d: -f6)"
        install -d -m 700 -o "$user" -g "$user" "$home/.ssh"
        printf '%s\n' "$pubkey" > "$home/.ssh/authorized_keys"
        chown "$user:$user" "$home/.ssh/authorized_keys"
        chmod 600 "$home/.ssh/authorized_keys"

        if ! command -v visudo >/dev/null 2>&1; then
          if command -v dnf >/dev/null 2>&1; then
            dnf install -y sudo
          elif command -v yum >/dev/null 2>&1; then
            yum install -y sudo
          elif command -v apt-get >/dev/null 2>&1; then
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y sudo
          else
            echo 'sudo/visudo missing and no supported package manager found'
            exit 1
          fi
        fi

        mkdir -p /etc/sudoers.d
        tmp="$(mktemp)"
        printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$user" > "$tmp"
        chmod 440 "$tmp"
        visudo -cf "$tmp" >/dev/null
        install -o root -g root -m 440 "$tmp" "/etc/sudoers.d/$user"
        rm -f "$tmp"

        su - "$user" -c 'sudo -n true'

        if ! command -v python3 >/dev/null 2>&1; then
          if command -v dnf >/dev/null 2>&1; then
            dnf install -y python3
          elif command -v yum >/dev/null 2>&1; then
            yum install -y python3
          elif command -v apt-get >/dev/null 2>&1; then
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y python3
          else
            echo 'Python missing and no supported package manager found'
            exit 2
          fi
        fi
```

这里的 `NOPASSWD: ALL` 只给临时账号使用，目的是让通用批量运维不再依赖第二套 sudo 密码。**如果本次只做只读检查，删掉 sudoers 相关部分即可。**

### 2.3 先只开一台

```bash
ansible-playbook \
  -i inventory-bootstrap.ini \
  bootstrap.yml \
  --limit node01
```

确认原有管理员通道仍正常，再继续。

## 3. 用临时 Key 批量运维

创建 `inventory-ops.ini`：

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
ansible_user=ops-maint
ansible_private_key_file=./.keys/ops-maint
ansible_become=true
```

先验证 `node01`：

```bash
ansible node01 -i inventory-ops.ini \
  -m ansible.builtin.raw \
  -a 'id; sudo -n id; chage -l ops-maint | grep "Account expires"'
```

确认临时账号、sudo 和过期时间正常后，对全部主机执行 bootstrap：

```bash
ansible-playbook -i inventory-bootstrap.ini bootstrap.yml
```

然后测试：

```bash
ansible linux -i inventory-ops.ini -m ansible.builtin.ping
```

### Python 缺失或版本过低

Bootstrap 会在常见 RPM / DEB 系统中尝试补装 `python3`。

如果系统 Python 太旧导致 `ansible ping` 失败，先检查：

```bash
ansible linux -i inventory-ops.ini \
  -m ansible.builtin.raw \
  -a 'python3 --version 2>/dev/null || true'
```

不要直接覆盖系统 Python。优先并行安装新版本，例如 `/usr/bin/python3.11`，再指定：

```ini
[linux:vars]
ansible_python_interpreter=/usr/bin/python3.11
```

内网主机没有可用 Python 包时，按 [Linux 离线软件安装速查](linux-offline-package-management.md) 下载对应发行版、版本和架构的软件包及依赖。

## 4. 常用批量命令

系统状态：

```bash
ansible linux -i inventory-ops.ini \
  -m ansible.builtin.shell \
  -a 'hostname; uptime; df -hT; free -h'
```

并发 5 台：

```bash
ansible linux -i inventory-ops.ini \
  -m ansible.builtin.command \
  -a 'uptime' \
  -f 5
```

复制脚本：

```bash
ansible linux -i inventory-ops.ini \
  -m ansible.builtin.copy \
  -a 'src=./check.sh dest=/tmp/check.sh mode=0755'
```

执行脚本：

```bash
ansible linux -i inventory-ops.ini \
  -m ansible.builtin.script \
  -a './check.sh'
```

安装软件：

```bash
ansible linux -i inventory-ops.ini \
  -b \
  -m ansible.builtin.package \
  -a 'name=tmux state=present'
```

有变更的任务固定使用：

```text
--limit 先跑 1 台
        ↓
确认结果
        ↓
serial 小批量
        ↓
全量验证
```

例如：

```yaml
---
- name: Batch change
  hosts: linux
  serial: 2

  tasks:
    - name: Check uptime
      ansible.builtin.command: uptime
      changed_when: false
```

```bash
ansible-playbook -i inventory-ops.ini change.yml --limit node01
ansible-playbook -i inventory-ops.ini change.yml
```

## 5. 用完立即关闭临时权限

Cleanup 使用最初的 `inventory-bootstrap.ini`，不要让 `ops-maint` 自己删除自己。

创建 `cleanup.yml`：

```yaml
---
- name: Revoke temporary operations access
  hosts: linux
  gather_facts: false

  vars:
    temp_user: ops-maint

  tasks:
    - name: Remove sudo, key and temporary account
      ansible.builtin.raw: |
        set -eu

        user={{ temp_user | quote }}
        rm -f "/etc/sudoers.d/$user"

        if id "$user" >/dev/null 2>&1; then
          home="$(getent passwd "$user" | cut -d: -f6)"
          rm -f "$home/.ssh/authorized_keys"
          usermod -L -s /sbin/nologin "$user" 2>/dev/null || true
          userdel -r "$user" 2>/dev/null || true
        fi
```

先回收一台：

```bash
ansible-playbook \
  -i inventory-bootstrap.ini \
  cleanup.yml \
  --limit node01
```

验证：

```bash
ansible node01 -i inventory-bootstrap.ini \
  -m ansible.builtin.raw \
  -a 'test ! -e /etc/sudoers.d/ops-maint && ! id ops-maint >/dev/null 2>&1 && echo REVOKED'
```

确认后回收全部：

```bash
ansible-playbook -i inventory-bootstrap.ini cleanup.yml
```

最后删除控制端临时 Key；如果 bootstrap Inventory 含明文密码，也一起删除：

```bash
rm -f .keys/ops-maint .keys/ops-maint.pub
rm -f inventory-bootstrap.ini
```

如果 `userdel` 因残留进程失败，脚本已经先删除 sudoers、公钥并将账号改为 `nologin`；此时远程批量登录权限已被回收，再单独清理残留账号即可。

## 6. 次日自动过期只是兜底

正常情况必须主动执行 cleanup。账号过期只是防止忘记回收的第二道保险：

```text
主动 cleanup          主路径
账号次日自动过期       兜底
删除控制端临时私钥     防止本机继续复用
```

不要创建永久 `ops-maint`，也不要长期复用同一把批量运维私钥。

## 7. Windows / macOS

Linux / macOS 可以直接作为 Ansible 控制端。

Windows 长期运维建议：

```text
Windows
  ↓ SSH
专用 Linux 控制机
  ↓ Ansible
多台 Linux
```

Windows 临时执行几条命令可使用 PowerShell + OpenSSH；一旦涉及账号、sudo、文件下发、失败重试和权限回收，统一使用上面的 Ansible 流程。

## 最终推荐

```text
一次短任务
  → 直接密码 Inventory
  → 批量执行
  → 删除 Inventory

需要隔离管理员密码
  → 密码只做 bootstrap
  → 临时账号 + 临时 Key
  → Ansible 批量运维
  → cleanup 强制回收
```

这样既省掉逐台手工写公钥，也避免永久 root Key 或永久 sudo 账号。

## 官方资料

- Ansible `raw`：https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/raw_module.html
- Ansible SSH Connection：https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/ssh_connection.html
- Ansible Inventory：https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html
- Ansible User：https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/user_module.html
- Ansible Vault：https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html
