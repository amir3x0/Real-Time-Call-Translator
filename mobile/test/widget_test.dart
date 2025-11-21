// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App loads and displays welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CallTranslatorApp());

    // Verify that our welcome text is displayed.
    expect(find.text('Welcome to Call Translator'), findsOneWidget);
    expect(find.text('Break language barriers with AI'), findsOneWidget);
    expect(find.byIcon(Icons.translate), findsOneWidget);

    // Tap the test button and trigger a frame.
    await tester.tap(find.text('Test App'));
    await tester.pump();

    // Verify that the snackbar appears.
    expect(find.text('Flutter app is running! ✅'), findsOneWidget);
  });
}
