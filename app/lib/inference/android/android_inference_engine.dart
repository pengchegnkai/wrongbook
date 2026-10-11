/// inference/android/android_inference_engine.dart —— Android 完整实现
/// 策略：推理统一经内网 HTTP 调 Termux llama-server（OpenAI 兼容接口）。
/// 本文件不做端侧二进制推理（845 端侧 llama.cpp 嵌入未验证），模型切换/下载走服务端脚本接口。
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/config.dart';
import '../../core/api_client.dart';
import '../local_inference_engine.dart';
import '../inference_request.dart';
import '../inference_response.dart';
import '../model_info.dart';
import '../../services/android/android_model_storage_service.dart';
import '../../services/android/android_device_capability_service.dart';

class AndroidInferenceEngine implements LocalInferenceEngine {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(minutes: 6),
  ));
  final ModelStorageService _storage = AndroidModelStorageService();
  final AndroidDeviceCapabilityService _capability = AndroidDeviceCapabilityService();

  ModelInfo? _current;

  String get _llamaBase => '${AppConfig.baseUrl}:8080';

  @override
  Future<bool> isAvailable() async {
    try {
      final r = await _dio.get('$_llamaBase/health');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> loadModel(ModelInfo model) async {
    // 通过服务端 API 请求切换模型（TUI/llama-server.sh 完成实际重启）
    final downloaded = await _storage.isDownloaded(model.fileName);
    if (!downloaded) {
      throw Exception('模型未下载：${model.fileName}');
    }
    final api = ApiClient();
    await api.post('/ai/local-model/switch', body: {'fileName': model.fileName});
    _current = model;
  }

  @override
  Future<void> unloadModel() async {
    _current = null;
    // 未实现服务端卸载（llama-server 无卸载接口），仅清空客户端状态
  }

  @override
  Future<ModelInfo?> currentModel() async => _current;

  @override
  Future<InferenceResponse> run(InferenceRequest request) async {
    final sw = Stopwatch()..start();
    try {
      final messages = <Map<String, dynamic>>[
        if (request.systemPrompt.isNotEmpty) {'role': 'system', 'content': request.systemPrompt},
        {'role': 'user', 'content': request.prompt},
      ];
      final r = await _dio.post('$_llamaBase/v1/chat/completions', data: {
        'model': 'local',
        'messages': messages,
        'max_tokens': request.maxTokens,
        'temperature': request.temperature,
        'stream': false,
      });
      sw.stop();
      final data = r.data as Map<String, dynamic>;
      final choice = (data['choices'] as List).first as Map<String, dynamic>;
      final usage = data['usage'] as Map<String, dynamic>?;
      return InferenceResponse(
        text: choice['message']?['content'] ?? '',
        model: data['model'] ?? 'local',
        totalTokens: usage?['total_tokens'],
        loadTimeMs: sw.elapsedMilliseconds,
      );
    } on DioException catch (e) {
      sw.stop();
      return InferenceResponse.failure('推理请求失败: ${e.message}');
    } catch (e) {
      return InferenceResponse.failure('推理失败: $e');
    }
  }

  @override
  Future<List<ModelInfo>> listModels() async {
    final downloaded = await _storage.listDownloaded();
    final caps = await _capability.probe();
    return downloaded.map((f) => ModelInfo(
          id: f,
          fileName: f,
          displayName: f,
          role: caps.recommendedModelRole,
          downloaded: true,
        )).toList();
  }
}
