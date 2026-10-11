#!/data/data/com.termux/files/usr/bin/bash
# setup.sh —— 错题本项目 Termux 一键环境安装（2026-10 更新版）
# 变更：llama.cpp 改用 pkg 官方包（无需自行编译）；模型使用共享存储路径
# 注意：本脚本融合了真机实测结论（LD_PRELOAD 坑、sv 服务失效），但整体仍需你实测
set -e

echo "=== [1/7] 基础包更新与安装 ==="
pkg update -y && pkg upgrade -y
pkg install -y nodejs-lts git curl wget lsof net-tools

echo "=== [2/7] 存储权限与唤醒锁 ==="
termux-setup-storage || echo "提示：若已授权过会直接通过；共享存储路径 ~/storage/downloads 可用"
termux-wake-lock || echo "警告：wake-lock 设置失败"

echo "=== [3/7] llama.cpp（pkg 官方包，无需编译） ==="
# 已验证可用：可执行文件在 $PREFIX/bin/llama-server
pkg install -y llama-cpp llama-cpp-backend-vulkan
command -v llama-server >/dev/null || { echo "错误：llama-server 未安装成功"; exit 1; }
echo "llama-server 路径: $(command -v llama-server)"
echo "当前为纯 CPU 模式（-ngl 0），Vulkan 后端包已装但未启用"

echo "=== [4/7] whiptail（TUI 用，可选） ==="
pkg install -y whiptail || echo "提示：whiptail 安装失败，TUI 将自动降级为纯 bash 数字菜单"

echo "=== [5/7] PostgreSQL 安装与初始化 ==="
pkg install -y postgresql
PGDATA="$PREFIX/var/lib/postgresql"
if [ ! -f "$PGDATA/PG_VERSION" ]; then
  mkdir -p "$PGDATA"
  # 实测坑：必须去掉 LD_PRELOAD，否则 initdb 派生的 /system/bin/sh
  # 因 libtermux-exec-ld-preload.so 不可访问而崩溃（"no data was returned by postgres -V"）
  env -u LD_PRELOAD initdb "$PGDATA" -U cuotiadmin || { echo "initdb 失败，请检查错误输出"; exit 1; }
fi

echo "=== [6/7] PM2 安装 ==="
npm install -g pm2 || { echo "PM2 安装失败"; exit 1; }

echo "=== [7/7] Node.js 原生模块编译配置 ==="
mkdir -p "$HOME/.gyp"
cat > "$HOME/.gyp/include.gypi" <<'EOF'
{
  'variables': {
    'android_ndk_path': ''
  }
}
EOF
if ! grep -q 'GYP_DEFINES' "$HOME/.bashrc" 2>/dev/null; then
  echo "export GYP_DEFINES=\"android_ndk_path=''\"" >> "$HOME/.bashrc"
fi

echo ""
echo "=== setup 完成 ==="
echo "模型位置（已验证可用）：$HOME/storage/downloads/MiniCPM5-1B-Q8_0.gguf"
echo "  如文件尚不在此处，请复制：cp ~/downloads/MiniCPM5-1B-Q8_0.gguf ~/storage/downloads/"
echo "下一步：cd ~/cuoti && bash termux/start-all.sh"
echo "README 中有电池优化等必读说明。"
