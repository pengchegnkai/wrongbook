#!/data/data/com.termux/files/usr/bin/bash
# tunnel.sh —— Cloudflare Tunnel 管理（免费套餐，零公网 IP）
# 前提：你的域名已添加到 Cloudflare（NS 托管在 Cloudflare，免费版即可）
# 用法:
#   tunnel.sh login                # 浏览器授权（一次性；生成 ~/.cloudflared/cert.pem）
#   tunnel.sh setup app.你的域名   # 创建命名隧道 + 绑定 DNS + 写配置
#   tunnel.sh start|stop|status    # 后台运行 / 停止 / 查看隧道
#   tunnel.sh quick                # 免登录临时隧道（随机 *.trycloudflare.com，临时调试）
set -u
CF_DIR="$HOME/.cloudflared"
LOG_DIR="$HOME/cuoti/logs"
PID_FILE="$LOG_DIR/cloudflared.pid"
TUNNEL_NAME="cuoti"
mkdir -p "$CF_DIR" "$LOG_DIR"

login() {
  echo "开始 Cloudflare 授权：下面会打印一个链接，用手机浏览器打开，"
  echo "登录 Cloudflare → 选择要用的域名 → 授权 Access。"
  cloudflared tunnel login 2>&1 | while IFS= read -r line; do
    case "$line" in
      https://dash.cloudflare.com/argotunnel*)
        echo ""
        echo ">>> 授权链接（浏览器打开）: $line"
        echo ">>> 完成授权后 cert.pem 会自动下载到本机";;
      *) echo "$line";;
    esac
  done
  if [ -f "$CF_DIR/cert.pem" ]; then
    echo "授权完成：$CF_DIR/cert.pem"
  else
    echo "授权未完成（未找到 cert.pem），请重试 tunnel.sh login"
  fi
}

setup() {
  local host="${1:-}"
  [ -z "$host" ] && { echo "用法: tunnel.sh setup app.你的域名.com"; exit 1; }
  [ -f "$CF_DIR/cert.pem" ] || { echo "先执行: tunnel.sh login"; exit 1; }
  # 创建隧道（幂等：已存在则跳过）
  if ! cloudflared tunnel list 2>/dev/null | grep -qw "$TUNNEL_NAME"; then
    cloudflared tunnel create "$TUNNEL_NAME" || exit 1
  fi
  # 凭据文件名是隧道 UUID（不是隧道名），从 tunnel list 取 ID
  local tid
  tid=$(cloudflared tunnel list 2>/dev/null | awk -v n="$TUNNEL_NAME" '$2==n{print $1}')
  [ -z "$tid" ] && { echo "未在 tunnel list 找到 $TUNNEL_NAME"; exit 1; }
  local cred="$CF_DIR/$tid.json"
  [ -f "$cred" ] || { echo "未找到隧道凭据 $cred"; exit 1; }
  cat > "$CF_DIR/config.yml" <<EOF
tunnel: $tid
credentials-file: $cred
# 只暴露后端 API(:3000)；llama-server(:8080) 与 PostgreSQL(:5432) 一律不暴露
ingress:
  - hostname: $host
    service: http://localhost:3000
  - service: http_status:404
EOF
  # -f：CNAME 已存在时覆盖（重复 setup 不报错）
  cloudflared tunnel route dns -f "$TUNNEL_NAME" "$host" || exit 1
  echo ""
  echo "隧道已创建并绑定: https://$host → http://localhost:3000"
  echo "启动: bash $0 start    停止: bash $0 stop"
}

start() {
  [ -f "$CF_DIR/config.yml" ] || { echo "先执行: tunnel.sh setup <主机名>"; exit 1; }
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "隧道已在运行 (PID $(cat "$PID_FILE"))"
    return
  fi
  nohup cloudflared tunnel run "$TUNNEL_NAME" > "$LOG_DIR/cloudflared.log" 2>&1 &
  echo $! > "$PID_FILE"
  # 等边缘连接建立（最多 30s）
  for _ in $(seq 1 15); do
    if grep -q 'Registered tunnel connection' "$LOG_DIR/cloudflared.log" 2>/dev/null; then
      echo "隧道已连接"
      grep -m1 'hostname' "$CF_DIR/config.yml" || true
      return
    fi
    sleep 2
  done
  echo "警告：30s 内未确认连接，请查看 $LOG_DIR/cloudflared.log"
}

stop() {
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null && echo "隧道已停止" || echo "进程不存在"
    rm -f "$PID_FILE"
  else
    echo "隧道未在运行（无 PID 文件）"
  fi
  pkill -f 'cloudflared tunnel' 2>/dev/null && echo "（清理了残留 cloudflared 进程）" || true
  return 0
}

status() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "运行中 (PID $(cat "$PID_FILE"))"
    grep -m1 'Registered tunnel connection' "$LOG_DIR/cloudflared.log" 2>/dev/null || echo "（尚未确认边缘连接）"
  else
    echo "未运行"
  fi
}

quick() {
  if [ -f "$PID_FILE.quick" ] && kill -0 "$(cat "$PID_FILE.quick")" 2>/dev/null; then
    echo "临时隧道已在运行，地址:"
    grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/cloudflared-quick.log" | head -1
    return
  fi
  echo "启动临时隧道（免登录，地址每次随机，仅供调试）…"
  nohup cloudflared tunnel --url http://localhost:3000 > "$LOG_DIR/cloudflared-quick.log" 2>&1 &
  echo $! > "$PID_FILE.quick"
  for _ in $(seq 1 10); do
    URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/cloudflared-quick.log" 2>/dev/null | head -1)
    [ -n "$URL" ] && { echo "临时地址: $URL"; return; }
    sleep 2
  done
  echo "未取得地址，请查看 $LOG_DIR/cloudflared-quick.log"
}

case "${1:-}" in
  login) login ;;
  setup) setup "${2:-}" ;;
  start) start ;;
  stop) stop ;;
  status) status ;;
  quick) quick ;;
  *) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
