import 'dart:async';

import '../../models/call_session.dart';
import '../../models/participant.dart';
import '../../models/contact.dart';
import 'mock_data.dart';

/// Mock repository for call operations.
/// 
/// Simulates backend API calls for creating and managing calls.
class MockCallRepository {
  final String _currentUserId;
  CallSession? _activeCall;
  final List<CallSession> _callHistory = [];

  MockCallRepository({required String currentUserId})
      : _currentUserId = currentUserId;

  /// Create a new call with selected contacts
  Future<CallSession> createCall(List<Contact> selectedContacts) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final currentUser = MockData.findUserById(_currentUserId);
    if (currentUser == null) {
      throw Exception('Current user not found');
    }

    final participants = <CallParticipant>[];
    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

    // Add current user as first participant
    participants.add(CallParticipant(
      id: 'p0',
      callId: callId,
      userId: currentUser.id,
      displayName: currentUser.fullName,
      speakingLanguage: currentUser.primaryLanguage,
      targetLanguage: currentUser.primaryLanguage,
      connectionQuality: 'excellent',
      isMuted: false,
      joinedAt: DateTime.now(),
      createdAt: DateTime.now(),
      isConnected: true,
    ));

    // Add selected contacts as participants
    for (var i = 0; i < selectedContacts.length; i++) {
      final contact = selectedContacts[i];
      participants.add(CallParticipant(
        id: 'p${i + 1}',
        callId: callId,
        userId: contact.contactUser.id,
        displayName: contact.displayName,
        speakingLanguage: contact.language,
        targetLanguage: currentUser.primaryLanguage, // Translate to current user's language
        connectionQuality: MockData.randomWeightedConnectionQuality(),
        isMuted: false,
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isConnected: true,
      ));
    }

    _activeCall = CallSession(
      id: callId,
      sessionId: sessionId,
      status: CallStatus.active,
      initiatorId: _currentUserId,
      participants: participants,
      maxParticipants: 4,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
    );

    return _activeCall!;
  }

  /// Create a call from user IDs (alternative method)
  Future<CallSession> createCallFromUserIds(List<String> participantUserIds) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final currentUser = MockData.findUserById(_currentUserId);
    if (currentUser == null) {
      throw Exception('Current user not found');
    }

    final participants = <CallParticipant>[];
    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

    // Add current user as first participant
    participants.add(CallParticipant(
      id: 'p0',
      callId: callId,
      userId: currentUser.id,
      displayName: currentUser.fullName,
      speakingLanguage: currentUser.primaryLanguage,
      targetLanguage: currentUser.primaryLanguage,
      connectionQuality: 'excellent',
      isMuted: false,
      joinedAt: DateTime.now(),
      createdAt: DateTime.now(),
      isConnected: true,
    ));

    // Add other participants
    for (var i = 0; i < participantUserIds.length; i++) {
      final user = MockData.findUserById(participantUserIds[i]);
      if (user != null) {
        participants.add(CallParticipant(
          id: 'p${i + 1}',
          callId: callId,
          userId: user.id,
          displayName: user.fullName,
          speakingLanguage: user.primaryLanguage,
          targetLanguage: currentUser.primaryLanguage,
          connectionQuality: MockData.randomWeightedConnectionQuality(),
          isMuted: false,
          joinedAt: DateTime.now(),
          createdAt: DateTime.now(),
          isConnected: true,
        ));
      }
    }

    _activeCall = CallSession(
      id: callId,
      sessionId: sessionId,
      status: CallStatus.active,
      initiatorId: _currentUserId,
      participants: participants,
      maxParticipants: 4,
      createdAt: DateTime.now(),
      startedAt: DateTime.now(),
    );

    return _activeCall!;
  }

  /// End the current call
  Future<void> endCall(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (_activeCall != null) {
      final endedCall = _activeCall!.copyWith(
        status: CallStatus.ended,
        endedAt: DateTime.now(),
        durationSeconds: _activeCall!.liveDuration.inSeconds,
      );
      _callHistory.add(endedCall);
      _activeCall = null;
    }
  }

  /// Toggle mute for current user
  Future<void> toggleMute(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (_activeCall != null) {
      final updatedParticipants = _activeCall!.participants.map((p) {
        if (p.userId == _currentUserId) {
          return p.copyWith(isMuted: !p.isMuted);
        }
        return p;
      }).toList();

      _activeCall = _activeCall!.copyWith(participants: updatedParticipants);
    }
  }

  /// Get active call
  CallSession? get activeCall => _activeCall;

  /// Get call history
  Future<List<CallSession>> getCallHistory() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_callHistory.reversed.toList());
  }

  /// Get current user's participant in the active call
  CallParticipant? getCurrentUserParticipant() {
    if (_activeCall == null) return null;
    return _activeCall!.participants.cast<CallParticipant?>().firstWhere(
      (p) => p!.userId == _currentUserId,
      orElse: () => null,
    );
  }
}
