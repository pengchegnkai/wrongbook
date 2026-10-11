#!/data/data/com.termux/files/usr/bin/bash
# menu_logs.sh —— 日志查看
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"

LOG_SOURCES=(
  "pm2-out|$LOG_DIR/pm2-out.log"
  "pm2-err|$LOG_DIR/pm2-err.log"
  "llama-server|$LOG_DIR/llama-server.log"
  "postgres|$LOG_DIR/postgres.log"
  "tui-error|$LOG_DIR/tui-error.log"
)

find_log() {
  for e in "${LOG_SOURCES[@]}"; do
    [ "${e%%|*}" = "$1" ] && echo "${e#*|}" && return
  done
}

while true; do
  c=$(menu "日志查看" \
    "1|实时查看（tail -f）" "2|查看最近 200 行" "3|关键词过滤" \
    "4|导出日志" "5|清空日志" "0|返回")
  case "$c" in
    1) s=$(menu "选择日志源" "1|pm2-out" "2|pm2-err" "3|llama-server" "4|postgres" "5|tui-error")
       [ -n "$s" ] && f=$(find_log "${LOG_SOURCES[$((s-1))]%%|*}") && echo "Ctrl+C 退出跟踪" && tail -f "$f" 2>/dev/null || msg "日志为空或不存在"
       ;;
    2) s=$(menu "选择日志源" "1|pm2-out" "2|pm2-err" "3|llama-server" "4|postgres" "5|tui-error")
       [ -n "$s" ] && pause_run "tail -n 200 '${LOG_SOURCES[$((s-1))]#*|}'" ;;
    3) kw=$(input "关键词" ""); s=$(menu "选择日志源" "1|pm2-out" "2|pm2-err" "3|llama-server" "4|postgres" "5|tui-error")
       [ -n "$s" ] && pause_run "grep -n '$kw' '${LOG_SOURCES[$((s-1))]#*|}' | tail -n 100" ;;
    4) s=$(menu "选择日志源" "1|pm2-out" "2|pm2-err" "3|llama-server" "4|postgres" "5|tui-error")
       [ -n "$s" ] && src="${LOG_SOURCES[$((s-1))]#*|}" && cp "$src" "$LOG_DIR/export-${src##*/}" && msg "已导出到 $LOG_DIR/export-${src##*/}" ;;
    5) s=$(menu "选择日志源" "1|pm2-out" "2|pm2-err" "3|llama-server" "4|postgres" "5|tui-error" "6|全部")
       if [ -n "$s" ]; then danger_confirm "清空日志（不可恢复）" && \
         if [ "$s" = "6" ]; then for e in "${LOG_SOURCES[@]}"; do : > "${e#*|}" 2>/dev/null; done; else : > "${LOG_SOURCES[$((s-1))]#*|}" 2>/dev/null; fi
         msg "已清空"; fi ;;
    ""|"ESC") break ;;
  esac
done
