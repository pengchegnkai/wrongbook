/// pages/home_page.dart —— 首页仪表盘
/// 内容：总错题 / 学科数 / 掌握度分布 / 今日待复习 / 已核验·待核验 / 快捷入口
/// 布局：手机竖屏单列；平板或横屏（宽度 ≥ 900）左右分栏（左侧导航 + 右侧内容）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/ui_states.dart';
import '../providers/stats_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const _entries = [
    (Icons.format_list_numbered, '错题列表', '/questions'),
    (Icons.school, '复习模式', '/review'),
    (Icons.camera_alt, '拍照录入', '/scan'),
    (Icons.auto_awesome, 'AI 分析', '/ai-analysis'),
    (Icons.bar_chart, '统计图表', '/charts'),
    (Icons.psychology, '提示词模板', '/prompt-templates'),
    (Icons.memory, 'AI 记忆', '/ai-memory'),
    (Icons.input, '导入导出', '/import-export'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: const Text('错题本'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: '设置',
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          SizedBox(width: 220, child: _NavPanel(onTap: (p) => context.push(p))),
                          const VerticalDivider(width: 1),
                          Expanded(child: _HomeContent(ref)),
                        ],
                      )
                    : _HomeContent(ref),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 平板/横屏左侧导航
class _NavPanel extends StatelessWidget {
  _NavPanel({required this.onTap});
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final e in HomePage._entries)
          ListTile(
            leading: Icon(e.$1, color: scheme.primary),
            title: Text(e.$2, style: const TextStyle(fontSize: 14)),
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onTap: () => onTap(e.$3),
          ),
      ],
    );
  }
}

/// 右侧/主内容区
class _HomeContent extends ConsumerWidget {
  _HomeContent(this.ref);
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final stats = ref.watch(overviewStatsProvider);
    return stats.when(
      loading: () => const PageSkeleton(itemCount: 4),
      error: (e, _) => ErrorRetryView(
        message: e.toString().startsWith('Exception:') ? e.toString().substring(10) : e.toString(),
        onRetry: () => ref.invalidate(overviewStatsProvider),
      ),
      data: (s) {
        if (s.total == 0) {
          return EmptyStateView(
            icon: Icons.menu_book,
            title: '还没有错题',
            message: '拍照或选图录入你的第一道错题，AI 帮你分析错因',
            actionLabel: '录入第一道错题',
            onAction: () => context.push('/scan'),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _OverviewCards(s: s),
            const SizedBox(height: 16),
            _MasteryRow(s: s),
            const SizedBox(height: 16),
            Text('快捷入口', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _EntryGrid(),
          ],
        );
      },
    );
  }
}

class _OverviewCards extends StatelessWidget {
  const _OverviewCards({required this.s});
  final dynamic s;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('总错题', '${s.total}', Icons.format_list_numbered, Colors.blue),
      ('今日复习', '${s.todayReview}', Icons.today, Colors.orange),
      ('学科', '${s.subjectCount}', Icons.school, Colors.green),
      ('已核验', '${s.verifiedSources}', Icons.verified, Colors.teal),
    ];
    return Row(
      children: [
        for (final it in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _StatTile(label: it.$1, value: it.$2, icon: it.$3, color: it.$4),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.s});
  final dynamic s;

  @override
  Widget build(BuildContext context) {
    final m = (s.mastery as Map?) ?? const {};
    final red = (m['red'] as num?)?.toInt() ?? 0;
    final yellow = (m['yellow'] as num?)?.toInt() ?? 0;
    final green = (m['green'] as num?)?.toInt() ?? 0;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('掌握度分布', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final seg in [(red, Colors.red), (yellow, Colors.orange), (green, Colors.green)])
                    if (seg.$1 > 0)
                      Expanded(flex: seg.$1, child: Container(color: seg.$2.withValues(alpha: 0.85))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Dot(color: Colors.red, label: '未掌握 $red'),
              const SizedBox(width: 16),
              _Dot(color: Colors.orange, label: '模糊 $yellow'),
              const SizedBox(width: 16),
              _Dot(color: Colors.green, label: '已掌握 $green'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _EntryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: [
        for (final e in HomePage._entries)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(e.$3),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(e.$1, size: 26, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(e.$2, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
