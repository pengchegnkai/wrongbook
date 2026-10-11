/// pages/ocr_review_page.dart —— OCR 结果校对页：识别 → 用户修正 → 保存草稿
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/ocr_provider.dart';
import '../providers/filter_provider.dart';
import '../core/api_client.dart';
import '../models/question.dart';

class OcrReviewPage extends ConsumerStatefulWidget {
  const OcrReviewPage({super.key});

  @override
  ConsumerState<OcrReviewPage> createState() => _OcrReviewPageState();
}

class _OcrReviewPageState extends ConsumerState<OcrReviewPage> {
  final _question = TextEditingController();
  final _answer = TextEditingController();
  final _correct = TextEditingController();
  String? _errorType;
  String? _mastery;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final path = args?['imagePath'] as String?;
    final ocr = ref.read(ocrProvider);
    if (path != null && ocr.draft == null && ocr.stage != _running) {
      Future.microtask(() async {
        await ref.read(ocrProvider.notifier).processImage(File(path));
        final d = ref.read(ocrProvider).draft;
        if (d != null && mounted) {
          setState(() {
            _question.text = d.originalQuestion;
            _answer.text = d.myAnswer ?? '';
          });
        }
      });
    } else if (ocr.draft != null) {
      _question.text = ocr.draft!.originalQuestion;
      _answer.text = ocr.draft!.myAnswer ?? '';
    }
  }

  static const _running = OcrStage.recognizing;

  @override
  Widget build(BuildContext context) {
    final ocr = ref.watch(ocrProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('校对错题草稿')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (ocr.stage == OcrStage.recognizing || ocr.stage == _running)
          const Center(child: CircularProgressIndicator()),
        if (ocr.error != null) Text('识别失败：${ocr.error}', style: const TextStyle(color: Colors.red)),
        if (ocr.draft?.uncertain == true)
          const Text('⚠ OCR 置信度低，请仔细校对', style: TextStyle(color: Colors.orange)),
        TextField(controller: _question, maxLines: 5, decoration: const InputDecoration(labelText: '原题', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _answer, maxLines: 3, decoration: const InputDecoration(labelText: '我的答案', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _correct, maxLines: 3, decoration: const InputDecoration(labelText: '正确答案（可留空，稍后核验）', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: '错因', border: OutlineInputBorder()),
          items: kErrorTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          value: _errorType,
          onChanged: (v) => setState(() => _errorType = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: '掌握度', border: OutlineInputBorder()),
          items: kMasteryOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          value: _mastery ?? 'red',
          onChanged: (v) => setState(() => _mastery = v),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _save(),
          child: const Text('保存错题'),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (_question.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('原题不能为空')));
      return;
    }
    final q = Question(
      originalQuestion: _question.text.trim(),
      myAnswer: _answer.text.trim().isEmpty ? null : _answer.text.trim(),
      correctAnswer: _correct.text.trim().isEmpty ? null : _correct.text.trim(),
      errorType: _errorType,
      mastery: _mastery ?? 'red',
      source: 'ocr',
    );
    try {
      // 直接经 API 保存（离线场景由队列兜底在 sync 时补传）
      final api = ApiClient();
      await api.post('/questions', body: q.toCreateJson());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
        context.go('/');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败（已入离线队列）: $e')));
    }
    ref.read(ocrProvider.notifier).reset();
  }
}
