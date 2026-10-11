#!/data/data/com.termux/files/usr/bin/bash
# menu_models.sh —— 模型管理（2026-10：pkg 版 llama-server + 双路径模型扫描）
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"; source "$TUI_DIR/lib/models.sh"

while true; do
  c=$(menu "模型管理" \
    "1|已下载模型列表（双路径）" "2|当前加载模型" "3|切换模型" \
    "4|重启 llama-server" "5|下载新模型" "6|删除模型" \
    "7|查看启动参数" "8|llama-server 安装信息" \
    "0|返回")
  case "$c" in
    1) msg "$(list_models)
（SHA256 请自行校验：sha256sum 文件名）
（换模型三步：改 server/.env 的 MODEL_PATH → llama-server.sh restart，见 README）" ;;
    2) msg "当前模型: $(current_model)" ;;
    3) pause_run "bash -c 'source $TUI_DIR/lib/models.sh; list_models'" 2>/dev/null
       m=$(input "输入模型文件完整路径（回车用 .env 的 MODEL_PATH）" "")
       [ -n "$m" ] && switch_model "$m" && msg "已切换并重启" ;;
    4) bash "$TERMUX_SCRIPTS/llama-server.sh" restart && msg "已重启" ;;
    5) url=$(input "模型下载 URL（请自行确认来源为 Hugging Face 官方仓库，Qwen2.5 URL 由你自行填写）" "")
       name=$(input "保存文件名" "$(basename "$url" 2>/dev/null)")
       sha=$(input "预期 SHA256（可留空跳过校验）" "")
       [ -n "$url" ] && download_model "$url" "$name" "$sha" | tail -5; pause_run "true" ;;
    6) pause_run "bash -c 'source $TUI_DIR/lib/models.sh; list_models'" 2>/dev/null
       m=$(input "要删除的模型文件完整路径" "")
       [ -n "$m" ] && delete_model "$m" ;;
    7) show_launch_params ;;
    8) show_pkg_info ;;
    ""|"ESC") break ;;
  esac
done
