#!/data/data/com.termux/files/usr/bin/bash
# lib/common.sh —— TUI 公共函数：whiptail 检测 + 纯 bash 降级
export CUOTI_DIR="$HOME/cuoti"
export LOG_DIR="$CUOTI_DIR/logs"
export TERMUX_SCRIPTS="$CUOTI_DIR/termux"
export PGUSER_DEFAULT="cuotiadmin"
export PGDATABASE_DEFAULT="cuoti"

mkdir -p "$LOG_DIR"

USE_WHRIPTAIL=0
if command -v whiptail >/dev/null 2>&1; then
  USE_WHRIPTAIL=1
fi

# confirm <消息> -> 0=确认 1=取消
confirm() {
  if [ "$USE_WHRIPTAIL" = "1" ]; then
    whiptail --title "确认" --yesno "$1" 10 60
  else
    printf "%s\n确认? (y/N): " "$1"
    read -r ans
    [ "$ans" = "y" ] || [ "$ans" = "Y" ]
  fi
}

# msg <消息>
msg() {
  if [ "$USE_WHRIPTAIL" = "1" ]; then
    whiptail --title "提示" --msgbox "$1" 12 70
  else
    printf "\n=== %s ===\n按回车继续..." "$1"
    read -r _
  fi
}

# menu <标题> "<值|显示文字>" ...  -> 输出所选值，ESC 返回空串
menu() {
  local title="$1"; shift
  if [ "$USE_WHRIPTAIL" = "1" ]; then
    local args=()
    for item in "$@"; do
      local v="${item%%|*}" t="${item#*|}"
      args+=("$v" "$t")
    done
    whiptail --title "$title" --menu "选择（Esc 返回）" 20 70 12 "${args[@]}" \
      3>&1 1>&2 2>&3
  else
    printf "\n=== %s ===\n" "$title"
    local i=1
    local values=()
    for item in "$@"; do
      printf "  %d. %s\n" "$i" "${item#*|}"
      values+=("${item%%|*}")
      i=$((i+1))
    done
    printf "  0. 返回\n选择: "
    read -r n
    case "$n" in
      0|""|q|Q) echo "" ;;
      ''|*[!0-9]*) echo "" ;;
      *) [ "$n" -le "${#values[@]}" ] && echo "${values[$((n-1))]}" || echo "" ;;
    esac
  fi
}

# input <标题> <默认值> -> 输入内容，取消返回空
input() {
  local title="$1" default="${2:-}"
  if [ "$USE_WHRIPTAIL" = "1" ]; then
    whiptail --title "$title" --inputbox "$title" 10 60 "$default" 3>&1 1>&2 2>&3
  else
    printf "%s [%s]: " "$title" "$default"
    read -r v
    echo "${v:-$default}"
  fi
}

# pause_run <命令> 执行命令并展示输出（whiptail 模式落盘再展示）
pause_run() {
  local cmd="$1"
  if [ "$USE_WHRIPTAIL" = "1" ]; then
    local tmp="$LOG_DIR/.tui_last_output"
    bash -c "$cmd" > "$tmp" 2>&1 || true
    whiptail --title "输出" --textbox "$tmp" 22 76
  else
    bash -c "$cmd"
    printf "\n按回车继续..."
    read -r _
  fi
}

# 服务探活快捷函数
api_ok() { curl -s -m 3 http://127.0.0.1:3000/api/health >/dev/null 2>&1; }
llama_ok() { curl -s -m 3 http://127.0.0.1:8080/health >/dev/null 2>&1; }
pg_ok() { pg_isready -q 2>/dev/null; }

# 危险操作统一：需输入 y 确认
danger_confirm() {
  local what="$1"
  if [ "$USE_WHRIPTAIL" = "1" ]; then
    whiptail --title "危险操作" --yesno "危险操作：$what\n\n确定继续？" 12 60
  else
    printf "危险操作：%s\n输入 y 确认: " "$what"
    read -r a; [ "$a" = "y" ] || [ "$a" = "Y" ]
  fi
}

err_friendly() {
  msg "操作失败：$1
（原始错误已写入 $LOG_DIR/tui-error.log）"
  echo "$(date '+%F %T') $1" >> "$LOG_DIR/tui-error.log"
}
