// Smoke test: the app boots and shows the login page when unauthenticated.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/app.dart';
import 'package:gate_closes/core/config/app_config.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the login page when unauthenticated', (tester) async {
    // Tests don't run bootstrap(), so set the active config manually.
    AppConfig.instance = const AppConfig.dev();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });
}
