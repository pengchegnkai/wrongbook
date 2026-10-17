/// pages/ai_vision_page.dart —— 双引擎图片解析
/// 流程：拍照/选图 → 选模式（极速 OCR / AI 视觉）→ 解析（差异化 Loading）
/// → 结构化校对（悬浮原图小窗可拖拽比对）→ 保存错题。
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/ui_states.dart';
import '../providers/stats_provider.dart';
import '../services/ai_parse_api.dart';

class AiVisionPage extends ConsumerStatefulWidget {
  const AiVisionPage({super.key});

  @override
  ConsumerState<AiVisionPage> createState() => _AiVisionPageState();
}

enum ParseStage { idle, parsing, done }

class _AiVisionPageState extends ConsumerState<AiVisionPage> {
  final _picker = ImagePicker();
  String _mode = 'ocr'; // 'ocr' | 'vision'
  File? _image;
  ParseStage _stage = ParseStage.idle;
  ParseResult? _result;
  String? _error;

  // 校对表单
  final _subjectCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  bool _rawExpanded = false;
  bool _saving = false;

  // 悬浮原图小窗
  Offset _floatPos = const Offset(230, 120);
  bool _floatCollapsed = true;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);
    try {
      // maxWidth/Height 960：视觉 token 数与图片像素成正比，
      // 缩图是纯 CPU 视觉推理的最大提速点（清晰度仍够识别题目）
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 960,
        maxHeight: 960,
      );
      if (x == null) return;
      final f = File(x.path);
      if (!await f.exists()) throw Exception('图片文件不存在，请重试');
      setState(() {
        _image = f;
        _result = null;
        _stage = ParseStage.idle;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _parse() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先拍照或选图')));
      return;
    }
    setState(() {
      _stage = ParseStage.parsing;
      _error = null;
      _result = null;
    });
    try {
      final r = await AiParseApi.parse(imagePath: _image!.path, mode: _mode);
      if (!mounted) return;
      setState(() {
        _result = r;
        _stage = ParseStage.done;
        _subjectCtrl.text = r.subject;
        _questionCtrl.text = r.question;
        _answerCtrl.text = r.myAnswer;
        _floatCollapsed = true;
        _floatPos = const Offset(230, 120);
      });
      ref.invalidate(overviewStatsProvider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = ParseStage.idle;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _save() async {
    final q = _questionCtrl.text.trim();
    if (q.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('原题为空，无法保存')));
      return;
    }
    setState(() => _saving = true);
    try {
      await AiParseApi.saveQuestion(
        question: q,
        myAnswer: _answerCtrl.text,
        source: _mode == 'vision' ? 'vision' : 'ocr',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存，可在错题列表查看')));
      ref.invalidate(overviewStatsProvider);
      context.go('/questions');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isVision = _mode == 'vision';

    return Scaffold(
      appBar: AppBar(title: const Text('图片解析')),
      body: Column(children: [
        const OfflineBanner(),
        Expanded(
          child: Stack(children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---- 模式切换（SegmentedButton） ----
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'ocr',
                      icon: Icon(Icons.bolt, size: 18),
                      label: Text('极速识别', style: TextStyle(fontSize: 13)),
                    ),
                    ButtonSegment(
                      value: 'vision',
                      icon: Icon(Icons.visibility, size: 18),
                      label: Text('AI 深度视觉', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _stage == ParseStage.parsing
                      ? null
                      : (s) => setState(() {
                          _mode = s.first;
                          _result = null;
                          _stage = ParseStage.idle;
                        }),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text(
                    isVision ? '适合手写 / 公式 / 图表，需 30-60 秒' : '适合打印文字，约 5-10 秒',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
                // ---- 图片预览 / 选择入口 ----
                if (_image == null)
                  EmptyStateView(
                    icon: Icons.camera_alt,
                    title: '拍一张题目照片',
                    message: '含你的作答，解析后在下一步校对',
                    actionLabel: '拍照',
                    onAction: () => _pick(ImageSource.camera),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(_image!, height: 180, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _stage == ParseStage.parsing ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('拍照'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _stage == ParseStage.parsing ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('相册'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // ---- 解析按钮 / 各模式 Loading ----
                if (_stage == ParseStage.idle)
                  FilledButton.icon(
                    onPressed: _image == null ? null : _parse,
                    icon: Icon(isVision ? Icons.visibility : Icons.bolt),
                    label: Text(isVision ? '开始深度视觉解析' : '开始极速识别'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                if (_stage == ParseStage.parsing) _LoadingByMode(isVision: isVision),
                // ---- 错误 ----
                if (_error != null && _stage != ParseStage.done) ...[
                  const SizedBox(height: 12),
                  ErrorRetryView(message: _error!, onRetry: _parse),
                ],
                // ---- 校对表单 ----
                if (_stage == ParseStage.done && _result != null) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Icon(Icons.check_circle, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      _result!.engine == 'vision' ? '视觉解析完成，请校对' : '识别完成${_result!.corrected ? '（AI 已纠错）' : '，请校对'}',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subjectCtrl,
                    decoration: const InputDecoration(labelText: '学科（可空）'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _questionCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '原题 *',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _answerCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '我的作答（可空）',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_result!.rawText != null && _result!.rawText!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _rawExpanded = !_rawExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Icon(
                            _rawExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text('原始识别文本（比对用）',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        ]),
                      ),
                    ),
                    if (_rawExpanded)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          _result!.rawText!,
                          style: const TextStyle(fontSize: 11, height: 1.5),
                        ),
                      ),
                  ],
                  if (_result!.extraQuestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('另识别出 ${_result!.extraQuestions.length} 题（本次仅保存第一题，其余可手动添加）',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_saving ? '保存中…' : '保存为错题'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                  const SizedBox(height: 90), // 底部导航栏让位
                ],
              ],
            ),
            // ---- 悬浮原图小窗（校对时拖到任意位置比对） ----
            if (_stage == ParseStage.done && _image != null)
              _FloatingImage(
                imagePath: _image!.path,
                collapsed: _floatCollapsed,
                position: _floatPos,
                onPan: (d) => setState(() => _floatPos = Offset(
                      (_floatPos.dx + d.dx).clamp(0.0, 400.0),
                      (_floatPos.dy + d.dy).clamp(40.0, 700.0),
                    )),
                onToggle: () => setState(() => _floatCollapsed = !_floatCollapsed),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// 按模式区分的 Loading 动画与文案
class _LoadingByMode extends StatelessWidget {
  const _LoadingByMode({required this.isVision});
  final bool isVision;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: isVision
          ? Column(children: [
              const _BreathingIcon(),
              const SizedBox(height: 12),
              const Text('AI 正在仔细看图，请耐心等待…', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text('深度视觉模式：手写/公式理解更准（约 30-120 秒）',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ])
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                const Text('正在极速识别…', style: TextStyle(fontSize: 13)),
              ],
            ),
    );
  }
}

/// 循环呼吸动画（缩放 0.85→1.0→0.85，845 上纯 Transform 零重排成本）
class _BreathingIcon extends StatefulWidget {
  const _BreathingIcon();

  @override
  State<_BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<_BreathingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.85,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _scale,
      child: Icon(Icons.visibility, size: 40, color: scheme.primary),
    );
  }
}

/// 悬浮原图小窗：可拖拽，点按放大/缩小（与 OCR 校对页同一交互）
class _FloatingImage extends StatelessWidget {
  const _FloatingImage({
    required this.imagePath,
    required this.collapsed,
    required this.position,
    required this.onPan,
    required this.onToggle,
  });

  final String imagePath;
  final bool collapsed;
  final Offset position;
  final ValueChanged<Offset> onPan;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final size = collapsed ? 110.0 : 320.0;
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (d) => onPan(d.delta),
        onTap: onToggle,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.5),
            child: Stack(children: [
              Positioned.fill(
                child: Image.file(File(imagePath), fit: collapsed ? BoxFit.cover : BoxFit.contain),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    collapsed ? Icons.zoom_out_map : Icons.zoom_in_map,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
