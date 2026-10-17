/// pages/model_download_page.dart —— 输入 URL + SHA256 下载模型
/// 下载地址与 SHA256 由用户自行确认（Hugging Face 官方仓库），本页不预填、不编造。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/android/android_model_download_service.dart';
import '../providers/local_model_provider.dart';

class ModelDownloadPage extends ConsumerStatefulWidget {
  const ModelDownloadPage({super.key});

  @override
  ConsumerState<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends ConsumerState<ModelDownloadPage> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  final _sha = TextEditingController();
  double _progress = 0;
  bool _busy = false;
  String? _msg;

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(modelListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('下载模型')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('⚠ 请自行在 Hugging Face 官方仓库确认下载地址与 SHA256（搜索关键词：Qwen2.5 GGUF Q4_K_M）。本应用不代填任何 URL。',
            style: TextStyle(color: Colors.orange, fontSize: 12)),
        const SizedBox(height: 16),
        TextField(controller: _url, decoration: const InputDecoration(labelText: '模型下载 URL')),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: const InputDecoration(labelText: '保存文件名（如 Qwen2.5-3B-Instruct-Q4_K_M.gguf）')),
        const SizedBox(height: 12),
        TextField(controller: _sha, decoration: const InputDecoration(labelText: '预期 SHA256（可空，跳过校验）')),
        const SizedBox(height: 16),
        if (_busy) LinearProgressIndicator(value: _progress > 0 ? _progress : null),
        if (_msg != null) Text(_msg!, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('开始下载'),
          onPressed: _busy ? null : () async {
            if (_url.text.trim().isEmpty || _name.text.trim().isEmpty) {
              setState(() => _msg = 'URL 和文件名必填');
              return;
            }
            setState(() { _busy = true; _progress = 0; _msg = null; });
            try {
              final svc = ModelDownloadService();
              final f = await svc.download(
                url: _url.text.trim(),
                fileName: _name.text.trim(),
                expectedSha256: _sha.text.trim().isEmpty ? null : _sha.text.trim(),
                onProgress: (p) => setState(() => _progress = p),
              );
              // 匹配到注册表中的模型则标记已下载
              final matched = models.where((m) => m.fileName == _name.text.trim()).toList();
              if (matched.isNotEmpty) {
                ref.read(modelListProvider.notifier).markDownloaded(matched.first.id,
                    sizeBytes: f?.lengthSync());
              }
              setState(() => _msg = '下载完成${_sha.text.trim().isEmpty ? '（未校验 SHA256）' : '，SHA256 校验通过'}');
            } catch (e) {
              setState(() => _msg = '下载失败：$e');
            } finally {
              setState(() => _busy = false);
            }
          },
        ),
        const SizedBox(height: 16),
        const Text('提示：模型文件较大（1-5GB），建议手机连 Wi-Fi 并保持 Termux 前台。', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}
