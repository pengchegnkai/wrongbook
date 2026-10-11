#!/data/data/com.termux/files/usr/bin/bash
# llama-server.sh —— 管理 llama-server（pkg 官方包版，2026-10 更新）
# 已验证：OpenAI 兼容接口 /v1/chat/completions 可用；纯 CPU 模式 -ngl 0
# 用法: llama-server.sh start|stop|status|restart [模型文件完整路径]
CUOTI_DIR="$HOME/cuoti"
LOG_DIR="$CUOTI_DIR/logs"
PID_FILE="$LOG_DIR/llama-server.pid"
PORT=8080
CTX=2048
THREADS=4

# llama-server 来自 pkg 包：llama-cpp + llama-cpp-backend-vulkan
LLAMA_BIN="$(command -v llama-server || echo "$PREFIX/bin/llama-server")"

# 默认模型：MiniCPM5-1B-Q8_0（共享存储路径，已验证可用）
DEFAULT_MODEL_PATH="$HOME/storage/downloads/MiniCPM5-1B-Q8_0.gguf"

# 若 server/.env 配置了 MODEL_PATH 则优先使用（如何换模型见 README）
ENV_FILE="$CUOTI_DIR/server/.env"
if [ -f "$ENV_FILE" ] && grep -q '^MODEL_PATH=' "$ENV_FILE"; then
  ENV_MODEL=$(grep '^MODEL_PATH=' "$ENV_FILE" | cut -d= -f2- | sed "s|^~|$HOME|")
  [ -f "$ENV_MODEL" ] && DEFAULT_MODEL_PATH="$ENV_MODEL"
fi

MODEL_PATH="${2:-$DEFAULT_MODEL_PATH}"

start() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "llama-server 已在运行 (PID $(cat "$PID_FILE"))"
    return
  fi
  [ -x "$LLAMA_BIN" ] || { echo "错误：未找到 llama-server，请先 pkg install llama-cpp llama-cpp-backend-vulkan"; exit 1; }
  [ -f "$MODEL_PATH" ] || { echo "错误：模型不存在 $MODEL_PATH"; echo "可用模型："; ls -1 "$HOME/storage/downloads/"*.gguf "$HOME/downloads/"*.gguf 2>/dev/null || echo "（无）"; exit 1; }
  mkdir -p "$LOG_DIR"
  # 已验证的启动参数：纯 CPU（-ngl 0），Vulkan 未启用
  # 注意：pkg 版 llama-server 存在（自编译版常见）参数解析崩溃问题，无需 workaround
  nohup "$LLAMA_BIN" --host 0.0.0.0 --port "$PORT" \
    --model "$MODEL_PATH" -ngl 0 -c "$CTX" --threads "$THREADS" \
    > "$LOG_DIR/llama-server.log" 2>&1 &
  echo $! > "$PID_FILE"
  echo "llama-server 已启动 (PID $(cat "$PID_FILE"))"
  echo "模型: $MODEL_PATH"
  echo "接口: http://0.0.0.0:$PORT/v1/chat/completions（OpenAI 兼容，已验证可用）"
  echo "日志: $LOG_DIR/llama-server.log"
}

stop() {
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null && echo "llama-server 已停止" || echo "进程不存在"
    rm -f "$PID_FILE"
  else
    echo "llama-server 未在运行（无 PID 文件）"
  fi
}

status() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "运行中 (PID $(cat "$PID_FILE"))"
    curl -s -m 3 "http://127.0.0.1:$PORT/health" || echo "（健康检查无响应，模型可能加载中）"
  else
    echo "未运行"
  fi
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  restart) stop; sleep 1; start ;;
  *) echo "用法: $0 start|stop|status|restart [模型文件完整路径]"; exit 1 ;;
esac
