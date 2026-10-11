#!/data/data/com.termux/files/usr/bin/bash
# menu_services.sh —— 服务管理（2026-10：PostgreSQL 用 pg_ctl，llama-server 用 pkg 版）
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"; source "$TUI_DIR/lib/services.sh"

while true; do
  c=$(menu "服务管理" \
    "1|查看全部服务状态" \
    "2|启动单个服务" "3|停止单个服务" "4|重启单个服务" \
    "5|启动全部" "6|停止全部" "7|重启全部" \
    "8|PID/端口/内存详情" \
    "9|开机自启开关说明" \
    "0|返回")
  case "$c" in
    1) svc_show_all_status ;;
    2) s=$(menu "启动" "1|postgresql" "2|node" "3|llama" "4|redis"); [ -n "$s" ] && case $s in 1) svc_start postgresql;; 2) svc_start node;; 3) svc_start llama;; 4) svc_start redis;; esac; msg "已执行" ;;
    3) s=$(menu "停止" "1|postgresql" "2|node" "3|llama" "4|redis")
       if [ -n "$s" ]; then danger_confirm "停止服务 $s" && case $s in 1) svc_stop postgresql;; 2) svc_stop node;; 3) svc_stop llama;; 4) svc_stop redis;; esac; fi ;;
    4) s=$(menu "重启" "1|postgresql" "2|node" "3|llama" "4|redis"); [ -n "$s" ] && case $s in 1) svc_restart postgresql;; 2) svc_restart node;; 3) svc_restart llama;; 4) svc_restart redis;; esac; msg "已执行" ;;
    5) bash "$TERMUX_SCRIPTS/start-all.sh" | tail -20; pause_run "true" ;;
    6) danger_confirm "停止全部服务" && bash "$TERMUX_SCRIPTS/stop-all.sh" && msg "已全部停止" ;;
    7) danger_confirm "重启全部服务" && bash "$TERMUX_SCRIPTS/stop-all.sh" && bash "$TERMUX_SCRIPTS/start-all.sh" && msg "已全部重启" ;;
    8) svc_pid_port_mem ;;
    9) msg "开机自启：未装 Termux:Boot，当前用 nohup+PM2。
可选装 Termux:Boot（F-Droid），创建 ~/.termux/boot/start-cuoti.sh 内容：
  #!/data/data/com.termux/files/usr/bin/bash
  bash ~/cuoti/termux/start-all.sh
（未验证，需你实测）" ;;
    ""|"ESC") break ;;
  esac
done
