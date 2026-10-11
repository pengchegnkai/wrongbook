/// providers/local_record_provider.dart —— 本地离线记录
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/task_queue_service.dart';
import '../services/sync_service.dart';

class LocalRecordState {
  final List<Map<String, dynamic>> pending;
  final List<Map<String, dynamic>> failed;
  const LocalRecordState({this.pending = const [], this.failed = const []});
}

class LocalRecordNotifier extends StateNotifier<LocalRecordState> {
  final TaskQueueService _queue = TaskQueueService();
  bool _inited = false;

  LocalRecordNotifier() : super(const LocalRecordState());

  Future<void> _ensureInit() async {
    if (!_inited) {
      await _queue.init();
      _inited = true;
    }
  }

  Future<void> refresh() async {
    await _ensureInit();
    state = LocalRecordState(pending: _queue.pending(), failed: _queue.failed());
  }

  Future<int> syncNow() async {
    await _ensureInit();
    final sync = SyncService();
    final ok = await sync.syncAll();
    await refresh();
    return ok;
  }

  Future<void> retryFailed() async {
    await _ensureInit();
    await _queue.retryAllFailed();
    await refresh();
  }

  Future<void> clear() async {
    await _ensureInit();
    await _queue.clear();
    await refresh();
  }
}

final localRecordProvider = StateNotifierProvider<LocalRecordNotifier, LocalRecordState>((ref) {
  final n = LocalRecordNotifier();
  n.refresh();
  return n;
});
