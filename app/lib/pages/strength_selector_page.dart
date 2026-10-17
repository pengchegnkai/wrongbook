/// pages/strength_selector_page.dart —— 思考强度默认配置（按学科/题型）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/strength_provider.dart';
import '../providers/filter_provider.dart';

class StrengthSelectorPage extends ConsumerWidget {
  const StrengthSelectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strengths = ref.watch(strengthsProvider);
    final configs = ref.watch(strengthConfigProvider);
    final errorTypes = ['（全部题型）', ...kErrorTypes];

    return Scaffold(
      appBar: AppBar(title: const Text('思考强度设置')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('强度说明'),
        strengths.maybeWhen(
          data: (list) => Column(children: list.map((s) => ListTile(
            dense: true,
            title: Text('${s.name}（max_tokens=${s.maxTokens}，采样 ${s.sampleCount} 次）'),
            subtitle: Text(s.description, style: const TextStyle(fontSize: 11)),
          )).toList()),
          orElse: () => const Center(child: CircularProgressIndicator()),
        ),
        const Divider(height: 32),
        const Text('添加/更新一条默认配置'),
        strengths.maybeWhen(
          data: (list) => _ConfigForm(strengths: list, subjects: const []),
          orElse: () => const SizedBox(),
        ),
        const Divider(height: 32),
        const Text('现有配置'),
        configs.maybeWhen(
          data: (rows) => Column(children: rows.map((r) => ListTile(
            dense: true,
            title: Text('学科 ${r['subject'] ?? '全部'} / 题型 ${r['question_type'] ?? '全部'}'),
            subtitle: Text('默认强度: ${r['default_strength']}'),
          )).toList()),
          orElse: () => const SizedBox(),
        ),
        Text('题型选项参考：${errorTypes.join('、')}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  final List<dynamic> strengths;
  final List<String> subjects;
  const _ConfigForm({required this.strengths, required this.subjects});

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  String? _strength;
  String? _subject;
  String? _questionType;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      DropdownButtonFormField<String>(
        decoration: const InputDecoration(labelText: '默认强度'),
        value: _strength,
        items: widget.strengths.map((s) => DropdownMenuItem(value: s.id as String, child: Text(s.name as String))).toList(),
        onChanged: (v) => setState(() => _strength = v),
      ),
      const SizedBox(height: 8),
      TextField(decoration: const InputDecoration(labelText: '学科（可空）'),
        onChanged: (v) => _subject = v.isEmpty ? null : v),
      const SizedBox(height: 8),
      TextField(decoration: const InputDecoration(labelText: '题型（可空）'),
        onChanged: (v) => _questionType = v.isEmpty ? null : v),
      const SizedBox(height: 8),
      FilledButton(onPressed: _strength == null ? null : () async {
        await ref.read(strengthConfigSaveProvider)(_subject, _questionType, _strength!);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存，重启分析后生效')));
      }, child: const Text('保存配置')),
    ]);
  }
}
