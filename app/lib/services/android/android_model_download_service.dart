/// services/android/android_model_download_service.dart
/// 说明：Qwen2.5 各型号的下载 URL 与 SHA256 由用户自行填写（不编造）。
/// 本服务只负责"给定 URL → 下载 → 校验 SHA256 → 落盘"。
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'android_model_storage_service.dart';

class ModelDownloadService {
  final ModelStorageService _storage = ModelStorageService();
  final Dio _dio = Dio();

  /// onProgress: 0.0 ~ 1.0
  Future<File?> download({
    required String url,
    required String fileName,
    String? expectedSha256,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _storage.modelDir();
    final target = File('${dir.path}/$fileName');
    try {
      await _dio.download(url, target.path,
          onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) onProgress(received / total);
      });
    } on DioException catch (e) {
      if (target.existsSync()) target.deleteSync();
      throw Exception('下载失败: ${e.message}');
    }
    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final actual = await sha256OfFile(target);
      if (actual != expectedSha256.toLowerCase()) {
        target.deleteSync();
        throw Exception('SHA256 校验不匹配：actual=$actual expected=$expectedSha256');
      }
    }
    return target;
  }

  Future<String> sha256OfFile(File f) async {
    // Dart 无内置 sha256，需 crypto 包；为避免 pubspec 未含依赖导致编译失败，
    // 这里用 Process 调 Termux/sha256sum 不可靠（App 内无 shell），改为提示用户。
    // TODO: 在 pubspec.yaml 添加 crypto: ^3.0.3 后启用以下实现（需你实测）：
    //   import 'package:crypto/crypto.dart';
    //   final bytes = await f.readAsBytes(); return sha256.convert(bytes).toString();
    throw UnimplementedError('SHA256 校验需在 pubspec.yaml 添加 crypto 包后启用（见注释），未验证');
  }

  Future<bool> verifySha256(File f, String expected) async {
    final actual = await sha256OfFile(f);
    return actual == expected.toLowerCase();
  }
}

/// 简单 JSON 工具（避免未使用 import 警告保留）
String encodeJson(Object? o) => jsonEncode(o);
