#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m'
INFO="${BLUE}[INFO]${NC}"
ERROR="${RED}❌ [ERROR]${NC}"
SUCCESS="${GREEN}✅ [OK]${NC}"
WARN="${YELLOW}⚠️ [WARN]${NC}"

init_paths() {
  REAL_PATH=$(readlink -f "$0")
  SCRIPT_NAME=$(basename "$REAL_PATH")
  SCRIPT_DIR=$(dirname "$REAL_PATH")

  if [ "$SCRIPT_NAME" = "oplist" ] && [ "$SCRIPT_DIR" = "$PREFIX/bin" ]; then
    ORIGINAL_SCRIPT=$(find "$HOME" -name "oplist.sh" -type f 2>/dev/null | head -n 1)
    if [ -n "$ORIGINAL_SCRIPT" ]; then
      SCRIPT_DIR=$(dirname "$ORIGINAL_SCRIPT")
      cd "$SCRIPT_DIR" || exit 1
    else
      echo -e "${ERROR} 无法找到原始脚本位置,请重新安装"
      exit 1
    fi
  fi

  cd "$SCRIPT_DIR" || exit 1

  FILE_NAME="openlist-android-arm64.tar.gz"
  DEST_DIR="$SCRIPT_DIR/Openlist"
  OPENLIST_LOGDIR="$DEST_DIR/data/log"
  OPENLIST_LOG="$OPENLIST_LOGDIR/openlist.log"
  ARIA2_DIR="$SCRIPT_DIR/aria2"
  ARIA2_LOG="$ARIA2_DIR/aria2.log"
  ARIA2_CMD="aria2c"
  GITHUB_TOKEN_FILE="$HOME/.openlist_token"
  ARIA2_SECRET_FILE="$HOME/.openlist_aria2_secret"
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
    if ! grep -q "$PREFIX/bin" ~/.zshrc 2>/dev/null; then
      echo "export PATH=\$PATH:$PREFIX/bin" >> ~/.zshrc
    fi
    echo -e "${INFO} 已将 $PREFIX/bin 添加到 PATH。请重启终端确保永久生效。"
  fi
  
  if [ ! -f "$OPLIST_PATH" ] || [ "$REAL_PATH" != "$(readlink -f "$OPLIST_PATH")" ]; then
    if [ "$REAL_PATH" != "$OPLIST_PATH" ]; then
      cp "$REAL_PATH" "$OPLIST_PATH"
      chmod +x "$OPLIST_PATH"
      echo -e "${SUCCESS} 已将脚本安装为全局命令：${YELLOW}oplist${NC}"
      echo -e "${INFO} 你现在可以随时输入 ${YELLOW}oplist${NC} 启动管理菜单！"
      sleep 2
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
  if [ -f "$VERSION_CACHE" ] && [ "$(find "$VERSION_CACHE" -mmin -15)" ]; then
    head -n1 "$VERSION_CACHE"
  else
    echo "检测更新中..."
  fi
}

check_version_bg() {
  if { [ ! -f "$VERSION_CACHE" ] || [ ! "$(find "$VERSION_CACHE" -mmin -15)" ]; } && \
     [ ! -f "$VERSION_CHECKING" ]; then
    get_github_token
    touch "$VERSION_CHECKING"
    (curl -s -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/OpenListTeam/OpenList/releases/latest" | \
      sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1 > "$VERSION_CACHE"
    rm -f "$VERSION_CHECKING") &
  fi
}

get_github_token() {
  if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
    echo -e "${INFO} 检测到你未设置 GitHub Token，请按项目readme提示获取Token。"
    read -ep "请输入你的 GitHub Token: " GITHUB_TOKEN
    echo "$GITHUB_TOKEN" > "$GITHUB_TOKEN_FILE"
    chmod 600 "$GITHUB_TOKEN_FILE"
  fi
  GITHUB_TOKEN=$(cat "$GITHUB_TOKEN_FILE")
}

get_aria2_secret() {
  if [ ! -f "$ARIA2_SECRET_FILE" ]; then
    echo -e "${INFO} 检测到你未设置 aria2 rpc 密钥。"
    read -ep "请输入aria2 rpc密钥: " ARIA2_SECRET
    echo "$ARIA2_SECRET" > "$ARIA2_SECRET_FILE"
    chmod 600 "$ARIA2_SECRET_FILE"
  fi
  ARIA2_SECRET=$(cat "$ARIA2_SECRET_FILE")
}

divider() {
  echo -e "${YELLOW}------------------------------------------------------------${NC}"
}

ensure_aria2() {
  if ! command -v aria2c >/dev/null 2>&1; then
    echo -e "${WARN} 未检测到 aria2c，正在尝试安装..."
    if command -v pkg >/dev/null 2>&1; then
      pkg update && pkg install -y aria2
    else
      echo -e "${ERROR} 无法自动安装 aria2c，请手动安装后重试。"
      exit 1
    fi
  fi
}

get_latest_url() {
  get_github_token
  curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/OpenListTeam/OpenList/releases/latest" | sed -n 's/.*"browser_download_url": *"\([^"]*android-arm64\.tar\.gz\)".*/\1/p' | head -n1
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
  echo -e "${INFO} 正在下载 ${YELLOW}$FILE_NAME${NC} ..."
  download_with_progress "$DOWNLOAD_URL" "$FILE_NAME" || { echo -e "${ERROR} 下载文件失败。"; cd - >/dev/null; return 1; }
  echo -e "${INFO} 正在解压 ${YELLOW}$FILE_NAME${NC} ..."
  extract_file "$FILE_NAME" || { echo -e "${ERROR} 解压文件失败。"; cd - >/dev/null; return 1; }
  if [ ! -f "openlist" ]; then
    echo -e "${ERROR} 未找到 openlist 可执行文件。"; cd - >/dev/null; return 1
  fi
  echo -e "${INFO} 创建文件夹 ${YELLOW}$DEST_DIR${NC} ..."
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
    echo -e "${ERROR} $DEST_DIR 文件夹不存在，请先安装 OpenList。"
    return 1
  fi
  DOWNLOAD_URL=$(get_latest_url)
  if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${ERROR} 未能获取到 OpenList 安装包下载地址。"
    return 1
  fi
  cd "$SCRIPT_DIR" || { echo -e "${ERROR} 无法切换到脚本目录。"; return 1; }
  echo -e "${INFO} 正在下载 ${YELLOW}$FILE_NAME${NC} ..."
  download_with_progress "$DOWNLOAD_URL" "$FILE_NAME" || { echo -e "${ERROR} 下载文件失败。"; cd - >/dev/null; return 1; }
  echo -e "${INFO} 正在解压 ${YELLOW}$FILE_NAME${NC} ..."
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
  pgrep -f "$ARIA2_CMD --enable-rpc" >/dev/null 2>&1
}

start_all() {
  ensure_aria2
  if [ ! -d "$DEST_DIR" ]; then
    echo -e "${ERROR} $DEST_DIR 文件夹不存在，请先安装 OpenList。"
    return 1
  fi
  mkdir -p "$ARIA2_DIR"
  get_aria2_secret
  if check_aria2_process; then
    PIDS=$(pgrep -f "$ARIA2_CMD --enable-rpc")
    echo -e "${WARN} aria2 已运行，PID：$PIDS"
  else
    echo -e "${INFO} 启动 aria2c ..."
    nohup $ARIA2_CMD --enable-rpc --rpc-listen-all=true --rpc-secret="$ARIA2_SECRET" > "$ARIA2_LOG" 2>&1 &
    sleep 2
    ARIA2_PID=$(pgrep -f "$ARIA2_CMD --enable-rpc" | head -n 1)
    if [ -n "$ARIA2_PID" ] && ps -p "$ARIA2_PID" >/dev/null 2>&1; then
      echo -e "${SUCCESS} aria2 已启动 (PID: $ARIA2_PID)。"
      echo -e "${INFO} 日志文件位置: ${YELLOW}$ARIA2_LOG${NC}"
      echo -e "${INFO} rpc 密钥: ${YELLOW}$ARIA2_SECRET${NC}"
    else
      echo -e "${ERROR} aria2 启动失败。"
      return 1
    fi
  fi

  mkdir -p "$OPENLIST_LOGDIR"
  OPENLIST_BIN=$(readlink -f "$DEST_DIR/openlist")
  if check_openlist_process; then
    PIDS=$(pgrep -f "$OPENLIST_BIN server")
    echo -e "${WARN} OpenList server 已运行，PID：$PIDS"
  else
    if [ ! -f "$DEST_DIR/openlist" ]; then
      echo -e "${ERROR} 未找到 openlist 可执行文件。"
      return 1
    fi
    if [ ! -x "$DEST_DIR/openlist" ]; then
      chmod +x "$DEST_DIR/openlist"
    fi
    divider
    echo -e "${INFO} 启动 openlist server..."
    cd "$DEST_DIR" || { echo -e "${ERROR} 进入 $DEST_DIR 失败。"; return 1; }
    "$OPENLIST_BIN" server > "$OPENLIST_LOG" 2>&1 &
    OPENLIST_PID=$!
    cd "$SCRIPT_DIR"
    sleep 3
    if ps -p "$OPENLIST_PID" >/dev/null 2>&1; then
      echo -e "${SUCCESS} OpenList server 已启动 (PID: $OPENLIST_PID)。"
    else
      echo -e "${ERROR} OpenList server 启动失败。"
      return 1
    fi
    if [ -f "$OPENLIST_LOG" ]; then
      PASSWORD=$(grep -oP '(?<=initial password is: )\S+' "$OPENLIST_LOG")
      if [ -n "$PASSWORD" ]; then
        echo -e "${SUCCESS} 检测到 OpenList 初始账户信息："
        echo -e "    用户名：${YELLOW}admin${NC}"
        echo -e "    密码：  ${YELLOW}$PASSWORD${NC}"
        echo -e "${INFO} 请在系统浏览器中访问：${YELLOW}http://localhost:5244${NC}"
      else
        echo -e "${WARN} 未在日志中找到初始密码，可能不是首次启动或请使用您设置的密码。"
        echo -e "${INFO} 若您已设置过账户密码，请系统浏览器直接访问：${YELLOW}http://localhost:5244${NC}"
      fi
    else
      echo -e "${ERROR} 未生成 openlist.log 日志文件。"
      echo -e "${INFO} 系统浏览器访问：${YELLOW}http://localhost:5244${NC}"
    fi
    echo -e "${INFO} 日志文件位于 ${YELLOW}$OPENLIST_LOG${NC}"
    divider
  fi
  return 0
}

stop_all() {
  OPENLIST_BIN=$(readlink -f "$DEST_DIR/openlist")
  if check_openlist_process; then
    PIDS=$(pgrep -f "$OPENLIST_BIN server")
    echo -e "${INFO} 检测到 OpenList server 正在运行，PID：$PIDS"
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
    PIDS=$(pgrep -f "$ARIA2_CMD --enable-rpc")
    echo -e "${INFO} 检测到 aria2 正在运行，PID：$PIDS"
    echo -e "${INFO} 正在终止 aria2 ..."
    pkill -f "$ARIA2_CMD --enable-rpc"
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
    PIDS=$(pgrep -f "$ARIA2_CMD --enable-rpc")
    echo -e "${INFO} aria2 状态：${GREEN}运行中 (PID: $PIDS)${NC}"
  else
    echo -e "${INFO} aria2 状态：${RED}未运行${NC}"
  fi
}

openlist_status_line() {
  OPENLIST_BIN=$(readlink -f "$DEST_DIR/openlist")
  if check_openlist_process; then
    PIDS=$(pgrep -f "$OPENLIST_BIN server")
    echo -e "${INFO} OpenList 状态：${GREEN}运行中 (PID: $PIDS)${NC}"
  else
    echo -e "${INFO} OpenList 状态：${RED}未运行${NC}"
  fi
}

view_openlist_log() {
  LOG_FILE="$OPENLIST_LOG"
  if [ ! -f "$LOG_FILE" ]; then
    echo -e "${ERROR} 未找到OpenList日志文件：$LOG_FILE"
    return 1
  fi
  echo -e "${INFO} 显示OpenList日志文件：${YELLOW}$LOG_FILE${NC}"
  cat "$LOG_FILE"
  echo -e "按回车键返回菜单..."
  read -r
}

view_aria2_log() {
  LOG_FILE="$ARIA2_LOG"
  if [ ! -f "$LOG_FILE" ]; then
    echo -e "${ERROR} 未找到aria2日志文件：$LOG_FILE"
    return 1
  fi
  echo -e "${INFO} 显示aria2日志文件：${YELLOW}$LOG_FILE${NC}"
  cat "$LOG_FILE"
  echo -e "按回车键返回菜单..."
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
    echo -e "按回车键返回菜单..."
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
    echo -e "${INFO} 请用命令：${YELLOW}oplist${NC} 重新运行。"
    sleep 1
    exec "$OPLIST_PATH"
  else
    echo -e "${ERROR} 下载最新管理脚本失败，请检查网络或稍后再试。"
    rm -f "$TMP_FILE"
  fi
  
  echo -e "按回车键返回菜单..."
  read -r
}

show_menu() {
  clear
  divider
  echo -e "${GREEN}       OpenList 管理菜单${NC}"
  divider

  init_cache_dir
  local_ver=$(get_local_version)
  latest_ver=$(get_latest_version)

  if [ "$latest_ver" = "检测更新中..." ]; then
    ver_status="${YELLOW}检测更新中...${NC}"
  elif [ -z "$local_ver" ]; then
    ver_status="${YELLOW}未安装${NC}"
  elif [ -z "$latest_ver" ]; then
    ver_status="${GREEN}已安装 $local_ver${NC}"
  elif [ "$local_ver" = "$latest_ver" ]; then
    ver_status="${GREEN}已是最新版本 $local_ver${NC}"
  else
    ver_status="${YELLOW}有新版本 $latest_ver (当前 $local_ver)${NC}"
  fi

  openlist_status_line
  aria2_status_line
  echo -e "${INFO} OpenList 版本：$ver_status"
  divider
  echo -e "${YELLOW}1)${NC} 安装 OpenList"
  echo -e "${YELLOW}2)${NC} 更新 OpenList"
  echo -e "${YELLOW}3)${NC} 启动 OpenList 和 aria2"
  echo -e "${YELLOW}4)${NC} 停止 OpenList 和 aria2"
  echo -e "${YELLOW}5)${NC} 查看OpenList启动日志"
  echo -e "${YELLOW}6)${NC} 查看aria2启动日志"
  echo -e "${YELLOW}7)${NC} 更新管理脚本"
  echo -e "${YELLOW}0)${NC} 退出"
  divider
}

init_paths
ensure_oplist_shortcut

while true; do
  show_menu
  check_version_bg
  read -ep "请输入选项 (0-7): " choice
  case $choice in
    1) install_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    2) update_openlist; echo -e "按回车键返回菜单..."; read -r ;;
    3) start_all; echo -e "按回车键返回菜单..."; read -r ;;
    4) stop_all; echo -e "按回车键返回菜单..."; read -r ;;
    5) view_openlist_log ;;
    6) view_aria2_log ;;
    7) update_script ;;
    0) echo -e "${INFO} 退出程序。"; exit 0 ;;
    *) echo -e "${ERROR} 无效选项，请输入 0-7。"; echo -e "按回车键返回菜单..."; read -r ;;
  esac
done
