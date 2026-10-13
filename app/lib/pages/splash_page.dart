/// pages/splash_page.dart —— 启动页：读本地 token → 自动登录引导 → 进首页或登录页
/// 断网时若本地 token 未过期，允许直接进入（页面顶部会显示离线提示条）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    ref.read(currentUserProvider.notifier).bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(currentUserProvider);
    if (auth.isCompleted && !_navigated) {
      _navigated = true;
      Future.microtask(() {
        if (!mounted) return;
        context.go(auth.valueOrNull != null ? '/' : '/login');
      });
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 96, color: scheme.onPrimary),
            const SizedBox(height: 24),
            Text(
              '错题本',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: scheme.onPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '本地私有错题管理 · AI 分析',
              style: TextStyle(color: scheme.onPrimary, opacity: 0.85),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: scheme.onPrimary),
            ),
            const SizedBox(height: 12),
            Text('正在启动…', style: TextStyle(color: scheme.onPrimary, opacity: 0.8)),
          ],
        ),
      ),
    );
  }
}
