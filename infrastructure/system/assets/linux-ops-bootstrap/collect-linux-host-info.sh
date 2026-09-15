#!/usr/bin/env bash
# Linux 主机只读信息采集：快速确认系统状态、资源、网络和部署业务线索。
# 默认只输出到 stdout；不修改系统配置，不自动提权，不读取密码/Token/环境变量/业务配置正文。
set -u
set -o pipefail
export LC_ALL=C

TIMEOUT_SECONDS="${COLLECT_TIMEOUT_SECONDS:-8}"

have() {
    command -v "$1" >/dev/null 2>&1
}

heading() {
    printf '\n## %s\n\n' "$1"
}

subheading() {
    printf '\n### %s\n\n' "$1"
}

code_begin() {
    printf '```text\n'
}

code_end() {
    printf '```\n'
}

run_cmd() {
    local label="$1"
    shift
    subheading "$label"
    code_begin
    if have timeout; then
        timeout "${TIMEOUT_SECONDS}s" "$@" 2>&1 || {
            rc=$?
            if [[ $rc -eq 124 ]]; then
                printf '[timeout after %ss]\n' "$TIMEOUT_SECONDS"
            else
                printf '[command exited with status %s]\n' "$rc"
            fi
        }
    else
        "$@" 2>&1 || printf '[command exited with status %s]\n' "$?"
    fi
    code_end
}

run_shell() {
    local label="$1"
    local cmd="$2"
    subheading "$label"
    code_begin
    if have timeout; then
        timeout "${TIMEOUT_SECONDS}s" bash -o pipefail -c "$cmd" 2>&1 || {
            rc=$?
            if [[ $rc -eq 124 ]]; then
                printf '[timeout after %ss]\n' "$TIMEOUT_SECONDS"
            else
                printf '[command exited with status %s]\n' "$rc"
            fi
        }
    else
        bash -o pipefail -c "$cmd" 2>&1 || printf '[command exited with status %s]\n' "$?"
    fi
    code_end
}

maybe_cmd() {
    local command_name="$1"
    local label="$2"
    shift 2
    if have "$command_name"; then
        run_cmd "$label" "$@"
    fi
}

printf '# Linux 主机信息采集报告\n\n'
printf -- '- **采集时间**：%s\n' "$(date '+%F %T %z' 2>/dev/null || date)"
printf -- '- **当前用户**：%s (uid=%s)\n' "$(id -un 2>/dev/null || printf unknown)" "$(id -u 2>/dev/null || printf unknown)"
printf -- '- **主机名**：%s\n' "$(hostname 2>/dev/null || printf unknown)"
printf -- '- **采集方式**：只读；未自动 sudo；单条外部命令默认超时 %ss\n' "$TIMEOUT_SECONDS"
printf '\n> 报告可能包含主机名、IP、监听端口、服务名、容器名和镜像名。对外发送前请先脱敏。\n'

heading '1. 系统与运行状态'
if have hostnamectl; then
    run_cmd 'hostnamectl' hostnamectl
else
    run_cmd 'uname' uname -a
fi

if [[ -r /etc/os-release ]]; then
    subheading '/etc/os-release'
    code_begin
    grep -E '^(NAME|VERSION|ID|VERSION_ID|PRETTY_NAME)=' /etc/os-release 2>/dev/null || true
    code_end
fi

run_cmd '内核' uname -a
run_cmd '运行时间与负载' uptime
if [[ -r /proc/loadavg ]]; then
    subheading '/proc/loadavg'
    code_begin
    cat /proc/loadavg 2>/dev/null || true
    code_end
fi

heading '2. CPU 与内存'
if have lscpu; then
    run_shell 'CPU 摘要' "lscpu | grep -E '^(Architecture|CPU\\(s\\)|On-line CPU|Model name|Socket|Core|Thread|NUMA node|Virtualization|Hypervisor vendor)'"
else
    run_cmd 'CPU 数量' getconf _NPROCESSORS_ONLN
fi
maybe_cmd free '内存' free -h

heading '3. 磁盘、文件系统与 LVM'
if have lsblk; then
    run_cmd '块设备' lsblk -e 7 -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
fi
maybe_cmd df '文件系统容量' df -hT
maybe_cmd df 'inode 使用率' df -ih
if have findmnt; then
    run_cmd '挂载摘要' findmnt -rn -o TARGET,SOURCE,FSTYPE
fi

if have pvs || have vgs || have lvs; then
    subheading 'LVM'
    code_begin
    if have pvs; then
        pvs --noheadings --units g -o pv_name,vg_name,pv_size,pv_free 2>&1 || true
    fi
    if have vgs; then
        vgs --noheadings --units g -o vg_name,vg_size,vg_free 2>&1 || true
    fi
    if have lvs; then
        lvs --noheadings --units g -o vg_name,lv_name,lv_size,lv_attr 2>&1 || true
    fi
    code_end
fi

heading '4. 网络、路由、DNS 与监听端口'
if have ip; then
    run_cmd '网卡地址' ip -br addr
    run_cmd '路由' ip route
    run_cmd '策略路由' ip rule
fi

if have resolvectl; then
    run_shell 'DNS 摘要' "resolvectl status | sed -n '1,120p'"
elif [[ -r /etc/resolv.conf ]]; then
    subheading '/etc/resolv.conf'
    code_begin
    grep -E '^(nameserver|search|domain)[[:space:]]' /etc/resolv.conf 2>/dev/null || true
    code_end
fi

if have ss; then
    run_cmd '监听端口' ss -lntup
elif have netstat; then
    run_cmd '监听端口' netstat -lntup
fi

heading '5. systemd 服务'
if have systemctl; then
    run_cmd '失败服务' systemctl --failed --no-pager
    run_shell '正在运行的服务' "systemctl list-units --type=service --state=running --no-pager --no-legend | sed -n '1,160p'"
fi

heading '6. 进程与业务线索'
if have ps; then
    run_shell 'CPU 占用最高的进程' "ps -eo pid,user,comm,%cpu,%mem --sort=-%cpu | head -n 21"
    run_shell '内存占用最高的进程' "ps -eo pid,user,comm,%cpu,%mem --sort=-%mem | head -n 21"
fi

heading '7. 容器与集群'
if have docker; then
    run_cmd 'Docker 版本' docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}}'
    run_cmd 'Docker 容器' docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
fi

if have podman; then
    run_cmd 'Podman 版本' podman version
    run_cmd 'Podman 容器' podman ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
fi

if have nerdctl; then
    run_cmd 'nerdctl 版本' nerdctl --version
    run_cmd 'nerdctl 容器' nerdctl ps -a
fi

if have crictl; then
    run_cmd 'CRI 容器' crictl ps -a
fi

if have k3s; then
    run_cmd 'K3s 版本' k3s --version
    run_cmd 'K3s 节点' k3s kubectl get nodes -o wide
    run_cmd 'K3s Pod' k3s kubectl get pods -A -o wide
elif have kubectl; then
    run_cmd 'kubectl 客户端版本' kubectl version --client
    run_cmd 'Kubernetes 节点' kubectl get nodes -o wide
    run_cmd 'Kubernetes Pod' kubectl get pods -A -o wide
fi

if have helm; then
    run_cmd 'Helm 版本' helm version --short
    run_cmd 'Helm Release' helm list -A
fi

heading '8. 常见组件版本'
for cmd in nginx haproxy redis-server redis-cli mysql psql java python3 python go; do
    if have "$cmd"; then
        subheading "$cmd"
        code_begin
        case "$cmd" in
            nginx) nginx -v 2>&1 | head -n 2 || true ;;
            haproxy) haproxy -v 2>&1 | head -n 3 || true ;;
            redis-server) redis-server --version 2>&1 | head -n 2 || true ;;
            redis-cli) redis-cli --version 2>&1 | head -n 2 || true ;;
            mysql) mysql --version 2>&1 | head -n 2 || true ;;
            psql) psql --version 2>&1 | head -n 2 || true ;;
            java) java -version 2>&1 | head -n 3 || true ;;
            python3) python3 --version 2>&1 | head -n 2 || true ;;
            python) python --version 2>&1 | head -n 2 || true ;;
            go) go version 2>&1 | head -n 2 || true ;;
        esac
        code_end
    fi
done

heading '9. 结论提示'
cat <<'EOF'
优先查看：
1. systemctl --failed 是否存在失败服务；
2. uptime / free / df 是否存在资源瓶颈；
3. ip route 与监听端口是否符合预期；
4. 正在运行的 systemd 服务、容器、Pod 和 Helm Release，用于判断当前部署业务；
5. CPU / 内存 Top 进程，用于快速定位异常占用。

本脚本不读取：
- 密码、Token、Cookie、私钥；
- 进程环境变量；
- Kubernetes Secret；
- Docker/Kubernetes 业务配置正文；
- journalctl/dmesg 原始日志正文。
EOF
