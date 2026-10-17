/// pages/question_list_page.dart —— 错题列表
/// 筛选栏（学科 / 掌握度 / 搜索）+ 卡片列表 + 下拉刷新 + 上拉加载
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/ui_states.dart';
import '../providers/filter_provider.dart';
import '../providers/question_provider.dart';

class QuestionListPage extends ConsumerStatefulWidget {
  const QuestionListPage({super.key});

  @override
  ConsumerState<QuestionListPage> createState() => _QuestionListPageState();
}

class _QuestionListPageState extends ConsumerState<QuestionListPage> {
  final _searchCtrl = TextEditingController();
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    ref.read(questionListProvider.notifier).refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final list = ref.read(questionListProvider);
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 120) {
      if (!list.loading && list.items.length < list.total) {
        ref.read(questionListProvider.notifier).loadMore();
      }
    }
  }

  void _onSearchChanged(String v) {
    final f = ref.read(questionFilterProvider);
    ref.read(questionFilterProvider.notifier).state =
        f.copyWith(search: v.isEmpty ? null : v, clearSearch: v.isEmpty);
    ref.read(questionListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(questionListProvider);
    final filter = ref.watch(questionFilterProvider);
    final subjects = ref.watch(subjectsProvider);
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (list.error != null && list.items.isEmpty) {
      body = ErrorRetryView(
        message: list.error!,
        onRetry: () => ref.read(questionListProvider.notifier).refresh(),
      );
    } else if (!list.loading && list.items.isEmpty) {
      body = EmptyStateView(
        icon: Icons.search_off,
        title: filter.search != null ? '没有匹配的错题' : '还没有错题',
        message: filter.search != null ? '换个关键词或清除筛选条件试试' : '拍照或选图录入你的第一道错题',
        actionLabel: filter.search != null ? '清除搜索' : '去录入',
        onAction: () {
          if (filter.search != null) {
            _searchCtrl.clear();
            final f = ref.read(questionFilterProvider);
            ref.read(questionFilterProvider.notifier).state = f.copyWith(clearSearch: true);
          }
          ref.read(questionListProvider.notifier).refresh();
          if (filter.search == null) context.push('/scan');
        },
      );
    } else {
      final showTopSkeleton = list.loading && list.items.isEmpty;
      body = RefreshIndicator(
        onRefresh: () => ref.read(questionListProvider.notifier).refresh(),
        child: showTopSkeleton
            ? const PageSkeleton(itemCount: 6)
            : NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  _onScroll();
                  return false;
                },
                child: ListView.separated(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: list.items.length + (list.loading ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == list.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final q = list.items[i];
                    return _QuestionCard(q: q, onTap: () => context.push('/questions/detail/${q.id}'));
                  },
                ),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题列表'),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: '录入错题', onPressed: () => context.push('/scan')),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          // 筛选栏
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: subjects.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (list) => DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        hint: const Text('全部学科', style: TextStyle(fontSize: 13)),
                        value: filter.subjectId,
                        items: [
                          for (final s in list)
                            DropdownMenuItem(
                              value: s['id'] as int,
                              child: Text('${s['name']}', overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) {
                          final f = ref.read(questionFilterProvider);
                          ref.read(questionFilterProvider.notifier).state =
                              f.copyWith(subjectId: v, clearSubject: v == null);
                          ref.read(questionListProvider.notifier).refresh();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: '搜索',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 掌握度 chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(label: '全部', selected: filter.mastery == null,
                    onTap: () => _setMastery(null)),
                for (final e in kMasteryOptions.entries)
                  _FilterChip(label: e.value, selected: filter.mastery == e.key,
                      onTap: () => _setMastery(e.key)),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  void _setMastery(String? m) {
    final f = ref.read(questionFilterProvider);
    ref.read(questionFilterProvider.notifier).state =
        f.copyWith(mastery: m, clearMastery: m == null);
    ref.read(questionListProvider.notifier).refresh();
  }
}

class _FilterChip extends StatelessWidget {
  _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(fontSize: 12, color: selected ? scheme.onPrimary : scheme.onSurface),
        selectedColor: scheme.primary,
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  _QuestionCard({required this.q, required this.onTap});
  final dynamic q;
  final VoidCallback onTap;

  Color get _masteryColor {
    switch (q.mastery) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = q.originalQuestion as String;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: _masteryColor, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (q.subjectName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${q.subjectName}', style: const TextStyle(fontSize: 11)),
                  ),
                const SizedBox(width: 8),
                if (q.chapterName != null)
                  Text('${q.chapterName}',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                const Spacer(),
                Text(_masteryColor == Colors.red ? '🔴' : _masteryColor == Colors.orange ? '🟡' : '🟢',
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (q.errorType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text('错因: ${q.errorType}', style: TextStyle(fontSize: 10, color: scheme.onErrorContainer)),
                  ),
                const Spacer(),
                if (q.reviewToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text('今日复习', style: const TextStyle(fontSize: 10)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
