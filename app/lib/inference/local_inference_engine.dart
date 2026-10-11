/// inference/local_inference_engine.dart —— 本地推理引擎抽象
/// Android 完整实现（HTTP 调内网 llama-server）；iOS/Windows/Linux 仅接口 + TODO
import 'inference_request.dart';
import 'inference_response.dart';
import 'model_info.dart';

abstract class LocalInferenceEngine {
  /// 模型服务是否可用
  Future<bool> isAvailable();

  /// 加载模型（本地平台上是拉起/切换 llama-server；HTTP 实现里是服务端操作）
  Future<void> loadModel(ModelInfo model);

  /// 卸载当前模型
  Future<void> unloadModel();

  /// 当前已加载模型（null = 未加载）
  Future<ModelInfo?> currentModel();

  /// 执行一次对话推理
  Future<InferenceResponse> run(InferenceRequest request);

  /// 可下载/已安装的模型列表
  Future<List<ModelInfo>> listModels();
}
