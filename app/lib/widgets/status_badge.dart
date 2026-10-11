/// widgets/status_badge.dart —— 状态徽章（核验状态/队列状态/服务状态）
import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final Map<String, (Color, String)>? mapping;

  const StatusBadge({super.key, required this.status, this.mapping});

  static const defaultMapping = {
    'verified': (Colors.green, '已核验'),
    'unverified': (Colors.grey, '待核验'),
    'invalid': (Colors.red, '核验无效'),
    'pending': (Colors.orange, '待处理'),
    'failed': (Colors.red, '失败'),
    'done': (Colors.green, '完成'),
    'searching': (Colors.blue, '搜索中'),
  };

  @override
  Widget build(BuildContext context) {
    final map = mapping ?? defaultMapping;
    final entry = map[status];
    final (color, label) = entry ?? (Colors.grey, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
