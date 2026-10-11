#!/data/data/com.termux/files/usr/bin/bash
# menu_backup.sh —— 备份与恢复
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"; source "$TUI_DIR/lib/backup.sh"

while true; do
  c=$(menu "备份与恢复" \
    "1|备份数据库" "2|备份模型" "3|备份配置" "4|备份日志" \
    "5|列出历史备份" "6|恢复备份" \
    "7|导出全部数据 JSON" "8|导入 JSON" \
    "0|返回")
  case "$c" in
    1) do_backup_db ;;
    2) do_backup_models ;;
    3) do_backup_config ;;
    4) do_backup_logs ;;
    5) list_backups ;;
    6) do_restore ;;
    7) export_all_json ;;
    8) import_json ;;
    ""|"ESC") break ;;
  esac
done
