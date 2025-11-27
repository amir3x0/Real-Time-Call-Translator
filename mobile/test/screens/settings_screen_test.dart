import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/screens/settings/settings_screen.dart';
import 'package:mobile/providers/settings_provider.dart';
import 'package:mobile/providers/auth_provider.dart';

void main() {
  testWidgets('Settings screen interactions', (WidgetTester tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));

    // Avoid pumpAndSettle because the VoiceRecorderWidget contains a repeating
    // animation (AnimationController.repeat) and that prevents the test from
    // settling. Instead, pump a small duration so the screen builds and move on.
    await tester.pump(const Duration(milliseconds: 300));

    // Check theme toggle control exists
    expect(find.byType(Switch), findsOneWidget);
    // Check language dropdown exists
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    // Check the voice sample section label exists and a logout button is present
    expect(find.text('Voice Sample'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // The VoiceRecorderWidget behavior tested in isolation in its own widget test.
  });
}
