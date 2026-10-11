/// services/task_queue_service.dart —— 本地离线队列（Hive 实现）
/// 默认离线优先：无网时操作入队，有网时同步。
import 'package:hive_flutter/hive_flutter.dart';

class TaskQueueService {
  static const _boxName = 'task_queue';
  Box? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// 入队一条待同步操作
  Future<void> enqueue(Map<String, dynamic> task) async {
    final id = 't_${DateTime.now().millisecondsSinceEpoch}';
    await _box?.put(id, {
      'id': id,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
      ...task,
    });
  }

  List<Map<String, dynamic>> pending() {
    final out = <Map<String, dynamic>>[];
    _box?.toMap().forEach((_, v) {
      final m = Map<String, dynamic>.from(v as Map);
      if (m['status'] == 'pending') out.add(m);
    });
    return out;
  }

  List<Map<String, dynamic>> failed() {
    final out = <Map<String, dynamic>>[];
    _box?.toMap().forEach((_, v) {
      final m = Map<String, dynamic>.from(v as Map);
      if (m['status'] == 'failed') out.add(m);
    });
    return out;
  }

  Future<void> markDone(String id) async {
    final t = _box?.get(id);
    if (t != null) {
      final m = Map<String, dynamic>.from(t as Map);
      m['status'] = 'done';
      await _box?.put(id, m);
    }
  }

  Future<void> markFailed(String id, String error) async {
    final t = _box?.get(id);
    if (t != null) {
      final m = Map<String, dynamic>.from(t as Map);
      m['status'] = 'failed';
      m['lastError'] = error;
      m['retryCount'] = ((m['retryCount'] as int?) ?? 0) + 1;
      await _box?.put(id, m);
    }
  }

  Future<void> retryAllFailed() async {
    for (final key in _box!.keys) {
      final m = Map<String, dynamic>.from(_box!.get(key) as Map);
      if (m['status'] == 'failed') {
        m['status'] = 'pending';
        await _box!.put(key, m);
      }
    }
  }

  Future<void> clear() => _box?.clear();
}
