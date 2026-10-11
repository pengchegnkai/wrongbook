/// services/network_info_service.dart —— 网络状态（在线判断 + 服务端信息）
/// 不依赖 connectivity_plus：用 dart:io 检查是否存在非回环网络接口（零额外依赖）
import 'dart:io';
import '../core/api_client.dart';

class NetworkInfoService {
  /// 是否可访问服务器（以 /api/health 探活为准，比 connectivity 更可靠）
  Future<bool> isServerReachable() async {
    try {
      await ApiClient().get('/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 设备是否有任意网络接口（Wi-Fi/移动数据）
  Future<bool> hasNetwork() async {
    try {
      final ifs = await NetworkInterface.list();
      return ifs.any((n) => n.addresses.isNotEmpty && !n.addresses.first.address.startsWith('127.'));
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> serverNetworkInfo() async {
    try {
      return await ApiClient().get('/network/info');
    } catch (_) {
      return null;
    }
  }
}
