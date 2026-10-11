#!/data/data/com.termux/files/usr/bin/bash
# lib/network.sh —— 网络与内网底层（未验证，需你实测）
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ENV_FILE="$CUOTI_DIR/server/.env"

get_lan_ip() {
  local ip
  ip=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}')
  [ -z "$ip" ] && ip=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
  echo "${ip:-未知}"
}

show_listening() {
  local out
  out=$(ss -tlnp 2>/dev/null | grep -E ':3000|:8080|:5432' || netstat -tlnp 2>/dev/null | grep -E ':3000|:8080|:5432' || echo "无")
  msg "监听端口：\n$out\n\n约定：3000=API(0.0.0.0) 8080=模型(0.0.0.0) 5432=数据库(仅127.0.0.1)"
}

switch_host() {
  local host="$1"
  [ -f "$ENV_FILE" ] || { err_friendly "缺少 $ENV_FILE"; return 1; }
  sed -i "s/^HOST=.*/HOST=$host/" "$ENV_FILE"
  msg "HOST 已改为 $host，需重启 Node.js 生效。"
}

show_cors() { grep '^CORS_ORIGINS' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || echo "未配置"; }

edit_cors() {
  local cur new
  cur=$(show_cors)
  new=$(input "CORS 白名单（逗号分隔，如 http://192.168.1.10:8080）" "$cur")
  [ -n "$new" ] && sed -i "s|^CORS_ORIGINS=.*|CORS_ORIGINS=$new|" "$ENV_FILE"
  msg "已更新，重启 Node.js 生效。"
}

active_tokens() {
  env -u LD_PRELOAD psql -U "$PGUSER_DEFAULT" -d "$PGDATABASE_DEFAULT" \
    -c "SELECT u.username, r.device_info, r.ip, r.expires_at FROM refresh_tokens r JOIN users u ON u.id=r.user_id WHERE r.revoked=false AND r.expires_at > now() ORDER BY r.expires_at DESC LIMIT 30;" 2>&1
}

force_logout_device() {
  local token_id
  token_id=$(input "要下线的 refresh_token id")
  danger_confirm "强制下线设备 token_id=$token_id" || return 1
  env -u LD_PRELOAD psql -U "$PGUSER_DEFAULT" -d "$PGDATABASE_DEFAULT" \
    -c "UPDATE refresh_tokens SET revoked=true WHERE id=$token_id;" 2>&1 \
    && msg "已下线" || err_friendly "下线失败"
}

test_lan() {
  local ip
  ip=$(get_lan_ip)
  local out=""
  out+="本机 IP: $ip\n"
  out+="API 探活: $(curl -s -m 3 -o /dev/null -w '%{http_code}' "http://$ip:3000/api/health" || echo 失败)\n"
  out+="模型探活: $(curl -s -m 3 -o /dev/null -w '%{http_code}' "http://$ip:8080/health" || echo 失败)"
  msg "$out"
}
