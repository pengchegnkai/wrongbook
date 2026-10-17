/// pages/ai_profile_page.dart —— AI 学习画像查看与编辑
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_memory_provider.dart';
import '../models/user_ai_memory.dart';

class AiProfilePage extends ConsumerStatefulWidget {
  const AiProfilePage({super.key});

  @override
  ConsumerState<AiProfilePage> createState() => _AiProfilePageState();
}

class _AiProfilePageState extends ConsumerState<AiProfilePage> {
  final _goal = TextEditingController();

  @override
  Widget build(BuildContext context, ) {
    final profile = ref.watch(aiProfileProvider);
    final actions = ref.watch(aiMemoryActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 学习画像'), actions: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: '从错题统计刷新', onPressed: () async {
          await ref.watch(aiMemoryServiceProvider).refreshProfile();
          ref.invalidate(aiProfileProvider);
        }),
      ]),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (AiProfile? p) => ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('薄弱学科', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(children: [if ((p?.weakSubjects.isEmpty ?? true)) const Text('暂无') else ...p!.weakSubjects.map((s) => Chip(label: Text(s)))]),
              const SizedBox(height: 8),
              const Text('常见错因', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(children: [if ((p?.commonErrorTypes.isEmpty ?? true)) const Text('暂无') else ...p!.commonErrorTypes.map((s) => Chip(label: Text(s)))]),
              const SizedBox(height: 8),
              Text('偏好解释风格：${p?.preferredExplanationStyle ?? '-'}'),
              Text('偏好思考强度：${p?.preferredStrength ?? '-'}'),
            ],
          ))),
          const SizedBox(height: 16),
          TextField(controller: _goal..text = p?.learningGoal ?? '',
            maxLines: 3, decoration: const InputDecoration(labelText: '学习目标（会影响 AI 分析口吻）')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '解释风格'),
            value: p?.preferredExplanationStyle,
            items: const [
              DropdownMenuItem(value: 'step_by_step', child: Text('分步讲解')),
              DropdownMenuItem(value: 'concise', child: Text('简洁')),
              DropdownMenuItem(value: 'detailed', child: Text('详尽推导')),
              DropdownMenuItem(value: 'exam_oriented', child: Text('应试导向')),
            ],
            onChanged: (_) {},
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () async {
            await actions.saveProfile(goal: _goal.text);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
          }, child: const Text('保存画像')),
        ]),
      ),
    );
  }
}
