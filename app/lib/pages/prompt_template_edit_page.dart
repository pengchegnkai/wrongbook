/// pages/prompt_template_edit_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/prompt_template_provider.dart';
import '../models/prompt_template.dart';

class PromptTemplateEditPage extends ConsumerStatefulWidget {
  final Map<String, dynamic>? template;
  const PromptTemplateEditPage({super.key, this.template});

  @override
  ConsumerState<PromptTemplateEditPage> createState() => _PromptTemplateEditPageState();
}

class _PromptTemplateEditPageState extends ConsumerState<PromptTemplateEditPage> {
  final _name = TextEditingController();
  final _content = TextEditingController();
  final _subjectCtrl = TextEditingController();
  String? _subject;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    if (t != null) {
      _name.text = t['name'] ?? '';
      _content.text = t['templateContent'] ?? t['template_content'] ?? '';
      _subject = t['subject'];
      _subjectCtrl.text = _subject ?? '';
      _isDefault = t['isDefault'] == true || t['is_default'] == true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.template == null ? '新建模板' : '编辑模板')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: '模板名称')),
        const SizedBox(height: 12),
        TextField(controller: _content, maxLines: 10, decoration: const InputDecoration(
          labelText: '模板内容', alignLabelWithHint: true)),
        const SizedBox(height: 8),
        const Text('可用变量：', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Wrap(children: [
          for (final v in kTemplateVariables)
            Padding(padding: const EdgeInsets.all(2), child: Chip(label: Text(v, style: const TextStyle(fontSize: 10)))),
        ]),
        const SizedBox(height: 12),
        TextField(decoration: const InputDecoration(labelText: '适用学科（可空=通用）'),
          onChanged: (v) => _subject = v.isEmpty ? null : v, controller: _subjectCtrl),
        SwitchListTile(title: const Text('设为默认模板'), value: _isDefault, onChanged: (v) => setState(() => _isDefault = v)),
        const SizedBox(height: 8),
        FilledButton(onPressed: () async {
          if (_name.text.trim().isEmpty || _content.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名称与内容必填')));
            return;
          }
          final t = PromptTemplate(
            id: widget.template?['id'],
            name: _name.text.trim(),
            subject: _subject,
            templateContent: _content.text,
            isDefault: _isDefault,
          );
          try {
            await ref.read(templateSaveProvider)(t);
            if (mounted) context.pop();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
            }
          }
        }, child: const Text('保存')),
      ]),
    );
  }
}
