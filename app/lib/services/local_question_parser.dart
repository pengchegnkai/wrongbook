/// services/local_question_parser.dart —— 本地版面分析：把 OCR 行分为题目/作答区域
/// 规则优先（不依赖模型）：
/// - 含"解：""答："或冒号结尾短行 → 作答区起点
/// - 题号（1. 2. （1））→ 题目行
/// - 手写/印刷分类：本地无可靠特征，默认 unknown，交给 AI understand-image 复核
import 'local_ocr_service.dart';
import 'answer_region_detector.dart';
import 'question_answer_pairing.dart';

class LocalQuestionParser {
  final AnswerRegionDetector _regionDetector = AnswerRegionDetector();

  ParsedDraft parse(OcrResult ocr) {
    final questionLines = <String>[];
    final answerLines = <String>[];
    bool inAnswer = false;

    for (final line in ocr.lines) {
      final t = line.text.trim();
      if (t.isEmpty) continue;
      if (!inAnswer && _regionDetector.isAnswerStart(t)) {
        inAnswer = true;
      }
      if (inAnswer) {
        answerLines.add(t);
      } else {
        questionLines.add(t);
      }
    }

    final question = QuestionAnswerPairing.normalize(questionLines.join('\n'));
    final answer = answerLines.join('\n');

    return ParsedDraft(
      originalQuestion: question,
      myAnswer: answer.isEmpty ? null : answer,
      scriptType: ScriptType.unknown, // 印刷/手写分类：本地不确定，交给 AI 分区
      uncertain: question.isEmpty || answer.isEmpty,
    );
  }
}

class ParsedDraft {
  final String originalQuestion;
  final String? myAnswer;
  final ScriptType scriptType;
  final bool uncertain;

  const ParsedDraft({
    required this.originalQuestion,
    this.myAnswer,
    required this.scriptType,
    required this.uncertain,
  });
}
