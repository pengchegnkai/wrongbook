/// providers/prompt_template_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../services/prompt_template_service.dart';
import '../models/prompt_template.dart';

final promptTemplateServiceProvider = Provider<PromptTemplateService>((ref) => PromptTemplateService());

final promptTemplatesProvider = FutureProvider<List<PromptTemplate>>((ref) async {
  return ref.watch(promptTemplateServiceProvider).list();
});

final defaultTemplateProvider = FutureProvider<PromptTemplate?>((ref) async {
  return ref.watch(promptTemplateServiceProvider).getDefault();
});

/// 模板保存（新建/更新）
final templateSaveProvider = Provider<Future<PromptTemplate> Function(PromptTemplate)>((ref) {
  return (t) async {
    final svc = ref.read(promptTemplateServiceProvider);
    final saved = t.id == null ? await svc.create(t) : await svc.update(t.id!, t);
    ref.invalidate(promptTemplatesProvider);
    ref.invalidate(defaultTemplateProvider);
    return saved;
  };
});

/// 模板预览（渲染结果缓存）
final templatePreviewProvider = FutureProvider.family<String, Map>((ref, args) async {
  final id = args['id'] as int;
  final vars = Map<String, dynamic>.from(args['vars'] as Map);
  return ref.watch(promptTemplateServiceProvider).preview(id, vars);
});

/// 快速直连 API（供预览页兜底）
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
