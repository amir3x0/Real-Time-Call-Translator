import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('LoginScreen flow test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // 1. Setup Provider & Screen
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          home: LoginScreen(),
          routes: {
            '/home': (context) => const Scaffold(body: Text("Home Screen")),
          },
        ),
      ),
    );

    // 2. Verify Initial UI
    expect(find.textContaining('Call Translator'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Phone & Password
    expect(find.text('Sign In'), findsOneWidget);

    // 3. Enter Text
    await tester.enterText(find.widgetWithText(TextField, 'Phone'), '052-111-2222');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');

    // 4. Tap Sign In
    await tester.tap(find.text('Sign In'));
    
    // 5. Rebuild UI after state change (Loading indicator should appear)
    await tester.pump(); 
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 6. Wait for async login work to complete without waiting on endless animations
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // 7. Verify Navigation to Home (Checking if "Home Screen" text is present)
    expect(find.text('Home Screen'), findsOneWidget);

    // 8. (Create account navigation is covered in a dedicated test.)
  });
}