/// pages/pending_queue_page.dart —— 待处理队列
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/local_record_provider.dart';

class PendingQueuePage extends ConsumerStatefulWidget {
  const PendingQueuePage({super.key});

  @override
  ConsumerState<PendingQueuePage> createState() => _PendingQueuePageState();
}

class _PendingQueuePageState extends ConsumerState<PendingQueuePage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localRecordProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('待处理队列'), actions: [
        IconButton(icon: const Icon(Icons.sync), tooltip: '立即同步', onPressed: () async {
          final ok = await ref.read(localRecordProvider.notifier).syncNow();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步成功 $ok 条')));
        }),
        IconButton(icon: const Icon(Icons.refresh), tooltip: '重试失败', onPressed: () => ref.read(localRecordProvider.notifier).retryFailed()),
      ]),
      body: (state.pending.isEmpty && state.failed.isEmpty)
          ? const Center(child: Text('队列为空'))
          : ListView(children: [
              const ListTile(title: Text('待同步', style: TextStyle(fontWeight: FontWeight.bold))),
              ...state.pending.map((t) => ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(t['action'] ?? ''),
                subtitle: Text(t['createdAt'] ?? ''),
              )),
              const ListTile(title: Text('失败', style: TextStyle(fontWeight: FontWeight.bold))),
              ...state.failed.map((t) => ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(t['action'] ?? ''),
                subtitle: Text(t['lastError'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              )),
            ]),
    );
  }
}
