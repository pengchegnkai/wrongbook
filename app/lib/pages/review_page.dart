/// pages/review_page.dart —— 复习模式
/// 卡片翻转（正面：原题 + 我的答案；背面：正确答案 + 解析）
/// 左右滑动切换卡片（PageView），底部三键标记掌握度（不会/模糊/掌握）后自动下一张。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/ui_states.dart';
import '../models/question.dart';
import '../providers/review_provider.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final PageController _pageCtrl = PageController();
  bool _flipped = false;
  bool _submitting = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    setState(() => _flipped = false);
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_pageCtrl.hasClients && _pageCtrl.page!.round() < _pageCtrl.position.maxScrollExtent / MediaQuery.sizeOf(context).width) {
        _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _submit(String result) async {
    final cards = ref.read(reviewCardsProvider).valueOrNull ?? const <Question>[];
    final idx = _pageCtrl.page?.round() ?? 0;
    if (idx >= cards.length || cards[idx].id == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(reviewSubmitProvider)(cards[idx].id!, result);
      _goNext();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交失败：${_msg(e)}，请检查网络')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception:') ? s.substring(10) : s;
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(reviewCardsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('复习模式'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: '复习日历',
            onPressed: () => context.push('/review-calendar'),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: cardsAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('加载今日待复习…'),
                  ],
                ),
              ),
              error: (e, _) => ErrorRetryView(
                message: _msg(e),
                onRetry: () => ref.invalidate(reviewCardsProvider),
              ),
              data: (cards) {
                if (cards.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.celebration,
                    title: '今天没有待复习的错题 🎉',
                    message: '录入新错题后，会按 1/3/7/15 天间隔提醒你复习',
                    actionLabel: '去录入错题',
                    onAction: () => context.push('/scan'),
                  );
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            '第 ${(_pageCtrl.page?.round() ?? 0) + 1} / ${cards.length} 张',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setState(() => _flipped = !_flipped),
                            icon: const Icon(Icons.flip_camera_android, size: 18),
                            label: Text(_flipped ? '看正面' : '翻面看答案'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageCtrl,
                        itemCount: cards.length,
                        onPageChanged: (i) => setState(() => _flipped = false),
                        itemBuilder: (context, i) => _ReviewCard(
                          question: cards[i],
                          flipped: _flipped,
                          onFlip: () => setState(() => _flipped = !_flipped),
                        ),
                      ),
                    ),
                    // 底部三键
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            for (final b in [
                              ('again', '不会', Colors.red, Icons.close),
                              ('hard', '模糊', Colors.orange, Icons.help),
                              ('good', '掌握', Colors.green, Icons.check),
                            ])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: FilledButton(
                                    onPressed: _submitting ? null : () => _submit(b.$1),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: b.$3,
                                      minimumSize: const Size.fromHeight(48),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(b.$4, size: 18),
                                        const SizedBox(width: 6),
                                        Text(b.$2, style: const TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  _ReviewCard({required this.question, required this.flipped, required this.onFlip});
  final Question question;
  final bool flipped;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final front = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.subjectName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(question.subjectName ?? '', style: TextStyle(fontSize: 13, color: scheme.primary)),
                const SizedBox(width: 8),
                Text(masteryLabel(question.mastery), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        const Spacer(),
        Text('原题', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            child: Text(question.originalQuestion, style: const TextStyle(fontSize: 16, height: 1.6)),
          ),
        ),
        const SizedBox(height: 16),
        if (question.myAnswer != null && question.myAnswer!.isNotEmpty) ...[
          Text('我的答案', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Text(question.myAnswer ?? '', style: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant)),
            ),
          ),
        ],
        const Spacer(),
      ],
    );

    final back = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Text('正确答案', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            child: Text(
              question.correctAnswer ?? '（暂无正确答案，稍后可补充核验）',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (question.analysis != null && question.analysis!.isNotEmpty) ...[
          Text('解析', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Text(question.analysis ?? '', style: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant)),
            ),
          ),
        ],
        const Spacer(),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onDoubleTap: onFlip,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Container(
            key: ValueKey(flipped ? 'back' : 'front'),
            width: double.infinity,
            height: double.infinity,
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: flipped ? Colors.green.withValues(alpha: 0.4) : scheme.outlineVariant),
            ),
            child: flipped ? back : front,
          ),
        ),
      ),
    );
  }
}
