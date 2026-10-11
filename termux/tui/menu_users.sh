#!/data/data/com.termux/files/usr/bin/bash
# menu_users.sh —— 用户管理
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"; source "$TUI_DIR/lib/db.sh"

while true; do
  c=$(menu "用户管理" \
    "1|用户列表" "2|查看登录日志" "3|用户设备列表" \
    "4|禁用/启用用户" "5|重置用户密码" "6|强制某用户下线" \
    "7|删除用户" \
    "0|返回")
  case "$c" in
    1) pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_quick users'" ;;
    2) u=$(input "用户名" ""); pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"SELECT l.action,l.ip,l.success,l.created_at FROM login_logs l JOIN users u ON u.id=l.user_id WHERE u.username=\x27\$0\x27 ORDER BY l.created_at DESC LIMIT 30;\"' \"$u\"" ;;
    3) u=$(input "用户名" ""); pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"SELECT r.id,r.device_info,r.ip,r.expires_at,r.revoked FROM refresh_tokens r JOIN users u ON u.id=r.user_id WHERE u.username=\x27\$0\x27;\"' \"$u\"" ;;
    4) u=$(input "用户名" ""); s=$(menu "操作" "1|禁用" "2|启用")
       [ "$s" = "1" ] && pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"UPDATE users SET status=\x27disabled\x27 WHERE username=\x27\$0\x27;\"' \"$u\""
       [ "$s" = "2" ] && pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"UPDATE users SET status=\x27active\x27 WHERE username=\x27\$0\x27;\"' \"$u\"" ;;
    5) u=$(input "用户名" "")
       danger_confirm "重置 $u 的密码（会生成临时密码并使其全部会话下线）" || continue
       tmp=$(head -c 12 /dev/urandom | base64 | tr -d '/+=' | head -c 10)
       hash=$(node -e "const b=require('bcryptjs');console.log(b.hashSync('$tmp',10))" 2>/dev/null)
       [ -z "$hash" ] && { err_friendly "bcryptjs 不可用（需 cd ~/cuoti/server && npm i）"; continue; }
       HASH="$hash" U="$u" env -u LD_PRELOAD bash -c 'psql -U "$PGUSER_DEFAULT" -d "$PGDATABASE_DEFAULT" -c "UPDATE users SET password_hash='"'"'"$HASH"'"'"' WHERE username='"'"'"$U"'"'"'; UPDATE refresh_tokens SET revoked=true WHERE user_id=(SELECT id FROM users WHERE username='"'"'"$U"'"'"');"' >/dev/null 2>&1 \
         && msg "临时密码: $tmp" || err_friendly "重置失败（可手动执行 SQL 更新 users.password_hash）" ;;
    6) u=$(input "用户名" "")
       danger_confirm "强制 $u 下线（撤销全部 token）" && pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"UPDATE refresh_tokens SET revoked=true WHERE user_id=(SELECT id FROM users WHERE username=\x27\$0\x27);\"' \"$u\"" ;;
    7) u=$(input "用户名" "")
       danger_confirm "删除用户 $u 及其全部数据（级联删除，不可恢复）" || continue
       pause_run "bash -c 'source $TUI_DIR/lib/db.sh; db_sql_query \"DELETE FROM users WHERE username=\x27\$0\x27;\"' \"$u\"" ;;
    ""|"ESC") break ;;
  esac
done
