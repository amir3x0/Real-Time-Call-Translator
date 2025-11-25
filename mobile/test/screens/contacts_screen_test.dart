import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/contacts_provider.dart';
import 'package:mobile/providers/call_provider.dart';
import 'package:mobile/screens/contacts/contacts_screen.dart';

void main() {
  testWidgets('Contacts screen displays list and add/delete', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ContactsProvider()),
          ChangeNotifierProvider(create: (_) => CallProvider()),
        ],
        child: MaterialApp(home: const ContactsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Expect mock contacts loaded
    expect(find.byType(ListTile), findsWidgets);

    // Enter new contact
    await tester.enterText(find.byType(TextField), 'New Contact');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Now the new contact must exist
    expect(find.text('New Contact'), findsOneWidget);
  });
}
