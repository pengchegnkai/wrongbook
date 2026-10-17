/// pages/review_page.dart —— 复习模式
/// 卡片翻转（正面：原题 + 我的答案；背面：正确答案 + 解析）
/// Tinder 交互：左滑=不会，右滑=掌握（带震动与飞出动画）；底部按钮保留。
/// 提交掌握度后该卡片从本地列表移除；全部完成显示完成态。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/ui_states.dart';
import '../models/question.dart';
import '../providers/review_provider.dart';
import '../providers/stats_provider.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final PageController _pageCtrl = PageController();
  bool _flipped = false;
  bool _submitting = false;
  List<Question>? _local; // 本地剩余卡片：提交成功即移除（来源：provider 首次数据）
  int? _initialCount; // 首次拉到的卡片总数：区分"今天本来就没有"和"已复习完"
  double _dragDx = 0; // 顶部卡片拖拽位移（Tinder 滑卡）

  /// 提交并翻页：滑卡/按钮统一入口
  Future<void> _submitCurrent(String result) async {
    final idx = _pageCtrl.page?.round() ?? 0;
    await _submit(idx, result);
    if (mounted && _local != null && _local!.isNotEmpty) {
      // 提交成功后移除了卡片，翻到下一张（越界则停在最后一页）
      final next = idx.clamp(0, _local!.length - 1);
      if (_pageCtrl.hasClients) {
        await _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // 每次进入本页都重新拉取今日待复习（离开期间的提交结果服务端已记录）
    Future.microtask(() => ref.invalidate(reviewCardsProvider));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(int idx, String result) async {
    final cards = _local;
    if (cards == null || _submitting || cards.isEmpty) return;
    // 删卡后 PageView 可能尚未跳转，_pageCtrl.page 可能越界 → clamp
    idx = idx.clamp(0, cards.length - 1);
    if (cards[idx].id == null) return;
    final qid = cards[idx].id!;
    setState(() => _submitting = true);
    try {
      await ref.read(reviewSubmitProvider)(qid, result);
      if (!mounted) return;
      setState(() {
        cards.removeAt(idx); // 本地移除，无需整页刷新
        _flipped = false;
      });
      // 移除的是最后一张时，PageView 的当前页会越出新的 itemCount → 跳回最后一页
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageCtrl.hasClients) return;
        final page = _pageCtrl.page ?? 0;
        if (cards.isNotEmpty && page >= cards.length) {
          _pageCtrl.jumpTo(_pageCtrl.position.maxScrollExtent);
        }
      });
      // 复习提交会影响首页概览统计 → 使其失效
      ref.invalidate(overviewStatsProvider);
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
                onRetry: () {
                  setState(() {
                    _local = null;
                    _initialCount = null;
                  });
                  ref.invalidate(reviewCardsProvider);
                },
              ),
              data: (cards) {
                _local ??= List<Question>.from(cards);
                _initialCount ??= cards.length;
                final list = _local!;
                if (list.isEmpty) {
                  // 复习完成（或今天本来就没有）共用完成态
                  return EmptyStateView(
                    icon: Icons.celebration,
                    title: '复习完成 🎉',
                    message: (_initialCount ?? 0) == 0
                        ? '今天没有待复习的错题。录入新错题后，会按 1/3/7/15 天间隔提醒你复习'
                        : '本轮错题已全部复习完毕，明天继续加油',
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
                            '第 ${(_pageCtrl.page?.round() ?? 0).clamp(0, list.length - 1) + 1} / ${list.length} 张',
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
                        itemCount: list.length,
                        onPageChanged: (i) => setState(() {
                          _flipped = false;
                          _dragDx = 0; // 换页重置拖拽
                        }),
                        itemBuilder: (context, i) {
                          final isTop = i == (_pageCtrl.page?.round() ?? 0);
                          return _SwipeCard(
                            dx: isTop ? _dragDx : 0,
                            enabled: isTop && !_submitting,
                            onDrag: (dx) => setState(() => _dragDx = dx),
                            onCommit: (right) {
                              HapticFeedback.mediumImpact(); // 滑出确认震动
                              _submitCurrent(right ? 'good' : 'again');
                            },
                            onCancel: () => setState(() => _dragDx = 0),
                            child: _ReviewCard(
                              question: list[i],
                              flipped: _flipped,
                              onFlip: () => setState(() => _flipped = !_flipped),
                            ),
                          );
                        },
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
                                    onPressed: _submitting ? null : () => _submitCurrent(b.$1),
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
  const _ReviewCard({required this.question, required this.flipped, required this.onFlip});
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

/// Tinder 滑卡容器：水平拖拽跟手、轻微旋转、方向角标；
/// 越过阈值松手 → 飞出并回调提交，否则回弹。
class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.dx,
    required this.onDrag,
    required this.onCommit,
    required this.onCancel,
    required this.child,
    required this.enabled,
  });

  final double dx;
  final ValueChanged<double> onDrag;
  final ValueChanged<bool> onCommit; // true=右滑(掌握) false=左滑(不会)
  final VoidCallback onCancel;
  final Widget child;
  final bool enabled;

  static const _threshold = 110.0;

  @override
  Widget build(BuildContext context) {
    final progress = (dx.abs() / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragStart: enabled ? (_) {} : null,
      onHorizontalDragUpdate: enabled
          ? (d) => onDrag(dx + d.delta.dx)
          : null,
      onHorizontalDragEnd: enabled
          ? (d) {
              final v = d.velocity.pixelsPerSecond.dx;
              if (dx > _threshold || v > 900) {
                onCommit(true);
              } else if (dx < -_threshold || v < -900) {
                onCommit(false);
              } else {
                onCancel();
              }
            }
          : null,
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: Transform.rotate(
          angle: dx / 28 * 0.03, // 轻微倾斜（845 上纯 transform 零成本）
          child: Stack(children: [
            child,
            // 方向角标：右滑=掌握（绿） 左滑=不会（红）
            if (progress > 0.15)
              Positioned(
                top: 18,
                left: dx > 0 ? 18 : null,
                right: dx < 0 ? 18 : null,
                child: Opacity(
                  opacity: progress * 0.9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (dx > 0 ? Colors.green : Colors.red).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dx > 0 ? '掌握 ✓' : '不会 ✗',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
