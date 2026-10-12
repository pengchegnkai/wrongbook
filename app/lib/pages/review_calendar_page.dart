/// pages/review_calendar_page.dart —— 今天/1天/3天/7天/15天分组
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/review_provider.dart';
import '../models/question.dart';

class ReviewCalendarPage extends ConsumerWidget {
  const ReviewCalendarPage({super.key});

  static const _groups = {'d1': '1 天后', 'd3': '3 天后', 'd7': '7 天后', 'd15': '15 天后'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(reviewTodayProvider);
    final upcoming = ref.watch(reviewUpcomingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('复习日历')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _group(context, '今天（${today.value?.length ?? 0}）', today.maybeWhen(data: (l) => l, orElse: () => [])),
        ..._groups.entries.map((e) => _group(context, e.value,
            upcoming.maybeWhen(data: (m) => m[e.key] ?? [], orElse: () => []))),
      ]),
    );
  }

  Widget _group(BuildContext context, String title, List<Question> items) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: items.isEmpty ? const Text('无') : Text(items.take(3).map((q) => q.originalQuestion).join(' / '), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: items.isEmpty ? null : Chip(label: Text('${items.length} 题')),
        onTap: items.isEmpty ? null : () => context.push('/review'),
      ),
    );
  }
}
