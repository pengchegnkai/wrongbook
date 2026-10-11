/// pages/charts_page.dart —— 饼图/柱状图/环形图/折线图（fl_chart）
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_provider.dart';

class ChartsPage extends ConsumerWidget {
  const ChartsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = ref.watch(errorsStatsProvider);
    final mastery = ref.watch(masteryStatsProvider);
    final weekly = ref.watch(weeklyStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('统计图表')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('错因分布（柱状图）'),
          SizedBox(height: 200, child: errors.maybeWhen(
            data: (rows) => rows.isEmpty
                ? const Center(child: Text('暂无数据'))
                : BarChart(BarChartData(
                    barGroups: [
                      for (var i = 0; i < rows.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(toY: (rows[i]['n'] as int?)?.toDouble() ?? 0, width: 16)
                        ]),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, getTitlesWidget: (v, _) => Text(
                          (rows[v.toInt()]['error_type'] ?? '') as String,
                          style: const TextStyle(fontSize: 9))),
                      ),
                    ),
                  )),
            orElse: () => const Center(child: CircularProgressIndicator()),
          )),
          const Divider(height: 32),
          const Text('掌握度分布（环形图）'),
          SizedBox(height: 200, child: mastery.maybeWhen(
            data: (rows) => rows.isEmpty
                ? const Center(child: Text('暂无数据'))
                : PieChart(PieChartData(sections: [
                    for (final r in rows)
                      PieChartSectionData(
                        value: (r['n'] as num).toDouble(),
                        title: '${r['mastery']}',
                        color: r['mastery'] == 'red' ? Colors.red : r['mastery'] == 'yellow' ? Colors.amber : Colors.green,
                      ),
                  ], centerSpaceRadius: 48)),
            orElse: () => const Center(child: CircularProgressIndicator()),
          )),
          const Divider(height: 32),
          const Text('近 7 天录入趋势（折线图）'),
          SizedBox(height: 200, child: weekly.maybeWhen(
            data: (rows) => rows.isEmpty
                ? const Center(child: Text('暂无数据'))
                : LineChart(LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < rows.length; i++)
                            FlSpot(i.toDouble(), (rows[i]['n'] as num).toDouble()),
                        ],
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, getTitlesWidget: (v, _) => Text(
                          (rows[v.toInt()]['day'] ?? '') as String, style: const TextStyle(fontSize: 9))),
                      ),
                    ),
                  )),
            orElse: () => const Center(child: CircularProgressIndicator()),
          )),
        ],
      ),
    );
  }
}
