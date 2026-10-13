/// services/auto_understand_service.dart —— AI 自动理解原题与作答
/// App 端 OCR → 上传文本 → 服务端 LLM 分区 → 返回带 confidence 的草稿
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/auto_understand_result.dart';

class AutoUnderstandService {
  /// ocrText：OCR 得到的文本（当前来自服务端 /api/ocr/recognize）
  Future<AutoUnderstandResult> understand(String ocrText) async {
    final data = await ApiClient().post('/ai/understand-image', body: {'ocrText': ocrText});
    return AutoUnderstandResult.fromJson(data);
  }

  /// 如需直接传图片（本地模型非多模态时服务端会要求 ocrText，此方法备用）
  Future<AutoUnderstandResult> understandImage(File image, {String? ocrText}) async {
    final dio = ApiClient().dio;
    final form = FormData.fromMap({
      if (ocrText != null) 'ocrText': ocrText,
      'image': await MultipartFile.fromFile(image.path),
    });
    final r = await dio.post('/ai/understand-image', data: form);
    return AutoUnderstandResult.fromJson(r.data['data']);
  }

  /// 结果转错题草稿
  Map<String, dynamic> toQuestionDraft(AutoUnderstandResult result) {
    return {
      'originalQuestion': result.questionText ?? '',
      'myAnswer': result.answerText,
      'source': 'ai_understand',
      if (result.subject != 'unknown') 'subjectName': result.subject,
    };
  }
}

String encode(Object? o) => jsonEncode(o);
