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

  Future<void> analyze({required int questionId, int? templateId, String? strength, String? extra}) async {
    state = const AnalysisState(running: true);
    try {
      final data = await ApiClient().post('/ai/analyze-question', body: {
        'questionId': questionId,
        if (templateId != null) 'templateId': templateId,
        if (strength != null) 'strength': strength,
        if (extra != null) 'extra': extra,
      }) as Map;
      state = AnalysisState(response: data['response'], logId: data['logId'], strength: data['strength']);
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
