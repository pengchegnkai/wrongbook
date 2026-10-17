/// core/api_client.dart —— Dio 封装：baseUrl 动态、token 自动附加、401 自动刷新（并发安全）、网络状态回调
import 'dart:async';
import 'package:dio/dio.dart';
import 'config.dart';
import '../providers/network_provider.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(minutes: 5), // AI 分析可能很慢
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor(dio));
  }

  /// 确保已配置服务器地址
  void ensureConfigured() {
    if (!AppConfig.isConfigured) {
      throw Exception('服务器地址未配置，请先在服务器配置页设置');
    }
    dio.options.baseUrl = AppConfig.apiBase;
  }

  /// 统一响应解包 { code, data, message }
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    ensureConfigured();
    final r = await dio.get(path, queryParameters: query);
    return r.data['data'];
  }

  Future<dynamic> post(String path, {Object? body}) async {
    ensureConfigured();
    final r = await dio.post(path, data: body);
    return r.data['data'];
  }

  Future<dynamic> put(String path, {Object? body}) async {
    ensureConfigured();
    final r = await dio.put(path, data: body);
    return r.data['data'];
  }

  Future<dynamic> delete(String path) async {
    ensureConfigured();
    final r = await dio.delete(path);
    return r.data['data'];
  }
}

/// 鉴权拦截器：
/// - onRequest 附 Bearer token（同步缓存，未 await 的 Future 绝不能塞进请求头）
/// - 401 自动用 refreshToken 换新 token 并重试原请求：
///   * Completer 防止并发 401 触发多次刷新
///   * authRetried 标记只重试一次，防死循环
///   * /auth/login /auth/register /auth/refresh 自身的 401 不自动刷新（精确匹配）
/// - 连接失败/连接超时：只标记离线，不清 token（断网 ≠ 未登录）；
///   receiveTimeout 不算离线（服务端可能仍在处理，如 OCR/AI 长请求）
/// - token 彻底失效清凭据时触发 onCredentialsInvalid 回调（由 main 接线到
///   登出状态与路由，否则守卫仍认为已登录，页面会卡死在失效会话里）
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  Completer<bool>? _refreshing;

  /// 凭据被拦截器清除时回调（main.dart 里接到 currentUserProvider / 路由）
  static void Function()? onCredentialsInvalid;

  AuthInterceptor(this._dio);

  // 这些接口自身的 401 是"凭据错误"的正常返回，不触发刷新
  static const _noRefreshPaths = {'/auth/login', '/auth/register', '/auth/refresh'};

  static bool _isNetworkError(DioExceptionType t) =>
      t == DioExceptionType.connectionError ||
      t == DioExceptionType.connectionTimeout ||
      t == DioExceptionType.sendTimeout;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final access = TokenStorage.accessTokenSync;
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    NetworkStatus.setOffline(false);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 网络失败：标记离线并透传，绝不视为未登录
    if (_isNetworkError(err.type)) {
      NetworkStatus.setOffline(true);
      return handler.next(err);
    }
    final path = err.requestOptions.path;
    final noRefresh = _noRefreshPaths.any((p) => path.contains(p));
    if (err.response?.statusCode == 401 && !noRefresh) {
      // 已重试过仍 401：token 彻底失效，清凭据终止循环
      if (err.requestOptions.extra['authRetried'] == true) {
        await TokenStorage.clearAll();
        onCredentialsInvalid?.call();
        return handler.next(err);
      }
      var refreshed = false;
      if (_refreshing != null) {
        // 并发 401：等待第一次刷新完成，共用其结果
        refreshed = await _refreshing!.future;
      } else {
        final completer = Completer<bool>();
        _refreshing = completer;
        try {
          refreshed = await AuthService.tryRefresh();
        } catch (_) {
          refreshed = false;
        } finally {
          completer.complete(refreshed);
          _refreshing = null;
        }
      }
      if (refreshed) {
        err.requestOptions.extra['authRetried'] = true;
        final access = TokenStorage.accessTokenSync;
        if (access != null && access.isNotEmpty) {
          err.requestOptions.headers['Authorization'] = 'Bearer $access';
        }
        try {
          final retry = await _dio.fetch(err.requestOptions);
          return handler.resolve(retry);
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
      await TokenStorage.clearAll();
      onCredentialsInvalid?.call();
    }
    handler.next(err);
  }
}
