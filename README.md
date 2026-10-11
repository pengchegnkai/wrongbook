# 错题本 —— 项目总 README

高中全科错题整理系统：**Termux 手机即服务器**（PostgreSQL + Node.js + llama.cpp 本地模型）+ **Flutter Android 客户端**。
按普通高中课程方案与广东新高考（3+1+2）整理，不含中职/职教高考内容。

## 目录结构

```
~/cuoti/
├── termux/          部署脚本 + TUI 控制终端（start-all / setup / tui/）
├── server/          Express 后端（routes/ services/ scripts/ schema.sql）
├── data/            seed.json 种子数据（示例，待你粘贴真实错题后覆盖）
├── app/             Flutter 客户端（Android 完整实现，iOS/Windows/Linux 占位 + TODO）
├── android/         Android 原生配置（Manifest / network_security_config）
├── models/          GGUF 模型文件目录
└── logs/ backups/   运行日志与备份
```

## 快速开始

```bash
# 1. 环境（首次，约 30-60 分钟）
bash ~/cuoti/termux/setup.sh

# 2. 修改密码与密钥
cp ~/cuoti/server/.env.example ~/cuoti/server/.env
#   修改 DB_PASSWORD、JWT_SECRET

# 3. 启动
bash ~/cuoti/termux/start-all.sh

# 4. 灌入示例数据（可选）
cd ~/cuoti/server && npm install && node scripts/seed.js

# 5. 隔离自检
node scripts/checkUserIsolation.js

# 6. 日常管理（推荐 TUI）
bash ~/cuoti/termux/start-tui.sh
```

App 端：`cd ~/cuoti/app && flutter pub get && flutter run`，首次启动在"服务器配置"填 Termux 内网地址。

## 核心约定

| 项 | 约定 |
|---|---|
| 数据隔离 | 所有业务表 user_id 外键 NOT NULL；路由强制 req.userId 过滤；checkUserIsolation.js 自检 |
| AI 推理 | 本地 llama-server :8080（OpenAI 兼容），云端 API 留接口不启用 |
| 思考强度 | 快速/标准/深度/极致 → 256/512/1024/2048 tokens，极致 3 次采样 |
| 复习 | 录入即排期 1/3/7/15 天；复习结果联动掌握度 🔴🟡🟢 |
| 来源核验 | 搜索 → 抓取 → 相似度评分 → A/B/C 可信度 → 用户采纳 |
| 自进化 | 显式反馈 + 复习隐式信号 → user_ai_memory / user_ai_profile → RAG 注入提示词 |
| RAG | 轻量文本相似度（关键词 + bigram 余弦），不装 pgvector |
| 内网 | API 0.0.0.0:3000，模型 0.0.0.0:8080，PostgreSQL 仅 127.0.0.1 |

## 已知未验证项（必读）

1. **全部 Termux 编译/安装命令**（setup.sh、llama.cpp Vulkan）未在真机完整跑通，失败点最可能是 Vulkan 构建与 whiptail。
2. **Flutter 依赖版本**以 pub.dev 官方页面为准，未逐一实测兼容性（`flutter pub get` 后处理冲突）。
3. **DuckDuckGo 搜索适配**（webSearch.js）基于页面结构解析，可能失效；未配置任何搜索 API key。
4. **MiniCPM5-1B 为纯文本模型**，图片理解走"App 端 ML Kit OCR + 服务端文本分区"，非端到端多模态。
5. Qwen2.5 各型号下载地址与 SHA256 由你自行确认填写，本项目不预填任何 URL。
6. Android 构建文件（build.gradle / Manifest）为配置片段，需与 `flutter create` 模板合并。
7. 所有页面/服务代码未运行验证，需 `flutter analyze` + 真机实测。

详细部署说明见 `termux/README.md`，TUI 使用见 `termux/tui/README.md`。
