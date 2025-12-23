import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../data/websocket/websocket_service.dart';
import '../data/api/api_service.dart';
import '../models/call.dart';
import '../models/live_caption.dart';
import '../models/participant.dart';

class CallProvider with ChangeNotifier {
  static const List<String> _languagePool = ['he', 'en', 'ru'];
  static const List<String> _connectionQualities = [
    'excellent',
    'good',
    'fair',
    'poor'
  ];
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
  StreamSubscription<WSMessage>? _wsSub;
  final List<LiveCaptionData> _captionBubbles = [];
  final Map<String, Timer> _bubbleTimers = {};
  final Random _random = Random();
  String? _activeSpeakerId;
  bool _disposed = false;

  // Incoming call state
  Call? _incomingCall;
  CallStatus? _incomingCallStatus;
  Timer? _callTimeoutTimer;
  String? _incomingCallerName;

  CallStatus get status => _status;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  String get liveTranscription => _liveTranscription;
  List<LiveCaptionData> get captionBubbles =>
      List.unmodifiable(_captionBubbles);
  String? get activeSpeakerId => _activeSpeakerId;
  Call? get incomingCall => _incomingCall;
  CallStatus? get incomingCallStatus => _incomingCallStatus;
  String? get incomingCallerName => _incomingCallerName;

  @visibleForTesting
  void setParticipantsForTesting(List<CallParticipant> participants) {
    _participants = participants;
    notifyListeners();
  }

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
    _wsService.connect(_activeSessionId ?? 'mock_session');
    _wsSub = _wsService.messages.listen(_handleWebSocketMessage);
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
    _participants = parts
        .map((p) => CallParticipant.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    _status = CallStatus.active;
    _activeSessionId = sessionId;

    // Connect to WS and listen
    _wsService.connect(sessionId);
    _wsSub?.cancel();
    _wsSub = _wsService.messages.listen(_handleWebSocketMessage);
    notifyListeners();
  }

  void endCall() {
    _status = CallStatus.ended;
    // Ensure we assign a new growable empty list instead of trying to clear
    // a fixed-length list (which may have been set by .toList(growable:false)).
    _participants = [];
    _activeSessionId = null;
    _wsSub?.cancel();
    _wsService.disconnect();
    _clearBubbles();
    notifyListeners();
  }

  void toggleMute() {
    // Logic to toggle mute would go here
    notifyListeners();
  }

  /// Connects to the Lobby websocket to receive real-time updates and incoming calls
  Future<void> connectToLobby({String? token}) async {
    debugPrint('[CallProvider] Connecting to Lobby...');
    _status = CallStatus.idle;
    _activeSessionId = 'lobby';

    // Connect to lobby session
    final success = await _wsService.connect('lobby', token: token);

    if (success) {
      _wsSub?.cancel();
      _wsSub = _wsService.messages.listen(_handleWebSocketMessage);
      debugPrint('[CallProvider] Connected to Lobby successfully');
    } else {
      debugPrint('[CallProvider] Failed to connect to Lobby');
    }
    notifyListeners();
  }

  /// Disconnects from Lobby WebSocket (called on logout)
  void disconnectFromLobby() {
    if (_activeSessionId == 'lobby') {
      debugPrint('[CallProvider] Disconnecting from Lobby...');
      _wsSub?.cancel();
      _wsService.disconnect();
      _activeSessionId = null;
      _status = CallStatus.idle;
      notifyListeners();
      debugPrint('[CallProvider] Disconnected from Lobby');
    }
  }

  /// Adds a mock participant to the active call UI for demo purposes.
  /// Returns `true` if a participant was added, otherwise `false`.
  bool addMockParticipant() {
    if (_status != CallStatus.active) return false;
    if (_participants.length >= 6) return false; // keep grid readable

    final speakingLanguage =
        _languagePool[_random.nextInt(_languagePool.length)];
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
      connectionQuality:
          _connectionQualities[_random.nextInt(_connectionQualities.length)],
      isMuted: _random.nextBool(),
      displayName: displayName,
    );

    _participants = [..._participants, newParticipant];
    notifyListeners();
    return true;
  }

  // Broadcast stream for other providers
  final _eventController = StreamController<WSMessage>.broadcast();
  Stream<WSMessage> get events => _eventController.stream;

  void _handleWebSocketMessage(WSMessage message) {
    // Re-broadcast to external listeners
    if (!_eventController.isClosed) {
      _eventController.add(message);
    }

    // Handle different message types
    switch (message.type) {
      case WSMessageType.transcript:
        if (_participants.isNotEmpty) {
          final text = message.data?['text'] as String? ?? '';
          final speakerId = message.data?['speaker_id'] as String? ??
              _participants[_random.nextInt(_participants.length)].id;
          _liveTranscription = text;
          _setActiveSpeaker(speakerId);
          _addCaptionBubble(speakerId, text);
        }
        break;
      case WSMessageType.participantJoined:
        // Handle participant joined
        break;
      case WSMessageType.participantLeft:
        // Handle participant left
        break;
      case WSMessageType.muteStatusChanged:
        // Handle mute status change
        break;
      case WSMessageType.callEnded:
        endCall();
        break;
      case WSMessageType.incomingCall:
        handleIncomingCall(message);
        break;
      case WSMessageType.userStatusChanged:
        _handleUserStatusChanged(message);
        break;
      case WSMessageType.contactRequest:
        _handleContactRequest(message);
        break;
      case WSMessageType.error:
        debugPrint('[CallProvider] WebSocket error: ${message.data}');
        break;
      default:
        // Handle other message types as needed
        break;
    }
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

  void handleIncomingCall(WSMessage message) {
    final callData = message.data;
    if (callData == null) return;

    try {
      _incomingCall = Call(
        id: callData['call_id'] as String? ?? '',
        sessionId: '', // Will be set when accepted
        status: CallStatus.ringing,
        callLanguage: callData['call_language'] as String? ?? 'he',
        callerUserId: callData['caller_id'] as String?,
        createdBy: callData['caller_id'] as String? ?? '',
        createdAt: DateTime.now(),
      );
      _incomingCallerName = callData['caller_name'] as String?;
      _incomingCallStatus = CallStatus.ringing;
      _startCallTimeout();
      notifyListeners();
    } catch (e) {
      debugPrint('[CallProvider] Error parsing incoming call: $e');
    }
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_incomingCall != null) {
        // Auto-reject after timeout
        rejectIncomingCall();
      }
    });
  }

  Future<void> acceptIncomingCall() async {
    if (_incomingCall == null) return;

    try {
      // Call API to accept - returns CallDetailResponse with session_id
      final callData = await _apiService.acceptCall(_incomingCall!.id);

      final sessionId = callData['session_id'] as String?;
      if (sessionId != null) {
        // Start call normally
        _status = CallStatus.active;
        _activeSessionId = sessionId;

        // Get participants from response
        final parts = callData['participants'] as List<dynamic>?;
        if (parts != null) {
          _participants = parts
              .map(
                  (p) => CallParticipant.fromJson(Map<String, dynamic>.from(p)))
              .toList();
        }

        // Connect to WS and listen
        _wsService.connect(sessionId);
        _wsSub?.cancel();
        _wsSub = _wsService.messages.listen(_handleWebSocketMessage);
      } else {
        throw Exception('No session_id in accept call response');
      }

      _incomingCall = null;
      _incomingCallStatus = null;
      _incomingCallerName = null;
      _callTimeoutTimer?.cancel();
      notifyListeners();
    } catch (e) {
      debugPrint('[CallProvider] Error accepting call: $e');
      // Clear incoming call state on error
      _incomingCall = null;
      _incomingCallStatus = null;
      _incomingCallerName = null;
      _callTimeoutTimer?.cancel();
      notifyListeners();
    }
  }

  Future<void> rejectIncomingCall() async {
    if (_incomingCall == null) return;

    try {
      await _apiService.rejectCall(_incomingCall!.id);
    } catch (e) {
      debugPrint('[CallProvider] Error rejecting call: $e');
    }

    _incomingCall = null;
    _incomingCallStatus = null;
    _incomingCallerName = null;
    _callTimeoutTimer?.cancel();
    notifyListeners();
  }

  /// Get last user status change from WebSocket (cleared after read)
  Map<String, dynamic>? get lastStatusChange {
    final change = _lastStatusChange;
    _lastStatusChange = null; // Clear after read
    return change;
  }

  Map<String, dynamic>? _lastStatusChange;

  void _handleUserStatusChanged(WSMessage message) {
    final data = message.data;
    if (data == null) return;

    final userId = data['user_id'] as String?;
    final isOnline = data['is_online'] as bool?;

    if (userId != null && isOnline != null) {
      _lastStatusChange = {'user_id': userId, 'is_online': isOnline};
      notifyListeners();
    }
  }

  /// Get last contact request (cleared after read)
  Map<String, dynamic>? get lastContactRequest {
    final req = _lastContactRequest;
    _lastContactRequest = null;
    return req;
  }

  Map<String, dynamic>? _lastContactRequest;

  void _handleContactRequest(WSMessage message) {
    if (message.data != null) {
      _lastContactRequest = message.data;
      notifyListeners();
    }
  }

  @override
  @override
  void dispose() {
    _disposed = true;
    _eventController.close();
    _wsSub?.cancel();
    _wsService.disconnect();
    _clearBubbles();
    _callTimeoutTimer?.cancel();
    super.dispose();
  }
}
