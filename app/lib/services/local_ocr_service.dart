/// services/local_ocr_service.dart —— 端侧 OCR（ML Kit），中文+拉丁识别
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class LocalOcrService {
  final TextRecognizer _zh = TextRecognizer(script: TextRecognitionScript.chinese);

  /// 识别图片中的文字，返回全文与行级结果（供版面分析）
  Future<OcrResult> recognize(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _zh.processImage(input);
    final lines = <OcrLine>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        lines.add(OcrLine(
          text: line.text,
          boundingBox: line.boundingBox,
        ));
      }
    }
    final full = lines.map((l) => l.text).join('\n');
    return OcrResult(fullText: full, lines: lines);
  }

  Future<void> dispose() => _zh.close();
}

class OcrLine {
  final String text;
  final dynamic boundingBox; // Rect
  const OcrLine({required this.text, this.boundingBox});
}

class OcrResult {
  final String fullText;
  final List<OcrLine> lines;
  const OcrResult({required this.fullText, required this.lines});
}
