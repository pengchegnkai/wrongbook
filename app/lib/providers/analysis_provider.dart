/// providers/analysis_provider.dart —— AI 分析流程
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/analysis_log.dart';

class AnalysisState {
  final bool running;
  final bool streaming; // 流式进行中（UI 用纯文本展示，完成后切 Markdown）
  final String? response;
  final String? error;
  final int? logId;
  final String? strength;
  const AnalysisState({
    this.running = false,
    this.streaming = false,
    this.response,
    this.error,
    this.logId,
    this.strength,
  });
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  AnalysisNotifier() : super(const AnalysisState());

  /// 流式分析（打字机效果）：POST SSE → 逐 delta 更新 state。
  /// 流式响应持续有字节流动，经 Cloudflare 隧道也不会触发 100s 超时。
  /// 节流：UI 每 100ms 刷新一次（845 上 Markdown/文本重排有成本）。
  Future<void> analyzeStream({required int questionId, int? templateId, String? strength, String? extra}) async {
    state = const AnalysisState(running: true, streaming: true);
    String full = '';
    var lastFlush = DateTime.now();
    try {
      final api = ApiClient();
      api.ensureConfigured();
      final resp = await api.dio.post(
        '/ai/analyze-question-stream',
        data: {
          'questionId': questionId,
          if (templateId != null) 'templateId': templateId,
          if (strength != null) 'strength': strength,
          if (extra != null) 'extra': extra,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
      final byteStream = (resp.data as ResponseBody).stream;
      String buf = '';
      int? logId;
      String? effStrength;
      String? streamError;

      await for (final chunk in byteStream) {
        buf += utf8.decode(chunk, allowMalformed: true);
        final lines = buf.split('\n');
        buf = lines.removeLast();
        for (final line in lines) {
          final t = line.trim();
          if (!t.startsWith('data:')) continue;
          final payload = t.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') continue;
          try {
            final j = jsonDecode(payload) as Map;
            if (j['error'] != null) {
              streamError = j['error'].toString();
            } else if (j['done'] == true) {
              logId = j['logId'] as int?;
              effStrength = j['strength']?.toString();
              final finalText = j['response']?.toString();
              if (finalText != null && finalText.isNotEmpty) full = finalText;
            } else if (j['delta'] != null) {
              full += j['delta'].toString();
            }
          } catch (_) { /* 不完整行忽略 */ }
        }
        // 节流刷新
        final now = DateTime.now();
        if (now.difference(lastFlush).inMilliseconds >= 100 && mounted) {
          lastFlush = now;
          state = AnalysisState(running: true, streaming: true, response: full);
        }
      }
      if (streamError != null) throw Exception(streamError);
      if (full.isEmpty) throw Exception('模型未返回内容，请重试');
      state = AnalysisState(response: full, logId: logId, strength: effStrength);
    } catch (e) {
      // 部分内容已到：展示已收到的文本而不是全丢
      if (full.isNotEmpty) {
        state = AnalysisState(response: full, error: '连接中断：$e（已显示部分结果）');
      } else {
        state = AnalysisState(error: e.toString());
      }
    }
  }

  /// 异步轮询模式（保留为回退：流式失败时 UI 可提示切换）
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
