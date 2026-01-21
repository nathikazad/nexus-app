import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_page.dart';
import 'screens/login_page.dart';
import 'screens/home_screen.dart';
import 'screens/models_list_screen.dart';
import 'screens/model_detail_screen.dart';
import 'screens/navigator/model_type_form_screen.dart';
import 'screens/navigator/model_type_selector_screen.dart';
import 'db.dart';
import 'auth.dart';

/// Bootstrap provider that waits for auth and GraphQL client initialization.
/// This ensures the app is fully initialized before showing the main UI.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  // Wait for auth state to be determined
  await ref.watch(authProvider.future);
  
  // Ensure GraphQL client is initialized (if user is logged in)
  // This is a Provider, not FutureProvider, so we just watch it
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
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/models/:modelTypeId',
        builder: (context, state) {
          final modelTypeId = int.parse(state.pathParameters['modelTypeId']!);
          return ModelsListScreen(modelTypeId: modelTypeId);
        },
      ),
      GoRoute(
        path: '/model-detail/:modelId',
        builder: (context, state) {
          final modelId = int.parse(state.pathParameters['modelId']!);
          return ModelDetailScreen(modelId: modelId);
        },
      ),
      GoRoute(
        path: '/model-type-form',
        builder: (context, state) {
          final modelTypeId = state.uri.queryParameters['modelTypeId'];
          return ModelTypeFormScreen(
            modelTypeId: modelTypeId != null ? int.tryParse(modelTypeId) : null,
          );
        },
      ),
      GoRoute(
        path: '/model-type-selector',
        builder: (context, state) => const ModelTypeSelectorScreen(),
      ),
    ],
    redirect: (context, state) {
      final location = state.uri.path;
      
      print('[Router] redirect() called - location: $location');
      print('[Router] bootstrapState.isLoading: ${bootstrapState.isLoading}');
      print('[Router] appStatus: $appStatus');
      
      // If bootstrap is still loading, show splash screen
      if (bootstrapState.isLoading) {
        print('[Router] Bootstrap loading → redirecting to /splash');
        return location == '/splash' ? null : '/splash';
      }
      
      // After bootstrap, use AppStatus to determine redirect
      switch (appStatus) {
        case AppStatus.initializing:
          // Should not happen after bootstrap, but handle gracefully
          print('[Router] AppStatus.initializing → redirecting to /splash');
          return location == '/splash' ? null : '/splash';
          
        case AppStatus.authenticated:
          // User is logged in, redirect to home if on login/splash
          if (location == '/login' || location == '/splash') {
            print('[Router] Authenticated on $location → redirecting to /');
            return '/';
          }
          print('[Router] Authenticated on $location → allowing access');
          return null;
          
        case AppStatus.unauthenticated:
          // User is not logged in, redirect to login
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

