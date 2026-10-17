import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/local_record_provider.dart';
import 'providers/network_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 启动时恢复持久化的服务器地址（否则每次重启都要重输）
  await Hive.initFlutter();
  final settings = await Hive.openBox('settings');
  final saved = settings.get('baseUrl') as String?;
  if (saved != null && saved.isNotEmpty) {
    AppConfig.setBaseUrl(saved);
  }
  runApp(const ProviderScope(child: CuotiApp()));
}

class CuotiApp extends ConsumerWidget {
  const CuotiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    // token 彻底失效（401 刷新失败被拦截器清凭据）时：
    // 同步登录态为未登录并跳登录页，否则守卫仍认为已登录、页面全部请求失败卡死
    AuthInterceptor.onCredentialsInvalid = () {
      ref.read(currentUserProvider.notifier).forceSignOut();
      router.go('/login');
    };
    // 断网期间入队的操作（如离线建错题）在网络恢复时自动上传；
    // 失败静默（队列保留，下次恢复再试）
    NetworkStatus._offline.addListener(() {
      if (!NetworkStatus.isOffline) {
        ref.read(localRecordProvider.notifier).syncNow().catchError((_) => 0);
      }
    });
    return MaterialApp.router(
      title: '错题本',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
