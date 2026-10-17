/// widgets/mermaid_webview.dart —— Mermaid 思维导图 WebView 渲染
/// webview_flutter 加载本地生成的 HTML；mermaid.js 从官方 CDN 引入
/// （离线时 WebView 加载不出图，页面保留源码区兜底）。
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MermaidWebview extends StatefulWidget {
  final String mermaidSource;
  const MermaidWebview({super.key, required this.mermaidSource});

  @override
  State<MermaidWebview> createState() => _MermaidWebviewState();
}

class _MermaidWebviewState extends State<MermaidWebview> {
  late final WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // 页面渲染成功/失败都会回调此通道（html 里 MermaidBridge.done(...)）
      ..addJavaScriptChannel('MermaidBridge', onMessageReceived: (_) {
        if (mounted) setState(() => _loaded = true);
      })
      ..loadHtmlString(_buildHtml(widget.mermaidSource));
  }

  static String _buildHtml(String source) {
    final encoded = jsonEncode(source); // 防 HTML 注入/转义问题
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<style>
  body { margin: 0; padding: 8px; background: #ffffff; }
  .mermaid { display: flex; justify-content: center; }
  svg { max-width: 100%; height: auto; }
</style>
</head><body>
<div class="mermaid" id="graph"></div>
<script>
  // 源码经 JSON 转义后解码，避免引号/换行破坏 HTML
  const src = JSON.parse($encoded);
  const el = document.getElementById('graph');
  el.textContent = src;
  mermaid.initialize({ startOnLoad: true, theme: 'default' });
  mermaid.run({ nodes: [el] }).then(() => {
    MermaidBridge && MermaidBridge.done('ok');
  }).catch(e => {
    document.body.innerText = '渲染失败: ' + e.message;
    MermaidBridge && MermaidBridge.done('error');
  });
</script>
</body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: Stack(children: [
          WebViewWidget(controller: _controller),
          // CDN 加载中/失败的提示（mermaid.run 完成后隐藏）
          if (!_loaded)
            const Center(child: Text('正在渲染思维导图…（需联网加载渲染库）')),
        ]),
      ),
      // 源码兜底：离线/渲染失败时用户仍可复制源码到支持 Mermaid 的工具查看
      ExpansionTile(
        title: const Text('查看 Mermaid 源码', style: TextStyle(fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(widget.mermaidSource,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
        ],
      ),
    ]);
  }
}
