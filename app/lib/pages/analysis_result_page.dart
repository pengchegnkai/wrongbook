/// pages/analysis_result_page.dart —— AI 分析执行与结果展示（Markdown 渲染 + 反馈）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../providers/analysis_provider.dart';
import '../providers/strength_provider.dart';
import '../providers/prompt_template_provider.dart';
import '../services/feedback_service.dart';

class AnalysisResultPage extends ConsumerStatefulWidget {
  const AnalysisResultPage({super.key});

  @override
  ConsumerState<AnalysisResultPage> createState() => _AnalysisResultPageState();
}

class _AnalysisResultPageState extends ConsumerState<AnalysisResultPage> {
  int? _questionId;
  int? _templateId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _questionId = args?['questionId'];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisProvider);
    final strengths = ref.watch(strengthsProvider);
    final templates = ref.watch(promptTemplatesProvider);
    final selectedStrength = ref.watch(selectedStrengthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 分析')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // 模板选择
        templates.maybeWhen(
          data: (list) => DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: '提示词模板'),
            value: _templateId,
            items: list.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
            onChanged: (v) => setState(() => _templateId = v),
          ),
          orElse: () => const Text('模板加载中…'),
        ),
        const SizedBox(height: 12),
        // 思考强度选择
        strengths.maybeWhen(
          data: (list) => DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '思考强度'),
            value: selectedStrength,
            items: list.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name}（${s.description}）'))).toList(),
            onChanged: (v) => ref.read(selectedStrengthProvider.notifier).state = v,
          ),
          orElse: () => const Text('强度加载中…'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始分析'),
          onPressed: _questionId == null ? null : () {
            ref.read(analysisProvider.notifier).analyze(
              questionId: _questionId!, templateId: _templateId, strength: selectedStrength);
          },
        ),
        const SizedBox(height: 16),
        if (state.running) const Center(child: Text('分析中，本地模型可能需要 1-3 分钟…')),
        if (state.error != null) Text('失败：${state.error}', style: const TextStyle(color: Colors.red)),
        if (state.response != null) ...[
          Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: MarkdownBody(data: state.response!),
          )),
          const SizedBox(height: 12),
          Row(children: [
            const Text('这条分析：'),
            ...FeedbackService.types.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ActionChip(label: Text(e.value, style: const TextStyle(fontSize: 11)), onPressed: () async {
                await FeedbackService().submit(questionId: _questionId, analysisLogId: state.logId, feedbackType: e.key);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已反馈：${e.value}')));
              }),
            )),
          ]),
        ],
      ]),
    );
  }
}
