/// widgets/source_badge.dart —— 来源可信度徽章（A/B/C）
import 'package:flutter/material.dart';

class SourceBadge extends StatelessWidget {
  final String authority;
  const SourceBadge({super.key, required this.authority});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (authority) {
      'A' => (Colors.green, 'A 级来源'),
      'B' => (Colors.blue, 'B 级来源'),
      _ => (Colors.grey, 'C 级来源'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
