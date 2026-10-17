/// pages/home_page.dart —— 首页仪表盘
/// 内容：总错题 / 学科数 / 掌握度分布 / 今日待复习 / 已核验·待核验 / 快捷入口
/// 布局：手机竖屏单列；平板或横屏（宽度 ≥ 900）左右分栏（左侧导航 + 右侧内容）
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/ui_states.dart';
import '../providers/stats_provider.dart';
import '../widgets/modern_card.dart';

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
                          const Expanded(child: _HomeContent()),
                        ],
                      )
                    : const _HomeContent(),
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
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(overviewStatsProvider);
    final weekly = ref.watch(weeklyStatsProvider);
    return stats.when(
      loading: () => const _FakeHomeContent(),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), // 底部让出毛玻璃导航栏
          children: [
            _OverviewCards(s: s),
            const SizedBox(height: 16),
            _MasteryRow(s: s),
            const SizedBox(height: 16),
            _WeeklyTrendCard(weekly: weekly),
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

/// 骨架屏假内容（与真实布局同构，skeletonizer 起来不跳变）
class _FakeHomeContent extends StatelessWidget {
  const _FakeHomeContent();

  @override
  Widget build(BuildContext context) {
    Widget fakeTile() => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.abc, size: 20),
              const SizedBox(height: 8),
              Text('888', style: Theme.of(context).textTheme.titleLarge),
              const Text('占位占位'),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(children: [
          for (var i = 0; i < 4; i++)
            Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: fakeTile())),
        ]),
        const SizedBox(height: 16),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }
}

/// 最近 7 天录入趋势（平滑曲线；数字用等宽字体）
class _WeeklyTrendCard extends ConsumerWidget {
  const _WeeklyTrendCard({required this.weekly});
  final AsyncValue<List<dynamic>> weekly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最近 7 天录入趋势', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: weekly.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(weeklyStatsProvider),
                  child: const Text('加载失败，点此重试', style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) return const Center(child: Text('暂无数据', style: TextStyle(fontSize: 12)));
                return LineChart(LineChartData(
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          (rows[v.toInt().clamp(0, rows.length - 1)]['day'] ?? '') as String,
                          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < rows.length; i++)
                          FlSpot(i.toDouble(), (rows[i]['n'] as num?)?.toDouble() ?? 0),
                      ],
                      isCurved: true,                       // 平滑曲线
                      curveSmoothness: 0.35,                // 845 上适度平滑，不过度采样
                      preventCurveOverShooting: true,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            scheme.primary.withValues(alpha: 0.25),
                            scheme.primary.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.tertiary],
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${s.y.toInt()}',
                            GoogleFonts.robotoMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ));
              },
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.robotoMono(
            fontSize: 22, fontWeight: FontWeight.bold, color: color)),
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
        borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
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
