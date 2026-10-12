/// pages/question_list_page.dart —— 错题列表：筛选、分页、点击进详情
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../providers/question_provider.dart';
import '../providers/filter_provider.dart';
import '../models/question.dart';
import '../widgets/question_card.dart';

class QuestionListPage extends ConsumerStatefulWidget {
  const QuestionListPage({super.key});

  @override
  ConsumerState<QuestionListPage> createState() => _QuestionListPageState();
}

class _QuestionListPageState extends ConsumerState<QuestionListPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
        ref.read(questionListProvider.notifier).loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(questionListProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionListProvider);
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题列表'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () => _showFilterSheet(context, subjects)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scan'),
        child: const Icon(Icons.camera_alt),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: '搜索题目内容…',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(icon: const Icon(Icons.close), onPressed: () {
                _search.clear();
                ref.read(questionFilterProvider.notifier).state = ref.read(questionFilterProvider).copyWith(clearSearch: true);
                ref.read(questionListProvider.notifier).refresh();
              }),
            ),
            onSubmitted: (v) {
              ref.read(questionFilterProvider.notifier).state = ref.read(questionFilterProvider).copyWith(search: v);
              ref.read(questionListProvider.notifier).refresh();
            },
          ),
        ),
        Expanded(
          child: state.error != null
              ? Center(child: Text('加载失败：${state.error}'))
              : state.items.isEmpty && !state.loading
                  ? const Center(child: Text('暂无错题，点右下角拍照录入'))
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: state.items.length + (state.loading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= state.items.length) {
                          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                        }
                        final q = state.items[i];
                        return QuestionCard(
                          question: q,
                          onTap: () => context.push('/questions/detail/${q.id}'),
                          onMasteryChanged: (m) => _updateMastery(q, m),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Future<void> _updateMastery(Question q, String mastery) async {
    try {
      await ApiClient().put('/questions/${q.id}', body: {'mastery': mastery});
      if (mounted) ref.read(questionListProvider.notifier).refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败：$e')));
    }
  }

  void _showFilterSheet(BuildContext context, AsyncValue<List<Map<String, dynamic>>> subjects) {
    showModalBottomSheet(context: context, builder: (_) {
      return Consumer(builder: (_, ref, __) {
        final filter = ref.watch(questionFilterProvider);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('按学科筛选'),
            ...subjects.maybeWhen(
              data: (list) => list.map((s) => RadioListTile<int>(
                title: Text(s['name']),
                value: s['id'],
                groupValue: filter.subjectId,
                onChanged: (v) {
                  ref.read(questionFilterProvider.notifier).state = filter.copyWith(subjectId: v);
                  ref.read(questionListProvider.notifier).refresh();
                  Navigator.pop(context);
                },
              )).toList(),
              orElse: () => [const ListTile(title: Text('学科加载中…'))],
            ),
            SwitchListTile(
              title: const Text('只看今日待复习'),
              value: filter.reviewTodayOnly,
              onChanged: (v) {
                ref.read(questionFilterProvider.notifier).state = filter.copyWith(reviewTodayOnly: v);
                ref.read(questionListProvider.notifier).refresh();
                Navigator.pop(context);
              },
            ),
            const Text('按掌握度筛选'),
            Wrap(children: kMasteryOptions.entries.map((e) => Padding(
              padding: const EdgeInsets.all(4),
              child: ChoiceChip(label: Text(e.value), selected: filter.mastery == e.key,
                onSelected: (_) {
                  ref.read(questionFilterProvider.notifier).state = filter.copyWith(mastery: e.key);
                  ref.read(questionListProvider.notifier).refresh();
                  Navigator.pop(context);
                }),
            )).toList()),
            const Text('按核验状态'),
            Wrap(children: kVerificationStatuses.entries.map((e) => Padding(
              padding: const EdgeInsets.all(4),
              child: ChoiceChip(label: Text(e.value), selected: filter.verificationStatus == e.key,
                onSelected: (_) {
                  ref.read(questionFilterProvider.notifier).state = filter.copyWith(verificationStatus: e.key);
                  ref.read(questionListProvider.notifier).refresh();
                  Navigator.pop(context);
                }),
            )).toList()),
            TextButton(onPressed: () {
              ref.read(questionFilterProvider.notifier).state = const QuestionFilter();
              ref.read(questionListProvider.notifier).refresh();
              Navigator.pop(context);
            }, child: const Text('清除全部筛选')),
          ],
        );
      });
    });
  }
}
