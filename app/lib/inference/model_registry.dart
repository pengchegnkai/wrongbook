/// inference/model_registry.dart —— 模型注册表：出厂默认 + 用户补充（2026-10 更新）
import '../core/local_model_config.dart';
import 'model_info.dart';

class ModelRegistry {
  final List<ModelInfo> _models = kDefaultModels
      .map((c) => ModelInfo(
            id: c.id,
            fileName: c.fileName,
            displayName: c.displayName,
            sizeBytes: c.sizeBytes,
            sha256: c.sha256,
            downloadUrl: c.downloadUrl,
            role: c.role,
          ))
      .toList();

  List<ModelInfo> get all => List.unmodifiable(_models);

  void markDownloaded(String id, {int? sizeBytes, String? sha256}) {
    final i = _models.indexWhere((m) => m.id == id);
    if (i >= 0) {
      _models[i] = ModelInfo(
        id: _models[i].id,
        fileName: _models[i].fileName,
        displayName: _models[i].displayName,
        sizeBytes: sizeBytes ?? _models[i].sizeBytes,
        sha256: sha256 ?? _models[i].sha256,
        downloadUrl: _models[i].downloadUrl,
        role: _models[i].role,
        downloaded: true,
      );
    }
  }

  ModelInfo? byId(String id) {
    for (final m in _models) {
      if (m.id == id) return m;
    }
    return null;
  }
}
