#!/data/data/com.termux/files/usr/bin/bash
# menu_database.sh —— 数据库管理
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"; source "$TUI_DIR/lib/db.sh"

while true; do
  c=$(menu "数据库管理" \
    "1|表与行数" "2|交互式 SQL 查询" \
    "3|最近10道错题" "4|各科错题数" "5|掌握度分布" "6|今日待复习" \
    "7|用户列表" "8|最近登录" \
    "9|查看表结构" \
    "10|备份数据库" "11|恢复数据库" "12|清理无用数据" \
    "0|返回")
  case "$c" in
    1) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_tables_rows'" ;;
    2) sql=$(input "输入 SQL（只读操作请用 SELECT，写操作自担风险）" "SELECT count(*) FROM questions;")
       [ -n "$sql" ] && pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"\$0\"' \"$sql\"" ;;
    3) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_quick recent_questions'" ;;
    4) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_quick count_by_subject'" ;;
    5) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_quick mastery_dist'" ;;
    6) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_quick today_review'" ;;
    7) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_quick users'" ;;
    8) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_quick recent_logins'" ;;
    9) t=$(input "表名" "questions"); pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_structure \"\$0\"' \"$t\"" ;;
    10) f=$(input "备份文件路径" "$CUOTI_DIR/backups/db-$(date '+%Y%m%d-%H%M%S').sql")
        pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_backup \"\$0\" && echo 备份完成: \$0' \"$f\"" ;;
    11) f=$(input "恢复文件路径" "")
        [ -n "$f" ] && db_restore "$f" && msg "恢复完成" ;;
    12) danger_confirm "清理 90 天前的 question_analysis_logs 与过期 refresh_tokens" && \
        pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"DELETE FROM question_analysis_logs WHERE created_at < now() - interval \x2790 days\x27; DELETE FROM refresh_tokens WHERE expires_at < now();\"'" ;;
    ""|"ESC") break ;;
  esac
done
