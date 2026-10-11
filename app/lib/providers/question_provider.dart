/// providers/question_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/question.dart';

/// 筛选条件
class QuestionFilter {
  final int? subjectId;
  final int? chapterId;
  final int? kpId;
  final String? mastery;
  final String? errorType;
  final String? verificationStatus;
  final String? search;
  final bool reviewTodayOnly;

  const QuestionFilter({
    this.subjectId, this.chapterId, this.kpId, this.mastery,
    this.errorType, this.verificationStatus, this.search, this.reviewTodayOnly = false,
  });

  QuestionFilter copyWith({int? subjectId, int? chapterId, int? kpId, String? mastery,
      String? errorType, String? verificationStatus, String? search, bool? reviewTodayOnly,
      bool clearSubject = false, bool clearChapter = false, bool clearKp = false,
      bool clearMastery = false, bool clearErrorType = false, bool clearSearch = false}) {
    return QuestionFilter(
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      chapterId: clearChapter ? null : (chapterId ?? this.chapterId),
      kpId: clearKp ? null : (kpId ?? this.kpId),
      mastery: clearMastery ? null : (mastery ?? this.mastery),
      errorType: clearErrorType ? null : (errorType ?? this.errorType),
      verificationStatus: verificationStatus ?? this.verificationStatus,
      search: clearSearch ? null : (search ?? this.search),
      reviewTodayOnly: reviewTodayOnly ?? this.reviewTodayOnly,
    );
  }

  Map<String, dynamic> toQuery(int page, int pageSize) => {
        if (subjectId != null) 'subjectId': subjectId,
        if (chapterId != null) 'chapterId': chapterId,
        if (kpId != null) 'kpId': kpId,
        if (mastery != null) 'mastery': mastery,
        if (errorType != null) 'errorType': errorType,
        if (verificationStatus != null) 'verificationStatus': verificationStatus,
        if (search != null && search!.isNotEmpty) 'search': search,
        if (reviewTodayOnly) 'reviewToday': 'true',
        'page': page, 'pageSize': pageSize,
      };
}

final questionFilterProvider = StateProvider<QuestionFilter>((ref) => const QuestionFilter());

class QuestionListState {
  final List<Question> items;
  final int total;
  final bool loading;
  final String? error;
  const QuestionListState({this.items = const [], this.total = 0, this.loading = false, this.error});
}

class QuestionListNotifier extends StateNotifier<QuestionListState> {
  final Ref ref;
  int _page = 1;
  QuestionListNotifier(this.ref) : super(const QuestionListState());

  Future<void> refresh() async {
    _page = 1;
    state = QuestionListState(loading: state.loading, items: state.items, total: state.total);
    await _load(replace: true);
  }

  Future<void> loadMore() async {
    if (state.loading) return;
    _page++;
    await _load(replace: false);
  }

  Future<void> _load({required bool replace}) async {
    state = QuestionListState(loading: true, items: state.items, total: state.total, error: null);
    try {
      final filter = ref.read(questionFilterProvider);
      final data = await ApiClient().get('/questions', query: filter.toQuery(_page, 20)) as Map;
      final items = (data['items'] as List).map((e) => Question.fromJson(e)).toList();
      state = QuestionListState(
        items: replace ? items : [...state.items, ...items],
        total: data['total'] ?? 0,
      );
    } catch (e) {
      state = QuestionListState(error: e.toString(), items: state.items, total: state.total);
    }
  }

  Future<void> delete(int id) async {
    await ApiClient().delete('/questions/$id');
    await refresh();
  }
}

final questionListProvider = StateNotifierProvider<QuestionListNotifier, QuestionListState>((ref) {
  return QuestionListNotifier(ref);
});

/// 筛选字典：学科/章节/知识点
final subjectsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ApiClient().get('/subjects') as List;
  return data.cast<Map<String, dynamic>>();
});

final chaptersProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, subjectId) async {
  final data = await ApiClient().get('/subjects/$subjectId/chapters') as List;
  return data.cast<Map<String, dynamic>>();
});

final kpsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, subjectId) async {
  final data = await ApiClient().get('/subjects/$subjectId/kps') as List;
  return data.cast<Map<String, dynamic>>();
});

/// 错题详情
final questionDetailProvider = FutureProvider.family<Question, String>((ref, id) async {
  final data = await ApiClient().get('/questions/$id');
  return Question.fromJson(data);
});
