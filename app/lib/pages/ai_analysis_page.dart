/// pages/ai_analysis_page.dart —— AI 分析页
/// 选错题（或从详情页带 questionId 进来）→ 选模板 → 选思考强度 → 调用 /api/ai/analyze-question
/// 说明：后端为本地模型非流式输出（llama-server 一次返回全文），
/// 这里如实显示"分析中 + 已用时"，结果到达后整段渲染（不做假流式）。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/ui_states.dart';
import '../models/analysis_log.dart';
import '../models/prompt_template.dart';
import '../providers/analysis_provider.dart';
import '../providers/prompt_template_provider.dart';
import '../providers/strength_provider.dart';

class AiAnalysisPage extends ConsumerStatefulWidget {
  const AiAnalysisPage({super.key, this.questionId});
  final int? questionId;

  @override
  ConsumerState<AiAnalysisPage> createState() => _AiAnalysisPageState();
}

class _AiAnalysisPageState extends ConsumerState<AiAnalysisPage> {
  int? _selectedQuestionId;
  int? _selectedTemplateId;
  String? _selectedStrength;
  final _extraCtrl = TextEditingController();
  Timer? _ticker;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _selectedQuestionId = widget.questionId;
    if (_selectedQuestionId == null) {
      _loadQuestions();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final data = await ApiClient().get('/questions', query: {'page': 1, 'pageSize': 30}) as Map;
      final items = data['items'] as List;
      if (items.isNotEmpty && _selectedQuestionId == null && mounted) {
        setState(() => _selectedQuestionId = items.first['id'] as int? ?? _selectedQuestionId);
      }
    } catch (_) {
      // 加载失败：下拉框显示空，用户可重试
    }
  }

  void _startTicker() {
    _elapsed = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _analyze() async {
    final qid = _selectedQuestionId;
    if (qid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择要分析的错题')));
      return;
    }
    ref.read(analysisProvider.notifier).reset();
    _startTicker();
    await ref.read(analysisProvider.notifier).analyze(
          questionId: qid,
          templateId: _selectedTemplateId,
          strength: _selectedStrength,
          extra: _extraCtrl.text.trim().isEmpty ? null : _extraCtrl.text.trim(),
        );
    _stopTicker();
  }

  @override
  Widget build(BuildContext context) {
    final analysis = ref.watch(analysisProvider);
    final templates = ref.watch(promptTemplatesProvider);
    final strengths = ref.watch(strengthsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 分析'), actions: [
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: '分析历史',
          onPressed: () => context.push('/analysis-history'),
        ),
      ]),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 错题选择（详情页进入时固定，列表进入时可选）
                if (widget.questionId == null) ...[
                  Text('选择错题', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _QuestionPicker(selected: _selectedQuestionId, onSelect: (id) => setState(() => _selectedQuestionId = id)),
                  const SizedBox(height: 16),
                ],
                // 模板选择
                Text('提示词模板', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                templates.when(
                  loading: () => const PageSkeleton(itemCount: 1),
                  error: (_, __) => Text('模板加载失败', style: TextStyle(fontSize: 12, color: scheme.error)),
                  data: (list) => DropdownButtonFormField<int?>(
                    value: _selectedTemplateId,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('默认模板')),
                      for (final t in list)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            '${t.name}${t.isDefault ? '（默认）' : ''}${t.subject != null ? ' · ${t.subject}' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: analysis.running
                        ? null
                        : (v) => setState(() => _selectedTemplateId = v),
                  ),
                ),
                const SizedBox(height: 16),
                // 思考强度
                Text('思考强度', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                strengths.when(
                  loading: () => const SizedBox(height: 36, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (_, __) => Text('强度加载失败', style: TextStyle(fontSize: 12, color: scheme.error)),
                  data: (list) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('默认', style: TextStyle(fontSize: 12)),
                        selected: _selectedStrength == null,
                        onSelected: analysis.running ? null : (_) => setState(() => _selectedStrength = null),
                      ),
                      for (final s in list)
                        Tooltip(
                          message: s.description,
                          child: ChoiceChip(
                            label: Text(s.name, style: const TextStyle(fontSize: 12)),
                            selected: _selectedStrength == s.id,
                            onSelected: analysis.running ? null : (_) => setState(() => _selectedStrength = s.id),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 补充说明
                TextField(
                  controller: _extraCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '补充说明（可选）',
                    hintText: '例如：重点讲一下第二种解法',

                  ),
                ),
                const SizedBox(height: 20),
                // 开始分析按钮
                FilledButton.icon(
                  onPressed: analysis.running ? null : _analyze,
                  icon: analysis.running
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(analysis.running ? '分析中…（已用 $_elapsed 秒）' : '开始分析'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
                if (analysis.running)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '本地模型分析可能需要 30-120 秒，结果返回后整段显示',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                // 错误
                if (analysis.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ErrorRetryView(message: analysis.error!, onRetry: _analyze),
                  ),
                // 结果
                if (analysis.response != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('分析结果', style: Theme.of(context).textTheme.titleSmall),
                      if (analysis.strength != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('强度: $analysis.strength',
                              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _analyze,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('再分析一次'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: MarkdownBody(
                      data: analysis.response!,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: 14, height: 1.6, color: scheme.onSurface),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 错题下拉选择（最近 30 条）
class _QuestionPicker extends ConsumerStatefulWidget {
  _QuestionPicker({required this.selected, required this.onSelect});
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  ConsumerState<_QuestionPicker> createState() => _QuestionPickerState();
}

class _QuestionPickerState extends ConsumerState<_QuestionPicker> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient().get('/questions', query: {'page': 1, 'pageSize': 30}) as Map;
      setState(() {
        _items = (data['items'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().startsWith('Exception:') ? e.toString().substring(10) : e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const SizedBox(
        height: 48,
        child: Row(children: [
          Expanded(child: PageSkeleton(itemCount: 0)),
          SizedBox(width: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        ]),
      );
    }
    if (_error != null) {
      return ErrorRetryView(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return EmptyStateView(
        icon: Icons.menu_book,
        title: '还没有错题',
        message: '先录入错题再来分析',
        actionLabel: '去录入',
        onAction: () => context.push('/scan'),
      );
    }
    return DropdownButtonFormField<int?>(
      value: widget.selected,
      decoration: const InputDecoration(

        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        for (final q in _items)
          DropdownMenuItem(
            value: q['id'] as int?,
            child: Text(
              '${(q['original_question'] ?? '').toString().length > 24 ? (q['original_question'] as String).substring(0, 24) : q['original_question']}…',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: widget.onSelect,
    );
  }
}
