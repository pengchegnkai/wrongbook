/// widgets/mermaid_webview.dart —— Mermaid 思维导图 WebView 渲染
/// TODO: 引入 webview_flutter 依赖（版本号请以 pub.dev 官方页面为准）后启用。
/// 当前为占位：显示源码。启用方式见注释。
import 'package:flutter/material.dart';

class MermaidWebview extends StatelessWidget {
  final String mermaidSource;
  const MermaidWebview({super.key, required this.mermaidSource});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text('WebView 渲染未启用（依赖 webview_flutter 待接入，未验证）。\n\nMermaid 源码：\n$mermaidSource'),
    ));
  }

  /// TODO 启用后实现：
  /// 1. pubspec.yaml 添加 webview_flutter（版本以 pub.dev 为准）
  /// 2. assets 中放入 mermaid.min.js（自行从官方 CDN 下载，本处不编造地址）
  /// 3. WebViewController.loadHtmlString(html)，html 含：
  ///    <div class="mermaid">$mermaidSource</div> 与 mermaid.initialize({startOnLoad:true})
}
