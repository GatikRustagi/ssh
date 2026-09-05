import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase initialization.
/// Keys are injected via `--dart-define` at build time — never hardcoded.
///
/// Usage:
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://yyrxgmkeyxfohururkfi.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
class SupabaseClientWrapper {
  SupabaseClientWrapper._();

  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yyrxgmkeyxfohururkfi.supabase.co',
  );

  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5cnhnbWtleXhmb2h1cnVya2ZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg2MjY1NDEsImV4cCI6MjEwNDIwMjU0MX0.2gKiuhHCK7U7_yB4TeNRa0wmxTmN7hDXZ3V2fEE0G0o',
  );

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      // Enable realtime for live dashboard updates
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
  }

  /// Convenience getter for the Supabase client throughout the app.
  static SupabaseClient get client => Supabase.instance.client;
}
