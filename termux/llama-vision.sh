#!/data/data/com.termux/files/usr/bin/bash
# llama-vision.sh —— MiniCPM-V 2.6 多模态视觉引擎（独立 :8081）
# 用法:
#   llama-vision.sh start    # 停文本模型 → 起视觉模型（8GB 内存只能二选一）
#   llama-vision.sh stop     # 停视觉模型
#   llama-vision.sh status
# 模型: ~/cuoti/models/vision/{ggml-model-Q3_K_M,mmproj-model-f16}.gguf
set -u
MODELS="$HOME/cuoti/models/vision"
LOG_DIR="$HOME/cuoti/logs"
PID_FILE="$LOG_DIR/llama-vision.pid"
mkdir -p "$LOG_DIR"

MMproj="$MODELS/mmproj-model-f16.gguf"
Main="$MODELS/ggml-model-Q3_K_M.gguf"

[ -f "$Main" ] || { echo "缺少 $Main（先运行模型下载）"; exit 1; }
[ -f "$MMproj" ] || { echo "缺少 $MMproj（先运行模型下载）"; exit 1; }

stop_text() {
  pkill -f 'llama-server.*8080' 2>/dev/null && echo "已停止文本模型(:8080)——8GB 内存无法双模型共存" || true
}

start() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "视觉模型已在运行 (PID $(cat "$PID_FILE"))"; return
  fi
  stop_text
  echo "加载 MiniCPM-V（权重+mmproj 共 4.85GB，约需 20-60 秒）…"
  nohup llama-server \
    --host 127.0.0.1 --port 8081 \
    --model "$Main" \
    --mmproj "$MMproj" \
    -ngl 0 -c 1024 --threads 4 \
    > "$LOG_DIR/llama-vision.log" 2>&1 &
  echo $! > "$PID_FILE"
  # 等待就绪
  for _ in $(seq 1 30); do
    if curl -s -m 2 http://127.0.0.1:8081/health | grep -q ok; then
      echo "视觉模型已就绪: http://127.0.0.1:8081"
      echo "App 里用「AI 深度视觉」模式即可（文本 AI 分析此时不可用，切回: llama-server.sh start）"
      return
    fi
    sleep 2
  done
  echo "警告：60s 未就绪，请查看 $LOG_DIR/llama-vision.log"
}

stop() {
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null && echo "视觉模型已停止"
    rm -f "$PID_FILE"
  else
    pkill -f 'llama-server.*8081' 2>/dev/null && echo "视觉模型已停止" || echo "未在运行"
  fi
  return 0
}

status() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "运行中 (PID $(cat "$PID_FILE"))  $(curl -s -m 2 http://127.0.0.1:8081/health 2>/dev/null || echo 'health 未响应')"
  else
    echo "未运行"
  fi
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
