/// providers/analysis_provider.dart —— AI 分析流程
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/analysis_log.dart';

class AnalysisState {
  final bool running;
  final String? response;
  final String? error;
  final int? logId;
  final String? strength;
  const AnalysisState({this.running = false, this.response, this.error, this.logId, this.strength});
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  AnalysisNotifier() : super(const AnalysisState());

  /// 异步分析：POST(async:true) 立即拿 logId → 每 3 秒轮询状态直到完成。
  /// 背景：经 Cloudflare 免费版隧道时源站响应约 100s 超时，长分析必须异步。
  Future<void> analyze({required int questionId, int? templateId, String? strength, String? extra}) async {
    state = const AnalysisState(running: true);
    try {
      final data = await ApiClient().post('/ai/analyze-question', body: {
        'questionId': questionId,
        'async': true,
        if (templateId != null) 'templateId': templateId,
        if (strength != null) 'strength': strength,
        if (extra != null) 'extra': extra,
      }) as Map;
      final logId = data['logId'] as int?;
      if (logId == null) throw Exception('服务端未返回任务 ID');
      // 轮询（最长 20 分钟；每次轮询都是短响应，不受代理超时限制）
      final deadline = DateTime.now().add(const Duration(minutes: 20));
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(seconds: 3));
        final st = await ApiClient().get('/ai/analysis-status/$logId') as Map;
        final status = st['status'] as String?;
        if (status == 'done') {
          state = AnalysisState(
            response: st['response'] as String?,
            logId: logId,
            strength: st['strength'] as String?,
          );
          return;
        }
        if (status == 'error') {
          throw Exception(st['response'] ?? '分析执行失败');
        }
        // running：继续轮询（UI 的"已用时"由页面 ticker 显示）
      }
      throw Exception('分析超时（20 分钟）。结果可能稍后完成，可在"分析历史"查看');
    } catch (e) {
      state = AnalysisState(error: e.toString());
    }
  }

  void reset() => state = const AnalysisState();
}

final analysisProvider = StateNotifierProvider<AnalysisNotifier, AnalysisState>((ref) => AnalysisNotifier());

final analysisHistoryProvider = FutureProvider<List<AnalysisLog>>((ref) async {
  final data = await ApiClient().get('/ai/analysis-logs') as List;
  return data.map((e) => AnalysisLog.fromJson(e)).toList();
});

final analysisLogDetailProvider = FutureProvider.family<AnalysisLog, int>((ref, id) async {
  final data = await ApiClient().get('/ai/analysis-logs/$id');
  return AnalysisLog.fromJson(data);
});
