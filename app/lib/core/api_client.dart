/// core/api_client.dart —— Dio 封装：baseUrl 动态、token 自动附加、401 自动刷新
import 'package:dio/dio.dart';
import 'config.dart';
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

/// 鉴权拦截器：附 token；401 时用 refreshToken 刷新一次并重试（仅一次，防死循环）
class AuthInterceptor extends Interceptor {
  final Dio _dio;
  AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 必须用同步缓存：accessToken 是 Future，未 await 时永远非 null，
    // 会把 "Bearer Instance of Future..." 塞进请求头导致全部 401
    final access = TokenStorage.accessTokenSync;
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // 已重试过仍 401：token 彻底失效，清凭据终止循环
      if (err.requestOptions.extra['authRetried'] == true) {
        await TokenStorage.clear();
        return handler.next(err);
      }
      final refreshed = await AuthService.tryRefresh();
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
      await TokenStorage.clear();
    }
    handler.next(err);
  }
}
