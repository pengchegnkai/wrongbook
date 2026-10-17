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

## 九、服务端 OCR（Tesseract，实测记录）

App 拍照录入的 OCR 在服务端执行（Termux Tesseract），客户端零原生 OCR 插件。

### 安装

```bash
pkg install -y tesseract          # 实测装得（当前版本 5.5.3）
```

**注意：Termux 仓库没有 `tesseract-lang-zh` 包**（实测 `Unable to locate package`），
中文语言包需手动下载 traineddata：

```bash
# GitHub 直连（手机网络经常连不上时改用下面 jsDelivr 镜像）
curl -L -o "$PREFIX/share/tessdata/chi_sim.traineddata" \
  "https://github.com/tesseract-ocr/tessdata_fast/raw/main/chi_sim.traineddata"
# jsDelivr 镜像（实测可用，文件约 2.4MB）
curl -L -o "$PREFIX/share/tessdata/chi_sim.traineddata" \
  "https://cdn.jsdelivr.net/gh/tesseract-ocr/tessdata_fast@main/chi_sim.traineddata"
```

验证：`tesseract --list-langs` 应列出 `chi_sim` 和 `eng`。

### 已知坑（已内置处理）

| 坑 | 现象 | 处理 |
|---|---|---|
| OpenMP 亲和性崩溃 | 直接跑 `tesseract` 报 `OMP: Error #13 (kmp_affinity)` 并 abort | `server/routes/ocr.js` 调用时已固定传 `KMP_AFFINITY=disabled OMP_NUM_THREADS=1`，无需手动处理 |
| 中英混识干扰符号 | `chi_sim+eng` 模式下英文图 `+` 被识别成 `2 二` | ocr.js 启发式：识别结果 CJK 占比 <5% 时自动用纯 `eng` 重识一次（实测有效） |
| 中文语言包缺失 | chi_sim+eng 执行失败 | 自动降级纯 `eng` 并重试；仍失败返回 `OCR 服务不可用`，App 提示安装方法 |

### 接口测试

```bash
# 1) 登录取 token（换成你的账号密码）
TOKEN=$(curl -s -X POST http://127.0.0.1:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"你的用户名","password":"你的密码"}' \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['data']['accessToken'])")

# 2) 上传图片识别（jpg/png，≤10MB）
curl -s -X POST http://127.0.0.1:3000/api/ocr/recognize \
  -H "Authorization: Bearer $TOKEN" \
  -F "image=@/path/to/image.jpg" | python3 -m json.tool
```

返回结构：`{ code: 0, data: { rawText, lang, questions: [{question, myAnswer}] } }`。
切题规则：行首题号（`1.` `2、` `（3）`）开始新题；`解：/答：/答案：` 行起为作答段。

### 识别质量说明

Tesseract 识别不保证全对，App 内 OCR 校对页**必须人工校对后再保存**。

**中文实测记录**（本机已验证，2026-10）：
- 测试图：Android 系统字体 `/system/fonts/NotoSansCJK-Regular.ttc` + Pillow 渲染的印刷体中文（无需下载 17MB 字体）
- 文字识别基本正确：「计算下列各式的值」「解：」等整句准确；题号切题（`1.` `(1)`）正确；「解：」行正确归入作答段
- **数学符号易误识**：`×`→`X`、`÷`→`二`、分数线/根号识别差——理科公式题校对量会明显偏大
- 手写体、实拍阴影/透视未测，预期比印刷体差
- 提高中文质量可换 `tessdata_best` 版 chi_sim.traineddata（更慢更准，地址同上把 `tessdata_fast` 换成 `tessdata_best`）

## 十、常见问题

| 问题 | 处理 |
|---|---|
| `whiptail: command not found` | 正常，TUI 会自动降级为纯 bash 菜单 |
| PM2 报 node-gyp 错误 | 确认 `~/.bashrc` 中有 `export GYP_DEFINES="android_ndk_path=''"`，重新登录 shell |
| 手机锁屏后服务失联 | 检查电池优化是否已关；`termux-wake-lock` |
| 内网其他设备访问不了 | 确认同一局域网；TUI「网络与内网」里检查 HOST 是否 0.0.0.0 |
| llama-server 无响应 | `bash termux/llama-server.sh status`；模型加载约需数秒到数十秒 |
| App 提示「OCR 服务不可用」 | 按上面第九节安装 tesseract 与中文语言包，重跑 `tesseract --list-langs` 验证 |

## 十一、安全提示

- 内网业务 API 全部需要 JWT 登录，无匿名访问。
- `server/.env` 中的 `JWT_SECRET` 请修改。
- PostgreSQL 不暴露内网。

## 十二、公网访问（Cloudflare Tunnel，免费套餐）

手机不在内网时，可通过 Cloudflare Tunnel 从公网访问后端（免费套餐即可，
无需公网 IP、无需端口转发、流量不过本地防火墙）。前提：一个已托管在
Cloudflare 的域名（NS 指向 Cloudflare，免费版即可）。

### 安装与授权（一次性）

```bash
pkg install -y cloudflared      # Termux 官方仓库有（实测 2026.10.1）
bash ~/cuoti/termux/tunnel.sh login
# 打印一个 dash.cloudflare.com 链接 → 手机浏览器打开 → 登录 Cloudflare
# → 选择域名 → 授权；完成后 ~/.cloudflared/cert.pem 自动生成
```

### 创建隧道并绑定域名（一次性）

```bash
bash ~/cuoti/termux/tunnel.sh setup cuoti.你的域名.com
# 自动完成：创建命名隧道 cuoti + 写 ~/.cloudflared/config.yml
#          + cloudflared tunnel route dns 写 CNAME 记录
```

只映射后端 API（localhost:3000）。llama-server(:8080) 与 PostgreSQL(:5432)
一律不暴露公网。

### 日常启停

```bash
bash ~/cuoti/termux/tunnel.sh start    # 后台运行（已验证边缘连接才返回）
bash ~/cuoti/termux/tunnel.sh stop
bash ~/cuoti/termux/tunnel.sh status
bash ~/cuoti/termux/tunnel.sh quick    # 免登录临时隧道（随机 trycloudflare
                                       # 地址，调试用，重启即换）
```

### App 端配置

服务器配置页填完整域名：`https://cuoti.你的域名.com`（App 自动识别 https
与内网 IP；裸域名会自动补 https）。

模式差异（App 已自动适配）：

| | 内网模式 | 公网域名模式 |
|---|---|---|
| 地址 | `http://192.168.x.x:3000` | `https://cuoti.你的域名.com` |
| AI 分析 | 走后端 `/api/ai/*`（推荐，同公网） | 走后端 `/api/ai/*` |
| 模型直连 | llama-server :8080 可直连 | 8080 不暴露，直连自动失效，推理走后端代理 |

### 实测记录（2026-10）

- `pkg install cloudflared` 直接可用（2026.10.1）
- 快速隧道（`--url`）与命名隧道均验证打通：公网 → 边缘 → 本机 3000
- `https://cuoti.pck-server.ccwu.cc/api/health` HTTP 200（1.3s，边缘在 lax）
- 公网登录接口实测 code:0
- 日志中的 ICMP proxy 警告无害（Termux 无权限配 ping_group_range，不影响 HTTP 隧道）

### 安全注意

- 隧道把后端暴露到公网：JWT 登录是唯一防线，`JWT_SECRET` 必须已改强随机值。
- 免费版 Cloudflare 不强制源站校验；如需进一步加固，可在 Cloudflare
  Zero Trust 配 Access 策略（本处仅作一般性说明，请以 Cloudflare 官方文档为准）。
- 临时隧道（quick）地址公开可猜性低但任何人可访问，用完即停。
