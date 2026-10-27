import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/channels/channel_detail_page.dart';
import '../features/channels/channels_page.dart';
import '../features/posts/post_detail_page.dart';
import '../features/posts/post_form_page.dart';
import '../features/posts/post_list_page.dart';
import '../features/settings/settings_page.dart';
import '../features/social_accounts/social_accounts_page.dart';
import '../logic/post_list_params.dart';
import '../state/auth_controller.dart';
import 'app_shell.dart';
import 'navigator_keys.dart';

bool _isAuthPath(String path) => path == '/login' || path == '/register';

/// Routes mirror the web app. Signed-out users only reach the auth screens; anything unknown goes
/// to the channels list.
final routerProvider = Provider<GoRouter>((ref) {
  final authChanges = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/channels',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final signedIn = ref.read(authProvider) != null;
      final path = state.uri.path;
      if (!signedIn && !_isAuthPath(path)) {
        return '/login';
      }
      if (signedIn && _isAuthPath(path)) {
        return '/channels';
      }
      return null;
    },
    onException: (context, state, router) => router.go('/channels'),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/channels'),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/channels',
                builder: (_, _) => const ChannelsPage(),
                routes: [
                  GoRoute(
                    path: ':channelId',
                    builder: (_, state) => ChannelDetailPage(
                      channelId: state.pathParameters['channelId']!,
                      initialPage: parsePageParam(state.uri.queryParameters['page']),
                      initialSize: parseSizeParam(state.uri.queryParameters['size']),
                    ),
                    routes: [
                      GoRoute(
                        path: 'posts',
                        builder: (_, state) => PostListPage(
                          channelId: state.pathParameters['channelId']!,
                          initialPage: parsePageParam(state.uri.queryParameters['page']),
                          initialSize: parseSizeParam(state.uri.queryParameters['size']),
                        ),
                      ),
                      // The editor takes the whole screen, so it sits above the navigation bar.
                      GoRoute(
                        path: 'posts/new',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => PostFormPage(channelId: state.pathParameters['channelId']!),
                      ),
                      GoRoute(
                        path: 'posts/:postId',
                        builder: (_, state) => PostDetailPage(
                          channelId: state.pathParameters['channelId']!,
                          postId: state.pathParameters['postId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'posts/:postId/edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, state) => PostFormPage(
                          channelId: state.pathParameters['channelId']!,
                          postId: state.pathParameters['postId'],
                        ),
                      ),
                      GoRoute(
                        path: 'social-accounts',
                        builder: (_, state) => SocialAccountsPage(channelId: state.pathParameters['channelId']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsPage())],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
