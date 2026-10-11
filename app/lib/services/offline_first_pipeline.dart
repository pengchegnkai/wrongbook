/// services/offline_first_pipeline.dart —— 离线优先管线
/// 录入流程：本地 OCR+解析 → 生成草稿 → 用户校对 → 保存：
///   有网：直接 POST /questions；
///   无网：入本地队列，联网后由 SyncService 推送。
import 'dart:io';
import '../models/question.dart';
import '../core/api_client.dart';
import 'local_ocr_service.dart';
import 'image_preprocessor.dart';
import 'local_question_parser.dart';
import 'task_queue_service.dart';

class OfflineFirstPipeline {
  final LocalOcrService _ocr = LocalOcrService();
  final ImagePreprocessor _pre = ImagePreprocessor();
  final LocalQuestionParser _parser = LocalQuestionParser();
  final TaskQueueService _queue = TaskQueueService();

  /// 步骤 1：图片 → 草稿（离线可用）
  Future<ParsedDraft> draftFromImage(File image) async {
    final preprocessed = await _pre.preprocess(image);
    final ocr = await _ocr.recognize(preprocessed.path);
    return _parser.parse(ocr);
  }

  /// 步骤 2：保存错题（在线直发，离线入队）
  Future<bool> saveQuestion(Question q, {required bool online}) async {
    if (online) {
      try {
        await ApiClient().post('/questions', body: q.toCreateJson());
        return true;
      } catch (_) {
        // 网络失败降级入队
      }
    }
    await _queue.enqueue({
      'action': 'create_question',
      'payload': q.toCreateJson(),
    });
    return false; // 已入队待同步
  }
}
