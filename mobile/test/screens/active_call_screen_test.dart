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
    // Avoid pumpAndSettle which times out if ongoing timers/animations are present;
    // instead advance the test clock by a small period and then perform small pumps.
    await tester.pump(const Duration(milliseconds: 300));

    // After starting there should be participant cards
    expect(find.byType(GridView), findsOneWidget);

    // Wait for mock WS messages (2s period) and assert transcription changed.
    // Advance the clock and pump to let the async mock timers run.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));

    // Ensure provider has an active speaker and a live transcription
    expect(callProv.liveTranscription != 'המתן, השרת מתרגם...', true);
    expect(callProv.activeSpeakerId != null, true);

    // Construct the exact subtitle string displayed at the bottom of the screen
    final active = callProv.participants.firstWhere((p) => p.id == callProv.activeSpeakerId);
    final expectedSubtitle = '${active.displayName}: ${callProv.liveTranscription}';

    // Assert the bottom subtitle (which includes speaker name) is present exactly once
    final subtitleFinder = find.byKey(const Key('live-subtitle'));
    expect(subtitleFinder, findsOneWidget);
    final subtitleText = (tester.widget<Text>(subtitleFinder)).data;
    expect(subtitleText, expectedSubtitle);

    // Clean up the mock call so timers are cancelled
    callProv.endCall();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
