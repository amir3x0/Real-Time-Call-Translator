import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/screens/auth/login_screen.dart';
import '../test_helpers.dart';

void main() {
  testWidgets('Login screen has Create Account button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(FakeAuthService()),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    // Allow animations to play
    await tester.pump(const Duration(milliseconds: 2000));

    final createAccountButton = find.byKey(const Key('login-create-account'));
    expect(createAccountButton, findsOneWidget);
  });
}
