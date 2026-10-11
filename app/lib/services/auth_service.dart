/// services/auth_service.dart —— 注册/登录/刷新
import '../core/api_client.dart';
import '../models/user.dart';

class AuthService {
  /// 登录。成功返回 User 并保存 token。
  static Future<User> login(String username, String password) async {
    final data = await ApiClient().post('/auth/login', body: {'username': username, 'password': password});
    await TokenStorage.saveTokens(data['accessToken'], data['refreshToken']);
    return User.fromJson(data['user']);
  }

  static Future<User> register(String username, String password, String nickname) async {
    final data = await ApiClient().post('/auth/register', body: {'username': username, 'password': password, 'nickname': nickname});
    await TokenStorage.saveTokens(data['accessToken'], data['refreshToken']);
    return User.fromJson(data['user']);
  }

  static Future<void> logout() async {
    try {
      final refresh = await TokenStorage.refreshToken;
      if (refresh != null) await ApiClient().post('/auth/logout', body: {'refreshToken': refresh});
    } finally {
      await TokenStorage.clear();
    }
  }

  /// 401 时刷新。成功返回 true（拦截器会重试原请求）。
  static Future<bool> tryRefresh() async {
    final refresh = await TokenStorage.refreshToken;
    if (refresh == null) return false;
    try {
      final dio = ApiClient().dio;
      // 刷新接口不带 Authorization
      dio.options.headers.remove('Authorization');
      final r = await dio.post('/auth/refresh', data: {'refreshToken': refresh});
      final data = r.data['data'];
      await TokenStorage.saveTokens(data['accessToken'], data['refreshToken']);
      return true;
    } catch (_) {
      return false;
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
