/// pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('错题本', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              TextField(controller: _user, decoration: const InputDecoration(labelText: '用户名', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(
                controller: _pass,
                obscureText: _obscure,
                decoration: InputDecoration(labelText: '密码', border: const OutlineInputBorder(),
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure))),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.isLoading ? null : () => ref.read(currentUserProvider.notifier).login(_user.text.trim(), _pass.text),
                child: auth.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('登录'),
              ),
              TextButton(onPressed: () => context.push('/register'), child: const Text('没有账号？注册')),
              TextButton(onPressed: () => context.push('/server-config'), child: const Text('服务器配置')),
            ],
          ),
        ),
      ),
    );
  }
}
