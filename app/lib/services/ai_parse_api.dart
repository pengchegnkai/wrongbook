/// services/ai_parse_api.dart —— 双引擎图片解析 API 封装
/// POST /api/ai/parse-image（multipart：image + mode）
/// mode=ocr    极速（5-10s）：tesseract + 文本 LLM 纠错
/// mode=vision 深度（30-120s）：多模态 Base64 视觉理解
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class ParseResult {
  final String engine; // 'ocr' | 'vision'
  final String subject;
  final String question;
  final String myAnswer;
  final String? rawText; // 仅 ocr 模式
  final bool corrected; // 仅 ocr 模式：LLM 是否纠错成功
  final List<String> extraQuestions; // 仅 ocr 模式：识别出的其他题
  const ParseResult({
    required this.engine,
    required this.subject,
    required this.question,
    required this.myAnswer,
    this.rawText,
    this.corrected = false,
    this.extraQuestions = const [],
  });
}

class AiParseApi {
  /// 解析图片。vision 模式超时给足 4 分钟（纯 CPU 多模态较慢）。
  static Future<ParseResult> parse({
    required String imagePath,
    required String mode, // 'ocr' | 'vision'
  }) async {
    final api = ApiClient();
    api.ensureConfigured();
    final isVision = mode == 'vision';
    try {
      final form = FormData.fromMap({
        'mode': mode,
        'image': await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split('/').last,
        ),
      });
      final r = await api.dio.post('/ai/parse-image', data: form,
          options: Options(
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: isVision
                ? const Duration(minutes: 4)
                : const Duration(seconds: 90),
          ));
      final d = r.data['data'] as Map;
      return ParseResult(
        engine: (d['engine'] ?? mode).toString(),
        subject: (d['subject'] ?? '').toString(),
        question: (d['question'] ?? '').toString(),
        myAnswer: (d['myAnswer'] ?? '').toString(),
        rawText: d['rawText']?.toString(),
        corrected: d['corrected'] == true,
        extraQuestions: [
          for (final q in (d['extraQuestions'] as List? ?? []))
            ((q as Map)['question'] ?? '').toString(),
        ].where((s) => s.isNotEmpty).toList(),
      );
    } on DioException catch (e) {
      // 501 = 视觉引擎不可用（当前模型无 --mmproj），后端 message 已是行动指引
      throw ApiClient.friendly(e);
    }
  }

  /// 把校对结果保存为新错题（字段与 OCR 校对页一致）
  static Future<void> saveQuestion({
    required String question,
    required String myAnswer,
    required String source,
  }) async {
    await ApiClient().post('/questions', body: {
      'originalQuestion': question,
      'myAnswer': myAnswer.trim().isEmpty ? null : myAnswer.trim(),
      'source': source, // 'ocr' | 'vision'
    });
  }
}
