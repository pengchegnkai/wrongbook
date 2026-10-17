/// pages/server_config_page.dart —— 服务器地址配置：手动输入 / 自动扫描 / 二维码
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../core/config.dart';
import '../services/server_discovery_service.dart';

class ServerConfigPage extends ConsumerStatefulWidget {
  const ServerConfigPage({super.key});

  @override
  ConsumerState<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends ConsumerState<ServerConfigPage> {
  final _url = TextEditingController();
  final _discovery = ServerDiscoveryService();
  List<String> _found = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isConfigured) _url.text = AppConfig.baseUrl;
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    final normalized = url.startsWith('http') ? url : 'http://$url';
    AppConfig.setBaseUrl(normalized);
    // 持久化：重启后 main.dart 会自动恢复，无需重输
    await Hive.box('settings').put('baseUrl', normalized);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存：${AppConfig.baseUrl}')));
      context.go('/login');
    }
  }

  Future<void> _scan() async {
    setState(() { _scanning = true; _found = []; });
    try {
      final found = await _discovery.scanSubnet();
      setState(() => _found = found);
    } finally {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('服务器配置')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: '如 192.168.1.100:3000',
              helperText: '在 Termux 的 start-all.sh 输出中可查看内网地址',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('保存')),
          const Divider(height: 32),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: _scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_find),
              label: const Text('自动扫描'),
              onPressed: _scanning ? null : _scan,
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('扫码'),
              onPressed: () async {
                final result = await context.push('/qr-scan');
                if (result is String && result.isNotEmpty) {
                  setState(() => _url.text = result);
                }
              },
            )),
          ]),
          if (_found.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('发现的服务器：'),
            ..._found.map((f) => ListTile(
              leading: const Icon(Icons.dns),
              title: Text(f),
              onTap: () { setState(() => _url.text = f); },
            )),
          ],
          const Divider(height: 32),
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('分享当前地址'),
            onPressed: () => Share.share('错题本服务器地址：${AppConfig.baseUrl}'),
          ),
        ],
      ),
    );
  }
}
