/// services/token_storage.dart —— token 与会话信息安全存储
/// 只使用 flutter_secure_storage（不存 SharedPreferences），字段：
/// accessToken / refreshToken / userId / username / rememberMe
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kAccess = 'cuoti_access_token';
  static const _kRefresh = 'cuoti_refresh_token';
  static const _kUserId = 'cuoti_user_id';
  static const _kUsername = 'cuoti_username';
  static const _kRemember = 'cuoti_remember_me';

  // ---- 同步缓存（拦截器需同步读取；启动后由 hasTokens() 灌入）----
  static String? _accessCache;
  static String? get accessTokenSync => _accessCache;
  static int? _userIdCache;
  static int? get userIdSync => _userIdCache;
  static String? _usernameCache;
  static String? get usernameSync => _usernameCache;
  static bool _rememberCache = true;
  static bool get rememberSync => _rememberCache;

  static Future<String?> get accessToken => _storage.read(key: _kAccess);
  static Future<String?> get refreshToken => _storage.read(key: _kRefresh);

  /// 保存登录会话。
  /// userId / username / rememberMe 传 null 表示保持原值（token 轮换刷新时用）。
  static Future<void> saveSession({
    required String access,
    required String refresh,
    int? userId,
    String? username,
    bool? rememberMe,
  }) async {
    _accessCache = access;
    if (userId != null) _userIdCache = userId;
    if (username != null) _usernameCache = username;
    if (rememberMe != null) _rememberCache = rememberMe;
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    if (userId != null) await _storage.write(key: _kUserId, value: userId.toString());
    if (username != null) await _storage.write(key: _kUsername, value: username);
    if (rememberMe != null) await _storage.write(key: _kRemember, value: rememberMe ? 'true' : 'false');
  }

  /// 清除全部会话（登出 / token 彻底失效）
  static Future<void> clearAll() async {
    _accessCache = null;
    _userIdCache = null;
    _usernameCache = null;
    _rememberCache = true;
    await _storage.deleteAll(keys: const [_kAccess, _kRefresh, _kUserId, _kUsername, _kRemember]);
  }

  /// 是否有本地 token；同时把磁盘数据灌入同步缓存（App 重启后调用一次）
  static Future<bool> hasTokens() async {
    final a = await _storage.read(key: _kAccess);
    final uid = await _storage.read(key: _kUserId);
    final uname = await _storage.read(key: _kUsername);
    final rem = await _storage.read(key: _kRemember);
    _accessCache = a;
    _userIdCache = uid != null ? int.tryParse(uid) : null;
    _usernameCache = uname;
    _rememberCache = rem != 'false';
    return a != null;
  }

  /// 解析 access token（JWT）的 exp（epoch 秒）；解析失败返回 -1
  static int parseAccessExp(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return -1;
      var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (p.length % 4 != 0) p += '=';
      final json = jsonDecode(utf8.decode(base64.decode(p))) as Map<String, dynamic>;
      final exp = json['exp'];
      return exp is int ? exp : -1;
    } catch (_) {
      return -1;
    }
  }
}
