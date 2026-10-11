/// services/android/android_model_storage_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ModelStorageService {
  /// 模型目录：App 私有目录 /models（与服务端 ~/cuoti/models 独立；实际推理在服务端，
  /// 此目录用于管理 App 端下载记录与校验信息）
  Future<Directory> modelDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/models');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<bool> isDownloaded(String fileName) async {
    final dir = await modelDir();
    final f = File('${dir.path}/$fileName');
    if (f.existsSync()) return true;
    // 服务端模型也算可用（推理在服务端）：交由后端接口判断，此处仅查本地
    return false;
  }

  Future<List<String>> listDownloaded() async {
    final dir = await modelDir();
    return dir.existsSync()
        ? dir.listSync().whereType<File>().map((f) => f.path.split('/').last).where((n) => n.endsWith('.gguf')).toList()
        : [];
  }

  Future<void> recordDeleted(String fileName) async {
    final dir = await modelDir();
    final f = File('${dir.path}/$fileName');
    if (f.existsSync()) f.deleteSync();
  }
}
