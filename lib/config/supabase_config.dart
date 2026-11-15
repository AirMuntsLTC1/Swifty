/// Supabase connection settings.
///
/// The anon key is designed to be public (it ships inside every app build).
/// NEVER put the service_role / secret key in the app.
///
/// Either edit the two defaults below, or pass them at build time:
///   flutter build apk --release \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT-REF.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR-ANON-KEY',
  );

  /// Name of the custom Edge Function that handles login, sign-up and password reset.
  static const String authFunction = 'email-code-auth';

  static bool get isConfigured =>
      !url.contains('YOUR-PROJECT-REF') && !anonKey.contains('YOUR-ANON-KEY');
}




