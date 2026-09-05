import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../services/supabase_service.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/ingestion_status/ingestion_status_screen.dart';

/// GoRouter with auth guard.
/// Unauthenticated users are redirected to /login.
/// Authenticated users visiting /login are redirected to /dashboard.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppConstants.routeDashboard,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final user = SupabaseService.instance.currentUser;
      final isLoggedIn = user != null;
      final isOnLogin = state.matchedLocation == AppConstants.routeLogin;

      if (!isLoggedIn && !isOnLogin) {
        return AppConstants.routeLogin;
      }
      if (isLoggedIn && isOnLogin) {
        return AppConstants.routeDashboard;
      }
      return null; // no redirect needed
    },
    refreshListenable: _AuthChangeNotifier(),
    routes: [
      GoRoute(
        path: AppConstants.routeLogin,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppConstants.routeDashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppConstants.routeIngestion,
        name: 'ingestion',
        builder: (context, state) => const IngestionStatusScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.error}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  );
});

/// Bridges Supabase auth state changes to GoRouter's [refreshListenable].
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    SupabaseService.instance.authStateChanges.listen((_) => notifyListeners());
  }
}
