import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/screens/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen flow test', (WidgetTester tester) async {
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
    expect(find.text('Call Translator'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Email & Password
    expect(find.text('Login'), findsOneWidget);

    // 3. Enter Text
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'user@demo.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');

    // 4. Tap Login
    await tester.tap(find.text('Login'));
    
    // 5. Rebuild UI after state change (Loading indicator should appear)
    await tester.pump(); 
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 6. Wait for Future.delayed (1 second in mock service)
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 7. Verify Navigation to Home (Checking if "Home Screen" text is present)
    expect(find.text('Home Screen'), findsOneWidget);
  });
}