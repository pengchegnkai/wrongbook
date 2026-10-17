/// services/auth_service.dart —— 注册 / 登录 / 刷新 / 自动登录
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/user.dart';
import 'token_storage.dart';

class AuthService {
  /// 登录。rememberMe=false 表示下次启动不自动登录。
  static Future<User> login(String username, String password, {bool rememberMe = true}) async {
    final data = await ApiClient().post('/auth/login', body: {'username': username, 'password': password}) as Map;
    final user = User.fromJson(data['user']);
    await TokenStorage.saveSession(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
      userId: user.id,
      username: user.username,
      rememberMe: rememberMe,
    );
    return user;
  }

  static Future<User> register(String username, String password, String nickname, {bool rememberMe = true}) async {
    final data = await ApiClient().post('/auth/register', body: {'username': username, 'password': password, 'nickname': nickname}) as Map;
    final user = User.fromJson(data['user']);
    await TokenStorage.saveSession(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
      userId: user.id,
      username: user.username,
      rememberMe: rememberMe,
    );
    return user;
  }

  static Future<void> logout() async {
    try {
      final refresh = await TokenStorage.refreshToken;
      if (refresh != null) await ApiClient().post('/auth/logout', body: {'refreshToken': refresh});
    } catch (_) {
      // 断网时服务器端吊销会失败——忽略，本地一定清除
    } finally {
      await TokenStorage.clearAll();
    }
  }

  /// 401 时刷新 token（服务端轮换：旧 refresh 吊销、发新 refresh）。
  /// 成功返回 true（拦截器重试原请求）。
  static Future<bool> tryRefresh() async {
    final refresh = await TokenStorage.refreshToken;
    if (refresh == null) return false;
    try {
      final api = ApiClient();
      api.ensureConfigured();
      final r = await api.dio.post('/auth/refresh', data: {'refreshToken': refresh});
      final data = r.data['data'] as Map;
      await TokenStorage.saveSession(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 启动自动登录：
  /// - 无本地 token → null
  /// - 登录时未勾选「记住我」→ 清除并返回 null（需手动登录）
  /// - access token 本地已过期 → 先尝试静默刷新（refresh 很可能仍有效，
  ///   与运行期 401 自动刷新行为一致），失败才清除
  /// - 网络可用：/auth/me 校验（401 时拦截器已尝试刷新并重试）
  /// - 仅连接类错误（断网）且仍持有 token → 返回离线 User（可进 App，顶部离线条）；
  ///   服务器 5xx/响应异常等不装作已登录，向上抛 → 进登录页
  static Future<User?> autoLogin() async {
    if (!await TokenStorage.hasTokens()) return null;
    if (!TokenStorage.rememberSync) {
      await TokenStorage.clearAll();
      return null;
    }
    final access = TokenStorage.accessTokenSync ?? '';
    final exp = TokenStorage.parseAccessExp(access);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (exp > 0 && exp < now) {
      final refreshed = await tryRefresh();
      if (!refreshed) {
        await TokenStorage.clearAll();
        return null;
      }
    }
    try {
      return await me();
    } on DioException catch (e) {
      final networkDown = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout;
      if (networkDown && await TokenStorage.hasTokens()) {
        return User(
          id: TokenStorage.userIdSync ?? 0,
          username: TokenStorage.usernameSync ?? 'offline',
          nickname: TokenStorage.usernameSync,
          status: 'active',
        );
      }
      rethrow; // 5xx/响应异常/401 已清凭据等 → bootstrap 置为未登录
    }
  }

  static Future<User> me() async {
    final data = await ApiClient().get('/auth/me');
    return User.fromJson(data);
  }

  static Future<List<LoginDevice>> devices() async {
    final data = await ApiClient().get('/auth/devices') as List;
    return data.map((e) => LoginDevice.fromJson(e)).toList();
  }

  static Future<void> logoutDevice(int deviceId) async {
    await ApiClient().post('/auth/logout-device', body: {'deviceId': deviceId});
  }

  static Future<void> changePassword(String oldPassword, String newPassword) async {
    await ApiClient().post('/auth/change-password', body: {'oldPassword': oldPassword, 'newPassword': newPassword});
  }
}
