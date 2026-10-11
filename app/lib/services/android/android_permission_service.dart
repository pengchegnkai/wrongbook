/// services/android/android_permission_service.dart
/// 权限声明在 AndroidManifest.xml；运行时权限（相机/存储）由 image_picker/file_picker 插件自动申请，
/// 本服务只做前置检查与用户提示。
import 'package:flutter/services.dart';

class AndroidPermissionService {
  static const _channel = MethodChannel('cuoti/permissions');

  /// 检查存储/相机权限是否已授予（Android 13+ 分区存储下多数场景无需 WRITE_EXTERNAL_STORAGE）
  Future<bool> ensureStoragePermission() async {
    try {
      return await _channel.invokeMethod('ensureStorage') ?? true;
    } on PlatformException {
      // 原生侧未实现时返回 true（依赖插件自动申请），并在页面提示
      return true;
    }
  }

  Future<bool> ensureCameraPermission() async {
    try {
      return await _channel.invokeMethod('ensureCamera') ?? true;
    } on PlatformException {
      return true;
    }
  }
}
