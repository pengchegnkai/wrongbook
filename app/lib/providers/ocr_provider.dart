/// providers/ocr_provider.dart —— OCR 流程状态
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_first_pipeline.dart';
import '../services/local_question_parser.dart';

enum OcrStage { idle, preprocessing, recognizing, parsing, done, error }

class OcrState {
  final OcrStage stage;
  final ParsedDraft? draft;
  final String? error;
  const OcrState({this.stage = OcrStage.idle, this.draft, this.error});
}

class OcrNotifier extends StateNotifier<OcrState> {
  final OfflineFirstPipeline _pipeline = OfflineFirstPipeline();

  OcrNotifier() : super(const OcrState());

  Future<void> processImage(File image) async {
    state = const OcrState(stage: OcrStage.recognizing);
    try {
      final draft = await _pipeline.draftFromImage(image);
      state = OcrState(stage: OcrStage.done, draft: draft);
    } catch (e) {
      state = OcrState(stage: OcrStage.error, error: e.toString());
    }
  }

  void reset() => state = const OcrState();
}

final ocrProvider = StateNotifierProvider<OcrNotifier, OcrState>((ref) => OcrNotifier());
