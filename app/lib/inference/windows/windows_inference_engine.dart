/// inference/windows/windows_inference_engine.dart —— Windows 占位
/// TODO: Windows 平台实现（可考虑 llama.cpp Windows 版本本地服务）。当前阶段不实现。
import '../local_inference_engine.dart';
import '../inference_request.dart';
import '../inference_response.dart';
import '../model_info.dart';

class WindowsInferenceEngine implements LocalInferenceEngine {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> loadModel(ModelInfo model) async {
    throw UnimplementedError('Windows 推理尚未实现（TODO）');
  }

  @override
  Future<void> unloadModel() async {}

  @override
  Future<ModelInfo?> currentModel() async => null;

  @override
  Future<InferenceResponse> run(InferenceRequest request) async {
    return InferenceResponse.failure('Windows 推理尚未实现（TODO）');
  }

  @override
  Future<List<ModelInfo>> listModels() async => [];
}
