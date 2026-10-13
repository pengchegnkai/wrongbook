/// services/ocr_api_service.dart —— 服务端 OCR API（Termux Tesseract）
/// 图片上传到 POST /api/ocr/recognize，服务端识别并按题号切分。
/// 客户端不再做任何本地 OCR（彻底移除 ML Kit，规避原生插件生命周期崩溃）。
import 'dart:io';
import '../core/api_client.dart';

/// OCR 切出的一道题
class OcrQuestion {
  final String question;
  final String myAnswer;
  const OcrQuestion({required this.question, this.myAnswer = ''});

  factory OcrQuestion.fromJson(Map<String, dynamic> j) => OcrQuestion(
        question: j['question'] ?? '',
        myAnswer: j['myAnswer'] ?? '',
      );
}

/// OCR 识别结果
class OcrResult {
  final String rawText; // 原始识别全文
  final String lang; // 实际使用的语言（chi_sim+eng 或降级 eng）
  final List<OcrQuestion> questions; // 按题号切分
  const OcrResult({required this.rawText, required this.lang, required this.questions});
}

class OcrApiService {
  /// 上传图片并识别。表单字段名：image；服务端识别可能需数秒到数十秒。
  Future<OcrResult> recognize(String imagePath) async {
    final api = ApiClient();
    api.ensureConfigured();
    final ext = imagePath.split('.').last.toLowerCase();
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imagePath,
        filename: 'ocr_$DateTime.now().microsecondsSinceEpoch.${ext == 'jpeg' ? 'jpg' : ext}',
      ),
    });
    final r = await api.dio.post('/ocr/recognize', data: form);
    final body = r.data as Map<String, dynamic>;
    if ((body['code'] ?? 0) != 0) {
      throw Exception(body['message'] ?? 'OCR 识别失败');
    }
    final d = (body['data'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    return OcrResult(
      rawText: d['rawText'] ?? '',
      lang: d['lang'] ?? 'chi_sim+eng',
      questions: ((d['questions'] as List?) ?? const [])
          .map((e) => OcrQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 把 Dio/通用异常转成友好中文提示
String friendlyOcrError(Object e) {
  if (e is Exception && e.toString().startsWith('Exception:')) {
    final msg = e.toString().substring(10);
    if (msg.contains('OCR 服务不可用')) return msg;
    if (msg.contains('未配置')) return msg;
  }
  final s = e.toString();
  if (s.contains('connectionError') || s.contains('SocketException') || s.contains('Connection')) {
    return '无法连接服务器，请检查服务器地址与网络';
  }
  if (s.contains('Timeout') || s.contains('timeout')) {
    return '请求超时，请检查服务器是否在线（识别较慢也可能超时）';
  }
  if (s.contains('401') || s.contains('登录已过期')) {
    return '登录已过期，请重新登录';
  }
  if (s.contains('500') || s.contains('502') || s.contains('503')) {
    return '服务器繁忙或出错，请稍后重试';
  }
  return s.length > 120 ? '${s.substring(0, 120)}…' : s;
}
