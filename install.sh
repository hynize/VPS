#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════════
# 米粒儿VPS流量消耗管理工具 - 增强版安装脚本 (修复 Alpine 兼容性)
# ═══════════════════════════════════════════════════════════════════════════════════

# 颜色配置
PRIMARY="\e[38;5;39m"
SUCCESS="\e[38;5;46m"
WARNING="\e[38;5;226m"
DANGER="\e[38;5;196m"
INFO="\e[38;5;117m"
WHITE="\e[97m"
RESET="\e[0m"

# 配置常量
REPO_URL="https://github.com/charmtv/VPS"
SCRIPT_URL="https://raw.githubusercontent.com/charmtv/VPS/main/milier_flow_latest.sh"
INSTALL_DIR="/root"
SCRIPT_NAME="milier_flow.sh"
SHORTCUT_NAME="xh"

show_header() {
    clear
    echo -e "${PRIMARY}                米粒儿VPS流量消耗管理工具${RESET}"
    echo -e "${INFO}                (支持 Alpine & 定时流量功能)${RESET}"
    echo -e "${PRIMARY}$(printf '%*s' 70 | tr ' ' '=')"
}

error_exit() { echo -e "${DANGER}❌ $1${RESET}" >&2; exit 1; }
success_msg() { echo -e "${SUCCESS}✅ $1${RESET}"; }
info_msg() { echo -e "${INFO}ℹ️  $1${RESET}"; }

detect_system() {
    if [[ -f /etc/alpine-release ]]; then
        OS_ID="alpine"
        INIT_SYSTEM="openrc"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_ID="${ID}"
        INIT_SYSTEM="systemd"
    else
        error_exit "不支持的操作系统"
    fi
    info_msg "检测到系统: $OS_ID, 初始化系统: $INIT_SYSTEM"
}

update_package_manager() {
    case "$OS_ID" in
        ubuntu|debian|linuxmint) apt-get update -y &>/dev/null ;;
        centos|rhel|fedora|rocky|almalinux) yum update -y &>/dev/null ;;
        alpine) apk update &>/dev/null ;;
    esac
}

install_dependencies() {
    info_msg "正在安装必要依赖..."
    
    # 基础依赖列表
    local pkgs=("curl" "wget" "procps" "coreutils")
    
    case "$OS_ID" in
        ubuntu|debian|linuxmint)
            apt-get install -y "${pkgs[@]}" cron &>/dev/null
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y "${pkgs[@]}" cronie &>/dev/null
            ;;
        alpine)
            # Alpine 核心依赖及定时服务
            apk add --no-cache bash curl wget procps coreutils dcron &>/dev/null
            rc-update add dcron default &>/dev/null
            rc-service dcron start &>/dev/null
            ;;
    esac

    # 验证关键命令（剔除 systemctl，改用通用检查）
    local check_cmds=("curl" "wget" "bash")
    for cmd in "${check_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            error_exit "依赖 $cmd 安装失败，请检查网络"
        fi
    done
    success_msg "依赖环境部署完成"
}

download_script() {
    mkdir -p "$INSTALL_DIR"
    if curl -fsSL "$SCRIPT_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
        success_msg "主脚本下载成功"
    else
        error_exit "主脚本下载失败"
    fi
}

create_global_shortcut() {
    local shortcut_path="/usr/local/bin/$SHORTCUT_NAME"
    cat > "$shortcut_path" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
bash "$INSTALL_DIR/$SCRIPT_NAME" "\$@"
EOF
    chmod +x "$shortcut_path"
    success_msg "快捷键 '$SHORTCUT_NAME' 创建成功"
}

setup_cron_job() {
    echo -e "\n${PRIMARY}---------- 定时任务配置 ----------${RESET}"
    read -p "是否需要开启每日定时跑流量功能? (y/n): " enable_cron
    if [[ "$enable_cron" == "y" ]]; then
        read -p "请输入每日执行时间 (格式 HH:MM, 例如 02:30): " run_time
        read -p "请输入每日消耗目标 (单位GB, 例如 2): " flow_gb
        
        local hour=${run_time%:*}
        local min=${run_time#*:}
        
        # 写入 crontab
        (crontab -l 2>/dev/null | grep -v "$SHORTCUT_NAME --auto"; echo "$min $hour * * * /usr/local/bin/$SHORTCUT_NAME --auto $flow_gb") | crontab -
        success_msg "定时任务已设定：每天 $run_time 自动消耗 ${flow_gb}GB"
    fi
}

main() {
    show_header
    detect_system
    update_package_manager
    install_dependencies
    download_script
    create_global_shortcut
    setup_cron_job
    echo -e "\n${SUCCESS}🎉 安装完成！直接输入 ${PRIMARY}$SHORTCUT_NAME${SUCCESS} 即可启动。${RESET}\n"
}

main "$@"
