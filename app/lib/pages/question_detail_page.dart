/// pages/question_detail_page.dart —— 错题详情
/// 原题 / 我的答案 / 正确答案 / 解析 / 知识点 / 错因 / 掌握度快选 / AI 分析入口 / 删除
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/ui_states.dart';
import '../providers/question_provider.dart';

class QuestionDetailPage extends ConsumerWidget {
  const QuestionDetailPage({super.key, required this.id});
  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这道错题？'),
        content: const Text('删除后不可恢复（分析历史保留）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ApiClient().delete('/questions/$id');
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：${_msg(e)}')));
      }
    }
  }

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception:') ? s.substring(10) : s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(questionDetailProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('错题详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: detail.when(
              loading: () => const PageSkeleton(itemCount: 5),
              error: (e, _) => ErrorRetryView(
                message: _msg(e),
                onRetry: () => ref.invalidate(questionDetailProvider(id)),
              ),
              data: (q) => _DetailContent(q: q, id: id, ref: ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  _DetailContent({required this.q, required this.id, required this.ref});
  final dynamic q;
  final String id;
  final WidgetRef ref;

  Future<void> _updateMastery(String mastery) async {
    try {
      await ApiClient().put('/questions/$id', body: {'mastery': mastery});
      ref.invalidate(questionDetailProvider(id));
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(const SnackBar(content: Text('掌握度已更新')));
      }
    } catch (e) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context)
            .showSnackBar(SnackBar(content: Text('更新失败：${_msg(e)}')));
      }
    }
  }

  String _msg(Object? e) {
    final s = e.toString();
    return s.startsWith('Exception:') ? s.substring(10) : s;
  }

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 学科 / 章节
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (q.subjectName != null)
              _Tag(text: '${q.subjectName}', color: scheme.primaryContainer, onColor: scheme.onPrimaryContainer),
            if (q.chapterName != null)
              _Tag(text: '${q.chapterName}', color: scheme.surfaceContainerHighest),
            if (q.difficulty != null && '${q.difficulty}'.isNotEmpty)
              _Tag(text: '难度: ${q.difficulty}', color: scheme.surfaceContainerHighest),
            if (q.errorType != null && '${q.errorType}'.isNotEmpty)
              _Tag(text: '错因: ${q.errorType}', color: scheme.errorContainer, onColor: scheme.onErrorContainer),
          ],
        ),
        const SizedBox(height: 16),
        _Section(title: '原题', child: Text('${q.originalQuestion}', style: const TextStyle(fontSize: 15, height: 1.5))),
        if (q.myAnswer != null && '${q.myAnswer}'.isNotEmpty)
          _Section(title: '我的答案', child: Text('${q.myAnswer}', style: const TextStyle(fontSize: 14, height: 1.5))),
        if (q.correctAnswer != null && '${q.correctAnswer}'.isNotEmpty)
          _Section(title: '正确答案', child: Text('${q.correctAnswer}', style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.greenAccent))),
        if (q.analysis != null && '${q.analysis}'.isNotEmpty)
          _Section(title: '解析', child: Text('${q.analysis}', style: const TextStyle(fontSize: 14, height: 1.5))),
        if ((q.knowledgePoints as List?)?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text('知识点', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final kp in q.knowledgePoints) _Tag(text: '$kp', color: scheme.tertiaryContainer),
            ],
          ),
        ],
        if (q.errorReason != null && '${q.errorReason}'.isNotEmpty)
          _Section(title: '错因说明', child: Text('${q.errorReason}', style: const TextStyle(fontSize: 13))),
        const SizedBox(height: 16),
        // 掌握度快选
        Text('掌握度', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final e in {'red': '🔴 未掌握', 'yellow': '🟡 模糊', 'green': '🟢 已掌握'}.entries)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value, style: const TextStyle(fontSize: 12)),
                    selected: q.mastery == e.key,
                    onSelected: (_) => _updateMastery(e.key),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => context.push('/ai-analysis', extra: {'questionId': int.tryParse(id)}),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('AI 分析这道错题'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.onColor});
  final String text;
  final Color color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, color: onColor)),
    );
  }
}
