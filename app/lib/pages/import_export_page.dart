/// pages/import_export_page.dart —— JSON/CSV 导入导出
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/export_service.dart';

class ImportExportPage extends ConsumerStatefulWidget {
  const ImportExportPage({super.key});

  @override
  ConsumerState<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends ConsumerState<ImportExportPage> {
  final _svc = ExportService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入导出')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        FilledButton.icon(
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
          label: const Text('导出 JSON（全部数据）'),
          onPressed: _busy ? null : () async {
            setState(() => _busy = true);
            try {
              final path = await _svc.exportJson();
              await Share.shareXFiles([XFile(path)]);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$e')));
            } finally {
              setState(() => _busy = false);
            }
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.table_chart),
          label: const Text('导出 CSV（Excel 可开）'),
          onPressed: _busy ? null : () async {
            setState(() => _busy = true);
            try {
              final path = await _svc.exportCsv();
              await Share.shareXFiles([XFile(path)]);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$e')));
            } finally {
              setState(() => _busy = false);
            }
          },
        ),
        const Divider(height: 32),
        OutlinedButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text('导入 JSON（写入当前账号）'),
          onPressed: _busy ? null : () async {
            final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
            if (result == null || result.files.single.path == null) return;
            setState(() => _busy = true);
            try {
              final n = await _svc.importJson(result.files.single.path!);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入成功 $n 条')));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败：$e')));
            } finally {
              setState(() => _busy = false);
            }
          },
        ),
        const SizedBox(height: 16),
        const Text('说明：导出只包含当前登录账号的数据；导入仅写入当前账号。', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}
