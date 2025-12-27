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

    test('endCall should clear participants and change status to ended', () {
      // Start first
      callProvider.setStatusForTesting(CallStatus.active);

      // Then End
      callProvider.endCall();

      expect(callProvider.status, CallStatus.ended);
      expect(callProvider.participants, isEmpty);
    });

    test('endCall should not throw when participants list is fixed-length', () {
      callProvider.setStatusForTesting(CallStatus.active);
      // Convert to a fixed-length list to reproduce the earlier edge-case
      final fixedParticipants =
          callProvider.participants.toList(growable: false);
      callProvider.setParticipantsForTesting(fixedParticipants);

      expect(() => callProvider.endCall(), returnsNormally);
      expect(callProvider.status, CallStatus.ended);
      expect(callProvider.participants, isEmpty);
    });
  });
}
