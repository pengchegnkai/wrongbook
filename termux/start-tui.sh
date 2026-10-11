#!/data/data/com.termux/files/usr/bin/bash
# start-tui.sh —— 启动交互式 TUI 控制终端
# whiptail 不可用时自动降级纯 bash 菜单（在 tui/main.sh 内部处理）
CUOTI_DIR="$HOME/cuoti"
bash "$CUOTI_DIR/termux/tui/main.sh"
