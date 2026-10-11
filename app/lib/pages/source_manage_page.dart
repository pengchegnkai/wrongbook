/// pages/source_manage_page.dart —— 来源管理：A/B/C 级、核验状态筛选
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../providers/filter_provider.dart';
import '../widgets/source_badge.dart';

class SourceManagePage extends ConsumerStatefulWidget {
  const SourceManagePage({super.key});

  @override
  ConsumerState<SourceManagePage> createState() => _SourceManagePageState();
}

class _SourceManagePageState extends ConsumerState<SourceManagePage> {
  List<dynamic> _items = [];
  bool _loading = true;
  String _authorityFilter = '';
  String _statusFilter = '';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 来源挂在错题上：取有来源的错题
      final q = await ApiClient().get('/questions', query: {
        if (_statusFilter.isNotEmpty) 'verificationStatus': _statusFilter,
        'pageSize': 50,
      }) as Map;
      setState(() => _items = (q['items'] as List).where((e) => (e['answer_source_url'] ?? '') != '').toList());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败：$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('来源管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Wrap(children: [
                  ChoiceChip(label: const Text('全部'), selected: _statusFilter.isEmpty, onSelected: (_) { _statusFilter=''; _load(); }),
                  ...kVerificationStatuses.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(label: Text(e.value), selected: _statusFilter == e.key,
                      onSelected: (_) { _statusFilter = e.key; _load(); }),
                  ))]),
                const SizedBox(height: 8),
                if (_items.isEmpty) const Center(child: Text('暂无来源数据')),
                ..._items.map((item) => Card(
                  child: ListTile(
                    leading: SourceBadge(authority: item['answer_source_authority'] ?? 'C'),
                    title: Text(item['answer_source_name'] ?? item['answer_source_url'] ?? '（未命名）', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('题目 ${item['id']}：${(item['original_question'] ?? '').substring(0, (item['original_question'] ?? '').toString().length.clamp(0, 40))}', style: const TextStyle(fontSize: 11)),
                  ),
                )),
              ],
            ),
    );
  }
}
