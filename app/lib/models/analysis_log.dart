/// models/analysis_log.dart
class AnalysisLog {
  final int id;
  final int? questionId;
  final String? model;
  final String? strength;
  final int? durationMs;
  final int? totalTokens;
  final DateTime? createdAt;
  final String? renderedPrompt;
  final String? aiResponse;

  const AnalysisLog({
    required this.id,
    this.questionId,
    this.model,
    this.strength,
    this.durationMs,
    this.totalTokens,
    this.createdAt,
    this.renderedPrompt,
    this.aiResponse,
  });

  factory AnalysisLog.fromJson(Map<String, dynamic> j) => AnalysisLog(
        id: j['id'],
        questionId: j['question_id'],
        model: j['model'],
        strength: j['strength'],
        durationMs: j['duration_ms'],
        totalTokens: j['total_tokens'],
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
        renderedPrompt: j['rendered_prompt'],
        aiResponse: j['ai_response'],
      );
}

/// 思考强度
class Strength {
  final String id;
  final String name;
  final int maxTokens;
  final int sampleCount;
  final String description;

  const Strength({required this.id, required this.name, required this.maxTokens, required this.sampleCount, required this.description});

  factory Strength.fromJson(Map<String, dynamic> j) => Strength(
        id: j['id'], name: j['name'], maxTokens: j['maxTokens'] ?? 512,
        sampleCount: j['sampleCount'] ?? 1, description: j['description'] ?? '',
      );
}
