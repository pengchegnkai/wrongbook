/// widgets/main_shell.dart —— M3 底部导航壳（毛玻璃 NavigationBar）
/// 四个分支：首页 / 错题 / 复习 / 我的。子页面仍在导航栈之上 push。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'modern_card.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (Icons.home_outlined, Icons.home, '首页'),
    (Icons.menu_book_outlined, Icons.menu_book, '错题'),
    (Icons.style_outlined, Icons.style, '复习'),
    (Icons.person_outline, Icons.person, '我的'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      // 毛玻璃底栏：内容从其下滚过时呈半透明模糊（845 上 sigma=10 可保持流畅）
      extendBody: true,
      bottomNavigationBar: GlassContainer(
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 64,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.$1, size: 24),
                  selectedIcon: Icon(d.$2, size: 26),
                  label: d.$3,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
