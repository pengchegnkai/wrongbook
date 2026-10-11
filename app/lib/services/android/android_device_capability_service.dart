/// services/android/android_device_capability_service.dart
/// Android 真机内存/能力探测。/proc/meminfo 在 Android 上可读（App 可访问的值受限但存在）。
import 'dart:io';
import '../../core/device_capability.dart';
import '../../core/platform_type.dart';

class AndroidDeviceCapabilityService {
  Future<DeviceCapability> probe() async {
    int total = 0, avail = 0;
    try {
      final lines = File('/proc/meminfo').readAsLinesSync();
      for (final l in lines) {
        if (l.startsWith('MemTotal')) {
          total = int.tryParse(l.split(RegExp(r'\s+'))[1]) ?? 0; // kB
        } else if (l.startsWith('MemAvailable')) {
          avail = int.tryParse(l.split(RegExp(r'\s+'))[1]) ?? 0;
        }
      }
    } catch (_) {}
    return DeviceCapability(
      totalMemoryMb: total ~/ 1024,
      availableMemoryMb: avail ~/ 1024,
      platform: PlatformType.android,
      cpuCores: Platform.numberOfProcessors,
      socModel: '', // SOC 型号无公开 API，留空；用户可在设置页手填
    );
  }
}
