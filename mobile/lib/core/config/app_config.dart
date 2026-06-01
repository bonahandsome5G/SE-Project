import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const appName = 'Lapor Infrastruktur';

  static String get supabaseUrl => _readEnv(
        'SUPABASE_URL',
        const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://filppwcwnspbdnjesggp.supabase.co',
        ),
      );

  static String get supabaseAnonKey => _readEnv(
        'SUPABASE_ANON_KEY',
        const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  static const reportPhotoBucket = 'report-photos';
  static const mapUserAgent = 'com.example.lapor_komdigi_frontend';

  static String get apiBaseUrl => _readEnv(
        'API_BASE_URL',
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:3000/api',
        ),
      );

  static String _readEnv(String key, String fallback) {
    final value = dotenv.maybeGet(key);

    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }
}
