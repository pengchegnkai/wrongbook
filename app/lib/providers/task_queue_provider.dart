/// providers/task_queue_provider.dart —— 队列统计（供首页/待处理队列页）
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_record_provider.dart';

final queueStatsProvider = Provider<Map<String, int>>((ref) {
  final state = ref.watch(localRecordProvider);
  return {
    'pending': state.pending.length,
    'failed': state.failed.length,
  };
});
