import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/call_provider.dart';
import 'package:mobile/models/call.dart';

import 'package:mobile/data/websocket/websocket_service.dart';
import 'package:mobile/data/services/call_api_service.dart';

// Manual Mocks
class MockWebSocketService extends WebSocketService {
  @override
  Stream<WSMessage> get messages => const Stream.empty();

  @override
  Future<void> disconnect() async {}
}

class MockCallApiService extends CallApiService {
  // Add methods if needed for testing, or just use as is
}

void main() {
  group('CallProvider Tests', () {
    late CallProvider callProvider;
    late MockWebSocketService mockWsService;
    late MockCallApiService mockApiService;

    setUp(() {
      mockWsService = MockWebSocketService();
      mockApiService = MockCallApiService();
      callProvider =
          CallProvider(wsService: mockWsService, apiService: mockApiService);
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
