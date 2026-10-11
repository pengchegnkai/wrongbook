# 交互式 TUI 控制终端说明（2026-10 更新）

启动：`bash ~/cuoti/termux/start-tui.sh`

## 实现方式

- 检测到 `whiptail` 时用 whiptail 菜单；否则**自动降级**为纯 bash 数字菜单。
- **未验证，需你实测**：Termux 上 whiptail 的兼容性，以及软键盘操作体验（建议外接键盘）。
- 快捷键：菜单中输入 `0` 或按 Esc 返回；状态总览中 `r` 刷新 `q` 退出。

## 结构

| 文件 | 职责 |
|---|---|
| main.sh | 主菜单（12 模块） |
| menu_*.sh | 各模块交互菜单 |
| lib/common.sh | whiptail/降级抽象、确认框、输入框 |
| lib/services.sh | 服务启停状态（pg_ctl + pkg 版 llama-server） |
| lib/db.sh | psql 封装与常用查询（含 LD_PRELOAD 修复） |
| lib/models.sh | 模型双路径扫描/切换/下载/删除/pkg 信息 |
| lib/network.sh | IP/端口/CORS/设备管理 |
| lib/backup.sh | 备份恢复（模型只备份清单+SHA256） |

## 模型管理约定（已验证）

- 默认模型：`~/storage/downloads/MiniCPM5-1B-Q8_0.gguf`（MiniCPM5-1B-Q8_0）
- 可下载模型目录：`~/cuoti/models/`（Qwen2.5 3B 已就位）
- 模型列表**双路径扫描**：共享存储 + 项目目录 + 私有 downloads
- 切换模型 = 写 `server/.env` 的 `MODEL_PATH`/`MODEL_NAME` → `llama-server.sh restart`
- llama-server 来自 `pkg install llama-cpp llama-cpp-backend-vulkan`，无需自编译
- 配置管理（菜单 10）可编辑 `MODEL_PATH`/`MODEL_NAME`/`PROMPT_TEMPLATE`

## 已知限制（不确定，需实测）

1. whiptail 在部分 Termux 版本上对中文渲染宽度可能异常，降级模式无此问题。
2. 交互式 SQL、模型下载为长任务，降级模式直接前台运行；whiptail 模式输出落盘查看。
3. 密码重置依赖 `bcryptjs`（需先 `cd ~/cuoti/server && npm install`）。
4. 所有 psql 命令假设用户 `cuotiadmin`、库 `cuoti`，与 setup.sh 一致。
