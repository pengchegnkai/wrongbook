/// providers/ai_memory_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_memory_service.dart';
import '../models/user_ai_memory.dart';

final aiMemoryServiceProvider = Provider<AiMemoryService>((ref) => AiMemoryService());

final aiMemoriesProvider = FutureProvider<List<UserAiMemory>>((ref) async {
  return ref.watch(aiMemoryServiceProvider).list();
});

final aiProfileProvider = FutureProvider<AiProfile?>((ref) async {
  return ref.watch(aiMemoryServiceProvider).profile();
});

class AiMemoryActions {
  final Ref ref;
  AiMemoryActions(this.ref);

  Future<void> create(String type, String key, String value) async {
    await ref.read(aiMemoryServiceProvider).create(memoryType: type, key: key, value: value);
    ref.invalidate(aiMemoriesProvider);
  }

  Future<void> update(int id, {String? value, double? confidence}) async {
    await ref.read(aiMemoryServiceProvider).update(id, value: value, confidence: confidence);
    ref.invalidate(aiMemoriesProvider);
  }

  Future<void> delete(int id) async {
    await ref.read(aiMemoryServiceProvider).delete(id);
    ref.invalidate(aiMemoriesProvider);
  }

  Future<void> saveProfile({String? strength, String? style, String? goal}) async {
    await ref.read(aiMemoryServiceProvider).updateProfile(
        preferredStrength: strength, preferredExplanationStyle: style, learningGoal: goal);
    ref.invalidate(aiProfileProvider);
  }
}

final aiMemoryActionsProvider = Provider<AiMemoryActions>((ref) => AiMemoryActions(ref));
