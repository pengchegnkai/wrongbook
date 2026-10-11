#!/data/data/com.termux/files/usr/bin/bash
# menu_config.sh —— 配置管理（2026-10：新增 MODEL_PATH/MODEL_NAME/PROMPT_TEMPLATE）
TUI_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TUI_DIR/lib/common.sh"

ENV_FILE="$CUOTI_DIR/server/.env"
[ -f "$ENV_FILE" ] || { printf 'JWT_SECRET=CHANGE_ME\nHOST=0.0.0.0\nPORT=3000\nMODEL_PATH=~/storage/downloads/MiniCPM5-1B-Q8_0.gguf\nMODEL_NAME=minicpm5-1b-q8\nPROMPT_TEMPLATE=general\n' > "$ENV_FILE"; }

# 敏感字段脱敏显示
show_env() {
  grep -vE '^\s*#|^\s*$' "$ENV_FILE" | while IFS='=' read -r k v; do
    case "$k" in
      JWT_SECRET|API_TOKEN|DB_PASSWORD|CLOUD_AI_API_KEY) echo "$k=****（已脱敏）" ;;
      *) echo "$k=$v" ;;
    esac
  done
}

while true; do
  c=$(menu "配置管理" \
    "1|查看配置（脱敏）" "2|编辑配置项" "3|校验配置" "4|恢复默认配置" \
    "5|快速切换模型（MODEL_PATH）" \
    "0|返回")
  case "$c" in
    1) msg "当前配置：\n$(show_env)" ;;
    2) k=$(input "配置项名（如 HOST/PORT/CORS_ORIGINS/MODEL_PATH/MODEL_NAME/PROMPT_TEMPLATE）" "")
       [ -z "$k" ] && continue
       cur=$(grep "^$k=" "$ENV_FILE" | cut -d= -f2-)
       v=$(input "新值" "$cur")
       if grep -q "^$k=" "$ENV_FILE"; then sed -i "s|^$k=.*|$k=$v|" "$ENV_FILE"; else echo "$k=$v" >> "$ENV_FILE"; fi
       case "$k" in
         MODEL_PATH|MODEL_NAME|PROMPT_TEMPLATE) msg "已保存 $k=$v。
MODEL_PATH/MODEL_NAME 变更需重启 llama-server（模型管理→重启）；
PROMPT_TEMPLATE 变更需重启 Node.js（服务管理→重启 node）。" ;;
         *) msg "已保存 $k=$v。重启 Node.js 生效（服务管理→重启 node）。" ;;
       esac ;;
    3) msg "校验结果：
JWT_SECRET: $(grep -q '^JWT_SECRET=CHANGE_ME' "$ENV_FILE" && echo '【警告】仍为默认值，请修改' || echo OK)
HOST: $(grep '^HOST=' "$ENV_FILE" | cut -d= -f2)
PORT: $(grep '^PORT=' "$ENV_FILE" | cut -d= -f2)
MODEL_PATH: $(mp=$(grep '^MODEL_PATH=' "$ENV_FILE" | cut -d= -f2- | sed "s|^~|$HOME|"); [ -f "$mp" ] && echo "OK（文件存在）" || echo "【警告】文件不存在: ${mp:-未配置}，将回退默认 MiniCPM5 路径")
MODEL_NAME: $(grep '^MODEL_NAME=' "$ENV_FILE" | cut -d= -f2-)
PROMPT_TEMPLATE: $(grep '^PROMPT_TEMPLATE=' "$ENV_FILE" | cut -d= -f2- || echo '未配置（默认 general）')" ;;
    4) danger_confirm "恢复默认 .env（JWT_SECRET 将重置，需重新改）" && \
       printf 'JWT_SECRET=CHANGE_ME\nHOST=0.0.0.0\nPORT=3000\nDB_HOST=127.0.0.1\nDB_PORT=5432\nDB_USER=cuoti\nDB_PASSWORD=cuoti_local_pw_2026\nDB_NAME=cuoti\nLLAMA_BASE_URL=http://127.0.0.1:8080\nMODEL_PATH=~/storage/downloads/MiniCPM5-1B-Q8_0.gguf\nMODEL_NAME=minicpm5-1b-q8\nPROMPT_TEMPLATE=general\nCORS_ORIGINS=http://localhost:*,http://127.0.0.1:*,http://192.168.*.*:*,http://10.*.*.*:*,http://172.16.*.*:*\nCLOUD_AI_ENABLED=false\n' > "$ENV_FILE" && msg "已恢复默认" ;;
    5) pause_run "bash -c 'source $TUI_DIR/lib/models.sh; list_models'" 2>/dev/null
       m=$(input "新模型完整路径" "")
       if [ -n "$m" ]; then
         if grep -q '^MODEL_PATH=' "$ENV_FILE"; then sed -i "s|^MODEL_PATH=.*|MODEL_PATH=$m|" "$ENV_FILE"; else echo "MODEL_PATH=$m" >> "$ENV_FILE"; fi
         msg "已写入 MODEL_PATH。重启 llama-server 生效（模型管理→重启）。"
       fi ;;
    ""|"ESC") break ;;
  esac
done
