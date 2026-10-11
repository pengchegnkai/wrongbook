/// providers/inference_provider.dart —— 本地推理调用
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../inference/inference_request.dart';
import '../inference/inference_response.dart';
import 'local_model_provider.dart';

final inferenceRunProvider = Provider<Future<InferenceResponse> Function(InferenceRequest)>((ref) {
  final engine = ref.watch(inferenceEngineProvider);
  return (request) => engine.run(request);
});
