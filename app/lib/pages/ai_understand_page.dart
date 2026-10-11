/// pages/ai_understand_page.dart —— 拍照 → OCR → AI 分区理解 → 草稿校对
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/ocr_provider.dart';
import '../providers/auto_understand_provider.dart';

class AiUnderstandPage extends ConsumerStatefulWidget {
  const AiUnderstandPage({super.key});

  @override
  ConsumerState<AiUnderstandPage> createState() => _AiUnderstandPageState();
}

class _AiUnderstandPageState extends ConsumerState<AiUnderstandPage> {
  final _picker = ImagePicker();

  Future<void> _capture() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (x == null) return;
    // 先 OCR（本地），再送 AI 分区
    await ref.read(ocrProvider.notifier).processImage(x.path);
    final ocr = ref.read(ocrProvider).draft;
    if (ocr == null || ocr.originalQuestion.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OCR 结果为空，无法理解')));
      return;
    }
    await ref.read(autoUnderstandProvider.notifier).understand(ocr.originalQuestion + '\n' + (ocr.myAnswer ?? ''));
    if (mounted) context.go('/ai-understand-review-placeholder'.replaceAll('-placeholder', ''));
  }

  @override
  Widget build(BuildContext context) {
    final au = ref.watch(autoUnderstandProvider);
    final ocr = ref.watch(ocrProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI 自动理解')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        FilledButton.icon(icon: const Icon(Icons.camera_alt), label: const Text('拍照并理解'), onPressed: _capture),
        const SizedBox(height: 16),
        if (ocr.stage == OcrStage.recognizing) const Center(child: Text('OCR 识别中…')),
        if (au.running) const Center(child: Text('AI 分区理解中…')),
        if (au.error != null) Text('失败：${au.error}', style: const TextStyle(color: Colors.red)),
        if (au.result != null) ...[
          Card(child: ListTile(
            leading: Icon(au.result!.needsConfirm ? Icons.warning_amber : Icons.check_circle,
                color: au.result!.needsConfirm ? Colors.orange : Colors.green),
            title: Text(au.result!.needsConfirm ? '部分分区置信度低，需人工确认' : '理解完成'),
            subtitle: Text('学科: ${au.result!.subject}  题型: ${au.result!.questionType}'),
          )),
          ...au.result!.detectedParts.map((p) => Card(child: ListTile(
            title: Text('【${p.type}】${p.needsConfirm ? '（需确认）' : ''}'),
            subtitle: Text(p.content, maxLines: 4, overflow: TextOverflow.ellipsis),
            trailing: Text('${(p.confidence * 100).toStringAsFixed(0)}%'),
          ))),
        ],
      ]),
    );
  }
}
