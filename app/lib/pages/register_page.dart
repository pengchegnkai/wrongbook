/// pages/register_page.dart —— 注册页（用户名 + 昵称 + 密码 + 确认密码）
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/ui_states.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _username = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _rememberMe = true;

  @override
  void dispose() {
    _username.dispose();
    _nickname.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _username.text.trim();
    if (name.length < 3 || name.length > 20) return '用户名需 3-20 个字符';
    if (!RegExp(r'^[A-Za-z0-9_\u4e00-\u9fa5]+$').hasMatch(name)) {
      return '用户名只能包含字母、数字、下划线、中文';
    }
    if (_password.text.length < 6) return '密码至少 6 位';
    if (_password.text != _confirm.text) return '两次输入的密码不一致';
    return null;
  }

  String? _extractErrorMessage(Object? error) {
    if (error is DioException) {
      final d = error.response?.data;
      if (d is Map && d['message'] is String && (d['message'] as String).isNotEmpty) {
        return d['message'] as String;
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return '无法连接服务器，请检查服务器地址与网络';
      }
    }
    final s = error.toString();
    return s.startsWith('Exception:') ? s.substring(10) : s;
  }

  Future<void> _register() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await ref.read(currentUserProvider.notifier).register(
          _username.text.trim(),
          _password.text,
          _nickname.text.trim().isEmpty ? _username.text.trim() : _nickname.text.trim(),
          rememberMe: _rememberMe,
        );
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(currentUserProvider);
    final errorText = auth is AsyncError ? _extractErrorMessage(auth.error) : null;
    final loading = auth.isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TextField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '用户名 *',
                      helperText: '3-20 位：字母 / 数字 / 下划线 / 中文',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nickname,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '昵称（可留空，默认同用户名）',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '密码 *',
                      helperText: '至少 6 位',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _register(),
                    decoration: const InputDecoration(
                      labelText: '确认密码 *',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                    title: const Text('记住我（下次启动自动登录）', style: TextStyle(fontSize: 13)),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorText, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: loading ? null : _register,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('注册并登录'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
