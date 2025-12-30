import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/websocket/websocket_service.dart';
import '../data/api/api_service.dart';
import '../models/call.dart';
import '../models/live_caption.dart';
import '../models/participant.dart';
import 'audio_controller.dart';
import 'incoming_call_handler.dart';
import 'caption_manager.dart';

/// Main call state provider.
///
/// Coordinates between:
/// - AudioController for audio I/O
/// - IncomingCallHandler for incoming call state
/// - CaptionManager for live captions
/// - WebSocketService for real-time communication
class CallProvider with ChangeNotifier {
  CallStatus _status = CallStatus.pending;
  List<CallParticipant> _participants = [];
  String? _activeSessionId;
  String _liveTranscription = "";
  String? _activeSpeakerId;

  bool _disposed = false;

  // Services
  final WebSocketService _wsService = WebSocketService();
  final ApiService _apiService = ApiService();
  StreamSubscription<WSMessage>? _wsSub;

  // Helpers
  late final AudioController _audioController;
  late final IncomingCallHandler _incomingCallHandler;
  late final CaptionManager _captionManager;

  // Event stream for other providers
  final _eventController = StreamController<WSMessage>.broadcast();

  CallProvider() {
    _audioController = AudioController(_wsService, notifyListeners);
    _incomingCallHandler = IncomingCallHandler(_apiService, notifyListeners);
    _captionManager = CaptionManager(notifyListeners, () => _disposed);
  }

  // === Getters ===

  CallStatus get status => _status;
  List<CallParticipant> get participants => List.unmodifiable(_participants);
  String get liveTranscription => _liveTranscription;
  List<LiveCaptionData> get captionBubbles => _captionManager.captionBubbles;
  String? get activeSpeakerId => _activeSpeakerId;
  bool get isMuted => _audioController.isMuted;
  bool get isSpeakerOn => _audioController.isSpeakerOn;
  Stream<WSMessage> get events => _eventController.stream;

  // Incoming call getters
  Call? get incomingCall => _incomingCallHandler.incomingCall;
  CallStatus? get incomingCallStatus => _incomingCallHandler.incomingCallStatus;
  String? get incomingCallerName => _incomingCallHandler.incomingCallerName;

  // === Testing helpers ===

  @visibleForTesting
  void setParticipantsForTesting(List<CallParticipant> participants) {
    _participants = participants;
    notifyListeners();
  }

  @visibleForTesting
  void setStatusForTesting(CallStatus status) {
    _status = status;
    notifyListeners();
  }

  // === Call Lifecycle ===

  /// Starts a real call by calling backend API and connecting to WebSocket
  Future<void> startCall(List<String> participantUserIds) async {
    final resp = await _apiService.startCall(participantUserIds);
    final sessionId = resp['session_id'] as String;
    final parts = resp['participants'] as List<dynamic>;

    _participants = parts
        .map((p) => CallParticipant.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    _status = CallStatus.active;
    _activeSessionId = sessionId;

    // Connect to WS
    await _wsSub?.cancel();
    await _wsService.connect(sessionId);
    _wsSub = _wsService.messages.listen(_handleWebSocketMessage);

    // Initialize Audio
    await _audioController.initAudio();

    notifyListeners();
  }

  void endCall() {
    debugPrint('[CallProvider] endCall called');
    _audioController.dispose();
    _status = CallStatus.ended;
    _participants = [];
    _activeSessionId = null;
    _wsSub?.cancel();
    _wsService.disconnect();
    _captionManager.clearBubbles();
    notifyListeners();
  }

  // === Audio Controls ===

  void toggleMute() => _audioController.toggleMute();

  Future<void> toggleSpeaker() => _audioController.toggleSpeaker();

  // === Lobby Connection ===

  /// Connects to the Lobby WebSocket to receive real-time updates
  Future<void> connectToLobby({String? token}) async {
    debugPrint('[CallProvider] Connecting to Lobby...');
    _status = CallStatus.idle;
    _activeSessionId = 'lobby';

    final success = await _wsService.connect('lobby', token: token);

    if (success) {
      _wsSub?.cancel();
      _wsSub = _wsService.messages.listen(_handleWebSocketMessage);
      debugPrint('[CallProvider] Connected to Lobby');
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
    }
  }

  // === Incoming Call Handling ===

  void handleIncomingCall(WSMessage message) {
    _incomingCallHandler.handleIncomingCall(message.data);
  }

  Future<void> acceptIncomingCall() async {
    final callData = await _incomingCallHandler.acceptIncomingCall();
    if (callData == null) return;

    final sessionId = callData['session_id'] as String?;
    if (sessionId != null) {
      _status = CallStatus.active;
      _activeSessionId = sessionId;

      final parts = callData['participants'] as List<dynamic>?;
      if (parts != null) {
        _participants = parts
            .map((p) => CallParticipant.fromJson(Map<String, dynamic>.from(p)))
            .toList();
      }

      await _wsSub?.cancel();
      await _wsService.connect(sessionId);
      _wsSub = _wsService.messages.listen(_handleWebSocketMessage);
      await _audioController.initAudio();
    }
    notifyListeners();
  }

  Future<void> rejectIncomingCall() =>
      _incomingCallHandler.rejectIncomingCall();

  // === WebSocket Message Handling ===

  void _handleWebSocketMessage(WSMessage message) {
    if (!_eventController.isClosed) {
      _eventController.add(message);
    }

    switch (message.type) {
      case WSMessageType.transcript:
        _handleTranscript(message);
        break;
      case WSMessageType.participantJoined:
        _handleParticipantJoined(message);
        break;
      case WSMessageType.participantLeft:
        break;
      case WSMessageType.muteStatusChanged:
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
        break;
    }
    notifyListeners();
  }

  void _handleTranscript(WSMessage message) {
    if (_participants.isEmpty) return;
    final text = message.data?['text'] as String? ?? '';
    final speakerId = message.data?['speaker_id'] as String?;
    if (speakerId != null) {
      _liveTranscription = text;
      _setActiveSpeaker(speakerId);
      _captionManager.addCaptionBubble(speakerId, text);
    }
  }

  void _setActiveSpeaker(String? participantId) {
    _activeSpeakerId = participantId;
    _participants = _participants
        .map((p) => p.copyWith(isSpeaking: p.id == participantId))
        .toList(growable: false);
  }

  void _handleParticipantJoined(WSMessage message) {
    if (message.data == null) return;

    final userId = message.data!['user_id'] as String?;
    if (userId == null) return;

    try {
      final index = _participants.indexWhere((p) => p.userId == userId);
      if (index != -1) {
        var p = _participants[index];
        final updatedParticipant = CallParticipant(
          id: p.id,
          callId: p.callId,
          userId: p.userId,
          targetLanguage: p.targetLanguage,
          speakingLanguage: p.speakingLanguage,
          joinedAt: DateTime.now(),
          createdAt: p.createdAt,
          isConnected: true,
          connectionQuality: p.connectionQuality,
          isMuted: p.isMuted,
          displayName: p.displayName,
        );

        final newList = List<CallParticipant>.from(_participants);
        newList[index] = updatedParticipant;
        _participants = newList;
        notifyListeners();
        debugPrint('[CallProvider] Participant $userId marked as connected');
      }
    } catch (e) {
      debugPrint('[CallProvider] Error handling participant join: $e');
    }
  }

  // === Status Change Handling ===

  Map<String, dynamic>? _lastStatusChange;
  Map<String, dynamic>? get lastStatusChange {
    final change = _lastStatusChange;
    _lastStatusChange = null;
    return change;
  }

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

  Map<String, dynamic>? _lastContactRequest;
  Map<String, dynamic>? get lastContactRequest {
    final req = _lastContactRequest;
    _lastContactRequest = null;
    return req;
  }

  void _handleContactRequest(WSMessage message) {
    if (message.data != null) {
      _lastContactRequest = message.data;
      notifyListeners();
    }
  }

  // === Dispose ===

  @override
  void dispose() {
    _disposed = true;
    _eventController.close();
    _wsSub?.cancel();
    _wsService.disconnect();
    _captionManager.dispose();
    _incomingCallHandler.dispose();
    super.dispose();
  }
}
