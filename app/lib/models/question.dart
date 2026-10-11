/// models/question.dart
class Question {
  final int? id;
  final int? subjectId;
  final int? chapterId;
  final String source;
  final String? difficulty;
  final String originalQuestion;
  final String? myAnswer;
  final String? correctAnswer;
  final String? analysis;
  final String? answerSourceUrl;
  final String? answerSourceName;
  final String? answerSourceAuthority;
  final String verificationStatus;
  final String? aiGeneratedAnswer;
  final String? errorType;
  final String? errorReason;
  final String mastery; // red | yellow | green
  final bool reviewToday;
  final List<String> knowledgePoints;
  final String? subjectName;
  final String? chapterName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Question({
    this.id,
    this.subjectId,
    this.chapterId,
    this.source = 'manual',
    this.difficulty,
    required this.originalQuestion,
    this.myAnswer,
    this.correctAnswer,
    this.analysis,
    this.answerSourceUrl,
    this.answerSourceName,
    this.answerSourceAuthority,
    this.verificationStatus = 'unverified',
    this.aiGeneratedAnswer,
    this.errorType,
    this.errorReason,
    this.mastery = 'red',
    this.reviewToday = false,
    this.knowledgePoints = const [],
    this.subjectName,
    this.chapterName,
    this.createdAt,
    this.updatedAt,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'],
        subjectId: j['subject_id'],
        chapterId: j['chapter_id'],
        source: j['source'] ?? 'manual',
        difficulty: j['difficulty'],
        originalQuestion: j['original_question'] ?? '',
        myAnswer: j['my_answer'],
        correctAnswer: j['correct_answer'],
        analysis: j['analysis'],
        answerSourceUrl: j['answer_source_url'],
        answerSourceName: j['answer_source_name'],
        answerSourceAuthority: j['answer_source_authority'],
        verificationStatus: j['verification_status'] ?? 'unverified',
        aiGeneratedAnswer: j['ai_generated_answer'],
        errorType: j['error_type'],
        errorReason: j['error_reason'],
        mastery: j['mastery'] ?? 'red',
        reviewToday: j['review_today'] == true,
        knowledgePoints: (j['knowledge_points'] as List?)?.cast<String>() ?? [],
        subjectName: j['subject_name'],
        chapterName: j['chapter_name'],
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
        updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at']) : null,
      );

  Map<String, dynamic> toCreateJson() => {
        'originalQuestion': originalQuestion,
        'myAnswer': myAnswer,
        'correctAnswer': correctAnswer,
        'analysis': analysis,
        'subjectId': subjectId,
        'chapterId': chapterId,
        'errorType': errorType,
        'errorReason': errorReason,
        'mastery': mastery,
        'difficulty': difficulty,
        'source': source,
        'kpIds': [],
        'tags': [],
      };
}

/// 掌握度常量
const kMasteryRed = 'red';
const kMasteryYellow = 'yellow';
const kMasteryGreen = 'green';

String masteryLabel(String m) {
  switch (m) {
    case kMasteryRed: return '🔴 未掌握';
    case kMasteryYellow: return '🟡 模糊';
    case kMasteryGreen: return '🟢 已掌握';
    default: return m;
  }
}
