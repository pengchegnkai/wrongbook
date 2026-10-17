/// core/config.dart —— 全局配置（服务器地址动态化，不硬编码 127.0.0.1）
class AppConfig {
  /// 服务器地址，由服务器配置页写入（手动输入 / 扫描 / mDNS）
  static String _baseUrl = '';

  static String get baseUrl => _baseUrl;

  static String get apiBase => '$_baseUrl/api';

  /// llama-server 直连地址（模型对话）。
  /// 公网域名模式（https://域名，无端口）下 llama-server 的 8080 不经隧道
  /// 暴露，直连不可达：返回 baseUrl 本身，/health 立即 404 → isAvailable
  /// 快速判 false，推理改走后端 /api/ai/* 代理（后端在服务器本机连 llama）。
  static String get llamaBase {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null || uri.host.isEmpty) return '$_baseUrl:8080';
    if (uri.scheme == 'https' && !uri.hasPort) {
      // 公网域名模式：8080 不经隧道暴露，直连不可达 → 返回 baseUrl，
      // /health 立即 404 → isAvailable 快速判 false，推理走后端 /api/ai/* 代理
      return _baseUrl;
    }
    // 内网模式：统一剥掉已有端口改拼 8080（baseUrl=http://ip:3000 时
    // 直接拼会得到 ip:3000:8080 非法 URL）
    return '${uri.scheme}://${uri.host}:8080';
  }

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static bool get isConfigured => _baseUrl.isNotEmpty;
}
