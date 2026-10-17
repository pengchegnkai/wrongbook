/// pages/settings_page.dart —— 设置页
/// 账号 / 服务器配置 / 登录设备管理 / 主题 / 导入导出 / AI 记忆 / 本地模型 / 退出登录（二次确认）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/config.dart';
import '../core/router.dart';
import '../core/ui_states.dart';
import '../providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('退出后本机登录状态将被清除，\n下次启动需要重新登录。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(currentUserProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 账号卡片
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 24, child: Text((user?.nickname?.isNotEmpty ?? false) ? user!.nickname![0].toUpperCase() : '?')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.nickname ?? user?.username ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('@${user?.username ?? ''}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      TextButton(onPressed: () => context.push('/profile'), child: const Text('编辑')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionTitle('服务器'),
                _Tile(
                  icon: Icons.dns_outlined,
                  title: '服务器地址',
                  subtitle: AppConfig.baseUrl,
                  onTap: () => context.push('/server-config'),
                ),
                _Tile(
                  icon: Icons.qr_code,
                  title: '扫码配置',
                  subtitle: '扫描内网地址二维码',
                  onTap: () => context.push('/qr-scan'),
                ),
                const SizedBox(height: 16),
                _SectionTitle('账号与安全'),
                _Tile(
                  icon: Icons.devices,
                  title: '登录设备管理',
                  subtitle: '查看登录设备并远程下线',
                  onTap: () => context.push('/devices'),
                ),
                _Tile(
                  icon: Icons.lock_reset,
                  title: '修改密码 / 昵称',
                  subtitle: '修改后其他设备需重新登录',
                  onTap: () => context.push('/profile'),
                ),
                const SizedBox(height: 16),
                _SectionTitle('个性化'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.dark_mode_outlined),
                      const SizedBox(width: 12),
                      const Text('主题模式'),
                      const Spacer(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<ThemeMode>(
                          value: themeMode,
                          items: const [
                            DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
                            DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                            DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
                          ],
                          onChanged: (v) => ref.read(themeModeProvider.notifier).state = v ?? ThemeMode.system,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionTitle('数据'),
                _Tile(
                  icon: Icons.input,
                  title: '导入 / 导出',
                  subtitle: 'JSON / CSV 备份与恢复',
                  onTap: () => context.push('/import-export'),
                ),
                _Tile(
                  icon: Icons.memory,
                  title: 'AI 记忆',
                  subtitle: '查看 / 编辑 / 删除 AI 对你的了解',
                  onTap: () => context.push('/ai-memory'),
                ),
                const SizedBox(height: 16),
                _SectionTitle('本地模型'),
                _Tile(
                  icon: Icons.memory,
                  title: '模型管理',
                  subtitle: '查看 / 切换 / 下载本地模型',
                  onTap: () => context.push('/model-manage'),
                ),
                const SizedBox(height: 24),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.errorContainer,
                    foregroundColor: scheme.onErrorContainer,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _confirmLogout(context, ref),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 8),
                      Text('退出登录'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('错题本 v1.0.0 · 本地私有部署',
                      style: TextStyle(fontSize: 11, color: scheme.outline)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  _Tile({required this.icon, required this.title, this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)) : null,
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
    );
  }
}
