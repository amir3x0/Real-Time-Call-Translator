import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/call_provider.dart';
import 'package:mobile/screens/call/active_call_screen.dart';

void main() {
  testWidgets('ActiveCallScreen shows participants and live transcription', (WidgetTester tester) async {
    final callProv = CallProvider();

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider.value(
        value: callProv,
        child: const ActiveCallScreen(),
      ),
    ));

    // Initially the call is not active
    expect(find.byType(ActiveCallScreen), findsOneWidget);

    // Start the mock call programmatically
    callProv.startMockCall();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // After starting there should be participant cards
    expect(find.byType(GridView), findsOneWidget);

    // Wait for mock ws messages (2s period) and assert transcription changed
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    // Provider's liveTranscription should have updated from the initial value
    expect(callProv.liveTranscription != 'המתן, השרת מתרגם...', true);
    // The screen should display the current provider transcription
    expect(find.textContaining(callProv.liveTranscription), findsOneWidget);

    // Clean up the mock call so timers are cancelled
    callProv.endCall();
    await tester.pumpAndSettle();
  });
}
