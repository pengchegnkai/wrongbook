/// services/question_answer_pairing.dart —— 原题/作答配对整理
class QuestionAnswerPairing {
  /// 去掉 OCR 常见噪声：多余空格、断行连字、页码
  static String normalize(String raw) {
    return raw
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\\s+'), ' ').trim())
        .where((l) => l.isNotEmpty && !RegExp(r'^第\s*\d+\s*页').hasMatch(l))
        .join('\n');
  }

  /// 把"我的作答"与"正确答案"配对成草稿
  static DraftPair pairDraft({required String originalQuestion, String? myAnswer, String? correctAnswer}) {
    return DraftPair(
      originalQuestion: normalize(originalQuestion),
      myAnswer: myAnswer == null || myAnswer.isEmpty ? null : normalize(myAnswer),
      correctAnswer: correctAnswer == null || correctAnswer.isEmpty ? null : normalize(correctAnswer),
    );
  }
}

class DraftPair {
  final String originalQuestion;
  final String? myAnswer;
  final String? correctAnswer;
  const DraftPair({required this.originalQuestion, this.myAnswer, this.correctAnswer});
}
