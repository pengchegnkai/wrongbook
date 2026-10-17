/// pages/knowledge_graph_page.dart —— 知识点图谱（Mermaid 思维导图经 WebView 渲染）
/// 说明：webview 依赖未加入 pubspec（版本号请以 pub.dev 官方页面为准）。
/// 当前实现：由后端知识点数据生成 Mermaid 源码文本展示 + 复制按钮；TODO 引入 webview 后用 mermaid.js 渲染。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../widgets/mermaid_webview.dart';

class KnowledgeGraphPage extends ConsumerStatefulWidget {
  const KnowledgeGraphPage({super.key});

  @override
  ConsumerState<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends ConsumerState<KnowledgeGraphPage> {
  String? _mermaid;

  Future<void> _buildGraph() async {
    try {
      final kps = await ApiClient().get('/subjects/kps/all') as List;
      final buf = StringBuffer('graph TD\n');
      for (var i = 0; i < kps.length; i++) {
        final kp = kps[i];
        final chapter = kp['chapter_name'] ?? '未分类';
        final name = (kp['name'] ?? '').toString().replaceAll(RegExp(r'["()]'), '');
        // 节点 id 用索引前缀，避免 hashCode 碰撞导致 Mermaid 节点错连
        buf.writeln('  n${i}c["$chapter"] --> n${i}k["$name"]');
      }
      if (!mounted) return;
      setState(() => _mermaid = buf.toString());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('知识点图谱'), actions: [
        IconButton(icon: const Icon(Icons.build), onPressed: _buildGraph),
      ]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('知识点图谱（Mermaid 渲染；离线时可展开下方源码）'),
              const SizedBox(height: 16),
              Expanded(
                child: _mermaid != null
                    ? MermaidWebview(mermaidSource: _mermaid!)
                    : const Center(child: Text('点击右上角按钮生成')),
              ),
              if (_mermaid != null)
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('复制 Mermaid 源码'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _mermaid!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
