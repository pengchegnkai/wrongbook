#!/data/data/com.termux/files/usr/bin/bash
# lib/models.sh —— 模型管理底层（2026-10：pkg 版 llama-server + 双路径扫描）
#
# 模型路径约定（已验证可用）：
#   1. ~/storage/downloads/MiniCPM5-1B-Q8_0.gguf   ← 默认模型（共享存储）
#   2. ~/cuoti/models/*.gguf                        ← Qwen2.5 等可下载模型
# 换模型：改 server/.env 的 MODEL_PATH → llama-server.sh restart（见 README）
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

MODEL_DIR="$CUOTI_DIR/models"
SHARED_DOWNLOADS="$HOME/storage/downloads"
ENV_FILE="$CUOTI_DIR/server/.env"

list_models() {
  local out=""
  # 路径 1：共享存储（默认模型所在）
  if [ -d "$SHARED_DOWNLOADS" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      local size
      size=$(du -h "$f" 2>/dev/null | cut -f1)
      out+="[共享存储] $(basename "$f")  ($size)\n"
    done < <(ls -1 "$SHARED_DOWNLOADS"/*.gguf 2>/dev/null)
  fi
  # 路径 2：项目模型目录（Qwen 等）
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local size
    size=$(du -h "$f" 2>/dev/null | cut -f1)
    out+="[项目目录] $(basename "$f")  ($size)\n"
  done < <(ls -1 "$MODEL_DIR"/*.gguf 2>/dev/null)
  [ -d "$HOME/downloads" ] && while IFS= read -r f; do
    [ -z "$f" ] && continue
    local size
    size=$(du -h "$f" 2>/dev/null | cut -f1)
    out+="[私有目录] $(basename "$f")  ($size)\n"
  done < <(ls -1 "$HOME/downloads"/*.gguf 2>/dev/null)
  echo -e "${out:-（无模型）}"
}

# 当前生效的模型路径（.env > 默认）
active_model_path() {
  if [ -f "$ENV_FILE" ] && grep -q '^MODEL_PATH=' "$ENV_FILE"; then
    grep '^MODEL_PATH=' "$ENV_FILE" | cut -d= -f2- | sed "s|^~|$HOME|"
  else
    echo "$SHARED_DOWNLOADS/MiniCPM5-1B-Q8_0.gguf"
  fi
}

current_model() {
  # 1) 运行中进程的命令行（最准确）
  local pid
  pid=$(cat "$LOG_DIR/llama-server.pid" 2>/dev/null)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    local m
    m=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | grep -A1 -- '--model' | tail -1)
    [ -n "$m" ] && { echo "$m"; return; }
  fi
  # 2) 未运行时显示 .env 约定
  echo "$(active_model_path)（未运行）"
}

switch_model() {
  local m="$1"
  if [ -z "$m" ]; then
    m=$(active_model_path)
  elif [ ! -f "$m" ]; then
    # 允许只输入文件名，自动到两个路径下找
    if [ -f "$MODEL_DIR/$m" ]; then m="$MODEL_DIR/$m";
    elif [ -f "$SHARED_DOWNLOADS/$m" ]; then m="$SHARED_DOWNLOADS/$m";
    elif [ -f "$HOME/downloads/$m" ]; then m="$HOME/downloads/$m";
    else err_friendly "模型不存在: $m"; return 1; fi
  fi
  # 写入 .env（MODEL_PATH 与 MODEL_NAME 同步更新）
  if grep -q '^MODEL_PATH=' "$ENV_FILE"; then
    sed -i "s|^MODEL_PATH=.*|MODEL_PATH=$m|" "$ENV_FILE"
  else
    echo "MODEL_PATH=$m" >> "$ENV_FILE"
  fi
  local mname
  mname=$(basename "$m" .gguf | tr 'A-Z' 'a-z' | tr -d '.')
  if grep -q '^MODEL_NAME=' "$ENV_FILE"; then
    sed -i "s|^MODEL_NAME=.*|MODEL_NAME=$mname|" "$ENV_FILE"
  else
    echo "MODEL_NAME=$mname" >> "$ENV_FILE"
  fi
  bash "$TERMUX_SCRIPTS/llama-server.sh" restart "$m"
}

download_model() {
  local url="$1" name="$2" expected_sha="$3"
  [ -z "$url" ] && { err_friendly "URL 为空"; return 1; }
  name="${name:-$(basename "$url")}"
  mkdir -p "$MODEL_DIR"
  msg "开始下载（长任务，进度见日志）：$url
下载完成后请自行校验 SHA256。"
  env -u LD_PRELOAD curl -L -o "$MODEL_DIR/$name" --progress-bar "$url" 2>>"$LOG_DIR/model-download.err" \
    && echo "下载完成" || echo "下载失败"
  if [ -n "$expected_sha" ]; then
    local actual
    actual=$(sha256sum "$MODEL_DIR/$name" 2>/dev/null | awk '{print $1}')
    [ "$actual" = "$expected_sha" ] && echo "SHA256 校验通过" || { echo "SHA256 不匹配！actual=$actual expected=$expected_sha"; return 1; }
  else
    echo "未提供 SHA256，跳过校验。actual=$(sha256sum "$MODEL_DIR/$name" 2>/dev/null | awk '{print $1}')"
  fi
}

delete_model() {
  local m="$1"
  [ -f "$m" ] || { err_friendly "文件不存在: $m"; return 1; }
  danger_confirm "删除模型 $m（不可恢复）" || return 1
  rm -f "$m" && echo "已删除"
}

show_launch_params() {
  msg "llama-server 启动参数（已验证可用）：
--host 0.0.0.0 --port 8080
--model <模型路径> -ngl 0 -c 2048 --threads 4

说明：
- 纯 CPU 模式（-ngl 0），Vulkan 后端包已装未启用
- 启动脚本会自动读取 server/.env 的 MODEL_PATH
- 换模型三步：换 gguf 文件 → 改 .env → llama-server.sh restart"
}

show_pkg_info() {
  msg "llama-server 安装信息（pkg 官方包，无需自编译）：
路径: $(command -v llama-server 2>/dev/null || echo '未安装')
安装: pkg install llama-cpp llama-cpp-backend-vulkan
版本: $(llama-server --version 2>/dev/null | head -1 || echo '未知')
后端: 纯 CPU（-ngl 0）；Vulkan 包已装未启用
OpenAI 兼容接口 /v1/chat/completions 已验证可用"
}
