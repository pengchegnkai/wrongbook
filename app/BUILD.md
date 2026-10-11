# 编译 APK 指南（必须在电脑上执行）

> 前提：Termux 上无法编译 Flutter 应用（Flutter 不支持以 Android 为构建宿主）。
> 本项目源码位于手机 `~/cuoti/app/`（lib + pubspec.yaml），android 平台工程需在电脑上用 flutter create 生成。

## 一、准备工作（电脑）

1. 安装 Flutter SDK：以 Flutter 官网安装文档为准（搜索关键词：`Flutter install`）。
   本项目 pubspec 要求 Dart SDK `>=3.2.0 <4.0.0`（即 Flutter 3.16 及以上）。
2. 从手机取出源码包：`~/storage/downloads/cuoti-app-src.tar.gz`（已打包好 lib + pubspec + android 配置片段），通过 USB/微信/网盘传到电脑并解压。

## 二、生成平台工程并合入源码（电脑）

```bash
# 1. 用 flutter create 生成完整 Android 工程（包名 com.cuoti）
flutter create --org com.cuoti --project-name cuoti_app cuoti_build
cd cuoti_build

# 2. 用手机端源码覆盖 lib（全部 Dart 代码都在这里）
rm -rf lib
cp -r /解压路径/app/lib ./

# 3. 覆盖 pubspec.yaml（依赖清单）
cp /解压路径/app/pubspec.yaml .

# 4. 合并 Android 配置（三处，照手机端 android/ 片段改）：
#    a) android/app/src/main/AndroidManifest.xml —— 合并权限（INTERNET 等）
#       与 application 属性（usesCleartextTraffic、networkSecurityConfig、label="错题本"）
#    b) android/app/src/main/res/xml/network_security_config.xml —— 从解压的
#       android/app/src/main/res/xml/ 复制过来（并把 domain 里改成你的服务器 IP 192.168.3.228）
#    c) android/app/build.gradle —— minSdk 24（ML Kit 要求）
```

## 三、编译（电脑）

```bash
flutter pub get          # 版本冲突时按提示 pub upgrade，版本号以 pub.dev 官方页面为准
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
# 调试版（可选）：flutter build apk --debug
```

## 四、安装到手机

1. 把 `app-release.apk` 传回手机（USB/微信/网盘均可），文件管理器安装。
2. 首次启动：进"服务器配置"页填 `192.168.3.228:3000`（与手机同一 Wi-Fi）。
3. 注册 → 登录 → 首页即仪表盘。

## 五、常见编译问题

| 问题 | 处理 |
|---|---|
| `flutter pub get` 版本冲突 | 按 pub 提示升级对应包；以 pub.dev 官方页面为准 |
| ML Kit 报 minSdk 错误 | 确认 build.gradle 里 minSdk 24 |
| 内网 HTTP 请求被拦 | 确认 network_security_config.xml 已合入且包含你的服务器 IP |
| 中文输入/字体异常 | 模拟器常见，真机一般正常 |
| qr_scan 页面 | 当前为手动输入占位（摄像头扫码插件未集成），不影响其他功能 |
