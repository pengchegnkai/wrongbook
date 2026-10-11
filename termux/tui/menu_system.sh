#!/data/data/com.termux/files/usr/bin/bash
# menu_system.sh —— 系统工具
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"

while true; do
  c=$(menu "系统工具" \
    "1|系统信息" "2|磁盘占用" "3|清理缓存" \
    "4|进程列表" "5|杀死指定进程" "6|检查端口占用" \
    "7|更新 Termux 包" "8|测试 API 连通性" \
    "0|返回")
  case "$c" in
    1) pause_run "uname -a; echo; termux-info 2>/dev/null | head -20 || pkg --version 2>/dev/null" ;;
    2) pause_run "du -sh ~/cuoti/* 2>/dev/null; echo; df -h ~" ;;
    3) danger_confirm "清理 npm 缓存与 TUI 临时文件" && pause_run "npm cache clean --force 2>/dev/null; rm -f $LOG_DIR/.status_snapshot $LOG_DIR/.tui_last_output; echo 已清理" ;;
    4) pause_run "ps aux 2>/dev/null | head -40 || ps -ef 2>/dev/null | head -40" ;;
    5) pid=$(input "要杀死的 PID" "")
       [ -n "$pid" ] && danger_confirm "杀死进程 $pid" && kill "$pid" 2>/dev/null && msg "已发送 TERM" || err_friendly "杀死失败（权限不足或 PID 不存在）" ;;
    6) p=$(input "检查端口" "3000"); pause_run "ss -tlnp 2>/dev/null | grep \":$p\" || netstat -tlnp 2>/dev/null | grep \":$p\" || echo 端口空闲" ;;
    7) danger_confirm "pkg update && pkg upgrade（耗时较长）" && pause_run "pkg update -y && pkg upgrade -y" ;;
    8) pause_run "echo API:; curl -s -m 5 http://127.0.0.1:3000/api/health || echo 无响应; echo; echo 模型:; curl -s -m 5 http://127.0.0.1:8080/health || echo 无响应" ;;
    ""|"ESC") break ;;
  esac
done
