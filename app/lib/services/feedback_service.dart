/// services/feedback_service.dart —— 分析反馈（自进化显式信号）
import '../core/api_client.dart';

class FeedbackService {
  static const types = {
    'useful': '有用',
    'useless': '无用',
    'wrong': '错误',
    'too_long': '太啰嗦',
    'too_brief': '太简略',
    'confused': '不懂',
  };

  Future<void> submit({
    int? questionId,
    int? analysisLogId,
    required String feedbackType,
    String? comment,
  }) async {
    await ApiClient().post('/ai/feedback', body: {
      if (questionId != null) 'questionId': questionId,
      if (analysisLogId != null) 'analysisLogId': analysisLogId,
      'feedbackType': feedbackType,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }
}
