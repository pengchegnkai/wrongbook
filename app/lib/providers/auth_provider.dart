/// providers/auth_provider.dart —— 登录态（含启动自动登录）
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, AsyncValue<User?>>((ref) => CurrentUserNotifier());

class CurrentUserNotifier extends StateNotifier<AsyncValue<User?>> {
  bool _bootstrapped = false;
  CurrentUserNotifier() : super(const AsyncValue.loading());

  /// 启动自动登录：读本地 token → 校验/刷新 → 决定进首页还是登录页。
  /// 由 splash 页 initState 触发一次。
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    try {
      final user = await AuthService.autoLogin();
      state = AsyncValue.data(user);
    } catch (e, st) {
      // autoLogin 内部已兜底，这里是双保险
      state = AsyncValue.data(null);
    }
  }

  Future<void> login(String username, String password, {bool rememberMe = true}) async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService.login(username, password, rememberMe: rememberMe);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String username, String password, String nickname, {bool rememberMe = true}) async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService.register(username, password, nickname, rememberMe: rememberMe);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = AsyncValue.data(null);
  }
}
