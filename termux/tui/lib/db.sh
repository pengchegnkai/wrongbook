#!/data/data/com.termux/files/usr/bin/bash
# lib/db.sh —— 数据库管理底层（未验证，需你实测）
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

PSQL() { env -u LD_PRELOAD psql -U "$PGUSER_DEFAULT" -d "$PGDATABASE_DEFAULT" "$@"; }

db_tables_rows() {
  PSQL -c "SELECT relname AS 表, n_live_tup AS 行数 FROM pg_stat_user_tables ORDER BY n_live_tup DESC;" 2>&1
}

db_sql_query() {
  local sql="$1"
  PSQL -c "$sql" 2>&1
}

db_structure() {
  local table="$1"
  PSQL -c "\d+ $table" 2>&1
}

db_backup() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  env -u LD_PRELOAD pg_dump -U "$PGUSER_DEFAULT" "$PGDATABASE_DEFAULT" > "$file" 2>"$LOG_DIR/db-backup.err"
  [ -s "$file" ] && echo "OK" || { cat "$LOG_DIR/db-backup.err"; echo "FAIL"; }
}

db_restore() {
  local file="$1"
  danger_confirm "将用 $file 覆盖恢复数据库（数据会被清空重建）" || return 1
  PSQL -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;' 2>/dev/null
  env -u LD_PRELOAD psql -U "$PGUSER_DEFAULT" -d "$PGDATABASE_DEFAULT" < "$file" 2>&1
}

# 常用查询快捷入口
db_quick() {
  case "$1" in
    recent_questions) db_sql_query "SELECT id, subject_id, error_type, mastery, created_at FROM questions ORDER BY created_at DESC LIMIT 10;" ;;
    count_by_subject) db_sql_query "SELECT s.name AS 科目, COUNT(q.id) AS 错题数 FROM subjects s LEFT JOIN questions q ON q.subject_id=s.id GROUP BY s.name ORDER BY 错题数 DESC;" ;;
    mastery_dist) db_sql_query "SELECT mastery AS 掌握度, COUNT(*) AS 数量 FROM questions GROUP BY mastery;" ;;
    today_review) db_sql_query "SELECT COUNT(*) FROM questions WHERE review_today = true;" ;;
    users) db_sql_query "SELECT id, username, nickname, role, status, last_login_at FROM users;" ;;
    recent_logins) db_sql_query "SELECT username, action, ip, success, created_at FROM login_logs ORDER BY created_at DESC LIMIT 20;" ;;
  esac
}

db_row_count() { # 单表行数（供状态总览用）
  PSQL -tAc "SELECT COUNT(*) FROM $1" 2>/dev/null || echo "?"
}
