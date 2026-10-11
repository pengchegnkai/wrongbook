/// models/auto_understand_result.dart —— AI 自动理解结果
class DetectedPart {
  final String type; // question | answer | analysis | unknown
  final String content;
  final double confidence;

  const DetectedPart({required this.type, required this.content, required this.confidence});

  bool get needsConfirm => confidence < 0.6;

  factory DetectedPart.fromJson(Map<String, dynamic> j) => DetectedPart(
        type: j['type'] ?? 'unknown',
        content: j['content'] ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

class AutoUnderstandResult {
  final List<DetectedPart> detectedParts;
  final String subject;
  final String questionType;
  final List<String> knowledgePoints;
  final bool uncertain;
  final bool needsConfirm;

  const AutoUnderstandResult({
    required this.detectedParts,
    required this.subject,
    required this.questionType,
    required this.knowledgePoints,
    required this.uncertain,
    required this.needsConfirm,
  });

  factory AutoUnderstandResult.fromJson(Map<String, dynamic> j) => AutoUnderstandResult(
        detectedParts: (j['detectedParts'] as List? ?? []).map((e) => DetectedPart.fromJson(e)).toList(),
        subject: j['subject'] ?? 'unknown',
        questionType: j['questionType'] ?? 'unknown',
        knowledgePoints: (j['knowledgePoints'] as List?)?.cast<String>() ?? [],
        uncertain: j['uncertain'] == true,
        needsConfirm: j['needsConfirm'] == true,
      );

  String? get questionText {
    final parts = detectedParts.where((p) => p.type == 'question').toList();
    return parts.isEmpty ? null : parts.map((p) => p.content).join('\n');
  }

  String? get answerText {
    final parts = detectedParts.where((p) => p.type == 'answer').toList();
    return parts.isEmpty ? null : parts.map((p) => p.content).join('\n');
  }
}
