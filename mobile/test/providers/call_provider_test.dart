import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/call_provider.dart';
import 'package:mobile/models/call.dart';

void main() {
  group('CallProvider Tests', () {
    late CallProvider callProvider;

    setUp(() {
      callProvider = CallProvider();
    });

    test('Initial status should be pending', () {
      expect(callProvider.status, CallStatus.pending);
      expect(callProvider.participants, isEmpty);
    });

    test('startMockCall should add participants and change status to active', () {
      callProvider.startMockCall();

      expect(callProvider.status, CallStatus.active);
      expect(callProvider.participants.length, 4); // startMockCall adds 4 mock participants
      expect(callProvider.liveTranscription, contains('מתרגם'));
    });

    test('endCall should clear participants and change status to ended', () {
      // Start first
      callProvider.startMockCall();
      
      // Then End
      callProvider.endCall();

      expect(callProvider.status, CallStatus.ended);
      expect(callProvider.participants, isEmpty);
    });
  });
}