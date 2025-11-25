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

    await tester.pumpAndSettle();

    // Check theme toggle control exists
    expect(find.byType(Switch), findsOneWidget);
    // Check language dropdown exists
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    // Check upload button exists
    expect(find.text('Upload'), findsOneWidget);
  });
}
