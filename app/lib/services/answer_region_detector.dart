/// services/answer_region_detector.dart —— 作答区起点检测规则
enum ScriptType { printed, handwritten, unknown }

class AnswerRegionDetector {
  /// 命中以下模式即认为进入作答区
  final List<RegExp> _patterns = [
    RegExp(r'^(解|答|证明|略解)[：:]'),
    RegExp(r'^(我的答案|我的作答|答案)[：:]'),
    RegExp(r'^(所以|因此|可得|故|即)[，,]'), // 常见解题开头（弱信号，需配合上文）
  ];

  bool isAnswerStart(String line) {
    return _patterns.any((p) => p.hasMatch(line));
  }

  /// 是否疑似题目行（题号开头）
  bool isQuestionLine(String line) {
    return RegExp(r'^(\d{1,2}[.、．]|[（(]\d{1,2}[)）])').hasMatch(line.trim());
  }
}
