/// services/sync_service.dart —— 联网后推送本地队列
import '../core/api_client.dart';
import 'task_queue_service.dart';

class SyncService {
  final TaskQueueService _queue = TaskQueueService();

  Future<void> init() => _queue.init();

  /// 返回成功同步条数
  Future<int> syncAll() async {
    var ok = 0;
    for (final task in _queue.pending()) {
      try {
        if (task['action'] == 'create_question') {
          await ApiClient().post('/questions', body: task['payload']);
          await _queue.markDone(task['id']);
          ok++;
        } else {
          // 未识别的任务不能留在 pending：否则每次同步都被反复遍历，队列永不消化
          await _queue.markFailed(task['id'], 'unsupported action: ${task['action']}');
        }
      } catch (e) {
        await _queue.markFailed(task['id'], e.toString());
      }
    }
    return ok;
  }
}
