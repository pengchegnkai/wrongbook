/// core/local_model_config.dart —— 本地模型配置（2026-10 更新）
/// llama-server 来自 pkg 官方包（pkg install llama-cpp llama-cpp-backend-vulkan），
/// 推理经内网 HTTP 调 Termux llama-server（OpenAI 兼容 /v1/chat/completions，已验证可用）。
/// 默认模型：MiniCPM5-1B-Q8_0（~/storage/downloads/，纯 CPU -ngl 0）。
/// Qwen2.5 系列作为"可下载"选项，URL 与 SHA256 留空由用户自行填写，本文件不编造。
class LocalModelConfig {
  final String id;
  final String fileName;
  final String displayName;
  final int? sizeBytes;        // 由模型管理页填充，不编造
  final String? sha256;        // 由用户自行校验填写（留空 = 未校验）
  final String? downloadUrl;   // 可下载模型的 URL，留空由用户填写
  final String role;           // main（默认）| backup | challenge

  const LocalModelConfig({
    required this.id,
    required this.fileName,
    required this.displayName,
    this.sizeBytes,
    this.sha256,
    this.downloadUrl,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
        'id': id, 'fileName': fileName, 'displayName': displayName,
        'sizeBytes': sizeBytes, 'sha256': sha256,
        'downloadUrl': downloadUrl, 'role': role,
      };

  factory LocalModelConfig.fromMap(Map m) => LocalModelConfig(
        id: m['id'], fileName: m['fileName'], displayName: m['displayName'],
        sizeBytes: m['sizeBytes'], sha256: m['sha256'],
        downloadUrl: m['downloadUrl'], role: m['role'] ?? 'backup',
      );
}

/// 出厂默认列表：
/// - MiniCPM5-1B-Q8_0 为默认模型（已就位于 ~/storage/downloads/，pkg 版 llama-server 已验证）
/// - Qwen2.5-3B Q4_K_M 已下载到 ~/cuoti/models/（可切换）
/// - 其余 Qwen 型号为可下载选项，URL/SHA256 留空由用户自行填写
const kDefaultModels = [
  LocalModelConfig(
    id: 'minicpm5-1b-q8',
    fileName: 'MiniCPM5-1B-Q8_0.gguf',
    displayName: 'MiniCPM5 1B Q8_0（默认模型，已就位）',
    role: 'main',
  ),
  LocalModelConfig(
    id: 'qwen25-3b',
    fileName: 'qwen2.5-3b-instruct-q4_k_m.gguf',
    displayName: 'Qwen2.5 3B Q4_K_M（可选切换，已下载）',
    role: 'backup',
  ),
  LocalModelConfig(
    id: 'qwen25-15b',
    fileName: 'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
    displayName: 'Qwen2.5 1.5B（可下载，URL/SHA256 由你填写）',
    role: 'backup',
  ),
  LocalModelConfig(
    id: 'qwen25-7b',
    fileName: 'Qwen2.5-7B-Instruct-Q4_K_M.gguf',
    displayName: 'Qwen2.5 7B（挑战模式，URL/SHA256 由你填写）',
    role: 'challenge',
  ),
];
