/// pages/ai_memory_page.dart —— 查看/编辑/删除 AI 记忆
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_memory_provider.dart';

class AiMemoryPage extends ConsumerWidget {
  const AiMemoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(aiMemoriesProvider);
    final actions = ref.watch(aiMemoryActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 记忆'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => _addDialog(context, actions)),
      ]),
      body: memories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('暂无记忆。反馈分析结果或复习会自动生成记忆'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final m = list[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(m.source == 'explicit' ? Icons.touch_app : Icons.auto_awesome,
                          color: m.memoryType == 'weak_signal' ? Colors.red : Colors.blue),
                      title: Text(m.key, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${m.value}\n置信度 ${((m.confidence ?? 0) * 100).toStringAsFixed(0)}% · 命中 ${m.hitCount} 次 · 来源 ${m.source ?? '-'}',
                          style: const TextStyle(fontSize: 11)),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            final ctrl = TextEditingController(text: m.value);
                            final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                              title: const Text('编辑记忆'),
                              content: TextField(controller: ctrl, maxLines: 3),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
                              ],
                            ));
                            if (ok == true) await actions.update(m.id, value: ctrl.text);
                          } else if (v == 'delete') {
                            await actions.delete(m.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _addDialog(BuildContext context, AiMemoryActions actions) {
    final type = TextEditingController(text: 'preference');
    final key = TextEditingController();
    final value = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('新增记忆'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: type, decoration: const InputDecoration(labelText: '类型（preference/weak_signal）')),
        TextField(controller: key, decoration: const InputDecoration(labelText: '键')),
        TextField(controller: value, decoration: const InputDecoration(labelText: '内容')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () async {
          await actions.create(type.text, key.text, value.text);
          if (context.mounted) Navigator.pop(context);
        }, child: const Text('保存')),
      ],
    ));
  }
}
