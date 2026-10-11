/// inference/ios/ios_inference_engine.dart —— iOS 占位
/// TODO: iOS 平台完整实现（如 Core ML / 端侧 llama.cpp 绑定）。当前阶段不实现。
import '../local_inference_engine.dart';
import '../inference_request.dart';
import '../inference_response.dart';
import '../model_info.dart';

class IosInferenceEngine implements LocalInferenceEngine {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> loadModel(ModelInfo model) async {
    throw UnimplementedError('iOS 推理尚未实现（TODO）');
  }

  @override
  Future<void> unloadModel() async {}

  @override
  Future<ModelInfo?> currentModel() async => null;

  @override
  Future<InferenceResponse> run(InferenceRequest request) async {
    return InferenceResponse.failure('iOS 推理尚未实现（TODO）');
  }

  @override
  Future<List<ModelInfo>> listModels() async => [];
}
