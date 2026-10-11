/// inference/inference_engine_factory.dart —— 按 Platform 分发
/// Android 完整实现；iOS/Windows/Linux 空实现 + TODO
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../core/platform_type.dart';
import 'local_inference_engine.dart';
import 'android/android_inference_engine.dart';
import 'ios/ios_inference_engine.dart';
import 'windows/windows_inference_engine.dart';
import 'linux/linux_inference_engine.dart';

class InferenceEngineFactory {
  static PlatformType currentPlatform() {
    if (kIsWeb) return PlatformType.unknown;
    if (Platform.isAndroid) return PlatformType.android;
    if (Platform.isIOS) return PlatformType.ios;
    if (Platform.isWindows) return PlatformType.windows;
    if (Platform.isLinux) return PlatformType.linux;
    if (Platform.isMacOS) return PlatformType.macos;
    return PlatformType.unknown;
  }

  static LocalInferenceEngine create() {
    switch (currentPlatform()) {
      case PlatformType.android:
        return AndroidInferenceEngine();
      case PlatformType.ios:
        return IosInferenceEngine();
      case PlatformType.windows:
        return WindowsInferenceEngine();
      case PlatformType.linux:
      case PlatformType.macos:
        return LinuxInferenceEngine();
      case PlatformType.unknown:
        return LinuxInferenceEngine(); // 兜底空实现
    }
  }
}
