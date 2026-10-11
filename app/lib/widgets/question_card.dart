/// widgets/question_card.dart —— 错题列表卡片
import 'package:flutter/material.dart';
import '../models/question.dart';

class QuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback? onTap;
  final ValueChanged<String>? onMasteryChanged;

  const QuestionCard({super.key, required this.question, this.onTap, this.onMasteryChanged});

  @override
  Widget build(BuildContext context) {
    final masteryColor = switch (question.mastery) {
      'red' => Colors.red,
      'yellow' => Colors.amber,
      _ => Colors.green,
    };
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 4, height: 16, color: masteryColor),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  question.originalQuestion,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                )),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                if (question.subjectName != null)
                  Padding(padding: const EdgeInsets.only(right: 8), child: Chip(
                    label: Text(question.subjectName!, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact)),
                if (question.errorType != null)
                  Text('错因：${question.errorType}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                if (question.answerSourceAuthority != null)
                  Text('来源 ${question.answerSourceAuthority} 级', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                Text(' · ${question.verificationStatus == 'verified' ? '已核验' : '待核验'}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
              if (onMasteryChanged != null)
                Align(alignment: Alignment.centerRight, child: PopupMenuButton<String>(
                  onSelected: onMasteryChanged,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'red', child: Text('🔴 未掌握')),
                    PopupMenuItem(value: 'yellow', child: Text('🟡 模糊')),
                    PopupMenuItem(value: 'green', child: Text('🟢 已掌握')),
                  ],
                  child: const Text('改掌握度', style: TextStyle(fontSize: 11)),
                )),
            ],
          ),
        ),
      ),
    );
  }
}
