import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/websocket/websocket_service.dart';
import '../data/api/api_service.dart';
import '../models/call.dart';
import '../models/live_caption.dart';
import '../models/participant.dart';

class CallProvider with ChangeNotifier {
  static const List<String> _languagePool = ['he', 'en', 'ru'];
  static const List<String> _connectionQualities = ['excellent', 'good', 'fair', 'poor'];
  static const List<String> _mockNames = [
    'Daniel',
    'Emma',
    'Noa',
    'Igor',
    'Amir',
    'Lena',
    'Sasha',
    'Yael',
    'Omer',
    'Svetlana',
  ];
  CallStatus _status = CallStatus.pending;
  List<CallParticipant> _participants = [];
  String? _activeSessionId;
  String _liveTranscription = "המתן, השרת מתרגם..."; // Mock subtitle
  final WebSocketService _wsService = WebSocketService();
  final ApiService _apiService = ApiService();
  StreamSubscription<String>? _wsSub;
  final List<LiveCaptionData> _captionBubbles = [];
  final Map<String, Timer> _bubbleTimers = {};
  final Random _random = Random();
  String? _activeSpeakerId;
  bool _disposed = false;

  CallStatus get status => _status;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  String get liveTranscription => _liveTranscription;
  List<LiveCaptionData> get captionBubbles => List.unmodifiable(_captionBubbles);
  String? get activeSpeakerId => _activeSpeakerId;

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
        displayName: 'Daniel',
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
        displayName: 'Emma',
      ),
      CallParticipant(
        id: 'p3',
        callId: 'c1',
        userId: 'u3',
        targetLanguage: 'ru',
        speakingLanguage: 'en',
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isConnected: true,
        connectionQuality: 'fair',
        isMuted: false,
        displayName: 'Noa',
      ),
      CallParticipant(
        id: 'p4',
        callId: 'c1',
        userId: 'u4',
        targetLanguage: 'en',
        speakingLanguage: 'he',
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
        isConnected: true,
        connectionQuality: 'excellent',
        isMuted: false,
        displayName: 'Igor',
      ),
    ];
    
    // start mock ws
    _wsService.start(_activeSessionId ?? 'mock_session');
    _wsSub = _wsService.messages.listen(_handleRealtimeTranscript);
    notifyListeners();
  }

  /// Starts a real call by calling backend API and connecting to the websocket
  Future<void> startCall(List<String> participantUserIds) async {
    // Call API to start call
    final resp = await _apiService.startCall(participantUserIds);
    final sessionId = resp['session_id'] as String;
    // final wsUrl = resp['websocket_url'] as String; // Ignored for now
    final parts = resp['participants'] as List<dynamic>;

    // Map participants
    _participants = parts.map((p) => CallParticipant.fromJson(Map<String, dynamic>.from(p))).toList();
    _status = CallStatus.active;
    _activeSessionId = sessionId;

    // Connect to WS and listen
    _wsService.start(sessionId);
    _wsSub?.cancel();
    _wsSub = _wsService.messages.listen(_handleRealtimeTranscript);
    notifyListeners();
  }

  void endCall() {
    _status = CallStatus.ended;
    _participants.clear();
    _activeSessionId = null;
    _wsSub?.cancel();
    _wsService.stop();
    _clearBubbles();
    notifyListeners();
  }

  void toggleMute() {
    // Logic to toggle mute would go here
    notifyListeners();
  }

  /// Adds a mock participant to the active call UI for demo purposes.
  /// Returns `true` if a participant was added, otherwise `false`.
  bool addMockParticipant() {
    if (_status != CallStatus.active) return false;
    if (_participants.length >= 6) return false; // keep grid readable

    final speakingLanguage = _languagePool[_random.nextInt(_languagePool.length)];
    String targetLanguage = speakingLanguage;
    while (targetLanguage == speakingLanguage) {
      targetLanguage = _languagePool[_random.nextInt(_languagePool.length)];
    }

    final displayName = _mockNames[_random.nextInt(_mockNames.length)];
    final newParticipant = CallParticipant(
      id: 'p${DateTime.now().millisecondsSinceEpoch}',
      callId: _participants.isNotEmpty ? _participants.first.callId : 'c1',
      userId: 'u${_participants.length + 1}',
      targetLanguage: targetLanguage,
      speakingLanguage: speakingLanguage,
      joinedAt: DateTime.now(),
      createdAt: DateTime.now(),
      isConnected: true,
      connectionQuality: _connectionQualities[_random.nextInt(_connectionQualities.length)],
      isMuted: _random.nextBool(),
      displayName: displayName,
    );

    _participants = [..._participants, newParticipant];
    notifyListeners();
    return true;
  }

  void _handleRealtimeTranscript(String message) {
    if (_participants.isEmpty) return;
    final int index = _random.nextInt(_participants.length);
    final speakerId = _participants[index].id;
    _liveTranscription = message;
    _setActiveSpeaker(speakerId);
    _addCaptionBubble(speakerId, message);
    notifyListeners();
  }

  void _setActiveSpeaker(String? participantId) {
    _activeSpeakerId = participantId;
    _participants = _participants
        .map((participant) => participant.copyWith(
              isSpeaking: participant.id == participantId,
              speakingEnergy: participant.id == participantId
                  ? 0.5 + _random.nextDouble() * 0.5
                  : 0.1,
            ))
        .toList(growable: false);
  }

  void _addCaptionBubble(String participantId, String text) {
    final bubble = LiveCaptionData(
      id: '${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(1000)}',
      participantId: participantId,
      text: text,
    );
    _captionBubbles.add(bubble);
    _bubbleTimers[bubble.id]?.cancel();
    _bubbleTimers[bubble.id] = Timer(const Duration(seconds: 4), () {
      _captionBubbles.removeWhere((item) => item.id == bubble.id);
      _bubbleTimers.remove(bubble.id);
      if (!_disposed) notifyListeners();
    });
  }

  void _clearBubbles() {
    for (final timer in _bubbleTimers.values) {
      timer.cancel();
    }
    _bubbleTimers.clear();
    _captionBubbles.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _wsSub?.cancel();
    _wsService.stop();
    _clearBubbles();
    super.dispose();
  }
}