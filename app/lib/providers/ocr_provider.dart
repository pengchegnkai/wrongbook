/// providers/ocr_provider.dart —— OCR 流程状态（服务端 OCR：上传图片 → Termux Tesseract 识别）
/// 客户端不再做本地识别，只做「上传 → 展示 → 校对 → 保存」。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ocr_api_service.dart';

enum OcrStage { idle, uploading, done, error }

class OcrState {
  final OcrStage stage;
  final OcrResult? result;
  final String? error;
  final String? imagePath;
  const OcrState({this.stage = OcrStage.idle, this.result, this.error, this.imagePath});
}

class OcrNotifier extends StateNotifier<OcrState> {
  final OcrApiService _service = OcrApiService();
  OcrNotifier() : super(const OcrState());

  /// 上传识别。重复调用会覆盖旧状态。
  Future<void> recognize(String imagePath) async {
    state = OcrState(stage: OcrStage.uploading, imagePath: imagePath);
    try {
      final result = await _service.recognize(imagePath);
      if (result.rawText.isEmpty) {
        state = OcrState(
          stage: OcrStage.error,
          imagePath: imagePath,
          error: '未识别到文字。请确认图片清晰、文字在画面主体位置后重试',
        );
        return;
      }
      state = OcrState(stage: OcrStage.done, result: result, imagePath: imagePath);
    } catch (e) {
      state = OcrState(stage: OcrStage.error, imagePath: imagePath, error: friendlyOcrError(e));
    }
  }

  /// 重试（用同一张图重新上传）
  Future<void> retry() async {
    final path = state.imagePath;
    if (path == null) return;
    await recognize(path);
  }

  void reset() => state = const OcrState();
}

final ocrProvider = StateNotifierProvider<OcrNotifier, OcrState>((ref) => OcrNotifier());
