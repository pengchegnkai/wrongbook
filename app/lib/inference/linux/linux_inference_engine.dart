/// inference/linux/linux_inference_engine.dart —— Linux/macOS 占位
/// TODO: Linux/macOS 平台实现。当前阶段不实现。
import '../local_inference_engine.dart';
import '../inference_request.dart';
import '../inference_response.dart';
import '../model_info.dart';

class LinuxInferenceEngine implements LocalInferenceEngine {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> loadModel(ModelInfo model) async {
    throw UnimplementedError('Linux/macOS 推理尚未实现（TODO）');
  }

  @override
  Future<void> unloadModel() async {}

  @override
  Future<ModelInfo?> currentModel() async => null;

  @override
  Future<InferenceResponse> run(InferenceRequest request) async {
    return InferenceResponse.failure('Linux/macOS 推理尚未实现（TODO）');
  }

  @override
  Future<List<ModelInfo>> listModels() async => [];
}
