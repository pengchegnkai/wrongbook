/// pages/model_manage_page.dart —— 本地模型管理：列表、切换、删除、下载入口
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/config.dart';
import '../providers/local_model_provider.dart';
import '../providers/inference_provider.dart';

class ModelManagePage extends ConsumerWidget {
  const ModelManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelListProvider);
    final availability = ref.watch(modelAvailabilityProvider);
    final selected = ref.watch(selectedModelProvider);
    // 公网域名模式（https，无端口）：8080 不经隧道暴露，直连不可用是预期
    final isDomainMode = AppConfig.baseUrl.startsWith('https://');

    return Scaffold(
      appBar: AppBar(title: const Text('本地模型管理'), actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '重新检测',
          onPressed: () => ref.invalidate(modelAvailabilityProvider),
        ),
        IconButton(icon: const Icon(Icons.download), onPressed: () => context.push('/model-download')),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: ListTile(
          leading: availability.maybeWhen(
            data: (ok) => Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? Colors.green : Colors.orange),
            orElse: () => const CircularProgressIndicator()),
          title: const Text('模型服务（Termux llama-server）'),
          subtitle: availability.maybeWhen(
            data: (ok) => ok
                ? const Text('在线 :8080')
                : Text(isDomainMode
                    ? '公网域名模式：模型端口不对外开放，直连不可用（预期行为）。\nAI 分析走服务器代理，不受影响。'
                    : '离线：请确认与服务器同内网且 llama-server 已启动（TUI 可重启）'),
            loading: () => const Text('检测中…'),
            error: (e, _) => Text('检测失败：$e'),
          ),
          isThreeLine: true,
        )),
        const SizedBox(height: 8),
        ...models.map((m) => Card(
          child: ListTile(
            leading: Icon(_roleIcon(m.role)),
            title: Row(children: [
              Expanded(child: Text(m.displayName, overflow: TextOverflow.ellipsis)),
              if (m.role == 'main')
                const Chip(label: Text('默认', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
              if (m.downloaded && m.role != 'main')
                const Chip(label: Text('已就位', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
            ]),
            subtitle: Text('${m.fileName}\n${m.sha256 == null ? 'SHA256：待你自行校验填写' : 'SHA256 已填写'}',
                style: const TextStyle(fontSize: 11)),
            isThreeLine: true,
            trailing: selected == m.id
                ? const Chip(label: Text('当前'))
                : TextButton(onPressed: () async {
                    try {
                      await ref.read(inferenceEngineProvider).loadModel(m);
                      ref.read(selectedModelProvider.notifier).state = m.id;
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已切换：${m.displayName}')));
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('切换失败：$e')));
                    }
                  }, child: const Text('切换')),
          ),
        )),
        const SizedBox(height: 12),
        const Text('说明：推理运行在 Termux 端 llama-server（:8080）；切换会请求服务端重启 llama-server。',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'main': return Icons.stars;
      case 'challenge': return Icons.bolt;
      default: return Icons.shield;
    }
  }
}
