/// providers/stats_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/stats.dart';

final overviewStatsProvider = FutureProvider<OverviewStats>((ref) async {
  final data = await ApiClient().get('/stats/overview');
  return OverviewStats.fromJson(data);
});

final errorsStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ApiClient().get('/stats/errors') as List;
  return data.cast<Map<String, dynamic>>();
});

final masteryStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ApiClient().get('/stats/mastery') as List;
  return data.cast<Map<String, dynamic>>();
});

final weeklyStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ApiClient().get('/stats/weekly') as List;
  return data.cast<Map<String, dynamic>>();
});

final subjectStatsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, subjectId) async {
  return await ApiClient().get('/stats/subject/$subjectId');
});
