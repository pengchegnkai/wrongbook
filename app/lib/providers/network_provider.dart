/// providers/network_provider.dart —— 网络状态（离线检测）
///
/// 纯 Dart 实现，不引入任何原生插件（避免 ML Kit 那类 "native peer collected" 生命周期崩溃）：
/// - ApiClient 拦截器在「连接失败/超时」时置 offline = true
/// - 任意请求成功（onResponse）时置 offline = false
///
/// 关键语义：断网只影响"能不能发请求"，绝不视为"未登录"，绝不因此清除 token。
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkStatus {
  NetworkStatus._();

  static final ValueNotifier<bool> _offline = ValueNotifier<bool>(false);

  static bool get isOffline => _offline.value;

  static void setOffline(bool value) {
    if (_offline.value != value) _offline.value = value;
  }
}

/// 页面读取离线状态：ValueListenableBuilder 实时刷新（断网/恢复即时生效）
final networkOfflineProvider = Provider<ValueListenable<bool>>((ref) => NetworkStatus._offline);
