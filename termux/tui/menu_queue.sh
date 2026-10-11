#!/data/data/com.termux/files/usr/bin/bash
# menu_queue.sh —— 队列管理（本地离线队列存于 local_records 表）
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"; source "$TUI_DIR/lib/db.sh"

while true; do
  c=$(menu "队列管理" \
    "1|待处理队列" "2|失败任务" "3|队列统计" \
    "4|重试失败任务" "5|删除队列项" "6|清空队列" \
    "0|返回")
  case "$c" in
    1) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"SELECT id, user_id, action, status, created_at FROM local_records WHERE status=\x27pending\x27 ORDER BY created_at LIMIT 50;\"'" ;;
    2) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"SELECT id, action, last_error, retry_count FROM local_records WHERE status=\x27failed\x27 ORDER BY updated_at DESC LIMIT 50;\"'" ;;
    3) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"SELECT status, COUNT(*) FROM local_records GROUP BY status;\"'" ;;
    4) danger_confirm "重试全部失败任务" && pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"UPDATE local_records SET status=\x27pending\x27, retry_count=0 WHERE status=\x27failed\x27;\"'" ;;
    5) i=$(input "队列项 id" ""); [ -n "$i" ] && danger_confirm "删除队列项 $i" && pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"DELETE FROM local_records WHERE id=\$0;\"' \"$i\"" ;;
    6) danger_confirm "清空整个本地队列（不可恢复）" && pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"DELETE FROM local_records;\"'" ;;
    ""|"ESC") break ;;
  esac
done
