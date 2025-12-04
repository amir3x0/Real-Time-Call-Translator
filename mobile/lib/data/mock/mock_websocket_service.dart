import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/transcription_entry.dart';
import '../../models/participant.dart';
import 'mock_data.dart';

/// WebSocket message types
enum WebSocketMessageType {
  /// Connection established
  connected,
  /// Audio chunk received from participant
  audio,
  /// Transcription result
  transcription,
  /// Translation result (transcription + translation)
  translation,
  /// Participant state changed (mute, speaking, etc.)
  participantState,
  /// Call state changed
  callState,
  /// Error message
  error,
  /// Ping/pong for keepalive
  ping,
  pong,
}

/// Simulated WebSocket message
class MockWebSocketMessage {
  final WebSocketMessageType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  const MockWebSocketMessage({
    required this.type,
    required this.payload,
    required this.timestamp,
  });

  factory MockWebSocketMessage.transcription(TranscriptionEntry entry) {
    return MockWebSocketMessage(
      type: WebSocketMessageType.translation,
      payload: entry.toJson(),
      timestamp: DateTime.now(),
    );
  }

  factory MockWebSocketMessage.participantState({
    required String participantId,
    required bool isSpeaking,
    required bool isMuted,
    double? speakingEnergy,
  }) {
    return MockWebSocketMessage(
      type: WebSocketMessageType.participantState,
      payload: {
        'participant_id': participantId,
        'is_speaking': isSpeaking,
        'is_muted': isMuted,
        'speaking_energy': speakingEnergy ?? 0.0,
      },
      timestamp: DateTime.now(),
    );
  }

  factory MockWebSocketMessage.connected(String sessionId) {
    return MockWebSocketMessage(
      type: WebSocketMessageType.connected,
      payload: {'session_id': sessionId},
      timestamp: DateTime.now(),
    );
  }

  factory MockWebSocketMessage.error(String message) {
    return MockWebSocketMessage(
      type: WebSocketMessageType.error,
      payload: {'error': message},
      timestamp: DateTime.now(),
    );
  }
}

/// Mock WebSocket Service for simulating real-time call communication.
/// 
/// This service simulates:
/// - Connection/disconnection lifecycle
/// - Periodic transcription messages from participants
/// - Speaking state changes (who is currently talking)
/// - Participant state updates
/// 
/// Usage:
/// ```dart
/// final service = MockWebSocketService();
/// await service.connect('session_123');
/// service.messageStream.listen((msg) {
///   // Handle incoming messages
/// });
/// ```
class MockWebSocketService {
  // Stream controllers
  final StreamController<MockWebSocketMessage> _messageController = 
      StreamController<MockWebSocketMessage>.broadcast();
  
  // State
  String? _sessionId;
  bool _isConnected = false;
  Timer? _transcriptionTimer;
  Timer? _speakingTimer;
  int _messageIndex = 0;
  
  // Participants in the current call
  List<CallParticipant> _participants = [];
  String? _currentSpeakerId;

  // Configuration
  final Duration transcriptionInterval;
  final Duration speakingChangeInterval;

  /// Stream of incoming WebSocket messages
  Stream<MockWebSocketMessage> get messageStream => _messageController.stream;

  /// Whether the service is connected
  bool get isConnected => _isConnected;

  /// Current session ID
  String? get sessionId => _sessionId;

  MockWebSocketService({
    this.transcriptionInterval = const Duration(seconds: 3),
    this.speakingChangeInterval = const Duration(seconds: 5),
  });

  /// Connect to a mock WebSocket session
  Future<bool> connect(String sessionId, {List<CallParticipant>? participants}) async {
    if (_isConnected) {
      debugPrint('MockWebSocket: Already connected');
      return false;
    }

    _sessionId = sessionId;
    _participants = participants ?? [];
    
    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    _isConnected = true;
    _messageIndex = 0;
    
    // Send connected message
    _messageController.add(MockWebSocketMessage.connected(sessionId));
    
    // Start simulation timers
    _startTranscriptionSimulation();
    _startSpeakingSimulation();
    
    debugPrint('MockWebSocket: Connected to session $sessionId');
    return true;
  }

  /// Disconnect from the WebSocket session
  Future<void> disconnect() async {
    _stopTimers();
    
    if (_isConnected) {
      _isConnected = false;
      _sessionId = null;
      _participants = [];
      _currentSpeakerId = null;
      debugPrint('MockWebSocket: Disconnected');
    }
  }

  /// Set participants for the call
  void setParticipants(List<CallParticipant> participants) {
    _participants = participants;
  }

  /// Send a mock audio chunk (simulates user speaking)
  void sendAudioChunk(List<int> audioData) {
    if (!_isConnected) return;
    // In real implementation, this would send audio to backend
    debugPrint('MockWebSocket: Sent audio chunk (${audioData.length} bytes)');
  }

  /// Send control message (mute, unmute, etc.)
  void sendControlMessage(String action, {Map<String, dynamic>? data}) {
    if (!_isConnected) return;
    debugPrint('MockWebSocket: Control message - $action');
  }

  // ========== Private Methods ==========

  void _startTranscriptionSimulation() {
    _transcriptionTimer = Timer.periodic(transcriptionInterval, (_) {
      if (!_isConnected || _participants.isEmpty) return;
      _emitMockTranscription();
    });
  }

  void _startSpeakingSimulation() {
    _speakingTimer = Timer.periodic(speakingChangeInterval, (_) {
      if (!_isConnected || _participants.isEmpty) return;
      _rotateSpeaker();
    });
  }

  void _stopTimers() {
    _transcriptionTimer?.cancel();
    _transcriptionTimer = null;
    _speakingTimer?.cancel();
    _speakingTimer = null;
  }

  void _emitMockTranscription() {
    if (_participants.isEmpty) return;

    // Get mock transcription messages
    const messages = MockData.transcriptionMessages;
    if (messages.isEmpty) return;

    // Pick next message in sequence
    final msgData = messages[_messageIndex % messages.length];
    _messageIndex++;

    // Pick a random participant (not the current user)
    final otherParticipants = _participants
        .where((p) => p.userId != MockData.currentMockUser.id)
        .toList();
    
    if (otherParticipants.isEmpty) return;

    final speaker = otherParticipants[_messageIndex % otherParticipants.length];
    final currentUser = MockData.currentMockUser;

    // Create transcription entry
    final entry = TranscriptionEntry(
      participantId: speaker.userId,
      participantName: speaker.displayName,
      originalText: msgData['text'] ?? '',
      translatedText: msgData['translation'] ?? msgData['text'] ?? '',
      sourceLanguage: speaker.speakingLanguage,
      targetLanguage: currentUser.primaryLanguage,
      timestamp: DateTime.now(),
      confidence: 92.0 + (_messageIndex % 8), // 92-99% confidence
    );

    _messageController.add(MockWebSocketMessage.transcription(entry));
    
    // Also update speaking state
    _setSpeaker(speaker.userId);
  }

  void _rotateSpeaker() {
    if (_participants.isEmpty) return;

    // Pick next speaker
    final otherParticipants = _participants
        .where((p) => p.userId != MockData.currentMockUser.id)
        .toList();
    
    if (otherParticipants.isEmpty) return;

    final nextIndex = (_messageIndex) % otherParticipants.length;
    final nextSpeaker = otherParticipants[nextIndex];
    
    _setSpeaker(nextSpeaker.userId);
  }

  void _setSpeaker(String speakerId) {
    // Clear previous speaker
    if (_currentSpeakerId != null && _currentSpeakerId != speakerId) {
      _messageController.add(MockWebSocketMessage.participantState(
        participantId: _currentSpeakerId!,
        isSpeaking: false,
        isMuted: false,
      ));
    }

    // Set new speaker
    _currentSpeakerId = speakerId;
    _messageController.add(MockWebSocketMessage.participantState(
      participantId: speakerId,
      isSpeaking: true,
      isMuted: false,
      speakingEnergy: 0.5 + (_messageIndex % 5) * 0.1, // Random energy 0.5-0.9
    ));
  }

  /// Dispose of the service
  void dispose() {
    disconnect();
    _messageController.close();
  }
}

/// Singleton instance for app-wide access
class MockWebSocket {
  static final MockWebSocketService _instance = MockWebSocketService();
  
  static MockWebSocketService get instance => _instance;
  
  MockWebSocket._();
}
