/// pages/review_page.dart —— 复习模式：先看原题和我的答案，点击显示正解/解析/来源
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/review_provider.dart';
import '../models/question.dart';
import '../widgets/source_badge.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(reviewCardsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('复习模式')),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('今天没有待复习的卡片 🎉'));
          final q = list.first;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('剩余 ${list.length} 张', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(children: [
                        Text('原题', style: Theme.of(context).textTheme.titleSmall),
                        SelectableText(q.originalQuestion),
                        const SizedBox(height: 12),
                        Text('我的答案', style: Theme.of(context).textTheme.titleSmall),
                        SelectableText(q.myAnswer ?? '（无）'),
                        if (_revealed) ...[
                          const Divider(height: 24),
                          Text('正确答案', style: Theme.of(context).textTheme.titleSmall),
                          SelectableText(q.correctAnswer ?? '（无）'),
                          const SizedBox(height: 12),
                          Text('解析', style: Theme.of(context).textTheme.titleSmall),
                          SelectableText(q.analysis ?? '（无）'),
                          const SizedBox(height: 8),
                          if ((q.answerSourceUrl ?? '').isNotEmpty) ...[
                            SourceBadge(authority: q.answerSourceAuthority ?? 'C'),
                            Text(q.answerSourceUrl!, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                          ],
                        ],
                      ]),
                    ),
                  ),
                ),
                if (!_revealed)
                  FilledButton(onPressed: () => setState(() => _revealed = true), child: const Text('显示答案'))
                else
                  Row(children: [
                    Expanded(child: FilledButton.tonal(
                      style: FilledButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => _submit(context, ref, q, 'again'), child: const Text('记错了'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton.tonal(
                      style: FilledButton.styleFrom(foregroundColor: Colors.amber.shade800),
                      onPressed: () => _submit(context, ref, q, 'hard'), child: const Text('有点模糊'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _submit(context, ref, q, 'good'), child: const Text('掌握了'))),
                  ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref, Question q, String result) async {
    try {
      await ref.read(reviewSubmitProvider)(q.id!, result);
      setState(() => _revealed = false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交失败：$e')));
    }
  }
}
