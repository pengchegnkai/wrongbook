/// inference/inference_response.dart
class InferenceResponse {
  final String text;
  final String model;
  final int? totalTokens;
  final int? firstTokenMs;
  final int? loadTimeMs;
  final bool success;
  final String? error;

  const InferenceResponse({
    required this.text,
    this.model = '',
    this.totalTokens,
    this.firstTokenMs,
    this.loadTimeMs,
    this.success = true,
    this.error,
  });

  factory InferenceResponse.failure(String message) =>
      InferenceResponse(text: '', success: false, error: message);
}
