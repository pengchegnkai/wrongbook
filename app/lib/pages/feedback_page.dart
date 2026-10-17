/// pages/feedback_page.dart —— 单独反馈页（详情页内也有快捷反馈）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/feedback_service.dart';

class FeedbackPage extends ConsumerStatefulWidget {
  final int? questionId;
  const FeedbackPage({super.key, this.questionId});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  String? _type;
  final _comment = TextEditingController();
  bool _done = false;
  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('反馈')),
      body: _done
          ? const Center(child: Text('感谢反馈！AI 已记录，将影响后续分析风格'))
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('这条 AI 分析：'),
              Wrap(children: FeedbackService.types.entries.map((e) => Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(label: Text(e.value), selected: _type == e.key, onSelected: (_) => setState(() => _type = e.key)),
              )).toList()),
              const SizedBox(height: 12),
              TextField(controller: _comment, maxLines: 3, decoration: const InputDecoration(labelText: '补充说明（可空）')),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              FilledButton(onPressed: (_type == null || _submitting) ? null : () async {
                setState(() => _submitting = true);
                try {
                  await FeedbackService().submit(
                    questionId: widget.questionId,
                    feedbackType: _type!,
                    comment: _comment.text,
                  );
                  if (mounted) setState(() => _done = true);
                } catch (e) {
                  if (mounted) setState(() => _error = e.toString());
                } finally {
                  if (mounted) setState(() => _submitting = false);
                }
              }, child: Text(_submitting ? '提交中…' : '提交反馈')),
            ]),
    );
  }
}
