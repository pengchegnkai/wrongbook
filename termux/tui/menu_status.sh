#!/data/data/com.termux/files/usr/bin/bash
# menu_status.sh —— 状态总览（3 秒刷新，q 暂停/退出；whiptail 下为单次快照）
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"; source "$TUI_DIR/lib/services.sh"; source "$TUI_DIR/lib/db.sh"

snapshot() {
  echo "===== 系统资源 ====="
  echo "内存: $(free -h 2>/dev/null | awk 'NR==2{print $3" / "$2}')"
  echo "存储: $(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $3" / "$2" ("$5")"}')"
  echo "CPU 负载: $(cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3)"
  echo "电池: $(termux-battery-status 2>/dev/null | grep -oP '"percentage":\s*\K\d+' || echo '需 Termux:API')"
  echo "温度: $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f°C", $1/1000}' || echo '不可读')"
  echo ""
  echo "===== 服务健康 ====="
  echo "API    : $(api_ok && echo OK || echo '无响应')"
  echo "模型   : $(llama_ok && echo OK || echo '无响应')"
  echo "数据库 : $(pg_ok && echo OK || echo '无响应')"
  echo ""
  echo "===== 数据概览 ====="
  echo "注册用户: $(db_row_count users)"
  echo "错题总数: $(db_row_count questions)"
  echo "今日待复习: $(psql -U "$PGUSER_DEFAULT" -d "$PGDATABASE_DEFAULT" -tAc "SELECT COUNT(*) FROM questions WHERE review_today=true" 2>/dev/null || echo '?')"
  echo "模型: $(current_model 2>/dev/null || echo '-')"
}

if [ "$USE_WHRIPTAIL" = "1" ]; then
  while true; do
    snapshot > "$LOG_DIR/.status_snapshot"
    whiptail --title "状态总览（每3秒刷新，Cancel 退出）" --textbox "$LOG_DIR/.status_snapshot" 24 76 \
      && sleep 3 || break
  done
else
  while true; do
    clear; snapshot
    echo ""
    echo "r=刷新  q=退出（3 秒后自动刷新）"
    read -t 3 -n 1 k
    case "$k" in q|Q) break;; esac
  done
fi
