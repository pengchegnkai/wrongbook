#!/data/data/com.termux/files/usr/bin/bash
# start-all.sh —— 启动全部服务并打印内网地址（2026-10 更新）
# 实测结论：termux-services 的 sv 启动 PostgreSQL 会报
# "unable to change to service directory"，故统一改用 pg_ctl 直接管理
CUOTI_DIR="$HOME/cuoti"
LOG_DIR="$CUOTI_DIR/logs"
PGDATA="$PREFIX/var/lib/postgresql"
mkdir -p "$LOG_DIR"

echo "=== 启动 PostgreSQL ==="
if pg_isready -q 2>/dev/null; then
  echo "PostgreSQL 已在运行"
else
  env -u LD_PRELOAD pg_ctl -D "$PGDATA" -l "$LOG_DIR/postgres.log" start \
    || echo "错误：PostgreSQL 启动失败，请查看 $LOG_DIR/postgres.log"
  sleep 2
fi
pg_isready || echo "警告：PostgreSQL 未就绪"

echo "=== 启动 Node.js 后端（PM2） ==="
cd "$CUOTI_DIR/server" || { echo "server 目录不存在"; exit 1; }
[ -d node_modules ] || npm install
pm2 start cuoti-api 2>/dev/null || pm2 start index.js --name cuoti-api
pm2 save

echo "=== 启动 llama-server（MiniCPM5-1B-Q8_0，纯 CPU） ==="
bash "$CUOTI_DIR/termux/llama-server.sh" start

sleep 2
echo ""
echo "================ 服务状态 ================"
pm2 list 2>/dev/null || echo "PM2 未运行"
pg_isready && echo "PostgreSQL: 运行中 (127.0.0.1:5432)" || echo "PostgreSQL: 未就绪"
curl -s -m 3 http://127.0.0.1:8080/health >/dev/null 2>&1 && echo "llama-server: 运行中 (:8080)" || echo "llama-server: 无响应（模型加载中或未启动）"

IP="$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')"
[ -z "$IP" ] && IP="$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)"
echo ""
echo "================ 内网访问地址 ================"
echo "后端 API    : http://${IP:-127.0.0.1}:3000"
echo "模型服务    : http://${IP:-127.0.0.1}:8080（OpenAI 兼容 /v1/chat/completions）"
echo "健康检查    : http://${IP:-127.0.0.1}:3000/api/health"
echo "手机本机    : http://127.0.0.1:3000"
echo "PostgreSQL  : 仅本机 127.0.0.1:5432（不暴露内网）"
echo ""
echo "提示：请关闭 Termux 电池优化，否则后台服务可能被杀（见 README）。"
