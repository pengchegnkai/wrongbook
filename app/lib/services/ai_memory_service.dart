/// services/ai_memory_service.dart —— AI 记忆与画像
import '../core/api_client.dart';
import '../models/user_ai_memory.dart';

class AiMemoryService {
  Future<List<UserAiMemory>> list() async {
    final data = await ApiClient().get('/ai-memory') as List;
    return data.map((e) => UserAiMemory.fromJson(e)).toList();
  }

  Future<UserAiMemory> create({required String memoryType, required String key, required String value}) async {
    final data = await ApiClient().post('/ai-memory', body: {
      'memoryType': memoryType, 'key': key, 'value': value,
    });
    return UserAiMemory.fromJson(data);
  }

  Future<void> update(int id, {String? value, double? confidence}) async {
    await ApiClient().put('/ai-memory/$id', body: {
      if (value != null) 'value': value,
      if (confidence != null) 'confidence': confidence,
    });
  }

  Future<void> delete(int id) async {
    await ApiClient().delete('/ai-memory/$id');
  }

  Future<AiProfile?> profile() async {
    final data = await ApiClient().get('/ai/profile');
    return data == null ? null : AiProfile.fromJson(data);
  }

  Future<void> updateProfile({String? preferredStrength, String? preferredExplanationStyle, String? learningGoal}) async {
    await ApiClient().put('/ai/profile', body: {
      if (preferredStrength != null) 'preferredStrength': preferredStrength,
      if (preferredExplanationStyle != null) 'preferredExplanationStyle': preferredExplanationStyle,
      if (learningGoal != null) 'learningGoal': learningGoal,
    });
  }

  Future<void> refreshProfile() async {
    await ApiClient().post('/ai/profile/refresh');
  }
}
