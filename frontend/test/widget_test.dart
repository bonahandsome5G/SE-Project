import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lapor_komdigi_frontend/core/config/app_config.dart';
import 'package:lapor_komdigi_frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString: '''
SUPABASE_URL=https://filppwcwnspbdnjesggp.supabase.co
SUPABASE_ANON_KEY=test-anon-key
API_BASE_URL=http://10.0.2.2:3000/api
''',
    );
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  });

  testWidgets('shows citizen auth screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Masuk Warga'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
