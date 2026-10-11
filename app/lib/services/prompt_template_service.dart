/// services/prompt_template_service.dart —— 提示词模板服务
import '../core/api_client.dart';
import '../models/prompt_template.dart';

class PromptTemplateService {
  Future<List<PromptTemplate>> list({String? subject, String? questionType}) async {
    final data = await ApiClient().get('/prompt-templates', query: {
      if (subject != null) 'subject': subject,
      if (questionType != null) 'questionType': questionType,
    }) as List;
    return data.map((e) => PromptTemplate.fromJson(e)).toList();
  }

  Future<PromptTemplate?> getDefault() async {
    final data = await ApiClient().get('/prompt-templates/default');
    return data == null ? null : PromptTemplate.fromJson(data);
  }

  Future<PromptTemplate> create(PromptTemplate t) async {
    final data = await ApiClient().post('/prompt-templates', body: t.toJson());
    return PromptTemplate.fromJson(data);
  }

  Future<PromptTemplate> update(int id, PromptTemplate t) async {
    final data = await ApiClient().put('/prompt-templates/$id', body: t.toJson());
    return PromptTemplate.fromJson(data);
  }

  Future<PromptTemplate> duplicate(int id) async {
    final data = await ApiClient().post('/prompt-templates/$id/duplicate');
    return PromptTemplate.fromJson(data);
  }

  Future<String> preview(int id, Map<String, dynamic> vars) async {
    final data = await ApiClient().post('/prompt-templates/$id/preview', body: vars);
    return (data as Map)['rendered'] ?? '';
  }

  Future<void> delete(int id) async {
    await ApiClient().delete('/prompt-templates/$id');
  }
}
