import 'package:flutter/material.dart';
import '../models/call.dart';
import '../models/participant.dart';

class CallProvider with ChangeNotifier {
  CallStatus _status = CallStatus.pending;
  List<CallParticipant> _participants = [];
  String? _activeSessionId;
  final String _liveTranscription = "המתן, השרת מתרגם..."; // Mock subtitle

  CallStatus get status => _status;
  List<CallParticipant> get participants => _participants;
  String get liveTranscription => _liveTranscription;

  // Start a mock call
  void startMockCall() {
    _status = CallStatus.active;
    _activeSessionId = "session_123";
    
    // Create Mock Participants
    _participants = [
      CallParticipant(
        id: 'p1',
        callId: 'c1',
        userId: 'u1',
        targetLanguage: 'he',
        speakingLanguage: 'en',
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isConnected: true,
        connectionQuality: 'excellent', // Green
        isMuted: false,
      ),
      CallParticipant(
        id: 'p2',
        callId: 'c1',
        userId: 'u2',
        targetLanguage: 'en',
        speakingLanguage: 'ru',
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isConnected: true,
        connectionQuality: 'good', // Light Green
        isMuted: true,
      ),
    ];
    
    notifyListeners();
  }

  void endCall() {
    _status = CallStatus.ended;
    _participants.clear();
    _activeSessionId = null;
    notifyListeners();
  }

  void toggleMute() {
    // Logic to toggle mute would go here
    notifyListeners();
  }
}