/// inference/inference_request.dart
class InferenceRequest {
  final String prompt;
  final String systemPrompt;
  final int maxTokens;
  final double temperature;

  const InferenceRequest({
    required this.prompt,
    this.systemPrompt = '',
    this.maxTokens = 512,
    this.temperature = 0.7,
  });
}
