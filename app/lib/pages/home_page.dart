/// pages/home_page.dart —— 首页仪表盘
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/stats_provider.dart';
import '../providers/local_record_provider.dart';
import '../providers/task_queue_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(overviewStatsProvider);
    final queue = ref.watch(queueStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('错题本'), actions: [
        IconButton(icon: const Icon(Icons.settings), onPressed: () => context.go('/settings')),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(overviewStatsProvider),
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(child: Text('加载失败：$e')),
            TextButton(onPressed: () => ref.invalidate(overviewStatsProvider), child: const Text('重试')),
          ]),
          data: (s) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: StatCard(title: '总错题', value: '${s.total}', color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(title: '学科数', value: '${s.subjectCount}', color: Colors.teal)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(title: '今日待复习', value: '${s.todayReview}', color: Colors.orange)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(title: '待处理队列', value: '${queue['pending']}/${queue['failed']}失败', color: Colors.purple)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(title: '🔴 未掌握', value: '${s.mastery['red'] ?? 0}', color: Colors.red)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: '🟡 模糊', value: '${s.mastery['yellow'] ?? 0}', color: Colors.amber)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: '🟢 已掌握', value: '${s.mastery['green'] ?? 0}', color: Colors.green)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(title: '已核验来源', value: '${s.verifiedSources}', color: Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(title: '待核验', value: '${s.pendingVerify}', color: Colors.grey)),
              ]),
              const SizedBox(height: 20),
              Wrap(spacing: 12, runSpacing: 12, children: [
                ActionChip(label: const Text('错题列表'), avatar: const Icon(Icons.list), onPressed: () => context.go('/questions')),
                ActionChip(label: const Text('复习'), avatar: const Icon(Icons.school), onPressed: () => context.go('/review')),
                ActionChip(label: const Text('拍照录题'), avatar: const Icon(Icons.camera_alt), onPressed: () => context.go('/scan')),
                ActionChip(label: const Text('AI 分析'), avatar: const Icon(Icons.psychology), onPressed: () => context.go('/prompt-templates')),
                ActionChip(label: const Text('图表'), avatar: const Icon(Icons.bar_chart), onPressed: () => context.go('/charts')),
                ActionChip(label: const Text('知识点图谱'), avatar: const Icon(Icons.account_tree), onPressed: () => context.go('/knowledge-graph')),
                ActionChip(label: const Text('复习日历'), avatar: const Icon(Icons.calendar_month), onPressed: () => context.go('/review-calendar')),
                ActionChip(label: const Text('导入导出'), avatar: const Icon(Icons.import_export), onPressed: () => context.go('/import-export')),
                ActionChip(label: const Text('AI 记忆'), avatar: const Icon(Icons.memory), onPressed: () => context.go('/ai-memory')),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
