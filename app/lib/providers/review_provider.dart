/// providers/review_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/question.dart';

final reviewTodayProvider = FutureProvider<List<Question>>((ref) async {
  final data = await ApiClient().get('/review/today') as List;
  return data.map((e) => Question.fromJson(e)).toList();
});

final reviewUpcomingProvider = FutureProvider<Map<String, List<Question>>>((ref) async {
  final data = await ApiClient().get('/review/upcoming') as Map;
  return data.map((k, v) => MapEntry(k, (v as List).map((e) => Question.fromJson(e)).toList()));
});

final reviewCardsProvider = FutureProvider<List<Question>>((ref) async {
  final data = await ApiClient().get('/review/cards') as List;
  return data.map((e) => Question.fromJson(e)).toList();
});

/// 提交复习结果：again / hard / good
final reviewSubmitProvider = Provider<Future<void> Function(int id, String result)>((ref) {
  return (id, result) async {
    await ApiClient().post('/review/$id', body: {'result': result});
    ref.invalidate(reviewTodayProvider);
    ref.invalidate(reviewCardsProvider);
    ref.invalidate(reviewUpcomingProvider);
  };
});
