/// pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _nick = TextEditingController();

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (prev, next) {
      next.whenOrNull(data: (u) {
        if (u != null && mounted) context.go('/');
      });
    });
    final auth = ref.watch(currentUserProvider);
    final error = auth.whenOrNull(error: (e, _) => e.toString());

    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _user, decoration: const InputDecoration(labelText: '用户名', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _nick, decoration: const InputDecoration(labelText: '昵称', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: '密码（至少 6 位）', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _pass2, obscureText: true, decoration: const InputDecoration(labelText: '确认密码', border: OutlineInputBorder())),
          if (error != null) ...[const SizedBox(height: 12), Text(error, style: const TextStyle(color: Colors.red, fontSize: 12))],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: auth.isLoading ? null : () {
              if (_pass.text != _pass2.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次密码不一致')));
                return;
              }
              ref.read(currentUserProvider.notifier).register(_user.text.trim(), _pass.text, _nick.text.trim());
            },
            child: const Text('注册'),
          ),
        ],
      ),
    );
  }
}
