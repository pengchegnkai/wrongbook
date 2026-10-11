#!/data/data/com.termux/files/usr/bin/bash
# stop-all.sh —— 停止全部服务（2026-10 更新，pg_ctl 版）
CUOTI_DIR="$HOME/cuoti"
PGDATA="$PREFIX/var/lib/postgresql"

echo "=== 停止 llama-server ==="
bash "$CUOTI_DIR/termux/llama-server.sh" stop

echo "=== 停止 Node.js（PM2） ==="
pm2 stop cuoti-api 2>/dev/null || echo "cuoti-api 未在运行"
# 不执行 pm2 kill，保留进程列表配置

echo "=== 停止 PostgreSQL ==="
if pg_isready -q 2>/dev/null; then
  env -u LD_PRELOAD pg_ctl -D "$PGDATA" stop -m fast || echo "警告：PostgreSQL 停止失败"
else
  echo "PostgreSQL 未在运行"
fi

echo "=== 全部服务已停止 ==="
