/// pages/prompt_template_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/prompt_template_provider.dart';

class PromptTemplateListPage extends ConsumerWidget {
  const PromptTemplateListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(promptTemplatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('提示词模板'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => context.push('/prompt-templates/edit')),
      ]),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('暂无模板，点右上角新建'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final t = list[i];
                  return Card(
                    child: ListTile(
                      title: Row(children: [
                        Expanded(child: Text(t.name)),
                        if (t.isDefault) const Chip(label: Text('默认', style: TextStyle(fontSize: 10))),
                      ]),
                      subtitle: Text('学科: ${t.subject ?? '通用'} · ${t.templateContent.length} 字', style: const TextStyle(fontSize: 11)),
                      onTap: () => context.push('/prompt-templates/preview', extra: {'template': t.toJson()}),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          final svc = ref.read(promptTemplateServiceProvider);
                          if (v == 'edit') {
                            context.push('/prompt-templates/edit', extra: {'template': t.toJson()});
                          } else if (v == 'duplicate') {
                            if (t.id != null) await svc.duplicate(t.id!);
                            ref.invalidate(promptTemplatesProvider);
                          } else if (v == 'default') {
                            if (t.id != null) await svc.update(t.id!, t.copyWithDefault());
                            ref.invalidate(promptTemplatesProvider);
                          } else if (v == 'delete') {
                            if (t.id != null) await svc.delete(t.id!);
                            ref.invalidate(promptTemplatesProvider);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(value: 'duplicate', child: Text('复制')),
                          PopupMenuItem(value: 'default', child: Text('设为默认')),
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
}
