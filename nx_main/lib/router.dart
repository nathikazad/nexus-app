import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nx_db/nx_db.dart';
import 'package:nexus_voice_assistant/data/providers.dart';
import 'package:nexus_voice_assistant/features/auth/login_page.dart';
import 'package:nexus_voice_assistant/features/home/home_page.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/model_detail_page.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/model_type_detail_page.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/model_type_form_page.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/model_type_selector_page.dart';
import 'package:nexus_voice_assistant/features/schema_navigator/models_list_page.dart';
import 'package:nexus_voice_assistant/features/splash/splash_page.dart';

/// Bootstrap provider that waits for auth and GraphQL client initialization.
/// This ensures the app is fully initialized before showing the main UI.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(authProvider.future);
  ref.watch(graphqlClientProvider);
}, name: 'appBootstrapProvider');

/// Router provider that handles navigation based on AppStatus.
/// Prevents flicker by checking bootstrap status first.
final routerProvider = Provider<GoRouter>((ref) {
  final bootstrapState = ref.watch(appBootstrapProvider);
  final appStatus = ref.watch(appStatusProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          onLoginSuccess: (urls) {
            final container = ProviderScope.containerOf(context);
            container.read(bleBackgroundServiceProvider).disconnectSocket();
            container.read(bleBackgroundServiceProvider).connectSocket(urls.sockWs);
          },
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/model-type/:modelTypeId',
        builder: (context, state) {
          final modelTypeId = int.parse(state.pathParameters['modelTypeId']!);
          return ModelTypeDetailPage(modelTypeId: modelTypeId);
        },
      ),
      GoRoute(
        path: '/models/:modelTypeId',
        builder: (context, state) {
          final modelTypeId = int.parse(state.pathParameters['modelTypeId']!);
          return ModelsListPage(modelTypeId: modelTypeId);
        },
      ),
      GoRoute(
        path: '/model-detail/:modelId',
        builder: (context, state) {
          final modelId = int.parse(state.pathParameters['modelId']!);
          return ModelDetailPage(modelId: modelId);
        },
      ),
      GoRoute(
        path: '/model-type-form',
        builder: (context, state) {
          final modelTypeId = state.uri.queryParameters['modelTypeId'];
          return ModelTypeFormPage(
            modelTypeId: modelTypeId != null ? int.tryParse(modelTypeId) : null,
          );
        },
      ),
      GoRoute(
        path: '/model-type-selector',
        builder: (context, state) => const ModelTypeSelectorPage(),
      ),
    ],
    redirect: (context, state) {
      final location = state.uri.path;

      print('[Router] redirect() called - location: $location');
      print('[Router] bootstrapState.isLoading: ${bootstrapState.isLoading}');
      print('[Router] appStatus: $appStatus');

      if (bootstrapState.isLoading) {
        print('[Router] Bootstrap loading → redirecting to /splash');
        return location == '/splash' ? null : '/splash';
      }

      switch (appStatus) {
        case AppStatus.initializing:
          print('[Router] AppStatus.initializing → redirecting to /splash');
          return location == '/splash' ? null : '/splash';

        case AppStatus.authenticated:
          if (location == '/login' || location == '/splash') {
            print('[Router] Authenticated on $location → redirecting to /');
            return '/';
          }
          print('[Router] Authenticated on $location → allowing access');
          return null;

        case AppStatus.unauthenticated:
          if (location == '/login') {
            print('[Router] Unauthenticated on /login → allowing access');
            return null;
          }
          print('[Router] Unauthenticated on $location → redirecting to /login');
          return '/login';
      }
    },
  );
}, name: 'routerProvider');
