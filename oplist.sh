#!/data/data/com.termux/files/usr/bin/bash

C_BOLD_BLUE="\033[1;34m"
C_BOLD_GREEN="\033[1;32m"
C_BOLD_YELLOW="\033[1;33m"
C_BOLD_RED="\033[1;31m"
C_BOLD_CYAN="\033[1;36m"
C_BOLD_MAGENTA="\033[1;35m"
C_BOLD_WHITE="\033[1;37m"
C_RESET="\033[0m"

INFO="${C_BOLD_BLUE}[INFO]${C_RESET}"
ERROR="${C_BOLD_RED}[ERROR]${C_RESET}"
SUCCESS="${C_BOLD_GREEN}[OK]${C_RESET}"
WARN="${C_BOLD_YELLOW}[WARN]${C_RESET}"

init_paths() {
    REAL_PATH=$(readlink -f "$0")
    SCRIPT_NAME=$(basename "$REAL_PATH")
    SCRIPT_DIR=$(dirname "$REAL_PATH")
    if [ "$SCRIPT_NAME" = "oplist" ] && [ "$SCRIPT_DIR" = "$PREFIX/bin" ]; then
        ORIGINAL_SCRIPT=$(find "$HOME" -name "oplist.sh" -type f 2>/dev/null | head -n 1)
        if [ -n "$ORIGINAL_SCRIPT" ]; then
            SCRIPT_DIR=$(dirname "$ORIGINAL_SCRIPT")
            cd "$SCRIPT_DIR" || { echo -e "${ERROR} 无法切换到脚本目录"; exit 1; }
        else
            echo -e "${ERROR} 无法找到原始脚本位置，请重新安装"
            exit 1
        fi
    fi
    cd "$SCRIPT_DIR" || { echo -e "${ERROR} 无法切换到脚本目录"; exit 1; }
    FILE_NAME="openlist-android-arm64.tar.gz"
    DEST_DIR="$SCRIPT_DIR/Openlist"
    OPENLIST_LOGDIR="$DEST_DIR/data/log"
    OPENLIST_LOG="$OPENLIST_LOGDIR/openlist.log"
    OPENLIST_CONF="$DEST_DIR/data/config.json"
    ARIA2_DIR="$SCRIPT_DIR/aria2"
    ARIA2_LOG="$ARIA2_DIR/aria2.log"
    ARIA2_CONF="$ARIA2_DIR/aria2.conf"
    ARIA2_CMD="aria2c"
    GITHUB_TOKEN_FILE="$HOME/.github_token"
    ARIA2_SECRET_FILE="$HOME/.aria2_secret"
    OPLIST_PATH="$PREFIX/bin/oplist"
    CACHE_DIR="$DEST_DIR/.cache"
    VERSION_CACHE="$CACHE_DIR/version.cache"
    VERSION_CHECKING="$CACHE_DIR/version.checking"
}

ensure_oplist_shortcut() {
    if ! echo "$PATH" | grep -q "$PREFIX/bin"; then
        export PATH="$PATH:$PREFIX/bin"
        if ! grep -q "$PREFIX/bin" ~/.bashrc 2>/dev/null; then
            echo "export PATH=\$PATH:$PREFIX/bin" >> ~/.bashrc
        fi
        echo -e "${INFO} 已将 ${C_BOLD_YELLOW}$PREFIX/bin${C_RESET} 添加到 PATH。请重启终端确保永久生效。"
    fi
    if [ ! -f "$OPLIST_PATH" ] || [ "$REAL_PATH" != "$(readlink -f "$OPLIST_PATH")" ]; then
        if [ "$REAL_PATH" != "$OPLIST_PATH" ]; then
            cp "$REAL_PATH" "$OPLIST_PATH"
            chmod +x "$OPLIST_PATH"
            echo -e "${SUCCESS} 已将脚本安装为全局命令：${C_BOLD_YELLOW}oplist${C_RESET}"
            echo -e "${INFO} 你现在可以随时输入 ${C_BOLD_YELLOW}oplist${C_RESET} 启动管理菜单！"
            sleep 3
        fi
    fi
}

init_cache_dir() {
    [ -d "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR"
}

get_local_version() {
    if [ -f "$DEST_DIR/openlist" ]; then
        "$DEST_DIR/openlist" version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1
    fi
}

get_latest_version() {
    if [ -f "$VERSION_CACHE" ] && [ "$(find "$VERSION_CACHE" -mmin -20)" ]; then
        head -n1 "$VERSION_CACHE"
    else
        echo "检测更新中..."
    fi
}

check_version_bg() {
    if { [ ! -f "$VERSION_CACHE" ] || [ ! "$(find "$VERSION_CACHE" -mmin -20)" ]; } && \
       [ ! -f "$VERSION_CHECKING" ]; then
        get_github_token
        touch "$VERSION_CHECKING"
        (curl -s -m 10 -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/repos/OpenListTeam/OpenList/releases/latest" | \
          sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1 > "$VERSION_CACHE"
        rm -f "$VERSION_CHECKING") &
    fi
}

get_github_token() {
    if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
        echo -e "${INFO} 检测到你未设置 GitHub Token，请按项目readme提示获取Token。"
        echo -ne "${C_BOLD_CYAN}请输入你的 GitHub Token:${C_RESET}"
        read GITHUB_TOKEN
        echo "$GITHUB_TOKEN" > "$GITHUB_TOKEN_FILE"
        chmod 600 "$GITHUB_TOKEN_FILE"
    fi
    GITHUB_TOKEN=$(cat "$GITHUB_TOKEN_FILE")
}

get_aria2_secret() {
    if [ ! -f "$ARIA2_SECRET_FILE" ]; then
        echo -e "${INFO} 检测到你未设置 aria2 RPC 密钥。"
        echo -e "${C_BOLD_CYAN}请输入aria2 RPC密钥:${C_RESET}"
        read -p "" ARIA2_SECRET
        echo "$ARIA2_SECRET" > "$ARIA2_SECRET_FILE"
        chmod 600 "$ARIA2_SECRET_FILE"
    fi
    ARIA2_SECRET=$(cat "$ARIA2_SECRET_FILE")
}

check_aria2_files() {
    get_aria2_secret
    mkdir -p "$ARIA2_DIR"
    touch "$ARIA2_DIR/aria2.session"
    chmod a+x "$ARIA2_DIR/aria2.session"
    
    local missing_files=0
    echo -e "${INFO} 检查 aria2 相关文件..."
    
    if ! command -v wget >/dev/null 2>&1; then
        echo -e "${ERROR} 未检测到 wget，请先安装 wget。"
        return 1
    fi

    local files=(
        "aria2.conf|https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/aria2.conf|600|rpc-secret=$ARIA2_SECRET"
        "clean.sh|https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/clean.sh|+x"
        "dht.dat|https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/dht.dat"
        "dht6.dat|https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/dht6.dat"
    )

    for file_info in "${files[@]}"; do
        IFS='|' read -r filename url perm post_process <<< "$file_info"
        local filepath="$ARIA2_DIR/$filename"
        
        if [ ! -f "$filepath" ]; then
            echo -e "${INFO} $filename 文件缺失，正在下载..."
            wget -q --no-check-certificate "$url" -O "$filepath"
            
            if [ -s "$filepath" ]; then
                if [ -n "$perm" ]; then
                    if [ "$perm" = "+x" ]; then
                        chmod +x "$filepath"
                    else
                        chmod "$perm" "$filepath"
                    fi
                fi
                if [ -n "$post_process" ]; then
                    sed -i "s|^rpc-secret=.*|$post_process|" "$filepath"
                fi
                echo -e "${SUCCESS} 已下载${perm:+并配置} $filename：${C_BOLD_YELLOW}$filepath${C_RESET}"
            else
                echo -e "${ERROR} 下载 $filename 失败，请检查网络或稍后再试。"
                rm -f "$filepath"
                missing_files=1
            fi
        fi
    done
    
    return $missing_files
}

create_aria2_conf() {
    if [ ! -f "$ARIA2_CONF" ]; then
        check_aria2_files
    else
        get_aria2_secret
    fi
}

divider() {
    echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
}

ensure_aria2() {
    if ! command -v aria2c >/dev/null 2>&1; then
        echo -e "${WARN} 未检测到 aria2，正在尝试安装..."
        if command -v pkg >/dev/null 2>&1; then
            pkg update && pkg install -y aria2
        else
            echo -e "${ERROR} 无法自动安装 aria2，请手动安装后重试。"
            exit 1
        fi
    fi
}

get_latest_url() {
    get_github_token
    curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/OpenListTeam/OpenList/releases/latest" | \
        sed -n 's/.*"browser_download_url": *"\([^"]*android-arm64\.tar\.gz\)".*/\1/p' | head -n1
}

download_with_progress() {
    url="$1"
    output="$2"
    if echo "$url" | grep -q "githubusercontent.com"; then
        get_github_token
        curl -L --progress-bar -H "Authorization: token $GITHUB_TOKEN" -o "$output" "$url"
    else
        curl -L --progress-bar -o "$output" "$url"
    fi
}

extract_file() {
    file="$1"
    tar -zxf "$file"
}

install_openlist() {
    ensure_aria2
    DOWNLOAD_URL=$(get_latest_url)
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${ERROR} 未能获取到 OpenList 安装包下载地址。"
        return 1
    fi
    cd "$SCRIPT_DIR" || { echo -e "${ERROR} 无法切换到脚本目录。"; return 1; }
    echo -e "${INFO} 正在下载 ${C_BOLD_YELLOW}$FILE_NAME${C_RESET} ..."
    download_with_progress "$DOWNLOAD_URL" "$FILE_NAME" || { echo -e "${ERROR} 下载文件失败。"; cd - >/dev/null; return 1; }
    echo -e "${INFO} 正在解压 ${C_BOLD_YELLOW}$FILE_NAME${C_RESET} ..."
    extract_file "$FILE_NAME" || { echo -e "${ERROR} 解压文件失败。"; cd - >/dev/null; return 1; }
    if [ ! -f "openlist" ]; then
        echo -e "${ERROR} 未找到 openlist 可执行文件。"; cd - >/dev/null; return 1
    fi
    echo -e "${INFO} 创建文件夹 ${C_BOLD_YELLOW}$DEST_DIR${C_RESET} ..."
    mkdir -p "$DEST_DIR"
    mv -f openlist "$DEST_DIR/" || { echo -e "${ERROR} 移动 openlist 文件失败。"; cd - >/dev/null; return 1; }
    chmod +x "$DEST_DIR/openlist"
    rm -f "$FILE_NAME"
    echo -e "${SUCCESS} OpenList 安装完成！"
    cd - >/dev/null
    return 0
}

update_openlist() {
    ensure_aria2
    if [ ! -d "$DEST_DIR" ]; then
        echo -e "${ERROR} ${C_BOLD_YELLOW}$DEST_DIR${C_RESET} 文件夹不存在，请先安装 OpenList。"
        return 1
    fi
    DOWNLOAD_URL=$(get_latest_url)
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${ERROR} 未能获取到 OpenList 安装包下载地址。"
        return 1
    fi
    cd "$SCRIPT_DIR" || { echo -e "${ERROR} 无法切换到脚本目录。"; return 1; }
    echo -e "${INFO} 正在下载 ${C_BOLD_YELLOW}$FILE_NAME${C_RESET} ..."
    download_with_progress "$DOWNLOAD_URL" "$FILE_NAME" || { echo -e "${ERROR} 下载文件失败。"; cd - >/dev/null; return 1; }
    echo -e "${INFO} 正在解压 ${C_BOLD_YELLOW}$FILE_NAME${C_RESET} ..."
    extract_file "$FILE_NAME" || { echo -e "${ERROR} 解压文件失败。"; cd - >/dev/null; return 1; }
    rm -f "$DEST_DIR/openlist"
    mv -f openlist "$DEST_DIR/"
    chmod +x "$DEST_DIR/openlist"
    rm -f "$FILE_NAME"
    rm -f "$VERSION_CACHE"
    echo -e "${SUCCESS} OpenList 更新完成！"
    cd - >/dev/null
    return 0
}

check_openlist_process() {
    OPENLIST_BIN=$(readlink -f "$DEST_DIR/openlist")
    pgrep -f "$OPENLIST_BIN server" >/dev/null 2>&1
}

check_aria2_process() {
    pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF" >/dev/null 2>&1
}

enable_autostart_both() {
    mkdir -p "$HOME/.termux/boot"
    local boot_file="$HOME/.termux/boot/openlist_and_aria2_autostart.sh"
    cat > "$boot_file" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
ARIA2_CMD="$ARIA2_CMD"
ARIA2_CONF="$ARIA2_CONF"
\$ARIA2_CMD --conf-path="\$ARIA2_CONF" > "\$ARIA2_LOG" 2>&1 &

OPENLIST_DIR="$DEST_DIR"
OPENLIST_LOG="$OPENLIST_LOG"
cd "\$OPENLIST_DIR" || exit 1
"\$OPENLIST_DIR/openlist" server > "\$OPENLIST_LOG" 2>&1 &
EOF
    chmod +x "$boot_file"
    echo -e "${SUCCESS} OpenList 和 aria2 已成功设置开机自启"
}

disable_autostart_both() {
    local boot_file="$HOME/.termux/boot/openlist_and_aria2_autostart.sh"
    if [ -f "$boot_file" ]; then
        rm -f "$boot_file"
        echo -e "${INFO} 已禁用 OpenList 和 aria2 开机自启"
    fi
}

start_all() {
    ensure_aria2
    if [ ! -d "$DEST_DIR" ]; then
        echo -e "${ERROR} ${C_BOLD_YELLOW}$DEST_DIR${C_RESET} 文件夹不存在，请先安装 OpenList。"
        return 1
    fi
    check_aria2_files
    if [ $? -ne 0 ]; then
        echo -e "${ERROR} aria2 文件检查失败，无法启动 aria2。"
        return 1
    fi
    if check_aria2_process; then
        PIDS=$(pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF")
        echo -e "${WARN} aria2 已运行，PID：${C_BOLD_YELLOW}$PIDS${C_RESET}"
    else
        echo -e "${INFO} 启动 aria2 ..."
        $ARIA2_CMD --conf-path="$ARIA2_CONF" > "$ARIA2_LOG" 2>&1 &
        sleep 2
        ARIA2_PID=$(pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF" | head -n 1)
        if [ -n "$ARIA2_PID" ] && ps -p "$ARIA2_PID" >/dev/null 2>&1; then
            echo -e "${SUCCESS} aria2 已启动 (PID: ${C_BOLD_YELLOW}$ARIA2_PID${C_RESET})."
            echo -e "${INFO} RPC 密钥：${C_BOLD_YELLOW}$ARIA2_SECRET${C_RESET}"
        else
            echo -e "${ERROR} aria2 启动失败，继续启动 OpenList..."
        fi
    fi
    mkdir -p "$OPENLIST_LOGDIR"
    OPENLIST_BIN=$(readlink -f "$DEST_DIR/openlist")
    if check_openlist_process; then
        PIDS=$(pgrep -f "$OPENLIST_BIN server")
        echo -e "${WARN} OpenList server 已运行，PID：${C_BOLD_YELLOW}$PIDS${C_RESET}"
    else
        if [ ! -f "$DEST_DIR/openlist" ]; then
            echo -e "${ERROR} 未找到 openlist 可执行文件。"
            return 1
        fi
        if [ ! -x "$DEST_DIR/openlist" ]; then
            chmod +x "$DEST_DIR/openlist"
        fi
        divider
        echo -e "${INFO} 启动 OpenList server..."
        cd "$DEST_DIR" || { echo -e "${ERROR} 进入 ${C_BOLD_YELLOW}$DEST_DIR${C_RESET} 失败。"; return 1; }
        "$OPENLIST_BIN" server > "$OPENLIST_LOG" 2>&1 &
        OPENLIST_PID=$!
        cd "$SCRIPT_DIR"
        sleep 3
        if ps -p "$OPENLIST_PID" >/dev/null 2>&1; then
            echo -e "${SUCCESS} OpenList server 已启动 (PID: ${C_BOLD_YELLOW}$OPENLIST_PID${C_RESET})."
        else
            echo -e "${ERROR} OpenList server 启动失败。"
            return 1
        fi
        if [ -f "$OPENLIST_LOG" ]; then
            PASSWORD=$(grep -oP '(?<=initial password is: )\S+' "$OPENLIST_LOG")
            if [ -n "$PASSWORD" ]; then
                echo -e "${SUCCESS} 检测到 OpenList 初始账户信息："
                echo -e "    用户名：${C_BOLD_YELLOW}admin${C_RESET}"
                echo -e "    密码：  ${C_BOLD_YELLOW}$PASSWORD${C_RESET}"
                echo -e "${INFO} 请在系统浏览器访问：${C_BOLD_YELLOW}http://localhost:5244${C_RESET}"
            else
                echo -e "${INFO} 非首次启动未在日志中找到初始密码，请使用您设置的密码。"
                echo -e "${INFO} 请在系统浏览器访问：${C_BOLD_YELLOW}http://localhost:5244${C_RESET}"
            fi
        else
            echo -e "${ERROR} 未生成 openlist.log 日志文件。"
            echo -e "${INFO} 请在系统浏览器访问：${C_BOLD_YELLOW}http://localhost:5244${C_RESET}"
        fi
        divider
    fi
    if command -v termux-wake-lock >/dev/null 2>&1; then
        termux-wake-lock
    fi
    echo -e "${C_BOLD_CYAN}是否开启 OpenList 和 aria2 开机自启？(y/n):${C_RESET}"
    read -r enable_boot
    if [[ "$enable_boot" =~ ^[Yy]$ ]]; then
        enable_autostart_both
    else
        disable_autostart_both
        echo -e "${INFO} 未开启开机自启。"
    fi
    divider
    return 0
}

stop_all() {
    OPENLIST_BIN=$(readlink -f "$DEST_DIR/openlist")
    if check_openlist_process; then
        PIDS=$(pgrep -f "$OPENLIST_BIN server")
        echo -e "${INFO} 检测到 OpenList server 正在运行，PID：${C_BOLD_YELLOW}$PIDS${C_RESET}"
        echo -e "${INFO} 正在终止 OpenList server..."
        pkill -f "$OPENLIST_BIN server"
        sleep 1
        if check_openlist_process; then
            echo -e "${ERROR} 无法终止 OpenList server 进程。"
            return 1
        fi
        echo -e "${SUCCESS} OpenList server 已成功终止。"
    else
        echo -e "${WARN} OpenList server 未运行。"
    fi
    if check_aria2_process; then
        PIDS=$(pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF")
        echo -e "${INFO} 检测到 aria2 正在运行，PID：${C_BOLD_YELLOW}$PIDS${C_RESET}"
        echo -e "${INFO} 正在终止 aria2 ..."
        pkill -f "$ARIA2_CMD --conf-path=$ARIA2_CONF")
        sleep 1
        if check_aria2_process; then
            echo -e "${ERROR} 无法终止 aria2 进程。"
            return 1
        fi
        echo -e "${SUCCESS} aria2 已成功终止。"
    else
        echo -e "${WARN} aria2 未运行。"
    fi
    return 0
}

aria2_status_line() {
    if check_aria2_process; then
        PIDS=$(pgrep -f "$ARIA2_CMD --conf-path=$ARIA2_CONF")
        echo -e "${INFO} aria2 状态：${C_BOLD_GREEN}运行中 (PID: $PIDS)${C_RESET}"
    else
        echo -e "${INFO} aria2 状态：${C_BOLD_RED}未运行${C_RESET}"
    fi
}

openlist_status_line() {
    OPENLIST_BIN=$(readlink -f "$DEST_DIR/openlist")
    if check_openlist_process; then
        PIDS=$(pgrep -f "$OPENLIST_BIN server")
        echo -e "${INFO} OpenList 状态：${C_BOLD_GREEN}运行中 (PID: $PIDS)${C_RESET}"
    else
        echo -e "${INFO} OpenList 状态：${C_BOLD_RED}未运行${C_RESET}"
    fi
}

edit_openlist_config() {
    if ! command -v vim >/dev/null 2>&1; then
        echo -e "${ERROR} 未检测到 vim，请先安装 vim。"
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read -r
        return 1
    fi
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 编辑 OpenList 配置文件   │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    if [ -f "$OPENLIST_CONF" ]; then
        echo -e "${INFO} 正在编辑 OpenList 配置文件：${C_BOLD_YELLOW}$OPENLIST_CONF${C_RESET}"
        vim "$OPENLIST_CONF"
        echo -e "${SUCCESS} OpenList 配置文件编辑完成。"
    else
        echo -e "${ERROR} 未找到 OpenList 配置文件：${C_BOLD_YELLOW}$OPENLIST_CONF${C_RESET}"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read -r
}

edit_aria2_config() {
    if ! command -v vim >/dev/null 2>&1; then
        echo -e "${ERROR} 未检测到 vim，请先安装 vim。"
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read -r
        return 1
    fi
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 编辑 aria2 配置文件      │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    if [ -f "$ARIA2_CONF" ]; then
        echo -e "${INFO} 正在编辑 aria2 配置文件：${C_BOLD_YELLOW}$ARIA2_CONF${C_RESET}"
        vim "$ARIA2_CONF"
        echo -e "${SUCCESS} aria2 配置文件编辑完成。"
    else
        echo -e "${ERROR} 未找到 aria2 配置文件：${C_BOLD_YELLOW}$ARIA2_CONF${C_RESET}"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read -r
}

view_openlist_log() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 查看 OpenList 日志       │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    if [ -f "$OPENLIST_LOG" ]; then
        echo -e "${INFO} 显示 OpenList 日志文件：${C_BOLD_YELLOW}$OPENLIST_LOG${C_RESET}"
        cat "$OPENLIST_LOG"
    else
        echo -e "${ERROR} 未找到 OpenList 日志文件：${C_BOLD_YELLOW}$OPENLIST_LOG${C_RESET}"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read -r
}

view_aria2_log() {
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 查看 aria2 日志          │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    if [ -f "$ARIA2_LOG" ]; then
        echo -e "${INFO} 显示 aria2 日志文件：${C_BOLD_YELLOW}$ARIA2_LOG${C_RESET}"
        cat "$ARIA2_LOG"
    else
        echo -e "${ERROR} 未找到 aria2 日志文件：${C_BOLD_YELLOW}$ARIA2_LOG${C_RESET}"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read -r
}

update_bt_tracker() {
    if [ ! -f "$ARIA2_CONF" ]; then
        echo -e "${ERROR} 未找到 aria2 配置文件：${C_BOLD_YELLOW}$ARIA2_CONF${C_RESET}"
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read -r
        return 1
    fi
    get_github_token
    echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
    echo -e "${C_BOLD_BLUE}│ 更新 BT Tracker         │${C_RESET}"
    echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
    echo -e "${INFO} 正在更新 BT Tracker ..."
    bash <(wget --header="Authorization: token $GITHUB_TOKEN" -O - https://raw.githubusercontent.com/giturass/aria2.conf/refs/heads/master/tracker.sh) "$ARIA2_CONF"
    if [ $? -eq 0 ]; then
        echo -e "${SUCCESS} BT Tracker 更新完成！"
    else
        echo -e "${ERROR} BT Tracker 更新失败，请检查网络或 GitHub Token。"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read -r
}

update_script() {
    if [ "$SCRIPT_NAME" = "oplist" ]; then
        ORIGINAL_SCRIPT=$(find "$HOME" -name "oplist.sh" -type f 2>/dev/null | head -n 1)
        if [ -n "$ORIGINAL_SCRIPT" ]; then
            REAL_PATH="$ORIGINAL_SCRIPT"
        else
            echo -e "${ERROR} 无法找到原始脚本位置，更新失败。"
            return 1
        fi
    fi
    TMP_FILE="$SCRIPT_DIR/oplist.sh.new"
    echo -e "${INFO} 正在下载最新管理脚本..."
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate "https://raw.githubusercontent.com/giturass/openlist_termux/main/oplist.sh" -O "$TMP_FILE"
    else
        echo -e "${ERROR} 未检测到 wget，请先安装 wget。"
        echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
        read -r
        return 1
    fi
    if [ -s "$TMP_FILE" ]; then
        chmod +x "$TMP_FILE"
        mv "$TMP_FILE" "$REAL_PATH"
        if [ -f "$OPLIST_PATH" ] && [ "$REAL_PATH" != "$OPLIST_PATH" ]; then
            cp "$REAL_PATH" "$OPLIST_PATH"
            chmod +x "$OPLIST_PATH"
        fi
        echo -e "${SUCCESS} 管理脚本已更新为最新版本。"
        echo -e "${INFO} 请用命令：${C_BOLD_YELLOW}oplist${C_RESET} 重新运行。"
        sleep 1
        exec "$OPLIST_PATH"
    else
        echo -e "${ERROR} 下载最新管理脚本失败，请检查网络或稍后再试。"
        rm -f "$TMP_FILE"
    fi
    echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
    read -r
}

show_menu() {
    clear
    echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
    echo -e "${C_BOLD_MAGENTA}         🌟 OpenList 管理菜单 🌟${C_RESET}"
    echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
    init_cache_dir
    local_ver=$(get_local_version)
    latest_ver=$(get_latest_version)
    if [ "$latest_ver" = "检测更新中..." ]; then
        ver_status="${C_BOLD_YELLOW}检测更新中...${C_RESET}"
    elif [ -z "$local_ver" ]; then
        ver_status="${C_BOLD_YELLOW}未安装${C_RESET}"
    elif [ -z "$latest_ver" ]; then
        ver_status="${C_BOLD_GREEN}已安装 $local_ver${C_RESET}"
    elif [ "$local_ver" = "$latest_ver" ]; then
        ver_status="${C_BOLD_GREEN}已是最新版本 $local_ver${C_RESET}"
    else
        ver_status="${C_BOLD_YELLOW}有新版本 $latest_ver (当前 $local_ver)${C_RESET}"
    fi
    openlist_status_line
    aria2_status_line
    echo -e "${INFO} OpenList 版本：$ver_status"
    echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
    echo -e "${C_BOLD_GREEN}a. 安装 OpenList${C_RESET}"
    echo -e "${C_BOLD_YELLOW}b. 更新 OpenList${C_RESET}"
    echo -e "${C_BOLD_CYAN}c. 启动 OpenList 和 aria2${C_RESET}"
    echo -e "${C_BOLD_RED}d. 停止 OpenList 和 aria2${C_RESET}"
    echo -e "${C_BOLD_MAGENTA}e. 编辑 OpenList 配置文件${C_RESET}"
    echo -e "${C_BOLD_MAGENTA}f. 编辑 aria2 配置文件${C_RESET}"
    echo -e "${C_BOLD_MAGENTA}g. 查看 OpenList 启动日志${C_RESET}"
    echo -e "${C_BOLD_MAGENTA}h. 查看 aria2 启动日志${C_RESET}"
    echo -e "${C_BOLD_YELLOW}i. 更新 aria2 BT Tracker${C_RESET}"
    echo -e "${C_BOLD_YELLOW}j. 更新管理脚本${C_RESET}"
    echo -e "${C_BOLD_WHITE}k. 退出${C_RESET}"
    echo -e "${C_BOLD_BLUE}=====================================${C_RESET}"
    echo -e "${C_BOLD_CYAN}请输入选项 (a-k):${C_RESET} \c"
}

init_paths
ensure_oplist_shortcut

while true; do
    show_menu
    check_version_bg
    read -r choice
    case $choice in
        a|A)
            echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
            echo -e "${C_BOLD_BLUE}│ 安装 OpenList           │${C_RESET}"
            echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
            install_openlist
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read -r
            ;;
        b|B)
            echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
            echo -e "${C_BOLD_BLUE}│ 更新 OpenList           │${C_RESET}"
            echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
            update_openlist
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read -r
            ;;
        c|C)
            echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
            echo -e "${C_BOLD_BLUE}│ 启动 OpenList 和 aria2 │${C_RESET}"
            echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
            start_all
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read -r
            ;;
        d|D)
            echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
            echo -e "${C_BOLD_BLUE}│ 停止 OpenList 和 aria2 │${C_RESET}"
            echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
            stop_all
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read -r
            ;;
        e|E)
            edit_openlist_config
            ;;
        f|F)
            edit_aria2_config
            ;;
        g|G)
            view_openlist_log
            ;;
        h|H)
            view_aria2_log
            ;;
        i|I)
            update_bt_tracker
            ;;
        j|J)
            echo -e "${C_BOLD_BLUE}┌──────────────────────────┐${C_RESET}"
            echo -e "${C_BOLD_BLUE}│ 更新管理脚本           │${C_RESET}"
            echo -e "${C_BOLD_BLUE}└──────────────────────────┘${C_RESET}"
            update_script
            ;;
        k|K)
            echo -e "${INFO} 退出程序。"
            exit 0
            ;;
        *)
            echo -e "${ERROR} 无效选项，请输入 a-k。"
            echo -e "${C_BOLD_MAGENTA}按回车键返回菜单...${C_RESET}"
            read -r
            ;;
    esac
done