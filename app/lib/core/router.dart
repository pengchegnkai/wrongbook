/// core/router.dart —— GoRouter 路由（含登录守卫）
/// 守卫规则：
/// - 启动引导（currentUserProvider）未完成：只允许停留 /splash
/// - 未登录：只允许 /splash /login /register /server-config，其余跳 /login
/// - 已登录：不允许停留在 /splash /login /register，自动进 /
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../pages/splash_page.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/server_config_page.dart';
import '../pages/home_page.dart';
import '../pages/question_list_page.dart';
import '../pages/question_detail_page.dart';
import '../pages/ai_analysis_page.dart';
import '../pages/review_page.dart';
import '../pages/charts_page.dart';
import '../pages/knowledge_graph_page.dart';
import '../pages/review_calendar_page.dart';
import '../pages/source_manage_page.dart';
import '../pages/import_export_page.dart';
import '../pages/settings_page.dart';
import '../pages/profile_page.dart';
import '../pages/scan_page.dart';
import '../pages/ocr_review_page.dart';
import '../pages/pending_queue_page.dart';
import '../pages/analysis_history_page.dart';
import '../pages/prompt_template_list_page.dart';
import '../pages/prompt_template_edit_page.dart';
import '../pages/prompt_template_preview_page.dart';
import '../pages/strength_selector_page.dart';
import '../pages/ai_memory_page.dart';
import '../pages/ai_profile_page.dart';
import '../pages/feedback_page.dart';
import '../pages/model_manage_page.dart';
import '../pages/model_download_page.dart';
import '../pages/login_device_manage_page.dart';
import '../pages/qr_scan_page.dart';
import '../widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  const publicPaths = {'/splash', '/login', '/register', '/server-config'};

  final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = ref.read(currentUserProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading) {
        // 启动引导未完成：锁在 splash
        return publicPaths.contains(loc) ? null : '/splash';
      }
      final user = auth.valueOrNull;
      if (user == null) {
        return publicPaths.contains(loc) ? null : '/login';
      }
      if (loc == '/splash' || loc == '/login' || loc == '/register') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/server-config', builder: (_, __) => const ServerConfigPage()),
      GoRoute(path: '/qr-scan', builder: (_, __) => const QrScanPage()),
      // ---- 底部导航壳：首页 / 错题 / 复习 / 我的（各自独立导航栈） ----
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/questions',
              builder: (_, __) => const QuestionListPage(),
              routes: [
                GoRoute(path: 'detail/:id', builder: (_, s) => QuestionDetailPage(id: s.pathParameters['id']!)),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/review', builder: (_, __) => const ReviewPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          ]),
        ],
      ),
      GoRoute(path: '/ai-analysis', builder: (_, s) {
        final extra = s.extra as Map<String, dynamic>?;
        return AiAnalysisPage(questionId: extra?['questionId'] as int?);
      }),
      GoRoute(path: '/review', builder: (_, __) => const ReviewPage()),
      GoRoute(path: '/charts', builder: (_, __) => const ChartsPage()),
      GoRoute(path: '/knowledge-graph', builder: (_, __) => const KnowledgeGraphPage()),
      GoRoute(path: '/review-calendar', builder: (_, __) => const ReviewCalendarPage()),
      GoRoute(path: '/sources', builder: (_, __) => const SourceManagePage()),
      GoRoute(path: '/import-export', builder: (_, __) => const ImportExportPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(path: '/scan', builder: (_, __) => const ScanPage()),
      GoRoute(path: '/ocr-review', builder: (_, __) => const OcrReviewPage()),
      GoRoute(path: '/pending-queue', builder: (_, __) => const PendingQueuePage()),
      GoRoute(path: '/analysis-history', builder: (_, __) => const AnalysisHistoryPage()),
      GoRoute(path: '/prompt-templates', builder: (_, __) => const PromptTemplateListPage()),
      GoRoute(path: '/prompt-templates/edit', builder: (_, s) {
        final extra = s.extra as Map<String, dynamic>?;
        return PromptTemplateEditPage(template: extra?['template']);
      }),
      GoRoute(path: '/prompt-templates/preview', builder: (_, s) {
        final extra = s.extra as Map<String, dynamic>?;
        return PromptTemplatePreviewPage(template: extra?['template']);
      }),
      GoRoute(path: '/strength-selector', builder: (_, __) => const StrengthSelectorPage()),
      GoRoute(path: '/ai-memory', builder: (_, __) => const AiMemoryPage()),
      GoRoute(path: '/ai-profile', builder: (_, __) => const AiProfilePage()),
      GoRoute(path: '/feedback', builder: (_, s) {
        final extra = s.extra as Map<String, dynamic>?;
        return FeedbackPage(questionId: extra?['questionId']);
      }),
      GoRoute(path: '/model-manage', builder: (_, __) => const ModelManagePage()),
      GoRoute(path: '/model-download', builder: (_, __) => const ModelDownloadPage()),
      GoRoute(path: '/devices', builder: (_, __) => const LoginDeviceManagePage()),
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(title: const Text('页面不存在')),
      body: Center(child: Text('路径错误: ${state.error?.toString() ?? ''}')),
    ),
  );

  // 登录态变化 → 重新评估守卫：redirect 在每次导航时 ref.read 当前状态，
  // 配合登录/登出后显式 context.go 即可完成重定向（无需 listenManual）。
  return router;
});

/// 主题模式（深色模式支持）
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
