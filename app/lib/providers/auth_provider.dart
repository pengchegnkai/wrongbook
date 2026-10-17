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
  /// 失败（服务器 5xx 等）置为 error 态：守卫按未登录处理跳登录页，
  /// 登录页能显示具体错误，而不是静默假装"未登录"。
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    try {
      final user = await AuthService.autoLogin();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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

  /// 凭据被拦截器判定彻底失效（401 刷新失败）时调用：
  /// token 已由拦截器 clearAll，这里只同步 UI 状态，路由随后跳登录页。
  void forceSignOut() {
    state = AsyncValue.data(null);
  }
}
