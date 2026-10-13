/// pages/ocr_review_page.dart —— 服务端 OCR 校对页
/// 流程：进入时自动上传图片到 POST /api/ocr/recognize → 展示原图 + 识别结果
/// → 用户逐题校对（原题 / 我的答案可编辑，可增删题）→ 保存全部错题。
/// 四态：上传中（骨架+进度）/ 出错（重试按钮）/ 完成（校对表单）/ 空（无图片）。
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/ui_states.dart';
import '../providers/ocr_provider.dart';

class OcrReviewPage extends ConsumerStatefulWidget {
  const OcrReviewPage({super.key});

  @override
  ConsumerState<OcrReviewPage> createState() => _OcrReviewPageState();
}

/// 一题的编辑控制器
class QEdit {
  final qCtrl = TextEditingController();
  final aCtrl = TextEditingController();
  QEdit({String q = '', String a = ''}) {
    qCtrl.text = q;
    aCtrl.text = a;
  }
  void dispose() {
    qCtrl.dispose();
    aCtrl.dispose();
  }
}

class _OcrReviewPageState extends ConsumerState<OcrReviewPage> {
  String? _imagePath;
  final List<QEdit> _edits = [];
  bool _autoStarted = false;
  bool _rawExpanded = false;
  bool _saving = false;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoStarted) return;
    _autoStarted = true;
    final extra = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _imagePath = extra?['imagePath'] as String?;
    if (_imagePath != null) {
      ref.read(ocrProvider.notifier).recognize(_imagePath!);
    }
  }

  @override
  void dispose() {
    for (final e in _edits) {
      e.dispose();
    }
    ref.read(ocrProvider.notifier).reset();
    super.dispose();
  }

  /// 结果到达后填充编辑框（只填一次，避免覆盖用户修改）
  void _applyResult(dynamic result) {
    if (_filled) return;
    _filled = true;
    final qs = result.questions as List;
    setState(() {
      _edits
        ..clear()
        ..addAll([for (final q in qs) QEdit(q: q.question as String, a: q.myAnswer as String)]);
    });
  }

  Future<void> _save() async {
    final items = _edits.where((e) => e.qCtrl.text.trim().isNotEmpty).toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有可保存的内容（原题不能为空）')));
      return;
    }
    setState(() => _saving = true);
    var ok = 0;
    String? failMsg;
    try {
      final api = ApiClient();
      for (final e in items) {
        await api.post('/questions', body: {
          'originalQuestion': e.qCtrl.text.trim(),
          'myAnswer': e.aCtrl.text.trim().isEmpty ? null : e.aCtrl.text.trim(),
          'source': 'ocr',
        });
        ok++;
      }
    } catch (err) {
      failMsg = err.toString().startsWith('Exception:') ? err.toString().substring(10) : err.toString();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (failMsg != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存了 $ok/$items.length 题，中断原因：$failMsg')));
    } else {
      if (mounted) context.go('/questions');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocr = ref.watch(ocrProvider);
    final path = _imagePath;
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    switch (ocr.stage) {
      case OcrStage.idle:
        body = EmptyStateView(
          icon: Icons.image_not_supported,
          title: '未指定图片',
          message: '请从「拍照录入」进入本页',
          actionLabel: '去拍照',
          onAction: () => context.push('/scan'),
        );
      case OcrStage.uploading:
        body = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (path != null && File(path).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('正在上传并识别（服务端 Tesseract，可能需要 10-60 秒）…',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const PageSkeleton(itemCount: 3),
          ],
        );
      case OcrStage.error:
        body = ErrorRetryView(
          message: ocr.error ?? '未知错误',
          onRetry: () => ref.read(ocrProvider.notifier).retry(),
        );
      case OcrStage.done:
        if (ocr.result != null && !_filled) {
          // 首帧渲染编辑器，随后填充编辑框
          WidgetsBinding.instance.addPostFrameCallback((_) => _applyResult(ocr.result));
        }
        body = Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (path != null && File(path).existsSync()) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(path), fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _RawTextPanel(
                    text: ocr.result!.rawText,
                    expanded: _rawExpanded,
                    onToggle: () => setState(() => _rawExpanded = !_rawExpanded),
                  ),
                  const SizedBox(height: 12),
                  if (ocr.result!.lang == 'eng')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '⚠ 中文语言包不可用，已降级为英文识别，中文内容可能识别失败',
                        style: TextStyle(fontSize: 12, color: scheme.error),
                      ),
                    ),
                  Text(
                    '识别出 ${ocr.result!.questions.length} 题，请校对后保存（原题为空的题会被跳过）',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < _edits.length; i++)
                    _QuestionEditor(
                      index: i,
                      edit: _edits[i],
                      onRemove: () => setState(() {
                        _edits[i].dispose();
                        _edits.removeAt(i);
                      }),
                    ),
                  OutlinedButton.icon(
                    onPressed: _edits.length >= 5 ? null : () => setState(() => _edits.add(QEdit())),
                    icon: const Icon(Icons.add),
                    label: const Text('添加一题'),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? '保存中…' : '保存全部错题（${_edits.length}）'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ),
          ],
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR 校对'),
        actions: [
          if (ocr.stage == OcrStage.done)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新识别',
              onPressed: path == null ? null : () {
                _edits.forEach((e) => e.dispose());
                _edits.clear();
                _filled = false;
                _rawExpanded = false;
                ref.read(ocrProvider.notifier).recognize(path);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _RawTextPanel extends StatelessWidget {
  const _RawTextPanel({required this.text, required this.expanded, required this.onToggle});
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.subject, size: 20),
            title: const Text('原始识别文本', style: TextStyle(fontSize: 13)),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SelectableText(text, style: const TextStyle(fontSize: 12, height: 1.5)),
            ),
        ],
      ),
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({required this.index, required this.edit, required this.onRemove});
  final int index;
  final QEdit edit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('第 ${index + 1} 题', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, size: 18), tooltip: '删除此题', onPressed: onRemove),
            ],
          ),
          TextField(
            controller: edit.qCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '原题',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: edit.aCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '我的答案（可留空）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
