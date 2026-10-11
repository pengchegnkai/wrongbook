/// services/server_discovery_service.dart —— 服务器发现：手动 / 端口扫描 / mDNS / 二维码
/// mDNS 在部分 Android 网络下被路由器拦截（未验证，需你实测）；端口扫描为保底方案。
import 'package:dio/dio.dart';
import 'package:multicast_dns/multicast_dns.dart';

class ServerDiscoveryService {
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 2), receiveTimeout: const Duration(seconds: 3)));

  /// 扫描常见内网网段（如 192.168.1.0/24 的 :3000）。返回可用的 baseUrl 列表。
  /// 845 手机扫描 256 个地址耗时较长（约 30-60 秒），UI 需显示进度。
  Future<List<String>> scanSubnet({String? cidrPrefix, int port = 3000}) async {
    final prefix = cidrPrefix ?? await _guessPrefix();
    final found = <String>[];
    final futures = <Future<void>>[];
    for (var i = 1; i <= 254; i++) {
      final ip = '$prefix.$i';
      futures.add(_probe('http://$ip:$port', found));
    }
    await Future.wait(futures);
    return found;
  }

  Future<void> _probe(String base, List<String> found) async {
    try {
      final r = await _dio.get('$base/api/network/discover');
      if (r.statusCode == 200 && r.data['data']?['service'] == 'cuoti-server') {
        found.add(base);
      }
    } catch (_) {}
  }

  Future<String> _guessPrefix() async {
    // 无平台通道拿本机 IP 的通用方案：常见默认段回退
    // TODO: 通过 network_info_plus 或原生通道获取本机 IP 推导网段（未验证，需你实测）
    return '192.168.1';
  }

  /// mDNS 发现（服务端需提供 _cuoti._tcp；当前后端未实现 mDNS 广播，
  /// 此方法预留，实测失败则用 scanSubnet）
  Future<String?> discoverMdns() async {
    final client = MDnsClient();
    try {
      await client.start();
      await for (final ptr in client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('_cuoti._tcp.local'))
          .timeout(const Duration(seconds: 5), onTimeout: (sink) => sink.close())) {
        await for (final srv in client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
            .timeout(const Duration(seconds: 3), onTimeout: (sink) => sink.close())) {
          await for (final ip in client
              .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
              .timeout(const Duration(seconds: 3), onTimeout: (sink) => sink.close())) {
            return 'http://${ip.address.address}:${srv.port}';
          }
        }
      }
    } catch (_) {
      return null;
    } finally {
      client.stop();
    }
    return null;
  }
}
