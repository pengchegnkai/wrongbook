/// pages/profile_page.dart —— 个人资料与改密
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  String? _msg;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        CircleAvatar(radius: 36, child: Text((user?.nickname ?? '?').characters.first)),
        const SizedBox(height: 8),
        Center(child: Text('用户名：${user?.username ?? '-'}')),
        Center(child: Text('昵称：${user?.nickname ?? '-'}')),
        const Divider(height: 32),
        const Text('修改密码（修改后其他设备将全部下线）'),
        const SizedBox(height: 8),
        TextField(controller: _old, obscureText: true, decoration: const InputDecoration(labelText: '旧密码')),
        const SizedBox(height: 12),
        TextField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: '新密码（至少 6 位）')),
        const SizedBox(height: 12),
        if (_msg != null) Text(_msg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        FilledButton(onPressed: () async {
          try {
            await AuthService.changePassword(_old.text, _new.text);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码已修改，请重新登录')));
            await ref.read(currentUserProvider.notifier).logout();
            if (mounted) context.go('/login');
          } catch (e) {
            if (mounted) setState(() => _msg = e.toString());
          }
        }, child: const Text('修改密码')),
      ]),
    );
  }
}
