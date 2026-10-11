#!/data/data/com.termux/files/usr/bin/bash
# lib/services.sh —— 服务管理底层操作（2026-10：pg_ctl + pkg 版 llama-server）
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

PGDATA="$PREFIX/var/lib/postgresql"

svc_start() {
  case "$1" in
    postgresql)
      if pg_isready -q 2>/dev/null; then echo "已在运行"; return; fi
      env -u LD_PRELOAD pg_ctl -D "$PGDATA" -l "$LOG_DIR/postgres.log" start
      sleep 2; pg_isready ;;
    node)
      cd "$CUOTI_DIR/server" && (pm2 start cuoti-api 2>/dev/null || pm2 start index.js --name cuoti-api) && pm2 save ;;
    llama)
      bash "$TERMUX_SCRIPTS/llama-server.sh" start ;;
    redis)
      sv up redis 2>/dev/null || echo "redis 未安装或启动失败" ;;
  esac
}

svc_stop() {
  case "$1" in
    postgresql)
      pg_isready -q 2>/dev/null && env -u LD_PRELOAD pg_ctl -D "$PGDATA" stop -m fast ;;
    node) pm2 stop cuoti-api 2>/dev/null || true ;;
    llama) bash "$TERMUX_SCRIPTS/llama-server.sh" stop ;;
    redis) sv down redis 2>/dev/null || true ;;
  esac
}

svc_restart() { svc_stop "$1"; sleep 1; svc_start "$1"; }

svc_status_line() {
  case "$1" in
    postgresql)
      if pg_isready -q 2>/dev/null; then echo "运行中"; else echo "停止"; fi ;;
    node)
      if api_ok; then echo "运行中 (:3000)"; else
        pm2 list 2>/dev/null | grep -q cuoti-api && echo "进程存在但 API 无响应" || echo "停止"
      fi ;;
    llama)
      if llama_ok; then echo "运行中 (:8080)"; else echo "停止"; fi ;;
    redis)
      redis-cli ping 2>/dev/null | grep -q PONG && echo "运行中" || echo "停止/未安装" ;;
  esac
}

svc_show_all_status() {
  local out="PostgreSQL : $(svc_status_line postgresql)
Node.js    : $(svc_status_line node)
llama-server: $(svc_status_line llama)
Redis      : $(svc_status_line redis)"
  msg "$out"
}

svc_pid_port_mem() {
  local out=""
  out+="Node.js  PID: $(pm2 pid cuoti-api 2>/dev/null || echo '-')\n"
  out+="llama-server PID: $(cat "$LOG_DIR/llama-server.pid" 2>/dev/null || echo '-')\n"
  out+="llama-server 二进制: $(command -v llama-server 2>/dev/null || echo '未安装（pkg install llama-cpp）')\n"
  out+="监听端口:\n"
  out+="$(ss -tlnp 2>/dev/null | grep -E ':3000|:8080|:5432' || echo '  （无匹配，net-tools 可用则换 netstat -tlnp）')"
  msg "$out"
}
