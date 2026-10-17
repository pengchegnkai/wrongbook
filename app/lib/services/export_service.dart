/// services/export_service.dart —— JSON/CSV 导出与 JSON 导入
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../core/api_client.dart';

class ExportService {
  Future<String> exportJson() async {
    final data = await ApiClient().get('/import-export/json');
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/cuoti-export-${DateTime.now().millisecondsSinceEpoch}.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return f.path;
  }

  Future<String> exportCsv() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/cuoti-export-${DateTime.now().millisecondsSinceEpoch}.csv');
    final r = await ApiClient().dio.get('/import-export/csv',
        options: Options(responseType: ResponseType.bytes));
    await f.writeAsBytes((r.data as List).cast<int>(), flush: true);
    return f.path;
  }

  Future<int> importJson(String filePath) async {
    final content = await File(filePath).readAsString();
    // 服务端期望 JSON 对象；若把文件原始字符串直接交给 Dio，会被再包一层
    // JSON 引号，服务端拿到的是字符串而非对象 → 导入失败。必须先解码。
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('导入文件不是有效的错题导出 JSON 对象');
    }
    final data = await ApiClient().post('/import-export/json', body: decoded);
    return (data as Map)['imported'] ?? 0;
  }
}
