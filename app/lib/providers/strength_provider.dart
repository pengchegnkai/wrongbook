/// providers/strength_provider.dart —— 思考强度选项与默认配置
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/analysis_log.dart';

final strengthsProvider = FutureProvider<List<Strength>>((ref) async {
  final data = await ApiClient().get('/analysis/strengths') as List;
  return data.map((e) => Strength.fromJson(e)).toList();
});

/// 选中强度（分析页传给后端；null = 使用用户配置默认）
final selectedStrengthProvider = StateProvider<String?>((ref) => null);

/// 按学科/题型的默认强度配置列表
final strengthConfigProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ApiClient().get('/analysis/strength-config') as List;
  return data.cast<Map<String, dynamic>>();
});

final strengthConfigSaveProvider = Provider<Future<void> Function(String? subject, String? questionType, String strength)>((ref) {
  return (subject, questionType, strength) async {
    await ApiClient().put('/analysis/strength-config', body: {
      if (subject != null) 'subject': subject,
      if (questionType != null) 'questionType': questionType,
      'defaultStrength': strength,
    });
    ref.invalidate(strengthConfigProvider);
  };
});
