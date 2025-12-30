import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/voice_recorder_widget.dart';

void main() {
  testWidgets('VoiceRecorderWidget shows upload button after recording',
      (WidgetTester tester) async {
    // Give the widget a constrained size to avoid overflow in tests
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SizedBox(
                    width: 600, height: 1200, child: VoiceRecorderWidget())))));

    // Initially upload button should not be present
    expect(find.byKey(const Key('voice-upload-button')), findsNothing);

    // Programmatically set the widget's internal state to reviewing for the test
    final dynamic state = tester.state(find.byType(VoiceRecorderWidget));
    state.setStateForTesting(RecorderState.reviewing);
    await tester.pump(const Duration(milliseconds: 200));

    // Now the Upload pill should be visible
    expect(find.byKey(const Key('voice-upload-button')), findsOneWidget);
    // And it should contain the 'Upload' label
    expect(
        find.descendant(
            of: find.byKey(const Key('voice-upload-button')),
            matching: find.text('Upload')),
        findsOneWidget);
  });
}
