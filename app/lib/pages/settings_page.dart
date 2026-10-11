/// pages/settings_page.dart —— 设置：账号/安全/AI 模式/思考强度默认/自进化/隐私
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/router.dart';
import '../providers/auth_provider.dart';
import '../providers/ai_memory_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _Header('账号'),
          ListTile(leading: const Icon(Icons.person), title: Text(user?.nickname ?? user?.username ?? '未登录'), onTap: () => context.go('/profile')),
          ListTile(leading: const Icon(Icons.devices), title: const Text('登录设备管理'), onTap: () => context.go('/devices')),
          ListTile(leading: const Icon(Icons.logout), title: const Text('退出登录'), onTap: () async {
            await ref.read(currentUserProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          }),
          const _Header('服务器'),
          ListTile(leading: const Icon(Icons.dns), title: const Text('服务器配置'), onTap: () => context.go('/server-config')),
          const _Header('AI 与自进化'),
          ListTile(leading: const Icon(Icons.tune), title: const Text('思考强度设置'), onTap: () => context.go('/strength-selector')),
          ListTile(leading: const Icon(Icons.memory), title: const Text('AI 记忆管理'), onTap: () => context.go('/ai-memory')),
          ListTile(leading: const Icon(Icons.face), title: const Text('AI 学习画像'), onTap: () => context.go('/ai-profile')),
          ListTile(leading: const Icon(Icons.dns), title: const Text('本地模型管理'), onTap: () => context.go('/model-manage')),
          const _Header('外观'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('深色模式'),
            trailing: DropdownButton<ThemeMode>(
              value: ref.watch(themeModeProvider),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
              ],
              onChanged: (m) { if (m != null) ref.read(themeModeProvider.notifier).state = m; },
            ),
          ),
          const _Header('数据'),
          ListTile(leading: const Icon(Icons.import_export), title: const Text('导入导出'), onTap: () => context.go('/import-export')),
          const _Header('隐私'),
          const ListTile(leading: Icon(Icons.lock), title: Text('数据隔离说明'),
            subtitle: Text('所有数据按账号隔离：错题、AI 记忆、检索与导出均只含当前账号数据', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
  );
}
