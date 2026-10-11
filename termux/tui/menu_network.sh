#!/data/data/com.termux/files/usr/bin/bash
# menu_network.sh —— 网络与内网
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"; source "$TUI_DIR/lib/network.sh"

while true; do
  c=$(menu "网络与内网" \
    "1|本机内网 IP" "2|监听端口" \
    "3|切换 HOST（127.0.0.1/0.0.0.0）" \
    "4|查看 CORS 白名单" "5|编辑 CORS 白名单" \
    "6|当前活跃设备（token）" "7|强制下线某设备" \
    "8|测试内网连通性" \
    "0|返回")
  case "$c" in
    1) msg "本机内网 IP: $(get_lan_ip)
局域网访问: http://$(get_lan_ip):3000" ;;
    2) show_listening ;;
    3) h=$(menu "选择 HOST" "1|0.0.0.0（内网可访问）" "2|127.0.0.1（仅本机）")
       [ "$h" = "1" ] && switch_host "0.0.0.0"
       [ "$h" = "2" ] && switch_host "127.0.0.1"
       [ -n "$h" ] && pause_run "bash -c 'source $TUI_DIR/lib/services.sh; svc_restart node'" ;;
    4) msg "当前 CORS: $(show_cors)" ;;
    5) edit_cors ;;
    6) pause_run "bash -c 'source $TUI_DIR/lib/network.sh; active_tokens'" ;;
    7) force_logout_device ;;
    8) test_lan ;;
    ""|"ESC") break ;;
  esac
done
