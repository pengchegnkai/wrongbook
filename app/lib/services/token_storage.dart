/// services/token_storage.dart —— 安全存储 access/refresh token
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kAccess = 'cuoti_access_token';
  static const _kRefresh = 'cuoti_refresh_token';

  static Future<String?> get accessToken => _storage.read(key: _kAccess);
  static Future<String?> get refreshToken => _storage.read(key: _kRefresh);

  /// 同步缓存（拦截器需要同步读取）
  static String? _accessCache;
  static String? get accessTokenSync => _accessCache;

  static Future<void> saveTokens(String access, String refresh) async {
    _accessCache = access;
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  static Future<void> clear() async {
    _accessCache = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  static Future<bool> hasTokens() async {
    return (await accessToken) != null;
  }
}
