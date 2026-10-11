/// providers/local_model_provider.dart —— 本地模型选择与管理
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../inference/inference_engine_factory.dart';
import '../inference/local_inference_engine.dart';
import '../inference/model_info.dart';
import '../core/local_model_config.dart';

final inferenceEngineProvider = Provider<LocalInferenceEngine>((ref) {
  return InferenceEngineFactory.create();
});

/// 已下载模型清单（初始为出厂默认；下载后标记）
final modelListProvider = StateNotifierProvider<ModelListNotifier, List<ModelInfo>>((ref) {
  return ModelListNotifier();
});

class ModelListNotifier extends StateNotifier<List<ModelInfo>> {
  ModelListNotifier() : super(kDefaultModels.map((c) => ModelInfo(
        id: c.id, fileName: c.fileName, displayName: c.displayName,
        sizeBytes: c.sizeBytes, sha256: c.sha256, role: c.role,
      )).toList());

  void markDownloaded(String id, {int? sizeBytes, String? sha256}) {
    state = [
      for (final m in state)
        if (m.id == id)
          ModelInfo(id: m.id, fileName: m.fileName, displayName: m.displayName,
              sizeBytes: sizeBytes ?? m.sizeBytes, sha256: sha256 ?? m.sha256,
              role: m.role, downloaded: true)
        else m
    ];
  }

  void markDeleted(String id) {
    state = [
      for (final m in state)
        if (m.id == id)
          ModelInfo(id: m.id, fileName: m.fileName, displayName: m.displayName,
              sizeBytes: m.sizeBytes, sha256: m.sha256, role: m.role, downloaded: false)
        else m
    ];
  }
}

/// 当前选用模型
final selectedModelProvider = StateProvider<String?>((ref) => null);

/// 模型服务可用性
final modelAvailabilityProvider = FutureProvider<bool>((ref) async {
  final engine = ref.watch(inferenceEngineProvider);
  return engine.isAvailable();
});
