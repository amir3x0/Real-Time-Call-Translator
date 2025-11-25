import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/participant.dart'; // וודא שזה המודל הנכון (CallParticipant או Participant)
import 'package:mobile/widgets/call/participant_card.dart';

// אם המודל שלך הוא CallParticipant תשתמש בו, כאן הנחתי שימוש במודל שיצרנו במימוש הקודם
void main() {
  testWidgets('ParticipantCard displays correct info', (WidgetTester tester) async {
    // 1. Setup Mock Participant
    final mockParticipant = CallParticipant(
      id: 'p1',
      callId: 'c1',
      userId: 'u1',
      targetLanguage: 'en',
      speakingLanguage: 'he', // Should show Israeli flag
      isMuted: true, // Should show mute icon
      isSpeakerOn: true,
      useVoiceCloning: false,
      joinedAt: DateTime.now(),
      createdAt: DateTime.now(),
      isConnected: true,
      connectionQuality: 'excellent',
    );

    // 2. Build Widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParticipantCard(
            participant: mockParticipant,
            mockName: 'Amir',
          ),
        ),
      ),
    );

    // 3. Assertions
    // Check Name
    expect(find.text('Amir'), findsOneWidget);
    
    // Check Flag (Hebrew = 🇮🇱)
    expect(find.text('🇮🇱'), findsOneWidget);

    // Check Mute Icon exists
    expect(find.byIcon(Icons.mic_off), findsOneWidget);
    
    // Check Avatar Initial
    expect(find.text('A'), findsOneWidget);
  });
}