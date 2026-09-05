import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase — keys injected via --dart-define at build time
  await SupabaseClientWrapper.initialize();

  runApp(
    // Riverpod ProviderScope wraps the entire app
    const ProviderScope(
      child: AudiencePulseApp(),
    ),
  );
}

class AudiencePulseApp extends ConsumerWidget {
  const AudiencePulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Audie — AI Social Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
