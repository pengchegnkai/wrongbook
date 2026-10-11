# 错题本 · Termux 部署说明（2026-10 更新版）

> 本文档已融合真机实测结论（LLD_PRELOAD 坑、sv 服务失效均已修复进脚本），但整体仍建议你完整实测一遍。

## 一、首次部署

```bash
mkdir -p ~/cuoti && cd ~/cuoti   # 项目文件已在此
bash termux/setup.sh             # 一键安装（约 10-20 分钟，无需编译 llama.cpp）
```

安装内容：nodejs-lts、PostgreSQL 18、**llama-cpp + llama-cpp-backend-vulkan（pkg 官方包，无需自编译）**、PM2、whiptail（可选）。

## 二、必做：关闭电池优化

1. Android 设置 → 应用 → Termux → 电池 → 选"不受限制/无限制"。
2. 建议在最近任务中锁定 Termux，防止后台被杀。

不做这一步，锁屏后 PostgreSQL / Node.js / llama-server 都可能被系统杀死。

## 三、模型说明（已验证可用）

- **默认模型：MiniCPM5-1B-Q8_0**，路径 `~/storage/downloads/MiniCPM5-1B-Q8_0.gguf`
- 若文件尚不在此处：
  ```bash
  cp ~/downloads/MiniCPM5-1B-Q8_0.gguf ~/storage/downloads/
  ```
- 启动参数（已验证）：`llama-server --host 0.0.0.0 --port 8080 -ngl 0 -c 2048 --threads 4`
- 纯 CPU 模式（-ngl 0）；Vulkan 后端包已安装但未启用
- OpenAI 兼容接口 `/v1/chat/completions` 已验证可用
- Qwen2.5 系列（3B 已下载至 `~/cuoti/models/qwen2.5-3b-instruct-q4_k_m.gguf`）作为可下载/可切换选项，URL 与 SHA256 由你自行填写

## 四、如何换模型（三步）

1. **换 gguf 文件**：把新模型放入任意可读目录（推荐 `~/storage/downloads/`）。
2. **改 .env**：编辑 `~/cuoti/server/.env`：
   ```
   MODEL_PATH=~/storage/downloads/你的模型.gguf
   MODEL_NAME=你的模型名
   ```
3. **重启 llama-server**：
   ```bash
   bash ~/cuoti/termux/llama-server.sh restart
   ```
   （脚本会自动读取 .env 中的 MODEL_PATH；若 .env 未配置则用默认 MiniCPM5 路径）

## 五、启动 / 停止

```bash
bash ~/cuoti/termux/start-all.sh    # 启动全部并打印内网地址
bash ~/cuoti/termux/stop-all.sh     # 停止全部
bash ~/cuoti/termux/start-tui.sh    # 交互式控制终端（推荐日常使用）
```

## 六、实测已踩坑（脚本已内置修复）

| 坑 | 现象 | 修复 |
|---|---|---|
| LD_PRELOAD 冲突 | `initdb` 报 "no data was returned by postgres -V" | 脚本用 `env -u LD_PRELOAD` 调用 |
| sv 服务失效 | `sv up postgresql` 报 "unable to change to service directory" | 弃用 sv，改用 `pg_ctl` 直接管理 |
| 自编译 llama-server | 参数解析阶段 Segfault（libllama-common.so） | 改用 pkg 官方包，无需自编译 |
| MiniCPM 模型 tensor 越界 | 自编译版报 "data is not within the file bounds" | pkg 版 + 用户已验证 MiniCPM5 可用 |

## 七、数据库

- PostgreSQL 仅监听 127.0.0.1:5432，不暴露内网。
- 超级用户：`cuotiadmin`；业务用户：`cuoti`（密码 `cuoti_local_pw_2026`，**建议修改**并与 `server/.env` 同步）。
- 服务端首次启动会自动执行 `server/schema.sql` 建表。

## 八、开机自启（可选）

你未安装 Termux:Boot。如需开机自启：

1. 在 F-Droid 安装 Termux:Boot 插件。
2. 打开一次 Termux:Boot 应用。
3. 创建 `~/.termux/boot/start-cuoti.sh`：
   ```bash
   #!/data/data/com.termux/files/usr/bin/bash
   bash ~/cuoti/termux/start-all.sh
   ```
   （未验证，需你实测）

当前方案：手动 `start-all.sh`，PM2 守护 Node.js，llama-server 用 nohup。

## 九、常见问题

| 问题 | 处理 |
|---|---|
| `whiptail: command not found` | 正常，TUI 会自动降级为纯 bash 菜单 |
| PM2 报 node-gyp 错误 | 确认 `~/.bashrc` 中有 `export GYP_DEFINES="android_ndk_path=''"`，重新登录 shell |
| 手机锁屏后服务失联 | 检查电池优化是否已关；`termux-wake-lock` |
| 内网其他设备访问不了 | 确认同一局域网；TUI「网络与内网」里检查 HOST 是否 0.0.0.0 |
| llama-server 无响应 | `bash termux/llama-server.sh status`；模型加载约需数秒到数十秒 |

## 十、安全提示

- 内网业务 API 全部需要 JWT 登录，无匿名访问。
- `server/.env` 中的 `JWT_SECRET` 请修改。
- PostgreSQL 不暴露内网。
