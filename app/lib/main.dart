import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'core/theme.dart';

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
