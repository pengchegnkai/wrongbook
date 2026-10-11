/// inference/model_info.dart（2026-10 更新：增加 downloadUrl 可选字段）
class ModelInfo {
  final String id;
  final String fileName;
  final String displayName;
  final int? sizeBytes;
  final String? sha256;
  final String? downloadUrl; // 可下载模型的 URL，留空由用户填写
  final String role; // main | backup | challenge
  final bool downloaded;

  const ModelInfo({
    required this.id,
    required this.fileName,
    required this.displayName,
    this.sizeBytes,
    this.sha256,
    this.downloadUrl,
    required this.role,
    this.downloaded = false,
  });
}
