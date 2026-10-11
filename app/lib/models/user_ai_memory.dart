/// models/user_ai_memory.dart
class UserAiMemory {
  final int id;
  final String memoryType;
  final String key;
  final String value;
  final double? confidence;
  final String? source;
  final int hitCount;
  final DateTime? updatedAt;

  const UserAiMemory({
    required this.id,
    required this.memoryType,
    required this.key,
    required this.value,
    this.confidence,
    this.source,
    this.hitCount = 0,
    this.updatedAt,
  });

  factory UserAiMemory.fromJson(Map<String, dynamic> j) => UserAiMemory(
        id: j['id'],
        memoryType: j['memory_type'] ?? '',
        key: j['key'] ?? '',
        value: j['value'] ?? '',
        confidence: (j['confidence'] as num?)?.toDouble(),
        source: j['source'],
        hitCount: j['hit_count'] ?? 0,
        updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
      );
}

class AiProfile {
  final String? preferredStrength;
  final String? preferredExplanationStyle;
  final List<String> weakSubjects;
  final List<String> commonErrorTypes;
  final String? learningGoal;

  const AiProfile({
    this.preferredStrength,
    this.preferredExplanationStyle,
    this.weakSubjects = const [],
    this.commonErrorTypes = const [],
    this.learningGoal,
  });

  factory AiProfile.fromJson(Map<String, dynamic> j) => AiProfile(
        preferredStrength: j['preferred_strength'],
        preferredExplanationStyle: j['preferred_explanation_style'],
        weakSubjects: (j['weak_subjects'] as List?)?.cast<String>() ?? [],
        commonErrorTypes: (j['common_error_types'] as List?)?.cast<String>() ?? [],
        learningGoal: j['learning_goal'],
      );
}
