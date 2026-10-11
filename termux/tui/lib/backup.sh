#!/data/data/com.termux/files/usr/bin/bash
# lib/backup.sh —— 备份与恢复底层（未验证，需你实测）
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
source "$(cd "$(dirname "$0")" && pwd)/db.sh"

BACKUP_DIR="$CUOTI_DIR/backups"
mkdir -p "$BACKUP_DIR"

do_backup_db() {
  local f="$BACKUP_DIR/db-$(date '+%Y%m%d-%H%M%S').sql"
  db_backup "$f" && msg "数据库已备份到 $f"
}

do_backup_models() {
  # 模型文件很大（GB 级），默认只打包项目模型目录的清单与校验值，
  # 完整模型备份请手动复制（共享存储文件手机文件管理器可直接操作）
  local f="$BACKUP_DIR/models-manifest-$(date '+%Y%m%d-%H%M%S').txt"
  {
    echo "== 模型清单 $(date '+%F %T') =="
    ls -lh "$HOME/storage/downloads/"*.gguf "$CUOTI_DIR/models/"*.gguf 2>/dev/null
    echo ""
    echo "== SHA256 =="
    sha256sum "$HOME/storage/downloads/"*.gguf "$CUOTI_DIR/models/"*.gguf 2>/dev/null
  } > "$f" 2>/dev/null
  msg "模型清单与 SHA256 已保存到 $f
（完整模型文件体积大，建议直接复制到电脑/网盘，不做 tar 打包）"
}

do_backup_config() {
  local f="$BACKUP_DIR/config-$(date '+%Y%m%d-%H%M%S').tar.gz"
  tar -czf "$f" -C "$CUOTI_DIR" server/.env termux 2>>"$LOG_DIR/backup.err" \
    && msg "完成: $f（.env 含密钥，注意保管）"
}

do_backup_logs() {
  local f="$BACKUP_DIR/logs-$(date '+%Y%m%d-%H%M%S').tar.gz"
  tar -czf "$f" -C "$CUOTI_DIR" logs 2>>"$LOG_DIR/backup.err" && msg "完成: $f"
}

list_backups() {
  msg "历史备份：\n$(ls -lh "$BACKUP_DIR" 2>/dev/null || echo '（无）')"
}

do_restore() {
  local f
  f=$(input "备份文件完整路径" "")
  [ -f "$f" ] || { err_friendly "文件不存在"; return 1; }
  case "$f" in
    *db-*) db_restore "$f" && msg "数据库恢复完成（服务端会自动执行 schema.sql 补表）" ;;
    *) msg "该类型备份不支持自动恢复，请手动解包覆盖：tar -xzf $f -C ~/cuoti" ;;
  esac
}

export_all_json() {
  local f="$BACKUP_DIR/export-all-$(date '+%Y%m%d-%H%M%S').json"
  curl -s -m 300 "http://127.0.0.1:3000/api/export/json" -H "X-API-Token: $(grep '^API_TOKEN=' "$CUOTI_DIR/server/.env" 2>/dev/null | cut -d= -f2-)" \
    -o "$f" && msg "已导出: $f" || err_friendly "导出失败（需后端运行且配置 API_TOKEN）"
}

import_json() {
  local f
  f=$(input "JSON 文件路径" "")
  [ -f "$f" ] || { err_friendly "文件不存在"; return 1; }
  danger_confirm "导入会写入当前用户数据" || return 1
  curl -s -m 600 -X POST "http://127.0.0.1:3000/api/import/json" \
    -H "Content-Type: application/json" \
    -H "X-API-Token: $(grep '^API_TOKEN=' "$CUOTI_DIR/server/.env" 2>/dev/null | cut -d= -f2-)" \
    --data-binary "@$f" > "$LOG_DIR/import-last.txt" 2>&1 \
    && msg "导入完成，响应见 $LOG_DIR/import-last.txt" || err_friendly "导入失败"
}
