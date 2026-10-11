/// core/config.dart —— 全局配置（服务器地址动态化，不硬编码 127.0.0.1）
class AppConfig {
  /// 服务器地址，由服务器配置页写入（手动输入 / 扫描 / mDNS）
  static String _baseUrl = '';

  static String get baseUrl => _baseUrl;

  static String get apiBase => '$_baseUrl/api';

  /// llama-server 直连地址（模型对话）
  static String get llamaBase => '$_baseUrl:8080';

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static bool get isConfigured => _baseUrl.isNotEmpty;
}
