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

`-k` 适合一批主机共用同一个 SSH 密码。每台密码不同，再单独创建一个**临时密码 Inventory**，不要污染长期使用的 `inventory.ini`。

`inventory-password.ini`：

```ini
[linux]
node01 ansible_host=192.168.1.101 ansible_user=root ansible_password=CHANGE_ME_01
node02 ansible_host=192.168.1.102 ansible_user=root ansible_password=CHANGE_ME_02
node03 ansible_host=192.168.1.103 ansible_user=root ansible_password=CHANGE_ME_03
```

普通用户 sudo 密码也可临时增加：

```ini
node01 ansible_host=192.168.1.101 ansible_user=ops ansible_password=CHANGE_ME_01 ansible_become_password=CHANGE_ME_SUDO_01
```

保护文件：

```bash
chmod 600 inventory-password.ini
```

指定这个临时 Inventory 执行：

```bash
ansible linux \
  -i inventory-password.ini \
  -m ansible.builtin.raw \
  -a 'hostname; uptime'
```

任务完成后删除：

```bash
rm -f inventory-password.ini
```

如果密码配置需要长期保存，不要长期明文保存 `ansible_password` / `ansible_become_password`，改用 `ansible-vault`。

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

## 9. 按主机规模选择执行方案

先按目标规模选择执行方式。`forks` 决定控制机同时工作的进程数，`serial` 决定一批放行多少台主机，`throttle` 可继续限制单个重负载任务的并发；三者同时存在时，实际并发不会超过其中最小的限制。

| 场景 | 推荐入口 | 起始并发 | 批次控制 | 结果留存 |
| --- | --- | ---: | --- | --- |
| 100 台以下 | 单控制机直接运行 `ansible-playbook` | `forks = 10`～`30` | `serial` 从 1 台逐步扩大 | 终端日志；长任务增加 `tee` 或逐主机结果 |
| 1000 台以上 | AWX / Automation Controller，或由外部调度队列调用 `ansible-runner` | 每个执行节点先从 `forks = 30`～`50` 起测 | 按地域、机房或业务分片，每片继续使用 `serial` | 集中保存作业、事件和逐主机结果 |

这些数值是保守起点，不是固定上限。最终并发应同时受控制机 CPU、内存、文件描述符、SSH 建连速度、网络带宽、目标机承载能力，以及软件仓库、API、数据库等共享后端容量约束。

### 9.1 100 台以下：单控制机滚动执行

小批量主机不需要额外搭建调度平台。建议保留 `strategy: linear`，先 1 台验证，再 10 台，最后按比例滚动执行。

`ansible.cfg`：

```ini
[defaults]
inventory = ./inventory.ini
forks = 20
timeout = 15
host_key_checking = True
```

生产变更 Playbook 可使用渐进批次：

```yaml
---
- name: Small fleet rolling operation
  hosts: linux
  gather_facts: false
  strategy: linear
  serial:
    - 1
    - 10
    - 25%
  max_fail_percentage: 10

  tasks:
    - name: Run the approved operation
      ansible.builtin.command: /usr/local/sbin/approved-operation
      register: operation_result
      changed_when: operation_result.rc == 0
```

执行顺序：

```bash
# 1. 确认实际目标，避免组名或 --limit 写错
ansible-playbook operation.yml --limit linux --list-hosts

# 2. 检查语法
ansible-playbook operation.yml --syntax-check

# 3. 模块支持检查模式时先预演；command、shell 和 raw 通常不能完整模拟变更
ansible-playbook operation.yml --limit node01 --check --diff

# 4. 单机真实验证
ansible-playbook operation.yml --limit node01 -f 1

# 5. 确认业务和监控正常后，排除已执行的金丝雀，再按 serial 扩大
ansible-playbook operation.yml --limit 'linux:!node01' -f 20
```

注意：

- `max_fail_percentage` 针对当前 `serial` 批次计算；达到停止条件时先排查，不要立即盲目重跑全量。
- 查询命令应使用 `changed_when: false`；变更任务优先使用 `package`、`template`、`copy`、`service` 等幂等模块。
- 一次性命令只能使用 `command` / `shell` / `raw` 时，应设计“已完成即跳过”的判断，避免重复执行产生副作用。
- SSH 断线风险较高时，使用 [tmux 长任务与远程会话速查](tmux-operations.md) 中的实时输出与日志模式；能够使用 systemd 的控制机也可参考 [systemd 与日志运维速查](linux-systemd-log-operations.md)。

### 9.2 1000 台以上：分片、排队、多执行节点

1000 台以上不建议在一个终端中执行单条 `ansible all -f 1000 ...`。即使控制机能够创建这些进程，共享软件源、管理 API、数据库或网络出口也可能先被打满。

推荐结构：

```text
Git 中的 Inventory + Playbook
              ↓
AWX / Automation Controller，或外部调度队列调用 ansible-runner
              ↓
多个执行节点（按容量限制并发）
              ↓
region_a / region_b / region_c 等独立 Inventory 分片
              ↓
每个分片内部继续使用 serial 滚动执行
```

Inventory 至少按故障域和业务角色分组：

```ini
[region_a]
a-node001 ansible_host=192.0.2.11
a-node002 ansible_host=192.0.2.12

[region_b]
b-node001 ansible_host=198.51.100.11
b-node002 ansible_host=198.51.100.12

[fleet:children]
region_a
region_b
```

大规模滚动 Playbook：

```yaml
---
- name: Large fleet rolling operation
  hosts: fleet
  gather_facts: false
  strategy: linear
  order: shuffle
  serial:
    - 1
    - 20
    - 5%
  max_fail_percentage: 5

  tasks:
    - name: Run the approved operation with backend protection
      ansible.builtin.command: /usr/local/sbin/approved-operation
      register: operation_result
      changed_when: operation_result.rc == 0
      throttle: 20
```

`order: shuffle` 可避免总是按 Inventory 固定顺序命中同一机架或同一编号段，但不能替代按故障域分组。涉及主从、仲裁、分片数据库等有顺序要求的系统，不要随机执行，应显式建立主机组并分别编排。

单个执行节点先使用保守并发验证：

```bash
# 只查看 region_a 的实际目标
ansible-playbook large-operation.yml \
  --limit 'region_a:&fleet' \
  --list-hosts

# 先执行一个分片；其他分片由作业队列按容量启动
ansible-playbook large-operation.yml \
  --limit 'region_a:&fleet' \
  -f 50
```

不要为了“并行”手工启动大量互不知情的后台 Shell。使用 AWX / Automation Controller，或由外部调度器为每个分片排队并调用 `ansible-runner`。调度器必须生成唯一作业 ID、限制执行节点容量、阻止同一主机进入重叠变更作业；Runner 负责执行 Ansible 并保存标准输出、最终状态和逐主机事件，本身不提供队列调度和主机互斥。

正式扩容并发前，至少检查：

```bash
# 控制机容量
nproc
free -h
ulimit -n

# Ansible 最终生效配置
ansible-config dump --only-changed

# 小分片 SSH 与模块执行基线
time ansible region_a -m ansible.builtin.ping -f 30
```

确认小分片稳定后再逐步增加执行节点或 `forks`。不要同时放大执行节点数、每节点 `forks` 和 `serial`，否则无法判断瓶颈来自控制机、网络、目标机还是共享后端。

经过兼容性验证后，可减少 SSH 往返：

```ini
[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

启用 `pipelining` 前应验证 sudo 策略和目标系统兼容性。只读任务不需要系统事实时保持 `gather_facts: false`；确实需要事实且多次复用时，再考虑事实缓存。

### 9.3 两种规模都必须执行的安全门

```text
核对 Inventory 与 --limit 实际目标
    ↓
语法检查 / 可用时执行 --check
    ↓
1 台真实验证
    ↓
小批次验证业务、监控和共享后端
    ↓
逐步扩大，失败率超过阈值立即停止
    ↓
按 successful / failed / unreachable 汇总并复查遗漏主机
```

- Playbook、Inventory 和配置进入版本控制，凭据使用 Ansible Vault 或调度平台凭据，不写入命令行和日志。
- 安装、升级和脚本任务必须可重复执行；无法幂等时，至少增加锁、完成标记或安装状态检查。
- 对软件仓库、下载服务或管理 API 设置 `throttle`，其值按后端容量决定，不要直接等同于主机总并发。
- 1000 台以上应保留作业 ID、Git 提交、操作者、目标分片、开始/结束时间和每台主机结果，失败重试只针对明确的失败集合。

## 10. 推荐现场用法

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
- Playbook 执行策略与并发控制：https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_strategies.html
- Playbook 错误处理与失败阈值：https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_error_handling.html
- SSH Connection：https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/ssh_connection.html
- `raw` 模块：https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/raw_module.html
- Ansible Vault：https://docs.ansible.com/projects/ansible/latest/vault_guide/index.html
- Ansible Runner：https://ansible.readthedocs.io/projects/runner/en/stable/intro.html
