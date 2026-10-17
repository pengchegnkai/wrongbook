/// pages/server_config_page.dart —— 服务器地址配置：手动输入 / 自动扫描 / 二维码
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../core/config.dart';
import '../services/server_discovery_service.dart';
import '../providers/question_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/review_provider.dart';
import '../providers/prompt_template_provider.dart';
import '../providers/strength_provider.dart';
import '../providers/ai_memory_provider.dart';

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

  /// 地址规范化：
  /// - 已带 scheme（https:// 或 http://）→ 原样（公网域名必须 https）
  /// - 内网 IP / host:port（如 192.168.3.228:3000）→ 前缀 http://
  /// - 裸公网域名（含 . 且非内网段）→ 前缀 https://
  ///   （Cloudflare 代理的 http 入口会 301 重定向，直接填对可省一次跳转）
  String _normalize(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final host = raw.split(':').first;
    final isPrivate = host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host) ||
        host == 'localhost' ||
        raw.startsWith('127.');
    return isPrivate ? 'http://$raw' : 'https://$raw';
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    final normalized = _normalize(url);
    AppConfig.setBaseUrl(normalized);
    // 持久化：重启后 main.dart 会自动恢复，无需重输
    await Hive.box('settings').put('baseUrl', normalized);
    // 换服务器（或从内网切公网域名）后，所有按旧地址缓存的 FutureProvider
    // 必须清空，否则各页仍显示旧服务器数据
    ref.read(questionFilterProvider.notifier).state = const QuestionFilter();
    ref.invalidate(questionListProvider);
    ref.invalidate(subjectsProvider);
    ref.invalidate(overviewStatsProvider);
    ref.invalidate(errorsStatsProvider);
    ref.invalidate(masteryStatsProvider);
    ref.invalidate(weeklyStatsProvider);
    ref.invalidate(reviewCardsProvider);
    ref.invalidate(promptTemplatesProvider);
    ref.invalidate(strengthsProvider);
    ref.invalidate(aiProfileProvider);
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
              hintText: '如 192.168.1.100:3000 或 https://cuoti.example.com',
              helperText: '内网填 IP:端口；公网域名（Cloudflare）填完整 https:// 地址',
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
