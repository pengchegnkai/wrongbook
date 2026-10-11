/// pages/question_detail_page.dart —— 原题/我的答案/正解/解析/知识点/来源/复习安排/AI 分析
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../providers/question_provider.dart';
import '../providers/filter_provider.dart';
import '../models/question.dart';
import '../widgets/source_badge.dart';

class QuestionDetailPage extends ConsumerWidget {
  final String id;
  const QuestionDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(questionDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('错题详情'), actions: [
        IconButton(icon: const Icon(Icons.delete), onPressed: () => _confirmDelete(context, ref)),
      ]),
      body: q.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (question) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(context, '原题', question.originalQuestion),
            _section(context, '我的答案', question.myAnswer ?? '（无）'),
            _section(context, '正确答案', question.correctAnswer ?? '（待补充）'),
            _section(context, '解析', question.analysis ?? '（无）'),
            if ((question.aiGeneratedAnswer ?? '').isNotEmpty)
              _section(context, 'AI 生成解析', question.aiGeneratedAnswer!),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('掌握度', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(children: kMasteryOptions.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: question.mastery == e.key,
                      onSelected: (_) => _setMastery(ref, question, e.key),
                    ),
                  )).toList()),
                  const SizedBox(height: 8),
                  Text('错因：${question.errorType ?? '未标记'}'),
                  Text('复习：${question.reviewToday ? '今日待复习' : '按 1/3/7/15 天安排'}'),
                  if (question.subjectName != null) Text('学科：${question.subjectName}'),
                ]),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('答案来源', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    TextButton(onPressed: () => _verify(ref), child: const Text('联网核验')),
                  ]),
                  const SizedBox(height: 4),
                  if ((question.answerSourceUrl ?? '').isNotEmpty) ...[
                    SourceBadge(authority: question.answerSourceAuthority ?? 'C'),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {}, // TODO: url_launcher 打开（插件未引入）
                      child: Text(question.answerSourceUrl!, style: const TextStyle(color: Colors.blue, fontSize: 12)),
                    ),
                  ] else
                    const Text('暂无来源，可点击"联网核验"搜索候选来源', style: TextStyle(color: Colors.grey)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.psychology),
              label: const Text('AI 分析此错题'),
              onPressed: () => context.push('/analysis-result', extra: {'questionId': question.id}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String body) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          SelectableText(body),
        ]),
      ),
    );
  }

  Future<void> _setMastery(WidgetRef ref, Question question, String mastery) async {
    await ApiClient().put('/questions/${question.id}', body: {'mastery': mastery});
    ref.invalidate(questionDetailProvider(question.id.toString()));
  }

  Future<void> _verify(WidgetRef ref) async {
    try {
      await ApiClient().post('/verify/$id');
      ref.invalidate(questionDetailProvider(id));
    } catch (e) {
      // 错误已在响应中带出；简单吞掉并刷新
      ref.invalidate(questionDetailProvider(id));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('删除错题'),
      content: const Text('确定删除？不可恢复。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
      ],
    ));
    if (ok == true && context.mounted) {
      await ref.read(questionListProvider.notifier).delete(int.parse(id));
      if (context.mounted) context.pop();
    }
  }
}
