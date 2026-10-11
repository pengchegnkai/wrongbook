#!/data/data/com.termux/files/usr/bin/bash
# main.sh —— TUI 控制终端主入口
# whiptail 不可用时自动降级纯 bash 数字菜单（未验证，需你实测）
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"

while true; do
  choice=$(menu "主菜单" \
    "1|服务管理" \
    "2|状态总览" \
    "3|日志查看" \
    "4|数据库管理" \
    "5|模型管理" \
    "6|队列管理" \
    "7|网络与内网" \
    "8|用户管理" \
    "9|备份与恢复" \
    "10|配置管理" \
    "11|系统工具" \
    "12|退出")
  case "$choice" in
    1) bash "$TUI_DIR/menu_services.sh" ;;
    2) bash "$TUI_DIR/menu_status.sh" ;;
    3) bash "$TUI_DIR/menu_logs.sh" ;;
    4) bash "$TUI_DIR/menu_database.sh" ;;
    5) bash "$TUI_DIR/menu_models.sh" ;;
    6) bash "$TUI_DIR/menu_queue.sh" ;;
    7) bash "$TUI_DIR/menu_network.sh" ;;
    8) bash "$TUI_DIR/menu_users.sh" ;;
    9) bash "$TUI_DIR/menu_backup.sh" ;;
    10) bash "$TUI_DIR/menu_config.sh" ;;
    11) bash "$TUI_DIR/menu_system.sh" ;;
    12|""|"ESC") confirm "确认退出 TUI？后台服务将继续运行。" && exit 0 ;;
  esac
done
