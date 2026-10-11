/// pages/analysis_history_page.dart —— 分析历史
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../providers/analysis_provider.dart';

class AnalysisHistoryPage extends ConsumerWidget {
  const AnalysisHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(analysisHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('分析历史')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (logs) => logs.isEmpty
            ? const Center(child: Text('暂无分析记录'))
            : ListView.builder(
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final log = logs[i];
                  return Card(
                    child: ListTile(
                      title: Text('题目 ${log.questionId ?? '-'} · ${log.strength ?? ''} · ${log.model ?? ''}'),
                      subtitle: Text('耗时 ${log.durationMs ?? '?'}ms · tokens ${log.totalTokens ?? '?'} · ${log.createdAt ?? ''}',
                          style: const TextStyle(fontSize: 11)),
                      onTap: () => showLogDetail(context, log),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// 简单详情弹层（避免新增路由）
Future<void> showLogDetail(BuildContext context, dynamic log) async {
  await showModalBottomSheet(context: context, builder: (_) => SizedBox(
    height: 500,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('提示词', style: TextStyle(fontWeight: FontWeight.bold)),
      SelectableText(log.renderedPrompt ?? '（无）'),
      const SizedBox(height: 12),
      const Text('AI 回复', style: TextStyle(fontWeight: FontWeight.bold)),
      MarkdownBody(data: log.aiResponse ?? '（无）'),
    ]),
  ));
}
