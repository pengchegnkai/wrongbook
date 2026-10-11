/// core/device_capability.dart —— 设备能力探测抽象（平台相关部分由 DeviceCapabilityService 实现）
import 'platform_type.dart';

class DeviceCapability {
  final int totalMemoryMb;
  final int availableMemoryMb;
  final PlatformType platform;
  final int cpuCores;
  final String socModel; // 如 "Snapdragon 845"，不可得则空串

  const DeviceCapability({
    required this.totalMemoryMb,
    required this.availableMemoryMb,
    required this.platform,
    required this.cpuCores,
    required this.socModel,
  });

  /// 推荐运行模型：8GB 内存 → 主力 3B；4GB → 保底 1.5B/MiniCPM；更低 → 仅文本缓存模式
  String get recommendedModelRole {
    if (availableMemoryMb >= 3500) return 'main';
    if (availableMemoryMb >= 1800) return 'backup';
    return 'backup-lite';
  }

  /// 高性能模式（7B）建议：仅在可用内存 > 6GB 时提示可尝试，实际未验证
  bool get challengeModelPlausible => availableMemoryMb >= 6000;
}
