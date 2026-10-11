/// widgets/ai_result_editor.dart —— AI 理解结果编辑器（分区确认）
import 'package:flutter/material.dart';

class AiResultEditor extends StatelessWidget {
  final List<AiPart> parts;
  final ValueChanged<int> onConfirmPart;   // 确认某分区
  final ValueChanged<int> onEditPart;      // 编辑某分区

  const AiResultEditor({
    super.key,
    required this.parts,
    required this.onConfirmPart,
    required this.onEditPart,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: parts.length,
      itemBuilder: (_, i) {
        final p = parts[i];
        final low = p.confidence < 0.6;
        return Card(
          color: low ? Colors.orange.withValues(alpha: 0.08) : null,
          child: ListTile(
            leading: Icon(low ? Icons.warning_amber : Icons.check_circle,
                color: low ? Colors.orange : Colors.green),
            title: Text('【${p.type}】${low ? '需人工确认' : ''}', style: const TextStyle(fontSize: 12)),
            subtitle: Text(p.content, maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => onEditPart(i)),
              IconButton(icon: const Icon(Icons.check, size: 18), onPressed: () => onConfirmPart(i)),
            ]),
          ),
        );
      },
    );
  }
}

class AiPart {
  final String type;
  final String content;
  final double confidence;
  const AiPart({required this.type, required this.content, required this.confidence});
}
