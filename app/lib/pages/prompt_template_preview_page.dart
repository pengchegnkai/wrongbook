/// pages/prompt_template_preview_page.dart —— 填变量 → 预览渲染结果
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prompt_template.dart';
import '../providers/prompt_template_provider.dart';

class PromptTemplatePreviewPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? template;
  const PromptTemplatePreviewPage({super.key, this.template});

  @override
  ConsumerState<PromptTemplatePreviewPage> createState() => _PromptTemplatePreviewPageState();
}

class _PromptTemplatePreviewPageState extends ConsumerState<PromptTemplatePreviewPage> {
  final _vars = <String, TextEditingController>{};
  bool _rendered = false;
  String _result = '';

  @override
  void initState() {
    super.initState();
    for (final v in kTemplateVariables) {
      _vars[v] = TextEditingController();
    }
  }

  Future<void> _preview() async {
    final id = widget.template?['id'];
    if (id == null) return;
    try {
      final svc = ref.read(promptTemplateServiceProvider);
      final result = await svc.preview(id, {
        for (final e in _vars.entries) e.key.replaceAll(RegExp(r'[{}]'), ''): e.value.text,
      });
      setState(() { _result = result; _rendered = true; });
    } catch (e) {
      setState(() => _result = '预览失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('预览：${widget.template?['name'] ?? ''}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final e in _vars.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(controller: e.value, decoration: InputDecoration(
              labelText: e.key, border: const OutlineInputBorder(), isDense: true)),
          ),
        FilledButton.icon(icon: const Icon(Icons.visibility), label: const Text('渲染预览'), onPressed: _preview),
        const SizedBox(height: 16),
        if (_rendered) Card(child: Padding(padding: const EdgeInsets.all(12), child: SelectableText(_result))),
      ]),
    );
  }
}
